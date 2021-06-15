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

return sc_logger