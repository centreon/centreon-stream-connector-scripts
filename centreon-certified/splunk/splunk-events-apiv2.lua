#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker Splunk Connector Events
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Parameters:
-- [MANDATORY] http_server_url: your splunk API url
-- [MANDATORY] splunk_token: see above, this will be your authentication token
-- [MANDATORY] splunk_index: index where you want to store the events
-- [OPTIONAL] splunk_source: source of the HTTP events collector, must be http:something
-- [OPTIONAL] splunk_sourcetype: sourcetype of the HTTP events collector, default _json
-- [OPTIONAL] splunk_host: host field for the HTTP events collector, default Central
-- [OPTIONAL] http_proxy_string: default empty
--
--------------------------------------------------------------------------------

-- Libraries
local curl = require "cURL"
-- Global variables
local previous_event = ""

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

function EventQueue.new(conf)
  local self = {}

  local mandatory_parameters = {
    "http_server_url",
    "splunk_token",
    "splunk_index"
  }

  self.fail = false

  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/stream-connector.log"
  local log_level = params.log_level or 2
  
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
  self.sc_params.params.proxy_address = params.proxy_address
  self.sc_params.params.proxy_port = params.proxy_port
  self.sc_params.params.proxy_username = params.proxy_username
  self.sc_params.params.proxy_password = params.proxy_password
  self.sc_params.params.splunk_source = params.splunk_source
  self.sc_params.params.splunk_sourcetype = params.splunk_sourcetype or "_json"
  self.sc_params.params.splunk_host = params.splunk_host or "Central"
  
  -- apply users params and check syntax of standard ones
  self.sc_params:param_override(params)
  self.sc_params:check_params()
  
  self.sc_params.params.__internal_ts_host_last_flush = os.time()
  self.sc_params.params.__internal_ts_service_last_flush = os.time()
  self.sc_params.params.__internal_ts_ack_last_flush = os.time()
  self.sc_params.params.__internal_ts_dt_last_flush = os.time()
  self.sc_params.params.__internal_ts_ba_last_flush = os.time()
  
  self.sc_flush = sc_flush.new(self.sc_params.params, self.sc_logger)
  self.sc_macros = sc_macros.new(self.sc_common, self.sc_params.params, self.sc_logger)

  local categories = self.sc_params.params.bbdo.categories
  local elements = self.sc_params.params.bbdo.elements

  self.format_event = {
    [categories.neb] = {
      [elements.acknowledgement] = function () return self:format_event_ack() end,
      [elements.downtime] = function () return self:format_event_dt() end,
      [elements.host_status] = function () return self:format_event_host() end,
      [elements.service_status] = function () return self:format_event_service() end
    },
    [categories.bam] = {
      [elements.ba_status] = function () return self:format_event_ba() end
    }
  }

  -- return EventQueue object
  setmetatable(self, { __index = EventQueue })
  return self
end

--------------------------------------------------------------------------------
---- EventQueue:format_event method
----------------------------------------------------------------------------------
function EventQueue:format_event()
  self.format_event[self.sc_event.event.category][self.sc_event.event.element]()
  self:add()
end

function EventQueue:format_event_host()
  self.sc_event.event.formated_event = {
    event_type = "host",
    state = self.sc_event.event.state,
    state_type = self.sc_event.event.state_type,
    hostname = self.sc_event.event.cache.host.name,
    output = string.gsub(self.sc_event.event.output, "\n", ""),
  }
end

function EventQueue:format_event_service()
  self.sc_event.event.formated_event = {
    event_type = "service",
    state = self.sc_event.event.state,
    state_type = self.sc_event.event.state_type,
    hostname = self.sc_event.event.cache.host.name,
    service_description = self.sc_event.event.cache.service.description,
    output = string.gsub(self.sc_event.event.output, "\n", ""),
  }
end

--------------------------------------------------------------------------------
---- EventQueue:flush method
---- Called when the max number of events or the max age are reached
----------------------------------------------------------------------------------

