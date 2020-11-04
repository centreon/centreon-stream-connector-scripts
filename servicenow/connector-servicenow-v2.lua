#!/usr/bin/lua

--------------------------------------------------------------------------------
-- Centreon Broker PagerDuty Connector
-- Tested with the public API on the developer platform:
-- https://events.pagerduty.com/v2/enqueue
--
-- References: 
-- https://developer.pagerduty.com/api-reference/reference/events-v2/openapiv3.json/paths/~1enqueue/post
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Prerequisites:
--
-- You need a PagerDuty instance
-- You need your instance's routing_key. According to the page linked above: "The GUID of one of your Events API V2 integrations. This is the "Integration Key" listed on the Events API V2 integration's detail page."
--
-- The lua-curl and luatz libraries are required by this script:
-- yum install lua-curl epel-release
-- yum install luarocks
-- luarocks install luatz
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Parameters:
-- [MANDATORY] pdy_routing_key: see above, this will be your authentication token
-- [RECOMMENDED] pdy_centreon_url: in order to get links/url that work in your events
-- [RECOMMENDED] log_level: level of verbose. Default is 2 but in production 1 is the recommended value.
-- [OPTIONAL] http_server_url: default "https://events.pagerduty.com/v2/enqueue"
-- [OPTIONAL] http_proxy_string: default empty
--
--------------------------------------------------------------------------------

-- libraries 
local curl = require "cURL"

-- Global variables

-- Useful functions
local function get_hostname(host_id)
  local hostname = broker_cache:get_hostname(host_id)
  if not hostname then
    broker_log:warning(1, "get_hostname: hostname for id " .. host_id .. " not found. Restarting centengine should fix this.")
    hostname = host_id
  end
  
  return hostname
end

local function get_service_description(host_id, service_id)
  local service = broker_cache:get_service_description(host_id, service_id)
  if not service then
    broker_log:warning(1, "get_service_description: service_description for id " .. host_id .. "." .. service_id .. " not found. Restarting centengine should fix this.")
    service = service_id
  end
  return service
end

local function split (string)
  local hash = {}
  local separator = ","
  
  -- https://stackoverflow.com/questions/1426954/split-string-in-lua
  for value in string.gmatch(string, "([^" .. separator .. "]+)") do
    table.insert(hash, value)
  end

  return hash
end

local function isEventValid (event)
  if event then
    return true
  end

  return false
end

local function isValidCategory (category)
  local mapping = {
    neb = 1,
    bbdo = 2,
    storage = 3,
    correlation = 4,
    dumper = 5,
    bam = 6,
    extcmd = 7
  }

  for i, v in ipairs(mapping) do
    for k, u in ipairs(split(self.category)) do
      if category == v and i == u then
        return true
      end
    end
  end
  
  return false
end

local function isValidElement(category, element)
  local mapping {
    [1] = {
      acknowledgement = 1,
      comment = 2,
      custom_variable = 3,
      custom_variable_status = 4
      downtime = 5,
      event_handler = 6,
      flapping_status = 7,
      host_check = 8,
      host_dependency = 9,
      host_group = 10,
      host_group_member = 11,
      host = 12,
      host_parent = 13,
      host_status = 14,
      instance = 15,
      instance_status = 16,
      log_entry = 17,
      module = 18,
      service_check = 19,
      service_dependency = 20,
      service_group = 21,
      service_group_member = 22,
      service = 23,
      service_status = 24,
      instance_configuration = 25
    },
    [3] = {
      neb = 1,
      bbdo = 2,
      storage = 3,
      correlation = 4,
      dumper = 5,
      bam = 6,
      extcmd = 7
    },
    [6] = {
      ba_status = 1,
      kpi_status = 2,
      meta_service_status = 3,
      ba_event = 4,
      kpi_event = 5,
      ba_duration_event = 6,
      dimension_ba_event = 7,
      dimension_kpi_event = 8,
      dimension_ba_bv_relation_event = 9,
      dimension_bv_event = 10,
      dimension_truncate_table_signal = 11,
      bam_rebuild = 12,
      dimension_timeperiod = 13,
      dimension_ba_timeperiod_relation = 14,
      dimension_timeperiod_exception = 15,
      dimension_timeperiod_exclusion = 16,
      inherited_downtime = 17
    }   
  }

  for i, v in ipairs(mapping[category]) do
    for k, u in ipairs(split(self.dataType)) do
      if element == v and i == u then
        return true
      end
    end
  end

  return false
end

