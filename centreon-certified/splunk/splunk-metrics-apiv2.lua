#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker Splunk Connector Events
--------------------------------------------------------------------------------

-- Libraries
local curl = require "cURL"
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_metrics = require("centreon-stream-connectors-lib.sc_metrics")
local sc_flush = require("centreon-stream-connectors-lib.sc_flush")
local sc_params = require("centreon-stream-connectors-lib.sc_params")

--------------------------------------------------------------------------------
-- Classe event_queue
--------------------------------------------------------------------------------

local EventQueue = {}
EventQueue.__index = EventQueue

--------------------------------------------------------------------------------
---- Constructor
---- @param conf The table given by the init() function and returned from the GUI
---- @return the new EventQueue
----------------------------------------------------------------------------------

function EventQueue.new(params)
  local self = {}

  local mandatory_parameters = {
    "http_server_url",
    "splunk_token"
  }

  self.fail = false

  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/splunk-metrics.log"
  local log_level = params.log_level or 3
  
  -- initiate mandatory objects
  self.sc_logger = sc_logger.new(logfile, log_level)
  self.sc_common = sc_common.new(self.sc_logger)
  self.sc_broker = sc_broker.new(self.sc_logger)
  self.sc_params = sc_params.new(self.sc_common, self.sc_logger)
  
  -- checking mandatory parameters and setting a fail flag
  if not self.sc_params:is_mandatory_config_set(mandatory_parameters, params) then
    self.fail = true
  end
  
  -- overriding default parameters for this stream connector if the default values doesn't suit the basic needs
  self.sc_params.params.splunk_index = params.splunk_index or ""
  self.sc_params.params.splunk_source = params.splunk_source or ""
  self.sc_params.params.splunk_sourcetype = params.splunk_sourcetype or "_json"
  self.sc_params.params.splunk_host = params.splunk_host or "Central"
  self.sc_params.params.accepted_categories = params.accepted_categories or "neb"
  self.sc_params.params.accepted_elements = params.accepted_elements or "host_status,service_status"
  self.sc_params.params.max_buffer_size = params.max_buffer_size or 30
  self.sc_params.params.hard_only = params.hard_only or 0
  self.sc_params.params.enable_host_status_dedup = params.enable_host_status_dedup or 0
  self.sc_params.params.enable_service_status_dedup = params.enable_service_status_dedup or 0
  self.sc_params.params.metric_name_regex = params.metric_name_regex or "[^a-zA-Z0-9_]"
  self.sc_params.params.metric_replacement_character = params.metric_replacement_character or "_"
  
  -- apply users params and check syntax of standard ones
  self.sc_params:param_override(params)
  self.sc_params:check_params()

  -- only load the custom code file, not executed yet
  if self.sc_params.load_custom_code_file and not self.sc_params:load_custom_code_file(self.sc_params.params.custom_code_file) then
    self.sc_logger:error("[EventQueue:new]: couldn't successfully load the custom code file: " .. tostring(self.sc_params.params.custom_code_file))
  end

  self.sc_params:build_accepted_elements_info()
  
  self.sc_flush = sc_flush.new(self.sc_params.params, self.sc_logger)

  local categories = self.sc_params.params.bbdo.categories
  local elements = self.sc_params.params.bbdo.elements

  self.format_event = {
    [categories.neb.id] = {
      [elements.host_status.id] = function () return self:format_event_host() end,
      [elements.service_status.id] = function () return self:format_event_service() end
    }
  }

  self.format_metric = {
    [categories.neb.id] = {
      [elements.host_status.id] = function (metric) return self:format_metric_host(metric) end,
      [elements.service_status.id] = function (metric) return self:format_metric_service(metric) end
    }
  }

  self.send_data_method = {
    [1] = function (payload, queue_metadata) return self:send_data(payload, queue_metadata) end
  }

  self.build_payload_method = {
    [1] = function (payload, event) return self:build_payload(payload, event) end
  }

  -- return EventQueue object
  setmetatable(self, { __index = EventQueue })
  return self
end

