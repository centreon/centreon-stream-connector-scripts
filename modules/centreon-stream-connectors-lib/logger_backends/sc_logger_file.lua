---
-- logger that is using a text file to write logs
-- (main difference with the broker logger backend is that it is not using broker method as proxy to write into a file)
-- @module sc_logger_file
-- @module ScLoggerFile

local sc_logger_file = {}
local ScLoggerFile = {}

function sc_logger_file.new(logger_params)
  local self = {}

  self.severity = logger_params.severity

  if type(severity) ~= "number" then
    self.severity = 1
  end

  self.logfile = logger_params.logfile or "/var/log/centreon-broker/stream-connector.log"
  self.fh = io.open(self.logfile, "a+")

  setmetatable(self, { __index = ScLoggerFile})
  return self
end

--- write_message: write a message in a file
-- @param message (string) the message to write
function ScLoggerFile:write_message(message)
  local date = os.date("%a %b %d %H:%M:%S %Y")
  self.fh:write("[" .. date .. "]" .. message .. "\n")
end

--- error: write an error message
-- @param message (string) the message that will be written
function ScLoggerFile:error(message)
  self:write_message("[ERROR] " .. message)
end

--- warning: write a warning message
-- @param message (string) the message that will be written
function ScLoggerFile:warning(message)
  if self.severity >= 2 then
    self:write_message("[WARNING] " .. message)
  end
end

--- notice: write a notice message
-- @param message (string) the message that will be written
function ScLoggerFile:notice(message)
  self:write_message("[NOTICE] " .. message)
end

--- info: write an info message
-- @param message (string) the message that will be written
function ScLoggerFile:info(message)
  if self.severity >= 2 then
    self:write_message("[INFO] " .. message)
  end
end

--- debug: write an debug message
-- @param message (string) the message that will be written
function ScLoggerFile:debug(message)
  if self.severity >= 3 then
    self:write_message("[DEBUG] " .. message)
  end
end


return sc_logger_file