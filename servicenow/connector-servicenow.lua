#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker Servicenow Connector
--
--------------------------------------------------------------------------------

local curl = require "cURL"

local serviceNow

-- Class for Service now connection
local ServiceNow = {}
ServiceNow.__index = ServiceNow

function ServiceNow:new(instance, username, password, clientId, clientPassword)
  local serviceNow = {}
  setmetatable(serviceNow, ServiceNow)
  serviceNow.instance = instance
  serviceNow.username = username
  serviceNow.password = password
  serviceNow.clientId = clientId
  serviceNow.clientPassword = clientPassword
  serviceNow.tokens = {}
  serviceNow.tokens.authToken = nil
  serviceNow.tokens.refreshToken = nil
  return serviceNow
end

function ServiceNow:getAuthToken ()
  if not self:refreshTokenIsValid() then
    self:authToken()
  end
  if not self:accessTokenIsValid() then
    self:refreshToken(self.tokens.refreshToken.token)
  end
  return self.tokens.authToken.token
end

function ServiceNow:authToken ()
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

function ServiceNow:refreshToken (token)
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

function ServiceNow:refreshTokenIsValid ()
  if not self.tokens.refreshToken then
    return false
  end
  if os.time(os.date("!*t")) > self.tokens.refreshToken.expTime then
    self.refreshToken = nil
    return false
  end
  return true
end

function ServiceNow:accessTokenIsValid ()
  if not self.tokens.authToken then
    return false
  end
  if os.time(os.date("!*t")) > self.tokens.authToken.expTime then
    self.authToken = nil
    return false
  end
  return true
end

function ServiceNow:call (url, method, data, authToken)
  method = method or "GET"
  data = data or nil
  authToken = authToken or nil

  local endpoint = "https://" .. tostring(self.instance) .. ".service-now.com/" .. tostring(url)
  broker_log:info(1, "Prepare url " .. endpoint)

  local res = ""
  local request = curl.easy()
    :setopt_url(endpoint)
    :setopt_writefunction(function (responce)
      res = res .. tostring(responce)
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

function init(parameters)
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

function write(data)
  local sendData = {
    source = "centreon",
    event_class = "centreon",
    severity = 5
  }

  broker_log:info(1, "Prepare Go category " .. tostring(data.category) .. " element " .. tostring(data.element))

  if data.category == 1 then
    broker_log:info(1, "Broker event data")
    for k, v in pairs(data) do
      broker_log:info(1, tostring(k) .. " : " .. tostring(v))
    end
    broker_log:info(1, "------")

    -- Doesn't process if the host is acknowledged or disabled
    if data.acknowledged or not data.enabled then
      broker_log:info(1, "Dropped because acknowledged or not enabled")
      return true
    end
    -- Doesn't process if the host state is not hard
    if data.state_type ~= 1 then
      broker_log:info(1, "Dropped because state is not hard")
      return true
    end
    hostname = broker_cache:get_hostname(data.host_id)
    if not hostname then
      broker_log:info(1, "Dropped missing hostname")
      return true
    end
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
      service_description = broker_cache:get_service_description(data.host_id, data.service_id)
      if not service_description then
        broker_log:info(1, "Droped missing service description")
        return true
      end
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
  else
    return true
  end

  return serviceNow:sendEvent(sendData)
end

function filter(category, element)
  if category == 1 then
    if element == 14 or element == 24 then
      broker_log:info(1, "Go category " .. tostring(category) .. " element " .. tostring(element))
      return true
    end
  end
  return false
end
