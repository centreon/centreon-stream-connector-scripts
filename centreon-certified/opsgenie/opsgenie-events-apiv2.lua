#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker Opsgenie Connector Events
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
    "app_api_token"
  }

  self.fail = false

  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/opsgenie-events.log"
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
  
  --params.max_buffer_size = 1
  
  -- overriding default parameters for this stream connector if the default values doesn't suit the basic needs
  self.sc_params.params.app_api_token = params.app_api_token
  self.sc_params.params.integration_api_token = params.integration_api_token
  self.sc_params.params.api_url = params.api_url or "https://api.opsgenie.com"
  self.sc_params.params.alerts_api_endpoint = params.alerts_api_endpoint or "/v2/alerts"
  self.sc_params.params.incident_api_endpoint = params.incident_api_endpoint or "/v1/incidents/create"
  self.sc_params.params.ba_incident_tags = params.ba_incident_tags or "centreon,application"
  self.sc_params.params.enable_incident_tags = params.enable_incident_tags or 1
  self.sc_params.params.get_bv = params.get_bv or 1
  self.sc_params.params.enable_severity = params.enable_severity or 0
  self.sc_params.params.default_priority = params.default_priority
  self.sc_params.params.priority_mapping = params.priority_mapping or "P1=1,P2=2,P3=3,P4=4,P5=5"
  self.sc_params.params.opsgenie_priorities = params.opsgenie_priorities or "P1,P2,P3,P4,P5"
  self.sc_params.params.accepted_categories = params.accepted_categories or "neb"
  self.sc_params.params.accepted_elements = params.accepted_elements or "host_status,service_status"
  self.sc_params.params.timestamp_conversion_format = params.timestamp_conversion_format or "%Y-%m-%d %H:%M:%S"
  
  
  -- apply users params and check syntax of standard ones
  self.sc_params:param_override(params)
  self.sc_params:check_params()
  
  -- need a queue for each type of event because ba status aren't sent on the same endpoint
  self.sc_params.params.send_mixed_events = 0
  
  self.sc_macros = sc_macros.new(self.sc_params.params, self.sc_logger)
  self.format_template = self.sc_params:load_event_format_file(true)

  -- only load the custom code file, not executed yet
  if self.sc_params.load_custom_code_file and not self.sc_params:load_custom_code_file(self.sc_params.params.custom_code_file) then
    self.sc_logger:error("[EventQueue:new]: couldn't successfully load the custom code file: " .. tostring(self.sc_params.params.custom_code_file))
  end

  self.sc_params:build_accepted_elements_info()
  self.sc_flush = sc_flush.new(self.sc_params.params, self.sc_logger)

  local categories = self.sc_params.params.bbdo.categories
  local elements = self.sc_params.params.bbdo.elements

  self.state_to_alert_type_mapping = {
    [categories.neb.id] = {
        [elements.host_status.id] = {
            [0] = "info",
            [1] = "error",
            [2] = "warning"
        },
        [elements.service_status.id] = {
            [0] = "info",
            [1] = "warning",
            [2] = "error",
            [3] = "warning"
        }
    }
  }

  self.format_event = {
    [categories.neb.id] = {
      [elements.host_status.id] = function () return self:format_event_host() end,
      [elements.service_status.id] = function () return self:format_event_service() end
    },
    [categories.bam.id] = {
      [elements.ba_status.id] = function () return self:format_event_ba() end
    }
  }

  self.send_data_method = {
    [1] = function (payload, queue_metadata) return self:send_data(payload, queue_metadata) end
  }

  self.build_payload_method = {
    [1] = function (payload, event) return self:build_payload(payload, event) end
  }

  -- handle metadatas for queues
  self.sc_flush:add_queue_metadata(
    categories.neb.id, 
    elements.host_status.id, 
    {
      api_endpoint = self.sc_params.params.alerts_api_endpoint,
      token = self.sc_params.params.app_api_token
    }
  )
  self.sc_flush:add_queue_metadata(
    categories.neb.id, 
    elements.service_status.id, 
    {
      api_endpoint = self.sc_params.params.alerts_api_endpoint,
      token = self.sc_params.params.app_api_token
    }
  )

  -- handle opsgenie priority mapping
  local severity_to_priority = {}
  self.priority_mapping = {}
  
  if self.sc_params.params.enable_severity == 1 then
    self.priority_matching_list = self.sc_common:split(self.sc_params.params.priority_matching, ',')

    for _, priority_group in ipairs(self.priority_matching_list) do
      severity_to_priority = self.sc_common:split(priority_group, '=')

      -- 
      if string.match(self.sc_params.params.opsgenie_priorities, severity_to_priority[1]) == nil then
        self.sc_logger:error("[EvenQueue.new]: severity is enabled but the priority configuration is wrong. configured matching: " 
          .. self.sc_params.params.priority_matching_list .. ", invalid parsed priority: " .. severity_to_priority[1]
          .. ", known Opsgenie priorities: " .. self.sc_params.params.opsgenie_priorities
          .. ". Considere adding your priority to the opsgenie_priorities list if the parsed priority is valid")
        break
      end

      self.priority_mapping[severity_to_priority[2]] = severity_to_priority[1]  
    end
  end

  -- return EventQueue object
  setmetatable(self, { __index = EventQueue })
  return self
end

