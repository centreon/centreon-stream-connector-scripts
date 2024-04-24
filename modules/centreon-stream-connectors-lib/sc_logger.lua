#!/usr/bin/lua

--- 
-- Logging module for centreon stream connectors
-- @module sc_logger
-- @alias sc_logger

local sc_logger = {}

--- build_message: prepare log message
-- @param severity (string) the severity of the message (WARNING, CRITIAL...)
-- @param message (string) the log message 
-- @return ouput (string) the formated log message
local function build_message(severity, message)
  local date = os.date("%a %b %d %H:%M:%S %Y")
  local output = date .. ": " .. severity .. ": " .. message .. "\n"
  
  return output
end


--- write_message: write a message in a file
-- @param message (string) the message to write
-- @param logfile (string) the file in which the message will be written
local function write_message(message, logfile)
  local file = io.open(logfile, "a")
  io.output(file)
  io.write(message)
  io.close(file)
end

--- file_logging: log message in a file
-- @param message (string) the message that need to be written
-- @param severity (string) the severity of the log
-- @param logfile (string) the ouput file
local function file_logging(message, severity, logfile)
  write_message(build_message(severity, message), logfile)
end

local ScLogger = {}

--- sc_logger.new: sc_logger constructor
-- @param [opt] logfile (string) output file for logs
-- @param [opt] severity (integer) the accepted severity level 
function sc_logger.new(logfile, severity)
  local self = {}
  self.severity = severity

  if type(severity) ~= "number" then
    self.severity = 1
  end

  self.logfile = logfile or "/var/log/centreon-broker/stream-connector.log"
  broker_log:set_parameters(self.severity, self.logfile)
  
  setmetatable(self, { __index = ScLogger })

  return self
end

--- error: write an error message
-- @param message (string) the message that will be written
function ScLogger:error(message)
  broker_log:error(1, message)
end

--- warning: write a warning message
-- @param message (string) the message that will be written
function ScLogger:warning(message)
  broker_log:warning(2, message)
end

--- notice: write a notice message
-- @param message (string) the message that will be written
function ScLogger:notice(message)
  broker_log:info(1, message)
end

-- info: write an informational message
-- @param message (string) the message that will be written
function ScLogger:info(message)
  broker_log:info(2,message)
end

--- debug: write a debug message
-- @param message (string) the message that will be written
function ScLogger:debug(message)
  broker_log:info(3, message)
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
    if params.allow_insecure_connection == 1 then
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