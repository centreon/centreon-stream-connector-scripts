#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker influxdb Connector Events
--------------------------------------------------------------------------------


-- Libraries
local curl = require "cURL"
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_event = require("centreon-stream-connectors-lib.sc_event")
local sc_params = require("centreon-stream-connectors-lib.sc_params")
local sc_macros = require("centreon-stream-connectors-lib.sc_macros")
local sc_flush = require("centreon-stream-connectors-lib.sc_flush")
local sc_metrics = require("centreon-stream-connectors-lib.sc_metrics")

--------------------------------------------------------------------------------
-- Classe event_queue
--------------------------------------------------------------------------------

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
    "bucket_id",
    "bucket_api_key",
    "org_name",
    "http_server_url"
  }

  self.fail = false

  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/infuxdb2-metrics.log"
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
  
  -- overriding default parameters for this stream connector if the default values doesn't suit the basic needs
  self.sc_params.params.bucket_api_key = params.bucket_api_key
  self.sc_params.params.bucket_id = params.bucket_id
  self.sc_params.params.org_name = params.org_name
  self.sc_params.params.http_server_url = params.http_server_url
  self.sc_params.params.influxdb2_api_endpoint = params.influxdb2_api_endpoint or "/api/v2/write"
  self.sc_params.params.influxdb2_precision = params.influxdb2_precision or "s" -- can be ms, s, us, ns [default]
  self.sc_params.params.accepted_categories = params.accepted_categories or "neb"
  self.sc_params.params.accepted_elements = params.accepted_elements or "host_status,service_status"
  -- according to https://docs.influxdata.com/influxdb/cloud/write-data/best-practices/optimize-writes/#batch-writes best practice is 5000 lines
  self.sc_params.params.max_buffer_size = params.max_buffer_size or 5000
  self.sc_params.params.hard_only = params.hard_only or 0
  self.sc_params.params.enable_host_status_dedup = params.enable_host_status_dedup or 0
  self.sc_params.params.enable_service_status_dedup = params.enable_service_status_dedup or 0
  -- https://docs.influxdata.com/influxdb/cloud/reference/syntax/line-protocol/#special-characters
  self.sc_params.params.metric_name_regex = params.metric_name_regex or "([, =])"
  self.sc_params.params.metric_replacement_character = params.metric_replacement_character or "\\%1" 
  
  -- apply users params and check syntax of standard ones
  self.sc_params:param_override(params)
  self.sc_params:check_params()
  self.sc_macros = sc_macros.new(self.sc_params.params, self.sc_logger)

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
---- EventQueue:format_accepted_event method
--------------------------------------------------------------------------------
function EventQueue:format_accepted_event()
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element

  self.sc_logger:debug("[EventQueue:format_event]: starting format event")

  -- can't format event if stream connector is not handling this kind of event and that it is not handled with a template file
  if not self.format_event[category][element] then
    self.sc_logger:error("[format_event]: You are trying to format an event with category: "
      .. tostring(self.sc_params.params.reverse_category_mapping[category]) .. " and element: "
      .. tostring(self.sc_params.params.reverse_element_mapping[category][element])
      .. ". If it is a not a misconfiguration, you should create a format file to handle this kind of element")
  else
    self.format_event[category][element]()
  end

  self.sc_logger:debug("[EventQueue:format_event]: event formatting is finished")
end

--- escape_special_characters: escape influxdb2 characters according to https://docs.influxdata.com/influxdb/cloud/reference/syntax/line-protocol/#special-characters
-- @param string (string) the string that probably contains special characters
-- @return (string) the string with escaped special characters
function EventQueue:escape_special_characters(string)
  local params = self.sc_params.params
  return string.gsub(tostring(string), params.metric_name_regex, params.metric_replacement_character)
end

--------------------------------------------------------------------------------
---- EventQueue:format_event_host method
--------------------------------------------------------------------------------
function EventQueue:format_event_host()
  local event = self.sc_event.event
  self.sc_logger:debug("[EventQueue:format_event_host]: call build_metric ")
  self.sc_metrics:build_metric(self.format_metric[event.category][event.element])
end

--------------------------------------------------------------------------------
---- EventQueue:format_event_service method
--------------------------------------------------------------------------------
function EventQueue:format_event_service()
  self.sc_logger:debug("[EventQueue:format_event_service]: call build_metric ")
  local event = self.sc_event.event
  self.sc_metrics:build_metric(self.format_metric[event.category][event.element])
end

--------------------------------------------------------------------------------
---- EventQueue:format_metric_host method
-- @param metric {table} a single metric data
--------------------------------------------------------------------------------
function EventQueue:format_metric_host(metric)
  self.sc_logger:debug("[EventQueue:format_metric_host]:  start format_metric host")
  self.sc_event.event.formated_event = metric.metric_name .. ",type=host," .. self:build_generic_tags(metric) .. " value=" .. metric.value .. " " .. self.sc_event.event.last_check
  self:add()
  self.sc_logger:debug("[EventQueue:format_metric_service]: end format_metric host")
