#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker Splunk Connector Events
--------------------------------------------------------------------------------


-- Libraries
local curl      = require("cURL")
local mime      = require("mime")
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_event  = require("centreon-stream-connectors-lib.sc_event")
local sc_params = require("centreon-stream-connectors-lib.sc_params")
local sc_macros = require("centreon-stream-connectors-lib.sc_macros")
local sc_flush  = require("centreon-stream-connectors-lib.sc_flush")


--------------------------------------------------------------------------------
-- Local functions
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Classe event_queue
--------------------------------------------------------------------------------

local event_queue = {}
event_queue.__index = event_queue

--------------------------------------------------------------------------------
---- Constructor
---- @param conf The table given by the init() function and returned from the GUI
---- @return the new event_queue
----------------------------------------------------------------------------------

function event_queue.new(params)
  local self = {}

  local mandatory_parameters = {
  }

  self.fail = false

  -- set up log configuration
  local logfile   = params.logfile or "/var/log/centreon-broker/prometheus-pushgateway-v2-events.log"
  local log_level = params.log_level or 1
  
  -- initiate mandatory objects
  self.sc_logger = sc_logger.new(logfile, log_level)
  self.sc_common = sc_common.new(self.sc_logger)
  self.sc_broker = sc_broker.new(self.sc_logger)
  self.sc_params = sc_params.new(self.sc_common, self.sc_logger)
  
  -- checking mandatory parameters and setting a fail flag
  if not self.sc_params:is_mandatory_config_set(mandatory_parameters, params) then
    self.fail = true
  end

  params.max_buffer_size = 1
  
  -- overriding default parameters for this stream connector if the default values doesn't suit the basic needs
  self.sc_params.params.accepted_categories           = params.accepted_categories or "neb"
  self.sc_params.params.accepted_elements             = params.accepted_elements or "host_status,service_status"
  self.sc_params.params.metric_name_regex             = params.metric_name_regex or '[^a-zA-Z0-9_:]'
  self.sc_params.params.metric_replacement_character  = params.metric_replacement_character or '_'
  self.sc_params.params.enable_host_status_dedup      = params.enable_host_status_dedup or 1
  self.sc_params.params.enable_service_status_dedup   = params.enable_service_status_dedup or 1

  -- prometheus specific parameters
  self.sc_params.params.prometheus_url         = params.prometheus_url or "http://127.0.0.1:9091"
  self.sc_params.params.http_timeout           = params.http_timeout or 30
  self.sc_params.params.prometheus_gateway_job = params.prometheus_gateway_job or "monitoring"
  -- force max_buffer_size to 1 because we each service is sent to its own url
  
  -- apply users params and check syntax of standard ones
  self.sc_params:param_override(params)
  self.sc_params:check_params()
  
  self.sc_macros = sc_macros.new(self.sc_params.params, self.sc_logger)
  self.format_template = self.sc_params:load_event_format_file()

  -- only load the custom code file, not executed yet
  if self.sc_params.load_custom_code_file and not self.sc_params:load_custom_code_file(self.sc_params.params.custom_code_file) then
    self.sc_logger:error("[event_queue:new]: couldn't successfully load the custom code file: " .. tostring(self.sc_params.params.custom_code_file))
  end

  self.sc_params:build_accepted_elements_info()
  self.sc_flush = sc_flush.new(self.sc_params.params, self.sc_logger)

  local categories = self.sc_params.params.bbdo.categories
  local elements = self.sc_params.params.bbdo.elements

  self.format_event = {
    [categories.neb.id] = {
      [elements.host_status.id] = function () return self:format_event_host() end,
      [elements.service_status.id] = function () return self:format_event_service() end
    },
    [categories.bam.id] = {}
  }

  self.send_data_method = {
    [1] = function (payload, queue_metadata) return self:send_data(payload, queue_metadata) end
  }

  self.build_payload_method = {
    [1] = function (payload, event) return self:build_payload(payload, event) end
  }

  -- return event_queue object
  setmetatable(self, { __index = event_queue })
  return self
end

--------------------------------------------------------------------------------
---- event_queue:format_event method
----------------------------------------------------------------------------------
function event_queue:format_accepted_event()
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element
  local template = self.sc_params.params.format_template[category][element]
  self.sc_logger:debug("[event_queue:format_event]: starting format event")
  self.sc_event.event.formated_event = {}

  if self.format_template and template ~= nil and template ~= "" then
    for index, value in pairs(template) do
      self.sc_event.event.formated_event[index] = self.sc_macros:replace_sc_macro(value, self.sc_event.event)
    end
  else
    -- can't format event if stream connector is not handling this kind of event and that it is not handled with a template file
    if not self.format_event[category][element] then
      self.sc_logger:error("[format_event]: You are trying to format an event with category: "
        .. tostring(self.sc_params.params.reverse_category_mapping[category]) .. " and element: "
        .. tostring(self.sc_params.params.reverse_element_mapping[category][element])
        .. ". If it is a not a misconfiguration, you should create a format file to handle this kind of element")
    else
      self.format_event[category][element]()
    end
  end

  self:add()
  self.sc_logger:debug("[event_queue:format_event]: event formatting is finished")