--------------------------------------------------------------------------------
---- EventQueue:format_event method
----------------------------------------------------------------------------------
function EventQueue:format_accepted_event()
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element
  self.sc_logger:debug("[EventQueue:format_event]: starting format event")

  -- can't format event if stream connector is not handling this kind of event
  if not self.format_event[category][element] then
    self.sc_logger:error("[format_event]: You are trying to format an event with category: "
      .. tostring(self.sc_params.params.reverse_category_mapping[category]) .. " and element: "
      .. tostring(self.sc_params.params.reverse_element_mapping[category][element])
      .. ". If it is a not a misconfiguration, you can open an issue at https://github.com/centreon/centreon-stream-connector-scripts/issues")
  else
    self.sc_logger:debug("[EventQueue:format_event]: going to format it")
    self.format_event[category][element]()
  end

  self.sc_logger:debug("[EventQueue:format_event]: event formatting is finished")
end


--------------------------------------------------------------------------------
---- EventQueue:format_event_host method
--------------------------------------------------------------------------------
function EventQueue:format_event_host()
  local event = self.sc_event.event

  self.sc_event.event.formated_event = {
    event_type = "host",
    state = event.state,
    state_type = event.state_type,
    hostname = event.cache.host.name,
    ctime = event.last_check
  }

  self.sc_logger:debug("[EventQueue:format_event_host]: call build_metric ")
  self.sc_metrics:build_metric(self.format_metric[event.category][event.element])
end

--------------------------------------------------------------------------------
---- EventQueue:format_event_service method
--------------------------------------------------------------------------------
function EventQueue:format_event_service()
  local event = self.sc_event.event
  
  self.sc_event.event.formated_event = {
    event_type = "service",
    state = event.state,
    state_type = event.state_type,
    hostname = event.cache.host.name,
    service_description = event.cache.service.description,
    ctime = event.last_check
  }
  
  self.sc_logger:debug("[EventQueue:format_event_service]: call build_metric ")
  self.sc_metrics:build_metric(self.format_metric[event.category][event.element])
end

--------------------------------------------------------------------------------
---- EventQueue:format_metric_host method
-- @param metric {table} a single metric data
--------------------------------------------------------------------------------
function EventQueue:format_metric_host(metric)
  self.sc_logger:debug("[EventQueue:format_metric_host]: call format_metric ")
  self:format_metric_event(metric)
end

--------------------------------------------------------------------------------
---- EventQueue:format_metric_service method
-- @param metric {table} a single metric data
--------------------------------------------------------------------------------
function EventQueue:format_metric_service(metric)
  self.sc_logger:debug("[EventQueue:format_metric_service]: call format_metric ")
  self:format_metric_event(metric)
end

--------------------------------------------------------------------------------
---- EventQueue:build_metadata method
-- @param metric {table} a single metric data
-- @return tags {table} a table with formated metadata 
--------------------------------------------------------------------------------
function EventQueue:format_metric_event(metric)
  self.sc_logger:debug("[EventQueue:format_metric]: start real format metric ")
  self.sc_event.event.formated_event["metric_name:" .. tostring(metric.metric_name)] = metric.value

  -- add metric instance in tags
  if metric.instance ~= "" then
    self.sc_event.event.formated_event["instance"] = metric.instance
  end

  if metric.subinstance[1] then
    self.sc_event.event.formated_event["subinstances"] = metric.subinstance
  end

  self:add()
  self.sc_logger:debug("[EventQueue:format_metric]: end real format metric ")
end