local function isValidEvent (event)
  local validEvent = {}
  
  if event.category == 1 then
    validEvent.service_status = false
    validEvent.host_status = false
    validEvent.ack = false
    validEvent.state = false
    validEvent.downtime = false

    if event.element == 14 then
      validEvent.serviceStatus = true
      for i, v in ipairs(self.hostStatus) do
        if event.status == v then
          validEvent.host_status = true
        end
      end
    elseif event.element == 24 then
      if event.host_id is nil and self.skip_anon_events == 1 then
        return false
      end

      validEvent.host_status = true
      for i, v in ipairs(self.serviceStatus) do
        if event.status == v then
          validEvent.service_status = true
        end
      end
    end

    if self.hardOnly ~= 0 or self.hardOnly ~= 1 then
      self.hardOnly = 1
    end 
  
    if self.acknowledged ~= 0 or self.acknowledged ~= 1 then
      self.acknowledged = 1
    end 
  
    if event.state_type >= self.hardOnly then
      validEvent.state = true
    end
  
    if event.ack >= self.acknowledged then
      validEvent.ack = true
    end
  
    if event.downtime >= self.inDowntime then
      validEvent.downtime = true
    end
  end
  
  for i, v in ipairs(validEvent) do
    if not v then
      return false
    end
  end

  return true
end

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

function EventQueue.new (conf)
  local retval = {
    host_status = "0,1,2",
    service_status = "0,1,2,3",
    hard_only = 1,
    acknowledged = 0,
    element_type = "metrics,host_status,service_status",
    category_type = "neb,storage",
    in_downtime = 0,
    max_buffer_size = 1,
    max_buffer_age = 5,
    skip_anon_events = 1
    instance = "",
    username = "",
    password = "",
    clientId = "",
    clientPassword = "",
    tokens = {},
    tokens.authToken = nil,
    tokens.refreshToken = nil,
  }

  for i,v in pairs(conf) do
    if retval[i] then
      retval[i] = v
      broker_log:info(2, "EventQueue.new: getting parameter " .. i .. " => " .. v)
    else
      broker_log:warning(1, "EventQueue.new: ingoring unhandled parameter " .. i .. " => " .. v)
    end
  end

  retval.__internal_ts_last_flush = os.time()
  retval.events = {}
  setmetatable(retval, EventQueue)
  -- Internal data initialization
  broker_log:info(2, "EventQueue.new: setting the internal timestamp to " .. retval.__internal_ts_last_flush)

  return retval
end

--------------------------------------------------------------------------------
-- EventQueue:getAuthToken handle tokens
-- @return {string} the new EventQueue
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
-- EventQueue:authToken prepare api call to get auth token
--------------------------------------------------------------------------------

EventQueue:authToken ()
  local data = "grant_type=password&client_id=" .. self.clientId .. "&client_secret=" .. self.clientPassword .. "&username=" .. self.username .. "&password=" .. self.password

  local res = self:call(
    "oauth_token.do",
    "POST",
    data
  )

  if not res.access_token then
    error("Authentication failed")
  end

  self.tokens.authToken = {
    token = res.access_token,
    expTime = os.time(os.date("!*t")) + 1700
  }

  self.tokens.refreshToken = {
    token = res.resfresh_token,
    expTime = os.time(os.date("!*t")) + 360000
  }
end

--------------------------------------------------------------------------------
-- EventQueue:refreshToken update token
-- @param {string} token 
--------------------------------------------------------------------------------

function EventQueue:refreshToken (token)
  local data = "grant_type=refresh_token&client_id=" .. self.clientId .. "&client_secret=" .. self.clientPassword .. "&username=" .. self.username .. "&password=" .. self.password
  
  res = self.call(
    "oauth_token.do",
    "POST",
    data
  )

  if not res.access_token then
    error("Bad access token")
  end

  self.tokens.authToken = {
    token = res.access_token,
    expTime = os.time(os.date("!*t")) + 1700
  }
end

--------------------------------------------------------------------------------
-- EventQueue:refreshTokenIsValid check if token is valid
-- @return {boolean}
--------------------------------------------------------------------------------

