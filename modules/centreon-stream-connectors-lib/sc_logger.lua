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
-- @param [opt] is_test (boolean) use broker log if true, directly write in file if false
function sc_logger.new(logfile, severity, is_test)
  local self = {}
  self.is_test = is_test
  self.severity = severity

  if type(self.is_test) ~= 'boolean' then
    self.is_test = false
  end

  if type(severity) ~= 'number' then
    self.severity = 1
  end

  self.logfile = logfile or '/var/log/centreon-broker/stream-connector.log'

  setmetatable(self, { __index = ScLogger })

  return self
end

--- error: write an error message
-- @param message (string) the message that will be written
function ScLogger:error(message)
  if not self.is_test then
    broker_log:error(1, message)
  else
    file_logging(message, 'ERROR', self.logfile)
  end
end

--- warning: write a warning message
-- @param message (string) the message that will be written
function ScLogger:warning(message)
  if self.severity >= 2 then
    if not self.is_test then
      broker_log:warning(2, message)
    else
      file_logging(message, 'WARNING', self.logfile)  
    end
  end
end

--- notice: write a notice message
-- @param message (string) the message that will be written
function ScLogger:notice(message)
  if not self.is_test then
    broker_log:info(1, message)
  else
    file_logging(message, 'NOTICE', self.logfile)
  end
end

--- debug: write a debug message
-- @param message (string) the message that will be written
function ScLogger:debug(message)
  if self.severity >= 3 then
    if not self.is_test then
      broker_log:info(3, message)
    else 
      file_logging(message, 'DEBUG', self.logfile)
    end
  end
end


return sc_logger