end

--------------------------------------------------------------------------------
---- EventQueue:format_metric_service method
-- @param metric {table} a single metric data
--------------------------------------------------------------------------------
function EventQueue:format_metric_service(metric)
  local params = self.sc_params.params
  self.sc_logger:debug("[EventQueue:format_metric_service]: start format_metric service")
  self.sc_event.event.formated_event = metric.metric_name .. ",type=service,service.name="
    .. self:escape_special_characters(self.sc_event.event.cache.service.description) 
    .. "," .. self:build_generic_tags(metric) .. " value=" .. metric.value .. " " .. self.sc_event.event.last_check
  self:add()
  self.sc_logger:debug("[EventQueue:format_metric_service]: end format_metric service")
end

--------------------------------------------------------------------------------
---- EventQueue:build_tags method
-- @param metric {table} a single metric data
-- @return tags {table} a table with formated metadata 
--------------------------------------------------------------------------------
function EventQueue:build_generic_tags(metric)
  local event = self.sc_event.event
  local tags = 'host.name=' .. event.cache.host.name .. ',poller=' .. self:escape_special_characters(event.cache.poller)

  -- add metric instance in tags
  if metric.instance ~= "" then
    tags = tags .. ',metric.instance=' .. self:escape_special_characters(metric.instance)
  end

  if metric.uom ~= "" then
    tags = tags .. ',metric.unit=' .. metric.uom
  end

  -- add metric subinstances in tags
  if metric.subinstance[1] then
    for subinstance_name, subinstance_value in ipairs(metric.subinstance) do
      tags = tags .. ',' .. self.sc_common:trim(subinstance_name, "_") .. '=' .. self:escape_special_characters(subinstance_value)
    end
  end

  return tags
end

--------------------------------------------------------------------------------
-- EventQueue:add, add an event to the sending queue
--------------------------------------------------------------------------------
function EventQueue:add()
  -- store event in self.events lists
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element

  self.sc_logger:debug("[EventQueue:add]: add event in queue category: " .. tostring(self.sc_params.params.reverse_category_mapping[category])
    .. " element: " .. tostring(self.sc_params.params.reverse_element_mapping[category][element]))

  self.sc_logger:debug("[EventQueue:add]: queue size before adding event: " .. tostring(#self.sc_flush.queues[category][element].events))
  self.sc_flush.queues[category][element].events[#self.sc_flush.queues[category][element].events + 1] = self.sc_event.event.formated_event

  self.sc_logger:info("[EventQueue:add]: queue size is now: " .. tostring(#self.sc_flush.queues[category][element].events) 
    .. ", max is: " .. tostring(self.sc_params.params.max_buffer_size))
end

--------------------------------------------------------------------------------
-- EventQueue:build_payload, concatenate data so it is ready to be sent
-- @param payload {string} json encoded string
-- @param event {table} the event that is going to be added to the payload
-- @return payload {string} json encoded string
--------------------------------------------------------------------------------
function EventQueue:build_payload(payload, event)
  if not payload then
    payload = event
  else
    payload = payload .. "\n" .. event
  end
  
  return payload
end

function EventQueue:send_data(payload, queue_metadata)
  self.sc_logger:debug("[EventQueue:send_data]: Starting to send data")
  local params = self.sc_params.params

  local url = params.http_server_url .. tostring(params.influxdb2_api_endpoint) 
    .. "?bucket=" .. tostring(params.bucket_id) .. "&org=" .. tostring(params.org_name) 
    .. "&precision=" .. tostring(params.influxdb2_precision)

  queue_metadata.headers = {
    "content-type: text/plain; charset=utf-8",
    "accept: application/json",
    "Authorization: Token " .. tostring(params.bucket_api_key)
  }

  self.sc_logger:log_curl_command(url, queue_metadata, params, payload)

  -- write payload in the logfile for test purpose
  if self.sc_params.params.send_data_test == 1 then
    self.sc_logger:notice("[send_data]: " .. tostring(payload))
    return true
  end

  self.sc_logger:info("[EventQueue:send_data]: Going to send the following json " .. tostring(payload))
  self.sc_logger:info("[EventQueue:send_data]: Influxdb address is: " .. tostring(url))

  local http_response_body = ""
  local http_request = curl.easy()
    :setopt_url(url)
    :setopt_writefunction(
      function (response)
        http_response_body = http_response_body .. tostring(response)
      end
    )
    :setopt(curl.OPT_TIMEOUT, self.sc_params.params.connection_timeout)
    :setopt(curl.OPT_SSL_VERIFYPEER, self.sc_params.params.allow_insecure_connection)
    :setopt(curl.OPT_HTTPHEADER,queue_metadata.headers)

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
      self.sc_logger:error("[EventQueue:send_data]: proxy_password parameter is not set but proxy_username is used")
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
  -- https://docs.influxdata.com/influxdb/cloud/api/#operation/PostWrite other than 204 is not good
  if http_response_code == 204 then
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