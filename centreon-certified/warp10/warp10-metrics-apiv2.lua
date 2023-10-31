#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker Warp10 Connector Events
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
    "api_token",
    "warp10_http_address"
  }

  self.fail = false

  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/warp10-metrics.log"
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
  self.sc_params.params.api_token = params.api_token
  self.sc_params.params.warp10_address = params.warp10_http_address
  self.sc_params.params.warp10_api_endpoint = params.warp10_api_endpoint or "/api/v0/update"
  self.sc_params.params.add_hg_in_labels = params.add_hg_in_labels or 1
  self.sc_params.params.add_sg_in_labels = params.add_sg_in_labels or 0
  self.sc_params.params.accepted_categories = params.accepted_categories or "neb"
  self.sc_params.params.accepted_elements = params.accepted_elements or "host_status,service_status"
  self.sc_params.params.max_buffer_size = params.max_buffer_size or 30
  self.sc_params.params.hard_only = params.hard_only or 0
  self.sc_params.params.enable_host_status_dedup = params.enable_host_status_dedup or 0
  self.sc_params.params.enable_service_status_dedup = params.enable_service_status_dedup or 0
  -- just need to url encode the metric name  so we don't need to filter out characters
  -- https://www.warp10.io/content/03_Documentation/03_Interacting_with_Warp_10/03_Ingesting_data/02_GTS_input_format#lines
  self.sc_params.params.metric_name_regex = params.metric_name_regex or "[.*]"
  self.sc_params.params.metric_replacement_character = params.metric_replacement_character or "_" 
  
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
    [1] = function (payload) return self:send_data(payload) end
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
---- EventQueue:format_metric_service method
-- @param metric {table} a single metric data
-------------------------------------------------------------------------------
function EventQueue:format_metric_event(metric)
  self.sc_logger:debug("[EventQueue:format_metric]: start real format metric ")
  local event = self.sc_event.event

  self.sc_event.event.formated_event = {
    data = event.last_check .. "000000// " .. broker.url_encode(metric.metric_name) .. self:build_labels(metric) .. self:build_attributes(metric) .. " " .. metric.value
  }

  self:add()
  self.sc_logger:debug("[EventQueue:format_metric]: end real format metric ")
end

--------------------------------------------------------------------------------
---- EventQueue:build_labels method
-- @param metric {table} a single metric data
-- @return labels_string {string} a string with all labels 
--------------------------------------------------------------------------------
function EventQueue:build_labels(metric)
  local event = self.sc_event.event
  local labels_string = "host=" .. broker.url_encode(event.cache.host.name)

  -- add service name in labels
  if event.cache.service.description then
    labels_string = labels_string .. ",service=" .. broker.url_encode(event.cache.service.description)
  end

  -- add hostgroups name in labels
  if event.cache.hostgroups and event.cache.hostgroups[1] and self.sc_params.params.add_hg_in_labels == 1 then
    local hostgroups_string = ""
    for _, hostgroup in ipairs(event.cache.hostgroups) do
      if hostgroups_string == "" then
        hostgroups_string = hostgroup.group_name
      else
        hostgroups_string = hostgroups_string .. " " .. hostgroup.group_name
      end
    end

    labels_string = labels_string .. ",hostgroups=" .. broker.url_encode(hostgroups_string)
  end

  -- add servicegroups name in labels
  if event.cache.servicegroups and event.cache.servicegroups[1] and self.sc_params.params.add_sg_in_labels == 1 then
    local servicegroups_string = ""
    for _, servicegroup in ipairs(event.cache.servicegroups) do
      if servicegroups_string == "" then
        servicegroups_string = servicegroup.group_name
      else
        servicegroups_string = servicegroups_string .. " " .. servicegroup.group_name
      end
    end

    labels_string = labels_string .. ",servicegroups=" .. broker.url_encode(servicegroups_string)
  end

  -- add metric instance in labels
  if metric.instance ~= "" then
    labels_string = labels_string .. ",instance=" .. broker.url_encode(metric.instance)
  end

  -- add metric subinstances in labels
  if metric.subinstance[1] then
    local subinstances_string = ""
    for _, subinstance in ipairs(metric.subinstance) do
      if subinstances_string == "" then
        subinstances_string = subinstance
      else
        subinstances_string = subinstances_string .. " " .. subinstance
      end
    end

    labels_string = labels_string .. ",subinstance=" .. broker.url_encode(subinstances_string)
  end

  return "{" .. labels_string .. "}"
end

--------------------------------------------------------------------------------
---- EventQueue:build_attributes method
-- @param metric {table} a single metric data
-- @return tags {table} a string with all attributes 
--------------------------------------------------------------------------------
function EventQueue:build_attributes(metric)
  local event = self.sc_event.event
  local attributes_string = ""

  -- add min to attributes
  if metric.min and metric.min == metric.min then
    if attributes_string == "" then
      attributes_string = "min=" .. metric.min
    else
      attributes_string = attributes_string .. ",min=" .. metric.min
    end
  end

  -- add max to attributes
  if metric.max and metric.max == metric.max then
    if attributes_string == "" then
      attributes_string = "max=" .. metric.max
    else
      attributes_string = attributes_string .. ",max=" .. metric.max
    end
  end

  -- add warning to attributes
  if metric.warning_high and metric.warning_high == metric.warning_high then
    if attributes_string == "" then
      attributes_string = "warning=" .. metric.warning_high
    else
      attributes_string = attributes_string .. ",warning=" .. metric.warning_high
    end
  end

  -- add critical to attributes
  if metric.critical_high and metric.critical_high == metric.critical_high then
    if attributes_string == "" then
      attributes_string = "critical=" .. metric.critical_high
    else
      attributes_string = attributes_string .. ",critical=" .. metric.critical_high
    end
  end

  -- add UOM to attributes
  if metric.uom then
    if attributes_string == "" then
      attributes_string = "uom=" .. metric.uom
    else
      attributes_string = attributes_string .. ",uom=" .. broker.url_encode(metric.uom)
    end
  end

  if attributes_string ~= "" then
    return "{" .. attributes_string .. "}"
  end

  return attributes_string
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
    payload = event.data
  else
    payload = payload .. "\n" .. event.data
  end
  
  return payload
end

function EventQueue:send_data(payload)
  self.sc_logger:debug("[EventQueue:send_data]: Starting to send data")

  local url = tostring(self.sc_params.params.warp10_address) .. tostring(self.sc_params.params.warp10_api_endpoint)

  -- write payload in the logfile for test purpose
  if self.sc_params.params.send_data_test == 1 then
    self.sc_logger:notice("[send_data]: " .. tostring(payload))
    return true
  end

  self.sc_logger:info("[EventQueue:send_data]: Going to send the following json " .. tostring(payload))
  self.sc_logger:info("[EventQueue:send_data]: warp10 address is: " .. tostring(url))

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
    :setopt(
      curl.OPT_HTTPHEADER,
      {
        "Transfer-Encoding:chunked",
        "X-Warp10-Token:" .. self.sc_params.params.api_token
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
  -- https://www.warp10.io/content/03_Documentation/03_Interacting_with_Warp_10/03_Ingesting_data/01_Ingress#response-status-code other than 200 is not good
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
