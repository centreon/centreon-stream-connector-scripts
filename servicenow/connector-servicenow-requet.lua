local http = require("socket.http")
local ltn12 = require("ltn12")
local JSON = (loadfile "JSON.lua")()

-- Class for Service now connection
ServiceNow = {}
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
  data = "grant_type=password&client_id=" .. self.clientId .. "&client_secret=" .. self.clientPassword ..
    "&username=" .. self.username .. "&password=" .. self.password

  res = self:call(
    "oauth_token.do",
    "POST",
    data
  )
  if not res.access_token then
    -- Exception
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
  data = "grant_type=refresh_token&client_id=" .. self.clientId .. "&client_secret=" .. self.clientPassword ..
  "&username=" .. self.username .. "&password=" .. self.password
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
  if self.tokens.refreshToken == nil then
    return false
  end
  if os.time(os.date("!*t")) > self.tokens.refreshToken.expTime then
    self.refreshToken = nil
    return false
  end
  return true
end

function ServiceNow:accessTokenIsValid ()
  if self.tokens.authToken == nil then
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

  headers = {
    ["Content-Type"] = "application/x-www-form-urlencoded";
    ["Content-Length"] = #data;
  }

  if authToken then
    headers["Content-Type"] = "application/json"
    headers["Accept"] = "application/json"
    headers["Authorization"] = "Bearer " .. authToken
  end

  print("https://" .. self.instance .. ".service-now.com/" .. url)
  print(data)
  print(method)
  for i,v in pairs(headers) do
    print("Header " .. i .. " : " .. v)
  end
  print("")

  local resp = {}
  res, code, resp_headers = http.request{
    url = "https://" .. self.instance .. ".service-now.com/" .. url,
    method = method,
    headers = headers,
    source = ltn12.source.string(data),
    sink = ltn12.sink.table(resp)
  }

  print(code)
  print(res)
  for i,v in pairs(resp_headers) do
    print("Header " .. i .. " : " .. v)
  end
  print("")

  if code >= 300 then
    error("Error when call the ServiceNow webservice")
  end

  return JSON:decode(res) -- JSON decode
end

function ServiceNow:sendEvent (event)
  -- Build event
  event = {}

  authToken = self:getAuthToken()
  if pcall(self:call(
      "api/now/table/em_event",
      "POST",
      event,
      authToken
    )) then
    return true
  end
  return false
end

sn = ServiceNow:new("xxxxxxxx", "xxxxxxx", "xxxxxxx", "xxxxxxx", "xxxxxxx")
sn:sendEvent({})
