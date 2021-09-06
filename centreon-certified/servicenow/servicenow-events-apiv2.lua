#!/usr/bin/lua

--------------------------------------------------------------------------------
-- Centreon Broker Service Now connector
-- documentation: https://docs.centreon.com/current/en/integrations/stream-connectors/servicenow.html
--------------------------------------------------------------------------------


-- libraries
local curl = require "cURL"
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_event = require("centreon-stream-connectors-lib.sc_event")
local sc_params = require("centreon-stream-connectors-lib.sc_params")

--------------------------------------------------------------------------------
-- EventQueue class
--------------------------------------------------------------------------------

local EventQueue = {}
EventQueue.__index = EventQueue

--------------------------------------------------------------------------------
-- Constructor
-- @param conf The table given by the init() function and returned from the GUI
-- @return the new EventQueue
--------------------------------------------------------------------------------

function EventQueue:new (params)
  local self = {}
  local mandatory_parameters = {
    [1] = "instance",
    [2] = "client_id",
    [3] = "client_secret",
    [4] = "username",
    [5] = "password"
  }

  self.tokens = {}
  self.tokens.authToken = nil
  self.tokens.refreshToken = nil
  

  self.events = {}
  self.fail = false

  local logfile = params.logfile or "/var/log/centreon-broker/servicenow-stream-connector.log"
  local log_level = params.log_level or 1

  -- initiate mandatory objects
  self.sc_logger = sc_logger.new(logfile, log_level)
  self.sc_common = sc_common.new(self.sc_logger)
  self.sc_broker = sc_broker.new(self.sc_logger)
  self.sc_params = sc_params.new(self.sc_common, self.sc_logger)

  self.sc_params.params.instance = params.instance
  self.sc_params.params.client_id = params.client_id
  self.sc_params.params.client_secret = params.client_secret
  self.sc_params.params.username = params.username
  self.sc_params.params.password = params.password

  self.sc_params.params.accepted_categories = params.accepted_categories or "neb"
  self.sc_params.params.accepted_elements = params.accepted_elements or "host_status,service_status"

  -- checking mandatory parameters and setting a fail flag
  if not self.sc_params:is_mandatory_config_set(mandatory_parameters, params) then
    self.fail = true
  end

  -- apply users params and check syntax of standard ones
  self.sc_params:param_override(params)
  self.sc_params:check_params()

  setmetatable(self, { __index = EventQueue })

  return self
end

--------------------------------------------------------------------------------
-- getAuthToken: obtain a auth token
-- @return {string} self.tokens.authToken.token, the auth token
--------------------------------------------------------------------------------
function EventQueue:getAuthToken ()
  if not self:refreshTokenIsValid() then
    self:authToken()
  end

  if not self:accessTokenIsValid() then
    self:refreshToken(self.tokens.refreshToken.token)
  end

  return self.tokens.authToken.token
end

--------------------------------------------------------------------------------
-- authToken: obtain auth token
--------------------------------------------------------------------------------
function EventQueue:authToken ()
  local data = "grant_type=password&client_id=" .. self.sc_params.params.client_id .. "&client_secret=" .. self.sc_params.params.client_secret .. "&username=" .. self.sc_params.params.username .. "&password=" .. self.sc_params.params.password

  local res = self:call(
    "oauth_token.do",
    "POST",
    data
  )

  if not res.access_token then
    broker_log:error(1, "EventQueue:authToken: Authentication failed, couldn't get tokens")
    return false
  end

  self.tokens.authToken = {
    token = res.access_token,
    expTime = os.time(os.date("!*t")) + 1700
  }

  self.tokens.refreshToken = {
    token = res.refresh_token,
    expTime = os.time(os.date("!*t")) + 360000
  }
end

--------------------------------------------------------------------------------
-- refreshToken: refresh auth token
--------------------------------------------------------------------------------
function EventQueue:refreshToken (token)
  local data = "grant_type=refresh_token&client_id=" .. self.sc_params.params.client_id .. "&client_secret=" .. self.sc_params.params.client_secret .. "&username=" .. self.sc_params.params.username .. "&password=" .. self.sc_params.params.password .. "&refresh_token=" .. token
  
  local res = self:call(
    "oauth_token.do",
    "POST",
    data
  )

  if not res.access_token then
    broker_log:error(1, 'EventQueue:refreshToken Bad access token')
    return false
  end

  self.tokens.authToken = {
    token = res.access_token,
    expTime = os.time(os.date("!*t")) + 1700
  }