function EventQueue:get_priority()
  local severity = nil
  local event = self.sc_event.event
  local params = self.sc_params.params

  -- get appropriate severity depending on event type (service|host)
  if event.service_id == nil then
    self.sc_logger:debug("[EventQueue:get_priority]: getting severity for host: " .. event.host_id)
    severity = event.cache.severity.host
  else
    self.sc_logger:debug("[EventQueue:get_priority]: getting severity for service: " .. event.service_id)
    severity = event.cache.severity.service
  end

  -- find the opsgenie priority depending on the found severity
  local matching_priority = self.priority_mapping[tostring(severity)]

  if not matching_priority then
    return params.default_priority
  end

  return matching_priority
end

--------------------------------------------------------------------------------
---- EventQueue:format_event method
----------------------------------------------------------------------------------
function EventQueue:format_accepted_event()
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element
  local template = self.sc_params.params.format_template[category][element]

  self.sc_logger:debug("[EventQueue:format_event]: starting format event")
  self.sc_event.event.formated_event = {}

  if self.format_template and template ~= nil and template ~= "" then
    self.sc_event.event.formated_event = self.sc_macros:replace_sc_macro(template, self.sc_event.event, true)
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
  self.sc_logger:debug("[EventQueue:format_event]: event formatting is finished")
end

-- https://docs.opsgenie.com/docs/alert-api#create-alert
function EventQueue:format_event_host()
  local event = self.sc_event.event
  local state = self.sc_params.params.status_mapping[event.category][event.element][event.state]

  self.sc_event.event.formated_event = {
    message = string.sub(os.date(self.sc_params.params.timestamp_conversion_format, event.last_update) 
      .. " " .. event.cache.host.name .. " is " .. state, 1, 130),
    description = string.sub(event.output, 1, 15000),
    alias = string.sub(event.cache.host.name .. "_" .. state, 1, 512)
  }

  local priority = self:get_priority()
  if priority then
    self.sc_event.event.formated_event.priority = priority
  end
end

-- https://docs.opsgenie.com/docs/alert-api#create-alert
function EventQueue:format_event_service()
  local event = self.sc_event.event
  local state = self.sc_params.params.status_mapping[event.category][event.element][event.state]
  
  self.sc_event.event.formated_event = {
    message = string.sub(os.date(self.sc_params.params.timestamp_conversion_format, event.last_update) 
      .. " " .. event.cache.host.name .. " // " .. event.cache.service.description .. " is " .. state, 1, 130),
    description = string.sub(event.output, 1, 15000),
    alias = string.sub(event.cache.host.name .. "_" .. event.cache.service.description .. "_" .. state, 1, 512)
  }

  local priority = self:get_priority()
  if priority then
    self.sc_event.event.formated_event.priority = priority
  end
end

-- https://docs.opsgenie.com/docs/incident-api#create-incident
function EventQueue:format_event_ba()
  local event = self.sc_event.event
  local state = self.sc_params.params.status_mapping[event.category][event.element][event.state]
  
  self.sc_event.event.formated_event = {
    message = string.sub(event.cache.ba.ba_name  .. " is " .. state .. ", health level reached " .. event.level_nominal, 1, 130)
  }

  if self.sc_params.params.enable_incident_tags == 1 then
    local tags = {}
    
    for _, bv_info in ipairs(event.cache.bvs) do
      -- can't have more than 20 tags
      if #tags < 50 then
        self.sc_logger:info("[EventQueue:format_event_ba]: add bv name: " .. tostring(bv_info.bv_name) .. " to list of tags")
        table.insert(tags, string.sub(bv_info.bv_name, 1, 50))
      end
    end

    local custom_tags = self.sc_common:split(self.sc_params.params.ba_incident_tags, ",")
    for _, tag_name in ipairs(custom_tags) do  
      -- can't have more than 20 tags
      if #tags < 20 then
        self.sc_logger:info("[EventQueue:format_event_ba]: add custom tag: " .. tostring(tag_name) .. " to list of tags")
        table.insert(tags, string.sub(tag_name, 1, 50))
      end
    end

    self.sc_event.formated_event.tags = tags
  end

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
    payload = broker.json_encode(event)
  else
    payload = payload .. "," .. broker.json_encode(event)
  end
  
  return payload
end

function EventQueue:send_data(payload, queue_metadata)
  self.sc_logger:debug("[EventQueue:send_data]: Starting to send data")

  local url = self.sc_params.params.api_url .. queue_metadata.api_endpoint
  queue_metadata.headers = {
    "content-type: application/json",
    "accept: application/json",
    "Authorization: GenieKey " .. queue_metadata.token 
  }

  self.sc_logger:log_curl_command(url, queue_metadata, self.sc_params.params, payload)
  -- write payload in the logfile for test purpose
  if self.sc_params.params.send_data_test == 1 then
    self.sc_logger:notice("[send_data]: " .. tostring(payload))
    return true
  end

  self.sc_logger:info("[EventQueue:send_data]: Going to send the following json " .. tostring(payload))
  self.sc_logger:info("[EventQueue:send_data]: Opsgenie address is: " .. tostring(url))

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
    :setopt(curl.OPT_HTTPHEADER, queue_metadata.headers)

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

  -- according to opsgenie documentation "Create alert requests are processed asynchronously, therefore valid requests are responded with HTTP status 202 - Accepted"
  -- https://docs.opsgenie.com/docs/alert-api#create-alert
  if http_response_code == 202 then
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