--------------------------------------------------------------------------------
-- EventQueue:add, add an event to the sending queue
--------------------------------------------------------------------------------
function EventQueue:add()
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element

  self.sc_logger:debug("[EventQueue:add]: add event in queue category: " .. tostring(self.sc_params.params.reverse_category_mapping[category])
    .. " element: " .. tostring(self.sc_params.params.reverse_element_mapping[category][element]))

  self.sc_logger:debug("[EventQueue:add]: queue size before adding event: " .. tostring(#self.sc_flush.queues[category][element].events))

  self.sc_flush.queues[category][element].events[#self.sc_flush.queues[category][element].events + 1] = {
    sourcetype = self.sc_params.params.splunk_sourcetype,
    source = self.sc_params.params.splunk_source,
    index = self.sc_params.params.splunk_index,
    host = self.sc_params.params.splunk_host,
    time = self.sc_event.event.last_check,
    fields = self.sc_event.event.formated_event
  }

  self.sc_logger:info("[EventQueue:add]: queue size is now: " .. tostring(#self.sc_flush.queues[category][element].events) 
    .. "max is: " .. tostring(self.sc_params.params.max_buffer_size))
end

--------------------------------------------------------------------------------
-- EventQueue:build_payload, concatenate data so it is ready to be sent
-- @param payload {string} json encoded string
-- @param event {table} the event that is going to be added to the payload
-- @return payload {string} json encoded string
--------------------------------------------------------------------------------
function EventQueue:build_payload(payload, event)
  if not payload then
    payload = broker.json_encode(event)
  else
    payload = payload .. broker.json_encode(event)
  end
  
  return payload
end

function EventQueue:send_data(payload, queue_metadata)
  self.sc_logger:debug("[EventQueue:send_data]: Starting to send data")

  -- write payload in the logfile for test purpose
  if self.sc_params.params.send_data_test == 1 then
    self.sc_logger:notice("[send_data]: " .. tostring(payload))
    return true
  end

  self.sc_logger:info("[EventQueue:send_data]: Going to send the following json " .. tostring(payload))
  self.sc_logger:info("[EventQueue:send_data]: Splunk address is: " .. tostring(self.sc_params.params.http_server_url))

  local http_response_body = ""
  local http_request = curl.easy()
    :setopt_url(self.sc_params.params.http_server_url)
    :setopt_writefunction(
      function (response)
        http_response_body = http_response_body .. tostring(response)
      end
    )
    :setopt(curl.OPT_TIMEOUT, self.sc_params.params.connection_timeout)
    :setopt(curl.OPT_SSL_VERIFYPEER, self.sc_params.params.allow_insecure_connection)
    :setopt(
      curl.OPT_HTTPHEADER,
      {
        "content-type: application/json",
        "content-length:" .. string.len(payload),
        "authorization: Splunk " .. self.sc_params.params.splunk_token,
      }
  )

  -- set proxy address configuration
  if (self.sc_params.params.proxy_address ~= '') then
    if (self.sc_params.params.proxy_port ~= '') then
      http_request:setopt(curl.OPT_PROXY, self.sc_params.params.proxy_address .. ':' .. self.sc_params.params.proxy_port)
    else 
      self.sc_logger:error("[EventQueue:send_data]: proxy_port parameter is not set but proxy_address is used")
    end
  end

  -- set proxy user configuration
  if (self.sc_params.params.proxy_username ~= '') then
    if (self.sc_params.params.proxy_password ~= '') then
      http_request:setopt(curl.OPT_PROXYUSERPWD, self.sc_params.params.proxy_username .. ':' .. self.sc_params.params.proxy_password)
    else
      broker_log:error("[EventQueue:send_data]: proxy_password parameter is not set but proxy_username is used")
    end
  end

  -- adding the HTTP POST data
  http_request:setopt_postfields(payload)

  -- performing the HTTP request
  http_request:perform()
  
  -- collecting results
  http_response_code = http_request:getinfo(curl.INFO_RESPONSE_CODE) 

  http_request:close()
  
  -- Handling the return code
  local retval = false
  if http_response_code == 200 then
    self.sc_logger:info("[EventQueue:send_data]: HTTP POST request successful: return code is " .. tostring(http_response_code))
    retval = true
  else
    self.sc_logger:error("[EventQueue:send_data]: HTTP POST request FAILED, return code is " .. tostring(http_response_code) .. ". Message is: " .. tostring(http_response_body))
  end
  
  return retval
end

--------------------------------------------------------------------------------
-- Required functions for Broker StreamConnector
--------------------------------------------------------------------------------

local queue

-- Fonction init()
function init(conf)
  queue = EventQueue.new(conf)
end

-- --------------------------------------------------------------------------------
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
  queue.sc_metrics = sc_metrics.new(event, queue.sc_params.params, queue.sc_common, queue.sc_broker, queue.sc_logger)
  queue.sc_event = queue.sc_metrics.sc_event

  if queue.sc_event:is_valid_category() then
    if queue.sc_metrics:is_valid_bbdo_element() then
      -- format event if it is validated
      if queue.sc_metrics:is_valid_metric_event() then
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
