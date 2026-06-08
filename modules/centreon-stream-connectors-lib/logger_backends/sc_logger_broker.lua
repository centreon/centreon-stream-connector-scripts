#!/bin/lua

---
-- logger that is using centreon broker methods to log
-- @module sc_logger_broker
-- @module ScLoggerBroker

local sc_logger_broker = {}
local ScLoggerBroker = {}

function sc_logger_broker.new(logger_params)
  local self = {}

  self.log_level = logger_params.log_level

  if type(self.log_level) ~= "number" then
    self.log_level = 1
  end

  self.logfile = logger_params.logfile or "/var/log/centreon-broker/stream-connector.log"
  broker_log:set_parameters(self.log_level, self.logfile)

  setmetatable(self, { __index = ScLoggerBroker})
  return self
end

--- error: write an error message
-- @param message (string) the message that will be written
function ScLoggerBroker:error(message)
  broker_log:error(1, message)
end

--- warning: write a warning message
-- @param message (string) the message that will be written
function ScLoggerBroker:warning(message)
  broker_log:warning(2, message)
end

--- notice: write a notice message
-- @param message (string) the message that will be written
function ScLoggerBroker:notice(message)
  broker_log:info(1, message)
end

-- info: write an informational message
-- @param message (string) the message that will be written
function ScLoggerBroker:info(message)
  broker_log:info(2,message)
end

--- debug: write a debug message
-- @param message (string) the message that will be written
function ScLoggerBroker:debug(message)
  broker_log:info(3, message)
end

return sc_logger_broker