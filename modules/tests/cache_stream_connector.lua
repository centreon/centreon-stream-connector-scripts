#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker Datadog Connector Events
--------------------------------------------------------------------------------


-- Libraries
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_cache = require("centreon-stream-connectors-lib.sc_cache")
local sc_params = require("centreon-stream-connectors-lib.sc_params")

--------------------------------------------------------------------------------
-- Classe event_queue
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Classe event_queue
--------------------------------------------------------------------------------

local EventQueue = {}
EventQueue.__index = EventQueue

--------------------------------------------------------------------------------
---- Constructor
---- @param conf The table given by the init() function and returned from the GUI
---- @return the new EventQueue
----------------------------------------------------------------------------------

function EventQueue.new(params)
  local self = {}

  local mandatory_parameters = {}

  self.fail = false

  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/sc_test_cache.log"
  local log_level = params.log_level or 1

  -- initiate mandatory objects
  self.sc_logger = sc_logger.new(logfile, log_level)
  self.sc_common = sc_common.new(self.sc_logger)
  self.sc_params = sc_params.new(self.sc_common, self.sc_logger)

  -- checking mandatory parameters and setting a fail flag
  if not self.sc_params:is_mandatory_config_set(mandatory_parameters, params) then
    self.fail = true
  end

  -- apply users params and check syntax of standard ones
  self.sc_params:param_override(params)
  self.sc_params:check_params()

  self.sc_cache = sc_cache.new(self.sc_params.params, self.sc_common, self.sc_logger)

  -- return EventQueue object
  setmetatable(self, { __index = EventQueue })
  return self
end


local queue

-- Fonction init()
function init(conf)
  queue = EventQueue.new(conf)
end

function write(event)
  return true
end

function flush()
  return true
end