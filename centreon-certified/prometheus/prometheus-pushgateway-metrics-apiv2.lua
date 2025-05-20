#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker Datadog Connector Events
--------------------------------------------------------------------------------


-- Libraries
local curl        = require("cURL")
local mime        = require("mime")
local sc_common   = require("centreon-stream-connectors-lib.sc_common")
local sc_logger   = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker   = require("centreon-stream-connectors-lib.sc_broker")
local sc_event    = require("centreon-stream-connectors-lib.sc_event")
local sc_params   = require("centreon-stream-connectors-lib.sc_params")
local sc_macros   = require("centreon-stream-connectors-lib.sc_macros")
local sc_flush    = require("centreon-stream-connectors-lib.sc_flush")
local sc_metrics  = require("centreon-stream-connectors-lib.sc_metrics")


--------------------------------------------------------------------------------
-- Local functions
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- unit_mapping: convert perfdata units to openmetrics standard
-- @param {string} unit, the unit value
-- @return {string} unit, the openmetrics unit name
-- @return {boolean}, true if the unit is found in the mapping or empty
--------------------------------------------------------------------------------
local function unit_mapping (unit)
  local unitMapping = {
    s = 'seconds',
    m = 'meters',
    B = 'bytes',
    g = 'grams',
    V = 'volts',
    A = 'amperes',
    K = 'kelvins',
    ["%"] = 'ratios',
    ["°"] = 'celsius',
    ["€"] = 'euros'
  }

  local unhandledUnit = nil

  if unit == nil or unit == '' or type(unit) ~= 'string' then
    unit = ''
  end

if unitMapping[unit] then
  unit = unitMapping[unit]
end

  return unit, true