function EventQueue:refreshTokenIsValid ()
  if not self.tokens.refreshToken then
    return false
  end

  if os.time(os.date("!*t")) > self.tokens.refreshToken.expTime then
    self.refreshToken = nil

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

  local endpoint = "https://" .. tostring(self.instance) .. ".service-now.com/" .. tostring(url)
  broker_log:info(1, "Prepare url " .. endpoint)

  local res = ""
  local request = curl.easy()
    :setopt_url(endpoint)
    :setopt_writefunction(function (response)
      res = res .. tostring(response)
    end)
  broker_log:info(1, "Request initialize")

  if not authToken then
    if method ~= "GET" then
      broker_log:info(1, "Add form header")
      request:setopt(curl.OPT_HTTPHEADER, { "Content-Type: application/x-www-form-urlencoded" })
      broker_log:info(1, "After add form header")
    end
  else
    broker_log:info(1, "Add JSON header")
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
    broker_log:info(1, "Add post data")
    request:setopt_postfields(data)
  end

  broker_log:info(1, "Call url " .. endpoint)
  request:perform()

  respCode = request:getinfo(curl.INFO_RESPONSE_CODE)
  broker_log:info(1, "HTTP Code : " .. respCode)
  broker_log:info(1, "Response body : " .. tostring(res))

  request:close()

  if respCode >= 300 then
    broker_log:info(1, "HTTP Code : " .. respCode)
    broker_log:info(1, "HTTP Error : " .. res)
    error("Bad request code")
  end

  if res == "" then
    broker_log:info(1, "HTTP Error : " .. res)
    error("Bad content")
  end

  broker_log:info(1, "Parsing JSON")
  return broker.json_decode(res)
end

--------------------------------------------------------------------------------
-- EventQueue:call send event to service now
-- @param {array} event, the event we want to send
-- @return {boolean}
--------------------------------------------------------------------------------

function ServiceNow:sendEvent (event)
  local authToken = self:getAuthToken()

  broker_log:info(1, "Event information :")
  for k, v in pairs(event) do
    broker_log:info(1, tostring(k) .. " : " .. tostring(v))
  end

  broker_log:info(1, "------")
  broker_log:info(1, "Auth token " .. authToken)
  if pcall(self:call(
      "api/now/table/em_event",
      "POST",
      broker.json_encode(event),
      authToken
    )) then
    return true
  end

  return false
end

--------------------------------------------------------------------------------
-- EventQueue:call 
-- @param {array} event, the event we want to send
-- @return {boolean}
--------------------------------------------------------------------------------

function init (parameters)
  logfile = parameters.logfile or "/var/log/centreon-broker/connector-servicenow.log"
  if not parameters.instance or not parameters.username or not parameters.password
     or not parameters.client_id or not parameters.client_secret then
     error("The needed parameters are 'instance', 'username', 'password', 'client_id' and 'client_secret'")
  end

  broker_log:set_parameters(1, logfile)
  broker_log:info(1, "Parameters")
  for i,v in pairs(parameters) do
    broker_log:info(1, "Init " .. i .. " : " .. v)
  end

  serviceNow = ServiceNow:new(
    parameters.instance,
    parameters.username,
    parameters.password,
    parameters.client_id,
    parameters.client_secret
  )
end

--------------------------------------------------------------------------------
-- write
-- @param {array} data, the data from broker
-- @return {boolean}
--------------------------------------------------------------------------------

function write (data)
  local sendData = {
    source = "centreon",
    event_class = "centreon",
    severity = 5
  }

  broker_log:info(1, "Prepare Go category " .. tostring(data.category) .. " element " .. tostring(data.element))

  if not isValidEvent(data) then
    return false
  end

  hostname = get_hostname(data.host_id)
  sendData.node = hostname
  sendData.description = data.output
  sendData.time_of_event = os.date("%Y-%m-%d %H:%M:%S", data.last_check)

  if data.element == 14 then
    sendData.resource = hostname
    if data.current_state == 0 then
      sendData.severity = 0
    elseif data.current_state then
      sendData.severity = 1
    end
  else
    service_description = get_service_description(data.host_id, data.service_id)
    if data.current_state == 0 then
      sendData.severity = 0
    elseif data.current_state == 1 then
      sendData.severity = 3
    elseif data.current_state == 2 then
      sendData.severity = 1
    elseif data.current_state == 3 then
      sendData.severity = 4
    end

    sendData.resource = service_description
  end

  return EventQueue:sendEvent(sendData)
end

--------------------------------------------------------------------------------
-- filter
-- @param {integer} category, the category of the event
-- @param {integer} element, the element of the event
-- @return {boolean}
--------------------------------------------------------------------------------
function filter (category, element)
  if not isValidCategory(category) then
    return false
  end

  if not isValidElement(category, element) then
    return false
  end

  broker_log:info(1, "Go category " .. tostring(category) .. " element " .. tostring(element))

  return true
end