function EventQueue:flush()

  broker_log:info(3, "EventQueue:flush: Concatenating all the events as one string")
  local http_post_data = ""
  for _, raw_event in ipairs(self.events) do
    http_post_data = http_post_data .. broker.json_encode(raw_event)
  end
  for s in http_post_data:gmatch("[^\r\n]+") do
    broker_log:info(3, "EventQueue:flush: HTTP POST data:   " .. s .. "")
  end
  
  broker_log:info(3, "EventQueue:flush: HTTP POST url: \"" .. self.http_server_url .. "\"")

  local http_response_body = ""
  local http_request = curl.easy()
    :setopt_url(self.http_server_url)
    :setopt_writefunction(
      function (response)
        http_response_body = http_response_body .. tostring(response)
      end
    )
    :setopt(curl.OPT_TIMEOUT, self.http_timeout)
    :setopt(
      curl.OPT_HTTPHEADER,
      {
        "content-type: application/json",
        "content-length:" .. string.len(http_post_data),
        "authorization: Splunk " .. self.splunk_token,
      }
  )

  -- setting the CURLOPT_PROXY
  if self.http_proxy_string and self.http_proxy_string ~= "" then
    broker_log:info(3, "EventQueue:flush: HTTP PROXY string is '" .. self.http_proxy_string .. "'")
    http_request:setopt(curl.OPT_PROXY, self.http_proxy_string)
  end

  -- adding the HTTP POST data
  http_request:setopt_postfields(http_post_data)

  -- performing the HTTP request
  http_request:perform()
  
  -- collecting results
  http_response_code = http_request:getinfo(curl.INFO_RESPONSE_CODE) 

  http_request:close()
  
  -- Handling the return code
  local retval = false
  if http_response_code == 200 then
    broker_log:info(2, "EventQueue:flush: HTTP POST request successful: return code is " .. http_response_code)
    -- now that the data has been sent, we empty the events array
    self.events = {}
    retval = true
  else
    broker_log:error(0, "EventQueue:flush: HTTP POST request FAILED, return code is " .. http_response_code)
    broker_log:error(1, "EventQueue:flush: HTTP POST request FAILED, message is:\n\"" .. http_response_body .. "\n\"\n")
  end
  -- and update the timestamp
  self.__internal_ts_last_flush = os.time()
  return retval
end

--------------------------------------------------------------------------------
-- EventQueue:add, add an event to the sending queue
--------------------------------------------------------------------------------
function EventQueue:add()
  -- store event in self.events lists
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element

  self.sc_flush.queue[category][element].events[#self.sc_flush.queue[category][element].events + 1] = {
    sourcetype = self.sc_params.param.splunk_sourcetype,
    source = self.sc_params.param.splunk_source,
    index = self.sc_params.param.splunk_index,
    host = self.sc_params.param.splunk_host,
    time = self.sc_event.event.last_check,
    event = self.sc_event.event.formated_event
  }
end

function EventQueue:send_data(data, element)
  self.sc_logger:debug("[EventQueue:send_data]: Starting to send data")

  local http_post_data = ""
  
  
  for _, raw_event in ipairs(data) do
    http_post_data = http_post_data .. broker.json_encode(raw_event)
  end

  self.sc_logger:info("[EventQueue:send_data]: Going to send the following json " .. tostring(http_post_data))
  self.sc_logger:info("[EventQueue:send_data]: Splunk address is: " .. tostring(self.sc_params.params.http_server_url))

  local http_response_body = ""
  local http_request = curl.easy()
    :setopt_url(self.sc_params.params.http_server_url)
    :setopt_writefunction(
      function (response)
        http_response_body = http_response_body .. tostring(response)
      end
    )
    :setopt(curl.OPT_TIMEOUT, self.http_timeout)
    :setopt(
      curl.OPT_HTTPHEADER,
      {
        "content-type: application/json",
        "content-length:" .. string.len(http_post_data),
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
  http_request:setopt_postfields(http_post_data)

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

-- Fonction write()
function write(e)
  -- First, flush all queues if needed (too old or size too big)
  queue.sc_flush:flush_all_queues(queue.send_data)

  -- skip event if a mandatory parameter is missing
  if queue.fail then
    queue.sc_logger:error("Skipping event because a mandatory parameter is not set")
    return true
  end

  -- initiate event object
  queue.sc_event = sc_event.new(event, queue.sc_params.params, queue.sc_common, queue.sc_logger, queue.sc_broker)

  -- drop event if wrong category
  if not queue.sc_event:is_valid_category() then
    return true
  end

  -- drop event if wrong element
  if not queue.sc_event:is_valid_element() then
    return true
  end

  -- drop event if it is not validated
  if queue.sc_event:is_valid_event() then
    queue:format_event()
  else
    return true
  end

  -- Since we've added an event to a specific queue, flush it if queue is full
  queue.sc_flush.flush[self.sc_event.event.category][self.sc_event.event.element](queue.send_data)
  return true
end
