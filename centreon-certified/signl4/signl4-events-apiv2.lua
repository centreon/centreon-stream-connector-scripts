#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker Signl4 Connector Events
--------------------------------------------------------------------------------

-- Libraries
local curl = require("cURL")
local mime = require("mime")

-- Centreon lua core libraries
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_event = require("centreon-stream-connectors-lib.sc_event")
local sc_params = require("centreon-stream-connectors-lib.sc_params")
local sc_macros = require("centreon-stream-connectors-lib.sc_macros")
local sc_flush = require("centreon-stream-connectors-lib.sc_flush")

--------------------------------------------------------------------------------
-- event_queue class
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
        "team_secret"
    }

    self.fail = false

    -- set up log configuration
    local logfile = params.logfile or "/var/log/centreon-broker/signl4-events-apiv2.log"
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

    -- force buffer size to 1 to avoid breaking the communication with signl4 (can't send more than one event at once)
    params.max_buffer_size = 1

    -- overriding default parameters for this stream connector if the default values doesn't suit the basic needs
    self.sc_params.params.accepted_categories = params.accepted_categories or "neb"
    self.sc_params.params.accepted_elements = params.accepted_elements or "host_status,service_status"
    self.sc_params.params.server_address = params.server_address or "https://connect.signl4.com" 
    self.sc_params.params.x_s4_source_system = params.x_s4_source_system or "Centreon"

    -- apply users params and check syntax of standard ones
    self.sc_params:param_override(params)
    self.sc_params:check_params()

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

    self.state_to_signlstatus_mapping = {
        [0] = "resolved",
        [1] = "new",
        [2] = "new",
        [3] = "new"
    }

    -- return EventQueue object
    setmetatable(self, { __index = EventQueue })
    return self
  end

--------------------------------------------------------------------------------
---- EventQueue:format_event method
---------------------------------------------------------------------------------
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

function EventQueue:format_event_host()
  self.sc_event.event.formated_event = {
    EventType = "HOST",
    Date = self.sc_macros:transform_date(self.sc_event.event.last_check),
    Host = self.sc_event.event.cache.host.name,
    Message = self.sc_event.event.output,
    Status = self.sc_params.params.status_mapping[self.sc_event.event.category][self.sc_event.event.element][self.sc_event.event.state],
    Title = "HOST ALERT:" .. self.sc_event.event.cache.host.name .. " is " .. self.sc_params.params.status_mapping[self.sc_event.event.category][self.sc_event.event.element][self.sc_event.event.state],
    ["X-S4-SourceSystem"] = self.sc_params.params.x_s4_source_system,
    ["X-S4-ExternalID"] = "HOSTALERT_" .. self.sc_event.event.host_id,
    ["X-S4-Status"] = self.state_to_signlstatus_mapping[self.sc_event.event.state]
  }
end

function EventQueue:format_event_service()
  self.sc_event.event.formated_event = {
    EventType = "SERVICE",
    Date = self.sc_macros:transform_date(self.sc_event.event.last_check),
    Host = self.sc_event.event.cache.host.name,
    Service = self.sc_event.event.cache.service.description,
    Message = self.sc_event.event.output,
    Status = self.sc_params.params.status_mapping[self.sc_event.event.category][self.sc_event.event.element][self.sc_event.event.state],
    Title = "SERVICE ALERT:" .. self.sc_event.event.cache.host.name .. "/" .. self.sc_event.event.cache.service.description .. " is " .. self.sc_params.params.status_mapping[self.sc_event.event.category][self.sc_event.event.element][self.sc_event.event.state],
    ["X-S4-SourceSystem"] = self.sc_params.params.x_s4_source_system,
    ["X-S4-ExternalID"] = "SERVICEALERT_" .. self.sc_event.event.host_id .. "_" .. self.sc_event.event.service_id,
    ["X-S4-Status"] = self.state_to_signlstatus_mapping[self.sc_event.event.state]
  }
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
    payload = broker.json_encode(event) .. '\n'
  else
    payload = payload .. broker.json_encode(event) .. '\n'
  end
  
  return payload
end

function EventQueue:send_data(payload, queue_metadata)
  self.sc_logger:debug("[EventQueue:send_data]: Starting to send data")
  local url = self.sc_params.params.server_address .. "/webhook/" .. self.sc_params.params.team_secret
  queue_metadata.headers = {"content-type: application/json"}

  self.sc_logger:log_curl_command(url, queue_metadata, self.sc_params.params, payload)

  -- write payload in the logfile for test purpose
  if self.sc_params.params.send_data_test == 1 then
    self.sc_logger:notice("[send_data]: " .. tostring(payload))
    return true
  end

  self.sc_logger:info("[EventQueue:send_data]: Going to send the following json " .. tostring(payload))
  self.sc_logger:info("[EventQueue:send_data]: Signl4 Server URL is: " .. tostring(url))

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

  if http_response_code == 200 or http_response_code == 201 then
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