end

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
  local logfile   = params.logfile or "/var/log/centreon-broker/prometheus-pushgateway-v2-metrics.log"
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
  self.sc_params.params.accepted_elements             = params.accepted_elements or "service_status"
  self.sc_params.params.metric_name_regex             = params.metric_name_regex or '[^a-zA-Z0-9_:]'
  self.sc_params.params.metric_replacement_character  = params.metric_replacement_character or '_'

  -- prometheus specific parameters
  self.sc_params.params.prometheus_url              = params.prometheus_url or "http://127.0.0.1:9091"
  self.sc_params.params.http_timeout                = params.http_timeout or 30
  self.sc_params.params.prometheus_gateway_job      = params.prometheus_gateway_job or "monitoring"
  self.sc_params.params.enable_extended_metric_name = params.enable_extended_metric_name or 1

  -- apply users params and check syntax of standard ones
  self.sc_params:param_override(params)
  self.sc_params:check_params()

  -- in order to have the proper use of that max_buffer_size param, we need to separate queues for hosts and services
  self.sc_params.params.send_mixed_events = 0

  self.sc_macros = sc_macros.new(self.sc_params.params, self.sc_logger)

  -- only load the custom code file, not executed yet
  if self.sc_params.load_custom_code_file and not self.sc_params:load_custom_code_file(self.sc_params.params.custom_code_file) then
    self.sc_logger:error("[event_queue:new]: couldn't successfully load the custom code file: " .. tostring(self.sc_params.params.custom_code_file))
  end

  self.sc_params:build_accepted_elements_info()
  self.sc_flush = sc_flush.new(self.sc_params.params, self.sc_logger)

  local categories = self.sc_params.params.bbdo.categories
  local elements   = self.sc_params.params.bbdo.elements

  -- it is not possible to have a payload containing metrics from different hosts or services.
  -- therefore, we need to check if the metric that we are working on belongs to the same host/service than the previous metric
  -- that's why we initiate a structure to store this info
  self.previous_info = {
    [categories.neb.id] = {
      [elements.host_status.id] = {
        host_id = "",
        flush_success = false
      },
      [elements.service_status.id] = {
        host_id = "",
        service_id = "",
        flush_success = false
      }
    }
  }

  self.format_event = {
    [categories.neb.id] = {
      [elements.host_status.id]    = function () return self:format_event_host() end,
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

  -- those sleep counters will avoid log spam and connection spam
  self.send_data_sleep_counter = self.sc_common:create_sleep_counter_table({}, 0, 300, 10)
  self.init_fail_sleep_counter = self.sc_common:create_sleep_counter_table({}, 0, 300, 10)

  -- return event_queue object
  setmetatable(self, { __index = event_queue })
  return self
end

--------------------------------------------------------------------------------
---- event_queue:format_accepted_event method
--------------------------------------------------------------------------------
function event_queue:format_accepted_event()
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element

  self.sc_logger:debug("[event_queue:format_accepted_event]: starting format event")

  -- can't format event if stream connector is not handling this kind of event and that it is not handled with a template file
  if not self.format_event[category][element] then
    self.sc_logger:error("[format_accepted_event]: You are trying to format an event with category: "
      .. tostring(self.sc_params.params.reverse_category_mapping[category]) .. " and element: "
      .. tostring(self.sc_params.params.reverse_element_mapping[category][element])
      .. ". If it is a not a misconfiguration, you should create a format file to handle this kind of element")
  else
    self.format_event[category][element]()
  end

  self.sc_logger:debug("[event_queue:format_accepted_event]: event formatting is finished")
end

--------------------------------------------------------------------------------
---- event_queue:format_event_host method
--------------------------------------------------------------------------------
function event_queue:format_event_host()
  local event = self.sc_event.event
  self.previous_info[event.category][event.element].flush_success = false

  -- this is the first time we receive a metric from a host, we store host id in the table
  if self.previous_info[event.category][event.element].host_id == "" then 
    self.previous_info[event.category][event.element].host_id = event.host_id
  else
    -- the event is linked to a new host, we can't send payload with data from different hosts so we force a data flush
    -- we store the new host id and then we continue working on metrics from said host
    if self.previous_info[event.category][event.element].host_id ~= event.host_id then
      while not self.previous_info[event.category][event.element].flush_success do
        if self.sc_flush:flush_all_queues(self.build_payload_method[1], self.send_data_method[1]) then
          self.previous_info[event.category][event.element].flush_success = true
          self.send_data_sleep_counter:reset()
        else
          self.send_data_sleep_counter:sleep()
        end
      end

      self.previous_info[event.category][event.element].host_id = event.host_id
    end
  end
  self.sc_logger:debug("[event_queue:format_event_host]: call build_metric ")
  self.sc_metrics:build_metric(self.format_metric[event.category][event.element])
end

--------------------------------------------------------------------------------
---- event_queue:format_event_service method
--------------------------------------------------------------------------------
function event_queue:format_event_service()
  self.sc_logger:debug("[event_queue:format_event_service]: starting format event service.")
  local event = self.sc_event.event

  self.previous_info[event.category][event.element].flush_success = false

  -- this is the first time we receive a metric from a servuce, we store host id and service id in the table
  if self.previous_info[event.category][event.element].host_id == "" 
    or self.previous_info[event.category][event.element].service_id == "" 
  then 
    self.previous_info[event.category][event.element].host_id = event.host_id
    self.previous_info[event.category][event.element].service_id = event.service_id
  else
    if self.previous_info[event.category][event.element].host_id ~= event.host_id 
      or self.previous_info[event.category][event.element].service_id ~= event.service_id 
    then
      -- the event is linked to a new service, we can't send payload with data from different services so we force a data flush
      -- we store the new host and service id and then we continue working on metrics from said service
      while not self.previous_info[event.category][event.element].flush_success do
        if self.sc_flush:flush_all_queues(self.build_payload_method[1], self.send_data_method[1]) then
          self.previous_info[event.category][event.element].flush_success = true
          self.send_data_sleep_counter:reset()
        else
          self.send_data_sleep_counter:sleep()
        end
      end

      self.previous_info[event.category][event.element].host_id = event.host_id
      self.previous_info[event.category][event.element].service_id = event.service_id
    end
  end
  self.sc_logger:debug("[event_queue:format_event_service]: call build_metric ")
  self.sc_metrics:build_metric(self.format_metric[event.category][event.element])
  self.sc_logger:debug("[event_queue:format_event_service]: format metric service is finished ")
end

--------------------------------------------------------------------------------
---- event_queue:format_metric_host method
-- @param metric {table} a single metric data
--------------------------------------------------------------------------------
function event_queue:format_metric_host(metric)
  self.sc_logger:debug("[event_queue:format_metric_host]: starting format event host.")
  local event = self.sc_event.event
  local sdesc = "host"

  event.formated_event = {
    prom_hname      = event.cache.host.name,
    prom_sdesc      = sdesc,
    prom_sdesc_url  = mime.b64(sdesc)
  }
  self.sc_logger:debug("[event_queue:format_metric_host]: call format_metric ")
  self:format_metric_event(metric)
  self.sc_logger:debug("[event_queue:format_metric_host]: format metric host is finished ")
end

--------------------------------------------------------------------------------
---- event_queue:format_metric_service method
-- @param metric {table} a single metric data
--------------------------------------------------------------------------------
function event_queue:format_metric_service(metric)
  self.sc_logger:debug("[event_queue:format_metric_service]: starting format event service.")
  local event = self.sc_event.event
  local sdesc = event.cache.service.description

  event.formated_event = {
    prom_hname      = event.cache.host.name,
    prom_sdesc      = sdesc,
    prom_sdesc_url  = mime.b64(sdesc)
  }
  self.sc_logger:debug("[event_queue:format_metric_service]: call format_metric ")
  self:format_metric_event(metric)
  self.sc_logger:debug("[event_queue:format_metric_service]: format metric service is finished ")
end

--------------------------------------------------------------------------------
-- add_unit_info: add unit metadata to match openmetrics standard
-- @param {string} label, the name of the metric
-- @param {string} unit, the unit name
-- @param {string} name, the name of the metric
-- @return {string} data, the unit metadata information
--------------------------------------------------------------------------------
function event_queue:add_unit_info (label, unit, name)
  local data = ''

  if (unit ~= '' and unit ~= nil) then
      data = '# UNIT ' .. name .. '\n'
  end

  return data
end

--------------------------------------------------------------------------------
--- create_metric_name: concatenates data to create the metric name
--- @param {string} label, the name of the perfdata
--- @param {string} unit, the unit name
--- @return {string} name, the prometheus metric name (open metric format)
--------------------------------------------------------------------------------
function event_queue:create_metric_name (label, unit)
  local name = ''
  local sdesc = self.sc_event.event.cache.service.description or 'host'
  local hname = self.sc_event.event.cache.host.name

    if (self.sc_params.params.enable_extended_metric_name == 0) then
      name = label
    else
      name = hname .. '_' .. sdesc .. ':' .. label
    end
    if (unit ~= '') then
      local pos_unit = string.find(name, unit)
      -- we append the unit only if the name is not already ending with it
      if not pos_unit or not (pos_unit > 0 and pos_unit == string.len(name) - string.len(unit) + 1) then
        name = name .. '_' .. unit
      end
    end
  return string.gsub(name, self.sc_params.params.metric_name_regex, self.sc_params.params.metric_replacement_character)
end

--------------------------------------------------------------------------------
--- event_queue:format_metric_service method
--- @param metric {table} a single metric data
-------------------------------------------------------------------------------
function event_queue:format_metric_event(metric)
  self.sc_logger:debug("[event_queue:format_metric]: start real format metric ")
  local event = self.sc_event.event
  local type  = self:get_metric_type(metric)
  local unit  = unit_mapping(metric.uom)
  local label = ''

  -- case when the metric belongs to an instance
  if metric.instance and metric.instance ~= '' then
    label =  metric.instance .. '_'
  end

  -- case when there are sub-levels of an instance
  local i, sub_instance
  for i, sub_instance in ipairs(metric.subinstance) do
    label =  label .. sub_instance .. '_'
  end

  label = label .. metric.metric_name

  local name  = self:create_metric_name(label, unit)
  local sdesc = event.formated_event.prom_sdesc

  -- Example of data to send
  --[[
# TYPE CENTREON_proc_crond:nbproc counter
CENTREON_proc_crond:nbproc{label="nbproc", host="CENTREON", service="proc-crond"} 1.0
  ]]
  -- Other example
  --[[
# TYPE CENTREON_Ah_Que_Coucou:bnp_bank_business_gold_reserve_euros counter
# UNIT CENTREON_Ah_Que_Coucou:bnp_bank_business_gold_reserve_euros
CENTREON_Financial:acme_bank_business_gold_reserve_euros{label="acme_bank_business_gold.reserve.euros", host="CENTREON", service="Financial"} 3.0
  ]]

  local data = '# TYPE ' .. name .. ' ' .. type .. '\n'
  data = data .. self:add_unit_info(label, unit, name)
  data = data .. name .. '{label="' .. label .. '", host="' .. event.cache.host.name .. '", service="' .. sdesc .. '"'

  if event.hostgroupsLabel then
    data = data .. ', ' .. event.hostgroupsLabel
  end

  data = data ..  '} ' .. metric.value .. '\n'

  if (self.enable_threshold_metrics == 1) then
    data = data .. self:threshold_metrics(metric, label, unit, type)
  end

  event.formated_event.payload = data

  self:add()
  self.sc_logger:debug("[event_queue:format_metric]: end real format metric ")
end

--------------------------------------------------------------------------------
--- is_number_and_not_a_NaN:  check if a number is a number (and not a NaN)
--- @param {number} number, the number to check
--- @return {boolean}
--------------------------------------------------------------------------------
local function is_number_and_not_a_NaN (number)
  if (number ~= number) then
    return false
  end
  
  if (type(number) ~= "number") then
    return false
  end

  return true
end

--------------------------------------------------------------------------------
-- get_metric_type: [for Prometheus] find out the metric type to match openmetrics standard
-- @param {table} perfdata, the perfdata informations
-- @return {string} metricType, the type of the metric
--------------------------------------------------------------------------------
function event_queue:get_metric_type (perfdata)
  if (is_number_and_not_a_NaN(perfdata.max)) then
    return "gauge"
  end
  
  return "counter"
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

  if not payload then -- FIXME: voir obsidian
    payload = event
  else
    table.insert(payload, event)
  end

  return payload
end

function event_queue:send_data(payload, queue_metadata)
  self.sc_logger:debug("[event_queue:send_data]: Starting to send data")
  local httpPostData = payload.payload
  local httpResponseBody = ""
  local url = self.sc_params.params.prometheus_url .. '/metrics/job/' .. self.sc_params.params.prometheus_gateway_job .. '/instance/' .. payload.prom_hname .. '/service@base64/' .. payload.prom_sdesc_url

  queue_metadata.headers = { "content-type: application/openmetrics-text" }

  local httpRequest = curl.easy()
  :setopt_url(url)
  :setopt_writefunction(
    function (response)
      httpResponseBody = httpResponseBody .. tostring(response)
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
      httpRequest:setopt(curl.OPT_PROXY, self.sc_params.params.proxy_address .. ':' .. self.sc_params.params.proxy_port)
    else
      self.sc_logger:error("event_queue:send_data: proxy_port parameter is not set but proxy_address is used")
    end
  end

  -- set proxy user configuration
  if (self.sc_params.params.proxy_username ~= '') then
    if (self.sc_params.params.proxy_password ~= '') then
      httpRequest:setopt(curl.OPT_PROXYUSERPWD, self.sc_params.params.proxy_username .. ':' .. self.sc_params.params.proxy_password)
    else
      self.sc_logger:error("event_queue:send_data: proxy_password parameter is not set but proxy_username is used")
    end
  end

  -- write payload in the logfile for test purpose
  if self.sc_params.params.send_data_test == 1 then
    self.sc_logger:notice("[send_data]: " .. tostring(httpPostData))
    return true
  end

  -- adding the HTTP POST data
  httpRequest:setopt_postfields(httpPostData)

  -- log the curl command for troubleshooting
  self.sc_logger:log_curl_command(url, queue_metadata, self.sc_params.params, httpPostData)

  -- performing the HTTP request
  httpRequest:perform()

  -- collecting results
  local httpResponseCode = httpRequest:getinfo(curl.INFO_RESPONSE_CODE)

  httpRequest:close()

  -- Handling the return code
  local retval = false
  if httpResponseCode == 200 then
    self.sc_logger:info("event_queue:send_data: HTTP POST request successful: return code is " .. httpResponseCode)
    -- now that the data has been sent, we empty the events array
    self.events = {}
    retval = true
  else
    self.sc_logger:error("event_queue:send_data: HTTP POST request FAILED, return code is " .. httpResponseCode .. " message is:\n\"" .. tostring(httpResponseBody) .. "\n\"\n")
    self.sc_logger:error("the body request " .. httpPostData)
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

-- --------------------------------------------------------------------------------
-- write,
-- @param {table} event, the event from broker
-- @return {boolean}
--------------------------------------------------------------------------------
function write(event)
  -- skip event if a mandatory parameter is missing
  if queue.fail then
    queue.sc_logger:error("Skipping event because a mandatory parameter is not set")
    queue.init_fail_sleep_counter:sleep()
    return false
  end

  queue.init_fail_sleep_counter:reset()

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