end

--------------------------------------------------------------------------------
-- refreshTokenIsValid: obtain auth token
--------------------------------------------------------------------------------
function EventQueue:refreshTokenIsValid ()
  if not self.tokens.refreshToken then
    return false
  end

  if os.time(os.date("!*t")) > self.tokens.refreshToken.expTime then
    self.tokens.refreshToken = nil
    return false
  end

  return true
end

--------------------------------------------------------------------------------
-- accessTokenIsValid: obtain auth token
--------------------------------------------------------------------------------
function EventQueue:accessTokenIsValid ()
  if not self.tokens.authToken then
    return false
  end

  if os.time(os.date("!*t")) > self.tokens.authToken.expTime then
    self.tokens.authToken = nil
    return false
  end

  return true
end

--------------------------------------------------------------------------------
-- EventQueue:call run api call
-- @param {string} url, the service now instance url
-- @param {string} method, the HTTP method that is used
-- @param {string} data, the data we want to send to service now
-- @param {string} authToken, the api auth token
-- @return {array} decoded output
-- @throw exception if http call fails or response is empty
--------------------------------------------------------------------------------
function EventQueue:call (url, method, data, authToken)
  method = method or "GET"
  data = data or nil
  authToken = authToken or nil

  local endpoint = "https://" .. tostring(self.sc_params.params.instance) .. ".service-now.com/" .. tostring(url)
  self.sc_logger:debug("EventQueue:call: Prepare url " .. endpoint)

  local res = ""
  local request = curl.easy()
    :setopt_url(endpoint)
    :setopt_writefunction(function (response)
      res = res .. tostring(response)
    end)
    :setopt(curl.OPT_TIMEOUT, self.sc_params.params.connection_timeout)

  self.sc_logger:debug("EventQueue:call: Request initialize")

  -- set proxy address configuration
  if (self.sc_params.params.proxy_address ~= '') then
    if (self.sc_params.params.proxy_port ~= '') then
      request:setopt(curl.OPT_PROXY, self.sc_params.params.proxy_address .. ':' .. self.sc_params.params.proxy_port)
    else 
      self.sc_logger:error("EventQueue:call: proxy_port parameter is not set but proxy_address is used")
    end
  end

  -- set proxy user configuration
  if (self.sc_params.params.proxy_username ~= '') then
    if (self.sc_params.params.proxy_password ~= '') then
      request:setopt(curl.OPT_PROXYUSERPWD, self.proxy_username .. ':' .. self.sc_params.params.proxy_password)
    else
      self.sc_logger:error("EventQueue:call: proxy_password parameter is not set but proxy_username is used")
    end
  end

  if not authToken then
    if method ~= "GET" then
      self.sc_logger:debug("EventQueue:call: Add form header")
      request:setopt(curl.OPT_HTTPHEADER, { "Content-Type: application/x-www-form-urlencoded" })
    end
  else
    broker_log:info(3, "Add JSON header")
    request:setopt(
      curl.OPT_HTTPHEADER,
      {
        "Accept: application/json",
        "Content-Type: application/json",
        "Authorization: Bearer " .. authToken
      }
    )
  end

  if method ~= "GET" then
    self.sc_logger:debug("EventQueue:call: Add post data")
    request:setopt_postfields(data)
  end

  self.sc_logger:debug("EventQueue:call: request body " .. tostring(data))
  self.sc_logger:debug("EventQueue:call: request header " .. tostring(authToken))
  self.sc_logger:warning("EventQueue:call: Call url " .. endpoint)
  request:perform()

  respCode = request:getinfo(curl.INFO_RESPONSE_CODE)
  self.sc_logger:debug("EventQueue:call: HTTP Code : " .. respCode)
  self.sc_logger:debug("EventQueue:call: Response body : " .. tostring(res))

  request:close()

  if respCode >= 300 then
    self.sc_logger:error("EventQueue:call: HTTP Code : " .. respCode)
    self.sc_logger:error("EventQueue:call: HTTP Error : " .. res)
    return false
  end

  if res == "" then
    self.sc_logger:warning("EventQueue:call: HTTP Error : " .. res)
    return false
  end

  return broker.json_decode(res)
end