end

function event_queue:format_event_host()
  self.sc_logger:debug("[event_queue:format_event_host]: starting format event host.")

  local event = self.sc_event.event
  local hname = event.cache.host.name
  local sdesc = "host"

  local name = string.gsub(hname .. '_' .. sdesc .. ':monitoring_status', self.sc_params.params.metric_name_regex, self.sc_params.params.metric_replacement_character)

  local data = '# TYPE ' .. name .. ' counter\n'
  data = data .. '# HELP ' .. name .. ' 0 is OK, 1 or higher is DOWN\n'
  if not event.hostgroups_label then
    data = data .. name .. '{label="monitoring_status", host="' .. hname .. '", service="' .. sdesc .. '"} ' .. event.state .. '\n'
  else
    data = data .. name .. '{label="monitoring_status", host="' .. hname .. '", service="' .. sdesc .. '", ' ..  event.hostgroups_label .. '} ' .. event.state .. '\n'
  end

  event.formated_event = {
    event_type          = "host",
    prom_hname          = event.cache.host.name,
    prom_sdesc          = sdesc,
    prom_sdesc_url      = mime.b64(sdesc),
    state               = event.state,
    state_type          = event.state_type,
    hostname            = hname,
    service_description = sdesc,
    output              = event.output,
    formatted_payload   = data
  }

end

function event_queue:format_event_service()
  self.sc_logger:debug("[event_queue:format_event_service]: starting format event service.")

  local event = self.sc_event.event
  local hname = event.cache.host.name
  local sdesc = event.cache.service.description

  local name = string.gsub(hname .. '_' .. sdesc .. ':monitoring_status', self.sc_params.params.metric_name_regex, self.sc_params.params.metric_replacement_character)

  local data = '# TYPE ' .. name .. ' counter\n'
  data = data .. '# HELP ' .. name .. ' 0 is OK, 1 is WARNING, 2 is CRITICAL, 3 or higher is UNKNOWN\n'
  if not event.hostgroups_label then
    data = data .. name .. '{label="monitoring_status", host="' .. hname .. '", service="' .. sdesc .. '"} ' .. event.state .. '\n'
  else
    data = data .. name .. '{label="monitoring_status", host="' .. hname .. '", service="' .. sdesc .. '", ' ..  event.hostgroups_label .. '} ' .. event.state .. '\n'
  end

  event.formated_event = {
    event_type          = "service",
    prom_hname          = event.cache.host.name,
    prom_sdesc          = sdesc,
    prom_sdesc_url      = mime.b64(sdesc),
    state               = event.state,
    state_type          = event.state_type,
    hostname            = hname,
    service_description = sdesc,
    output              = event.output,
    formatted_payload   = data
  }
end

