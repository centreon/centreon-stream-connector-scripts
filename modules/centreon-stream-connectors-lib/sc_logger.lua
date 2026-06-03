#!/usr/bin/lua

--- 
-- Logging module for centreon stream connectors
-- @module sc_logger
-- @alias sc_logger

local sc_logger = {}
local ScLogger = {}

--- sc_logger.new: sc_logger constructor
-- @param [opt] logger_params (table) a table of params that contains needed parameters for the given logger backend
function sc_logger.new(logger_params)
  local self = {}

  if pcall(require, "centreon-stream-connectors-lib.logger_backends.sc_logger_" .. logger_params.logger_backend) then
    local logger_backend = require("centreon-stream-connectors-lib.logger_backends.sc_logger_" .. logger_params.logger_backend)
    self.logger_backend = logger_backend.new(logger_params)
  else
    self.logger_backend = require("centreon-stream-connectors-lib.logger_backends.sc_logger_broker")
  end

  setmetatable(self, { __index = ScLogger })
  return self
end

--- error: write an error message
-- @param message (string) the message that will be written
function ScLogger:error(message)
  self.logger_backend:error(message)
end

--- warning: write a warning message
-- @param message (string) the message that will be written
function ScLogger:warning(message)
  self.logger_backend:warning(message)
end

--- notice: write a notice message
-- @param message (string) the message that will be written
function ScLogger:notice(message)
  self.logger_backend:notice(message)
end

-- info: write an informational message
-- @param message (string) the message that will be written
function ScLogger:info(message)
  self.logger_backend:info(message)
end

--- debug: write a debug message
-- @param message (string) the message that will be written
function ScLogger:debug(message)
  self.logger_backend:debug(message)
end

--- log_curl_command: build a shell curl command based on given parameters and write it in the logfile
-- @param url (string) the url to which curl will send data
-- @param metadata (table) a table that contains headers information and http method for curl
-- @param params (table) the stream connector params table
-- @param data (string) [opt] the data that must be send by curl
-- @param basic_auth (table) [opt] a table that contains the username and the password if using basic auth ({"username" = username, "password" = password})
function ScLogger:log_curl_command(url, metadata, params, data, basic_auth)
  if params.log_curl_commands == 1 then
    self:debug("[sc_logger:log_curl_command]: starting computing curl command")
    local curl_string = "curl"

    -- handle proxy
    self:debug("[sc_looger:log_curl_command]: proxy information: protocol: " .. params.proxy_protocol .. ", address: "
      .. params.proxy_address .. ", port: " .. params.proxy_port .. ", user: " .. params.proxy_username .. ", password: "
      .. tostring(params.proxy_password))
    local proxy_url
    
    if params.proxy_address ~= "" then  
      if params.proxy_username ~= "" then
        proxy_url = params.proxy_protocol .. "://" .. params.proxy_username .. ":" .. params.proxy_password
          .. "@" .. params.proxy_address .. ":" .. params.proxy_port
      else
        proxy_url = params.proxy_protocol .. "://" .. params.proxy_address .. ":" .. params.proxy_port
      end
  
      curl_string = curl_string .. " --proxy '" .. proxy_url .. "'"
    end
  
    -- handle certificate verification
    -- It's false because of this part: Tell libcurl to not verify the peer. With libcurl you disable this with curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, FALSE);
    if params.verify_certificate == false then
      curl_string = curl_string .. " -k"
    end

    -- handle http method
    if metadata.method then
      curl_string = curl_string .. " -X " .. metadata.method
    elseif data then
      curl_string = curl_string .. " -X POST"
    else
      curl_string = curl_string .. " -X GET"
    end
  
    -- handle headers
    if metadata.headers then
      for _, header in ipairs(metadata.headers) do
        curl_string = curl_string .. " -H '" .. tostring(header) .. "'"
      end
    end
  
    curl_string = curl_string .. " '" .. tostring(url) .. "'"
  
    -- handle curl data
    if data and data ~= "" then
      curl_string = curl_string .. " -d '" .. data .. "'"
    end

    -- handle http basic auth
    if basic_auth then
      curl_string = curl_string .. " -u '" .. basic_auth.username .. ":" .. basic_auth.password .. "'"
    end
  
    self:notice("[sc_logger:log_curl_command]: " .. curl_string)
  else
    self:debug("[sc_logger:log_curl_command]: curl command not logged because log_curl_commands param is set to: " .. params.log_curl_commands)
  end
end

return sc_logger