function EventQueue:format_event()
    self.sc_event.event.formated_event = {
        source = "centreon",
        event_class = "centreon",
        severity = 5,
        node = tostring(self.sc_event.event.cache.host.name),
        time_of_event = os.date("!%Y-%m-%d %H:%M:%S", self.sc_event.event.last_check),
        description = self.sc_event.event.output
    }

  if self.sc_event.event.element == 14 then

    self.sc_event.event.formated_event.resource = tostring(self.sc_event.event.cache.host.name)
    self.sc_event.event.formated_event.severity = self.sc_event.event.state

  elseif self.sc_event.event.element == 24 then
    self.sc_event.event.formated_event.resource = tostring(self.sc_event.event.cache.service.description)
    if self.sc_event.event.state == 0 then
        self.sc_event.event.formated_event.severity = 0
    elseif self.sc_event.event.state == 1 then
        self.sc_event.event.formated_event.severity = 3
    elseif self.sc_event.event.state == 2 then 
        self.sc_event.event.formated_event.severity = 1
    elseif self.sc_event.event.state == 3 then 
        self.sc_event.event.formated_event.severity = 4
    end
  end
  
  self:add()
end
  


local queue

--------------------------------------------------------------------------------
-- init, initiate stream connector with parameters from the configuration file
-- @param {table} parameters, the table with all the configuration parameters
--------------------------------------------------------------------------------
function init (parameters)
  queue = EventQueue:new(parameters)
end

--------------------------------------------------------------------------------
-- EventQueue:add, add an event to the queue
-- @param {table} eventData, the data related to the event 
-- @return {boolean}
--------------------------------------------------------------------------------
function EventQueue:add ()
  self.events[#self.events + 1] = self.sc_event.event.formated_event
  return true
end

--------------------------------------------------------------------------------
-- EventQueue:flush, flush stored events
-- Called when the max number of events or the max age are reached
-- @return {boolean}
--------------------------------------------------------------------------------
function EventQueue:flush ()
  self.sc_logger:debug("EventQueue:flush: Concatenating all the events as one string")

  self:send_data()

  self.events = {}
  
  -- and update the timestamp
  self.sc_params.params.__internal_ts_last_flush = os.time()
  return true
end

--------------------------------------------------------------------------------
-- EventQueue:send_data, send data to external tool
-- @return {boolean}
--------------------------------------------------------------------------------
function EventQueue:send_data ()
  local data = ''
  local authToken = self:getAuthToken()
  local counter = 0

  for _, raw_event in ipairs(self.events) do
    if counter == 0 then
      data = broker.json_encode(raw_event) 
      counter = counter + 1
    else
      data = data .. ',' .. broker.json_encode(raw_event)
    end
  end

  data = '{"records":[' .. data .. ']}'
  self.sc_logger:notice('EventQueue:send_data:  creating json: ' .. data)

  if self:call(
      "api/global/em/jsonv2",
      "POST",
      data,
      authToken
    ) then
    return true
  end

  return false
end

--------------------------------------------------------------------------------
-- write,
-- @param {array} event, the event from broker
-- @return {boolean}
--------------------------------------------------------------------------------
function write (event)
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
  
  -- First, are there some old events waiting in the flush queue ?
  if (#queue.events > 0 and os.time() - queue.sc_params.params.__internal_ts_last_flush > queue.sc_params.params.max_buffer_age) then
    queue.sc_logger:warning("write: Queue max age (" .. os.time() - queue.sc_params.params.__internal_ts_last_flush .. "/" .. queue.sc_params.params.max_buffer_age .. ") is reached, flushing data")
    queue:flush()
  end

  -- Then we check that the event queue is not already full
  if (#queue.events >= queue.sc_params.params.max_buffer_size) then
    queue.sc_logger:warning("write: Queue max size (" .. #queue.events .. "/" .. queue.sc_params.params.max_buffer_size .. ") is reached BEFORE APPENDING AN EVENT, trying to flush data before appending more events, after 1 second pause.")
    queue:flush()
  end

  -- adding event to the queue
  if queue.sc_event:is_valid_event() then
    queue:format_event()
  else
    return true
  end

  -- Then we check whether it is time to send the events to the receiver and flush
  if (#queue.events >= queue.sc_params.params.max_buffer_size) then
    queue.sc_logger:warning( "write: Queue max size (" .. #queue.events .. "/" .. queue.sc_params.params.max_buffer_size .. ") is reached, flushing data")
    return queue:flush()
  end

  return true
end