--------------------------------------------------------------------------------
-- event_queue:add, add an event to the sending queue
--------------------------------------------------------------------------------
function event_queue:add()
  -- store event in self.events lists
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element

  self.sc_logger:debug("[event_queue:add]: add event in queue category: " .. tostring(self.sc_params.params.reverse_category_mapping[category])
    .. " element: " .. tostring(self.sc_params.params.reverse_element_mapping[category][element]))

  self.sc_logger:debug("[event_queue:add]: queue size before adding event: " .. tostring(#self.sc_flush.queues[category][element].events))
  self.sc_flush.queues[category][element].events[#self.sc_flush.queues[category][element].events + 1] = self.sc_event.event.formated_event

  self.sc_logger:info("[event_queue:add]: queue size is now: " .. tostring(#self.sc_flush.queues[category][element].events) 
    .. ", max is: " .. tostring(self.sc_params.params.max_buffer_size))
end

--------------------------------------------------------------------------------
-- event_queue:build_payload, concatenate data so it is ready to be sent
-- @param payload {string} json encoded string
-- @param event {table} the event that is going to be added to the payload
-- @return payload {string} json encoded string
--------------------------------------------------------------------------------
function event_queue:build_payload(payload, event)
  if not payload then
    payload = event
  else
    self.sc_logger:error("[event_queue:build_payload]: payload should be nil at this point.")
    table.insert(payload, event)
  end
  
  return payload
end


function event_queue:send_data(payload, queue_metadata)
  self.sc_logger:debug("[event_queue:send_data]: Starting to send data")
  --self.sc_logger:warning("[event_queue:send_data]: payload: " .. self.sc_common:dumper(payload))
  
  local http_response_body = ""
  local label = "status"
  local url = self.sc_params.params.prometheus_url .. '/metrics/job/' .. self.sc_params.params.prometheus_gateway_job .. '/instance/' .. payload.prom_hname .. '/service@base64/' .. payload.prom_sdesc_url

  queue_metadata.headers = { "content-type: application/openmetrics-text" }

  local http_request = curl.easy()
  :setopt_url(url)
  :setopt_writefunction(
    function (response)
      http_response_body = http_response_body .. tostring(response)
    end
  )
  :setopt(curl.OPT_TIMEOUT, self.sc_params.params.http_timeout)
  :setopt(
    curl.OPT_HTTPHEADER,
    queue_metadata.headers
  )

  -- set proxy address configuration
  if (self.sc_params.params.proxy_address and self.sc_params.params.proxy_address ~= '') then
    if (self.sc_params.params.proxy_port and self.sc_params.params.proxy_port ~= '') then
      http_request:setopt(curl.OPT_PROXY, self.sc_params.params.proxy_address .. ':' .. self.sc_params.params.proxy_port)
    else
      self.sc_logger:error("event_queue:send_data: proxy_port parameter is not set but proxy_address is used")
    end
  end

  -- set proxy user configuration
  if (self.sc_params.params.proxy_username ~= '') then
    if (self.sc_params.params.proxy_password ~= '') then
      http_request:setopt(curl.OPT_PROXYUSERPWD, self.sc_params.params.proxy_username .. ':' .. self.sc_params.params.proxy_password)
    else
      self.sc_logger:error("event_queue:send_data: proxy_password parameter is not set but proxy_username is used")
    end
  end

  -- write payload in the logfile for test purpose
  if self.sc_params.params.send_data_test == 1 then
    self.sc_logger:notice("[send_data]: " .. tostring(payload.formatted_payload))
    return true
  end
  -- adding the HTTP POST data
  http_request:setopt_postfields(payload.formatted_payload)

  -- log the curl command for troubleshooting
  self.sc_logger:log_curl_command(url, queue_metadata, self.sc_params.params, payload.formatted_payload)

  -- performing the HTTP request
  http_request:perform()

  -- collecting results
  local http_response_code = http_request:getinfo(curl.INFO_RESPONSE_CODE)

  http_request:close()

  -- Handling the return code
  local retval = false
  if http_response_code == 200 then
    self.sc_logger:info("event_queue:send_data: HTTP POST request successful: return code is " .. http_response_code)
    -- now that the data has been sent, we empty the events array
    self.events = {}
    retval = true
  else
    self.sc_logger:error("event_queue:send_data: HTTP POST request FAILED, return code is " .. http_response_code .. " message is:\n\"" .. tostring(http_response_body) .. "\n\"\n")
    self.sc_logger:error("the body request " .. payload.formatted_payload)
  end


  self.sc_logger:debug("[event_queue:send_data]: End")
  
  return retval
end

--------------------------------------------------------------------------------
-- Required functions for Broker StreamConnector
--------------------------------------------------------------------------------

local queue

-- Fonction init()
function init(conf)
  queue = event_queue.new(conf)
end

--------------------------------------------------------------------------------
-- write,
-- @param {table} event, the event from broker
-- @return {boolean}
--------------------------------------------------------------------------------
function write (event)
  -- skip event if a mandatory parameter is missing
  if queue.fail then
    queue.sc_logger:error("Skipping event because a mandatory parameter is not set")
    return false
  end

  -- initiate event object
  queue.sc_event = sc_event.new(event, queue.sc_params.params, queue.sc_common, queue.sc_logger, queue.sc_broker)
  if queue.sc_event:is_valid_category() then
    if queue.sc_event:is_valid_element() then
      -- format event if it is validated
      if queue.sc_event:is_valid_event() then
        queue:format_accepted_event()
      end
  --- log why the event has been dropped 
    else
      queue.sc_logger:debug("dropping event because element is not valid. Event element is: "
        .. tostring(queue.sc_params.params.reverse_element_mapping[queue.sc_event.event.category][queue.sc_event.event.element]))
    end    
  else
    queue.sc_logger:debug("dropping event because category is not valid. Event category is: "
      .. tostring(queue.sc_params.params.reverse_category_mapping[queue.sc_event.event.category]))
  end
  
  return flush()
end

-- flush method is called by broker every now and then (more often when broker has nothing else to do)
function flush()
  local queues_size = queue.sc_flush:get_queues_size()
  
  -- nothing to flush
  if queues_size == 0 then
    return true
  end

  -- flush all queues because last global flush is too old
  if queue.sc_flush.last_global_flush < os.time() - queue.sc_params.params.max_all_queues_age then
    if not queue.sc_flush:flush_all_queues(queue.build_payload_method[1], queue.send_data_method[1]) then
      return false
    end

    return true
  end

  -- flush queues because too many events are stored in them
  if queues_size > queue.sc_params.params.max_buffer_size then
    if not queue.sc_flush:flush_all_queues(queue.build_payload_method[1], queue.send_data_method[1]) then
      return false
    end

    return true
  end

  -- there are events in the queue but they were not ready to be send
  return false
end
