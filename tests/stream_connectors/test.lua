#!/usr/bin/lua

-- Libraries
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_event = require("centreon-stream-connectors-lib.sc_event")
local sc_params = require("centreon-stream-connectors-lib.sc_params")
local sc_macros = require("centreon-stream-connectors-lib.sc_macros")
local sc_flush = require("centreon-stream-connectors-lib.sc_flush")
local sc_metrics = require("centreon-stream-connectors-lib.sc_metrics")
local sc_storage = require("centreon-stream-connectors-lib.sc_storage")

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

  broker_log:info(0, 'lua start test')

  local self = {}

  local mandatory_parameters = {}

  self.fail = false

  -- set up log configuration
  local logfile = params.logfile or "/tmp/test-LUA.log"
  local log_level = params.log_level or 2

  -- initiate mandatory objects
  self.sc_logger = sc_logger.new(logfile, log_level)
  self.sc_common = sc_common.new(self.sc_logger)
  self.sc_params = sc_params.new(self.sc_common, self.sc_logger)

  -- checking mandatory parameters and setting a fail flag
  if not self.sc_params:is_mandatory_config_set(mandatory_parameters, params) then
    self.fail = true
  end

  -- overriding default parameters for this stream connector if the default values doesn't suit the basic needs
  self.sc_params.params.accepted_categories = params.accepted_categories or "neb"
  self.sc_params.params.accepted_elements = params.accepted_elements or "host_status,service_status"
  -- storage params
  self.sc_params.params.storage_backend = params.storage_backend or "sqlite"
  -- apply users params and check syntax of standard ones
  self.sc_params:param_override(params)
  self.sc_params:check_params()
  self.sc_macros = sc_macros.new(self.sc_params.params, self.sc_logger)

  self.sc_params:build_accepted_elements_info()
  self.sc_flush = sc_flush.new(self.sc_params.params, self.sc_logger)
  self.sc_broker = sc_broker.new(self.sc_params.params, self.sc_logger)
  self.sc_storage = sc_storage.new(self.sc_common, self.sc_logger, self.sc_params.params)

  local categories = self.sc_params.params.bbdo.categories
  local elements = self.sc_params.params.bbdo.elements

  -- return EventQueue object
  setmetatable(self, { __index = EventQueue })
  return self
end

--------------------------------------------------------------------------------
-- Required functions for Broker StreamConnector
--------------------------------------------------------------------------------

local queue
local downtime

-- Fonction init()
function init(conf)
  queue = EventQueue.new(conf)
end

--------------------------------------------------------------------------------
-- write,
-- @param {table} event, the event from broker
-- @return {boolean}
--------------------------------------------------------------------------------
function write (event)
    -- skip event if a mandatory parameter is missing
    if queue.fail then
        queue.sc_logger:error("Skipping event because a mandatory parameter is not set")
        return false
    end
    -- initiate event object
    queue.sc_event = sc_event.new(event, queue.sc_params.params, queue.sc_common, queue.sc_logger, queue.sc_broker, queue.sc_storage)

    if event._type == 65541 or event._type == 65572 then
        broker_log:info(0, 'downtime event detected')
        broker_log:info(0, 'broker event data: ' .. broker.json_encode(event))
        broker_log:info(0, 'queue.sc_event event data: ' .. broker.json_encode(queue.sc_event.event))
        --local svc = broker_cache:get_service(event.host_id,event.service_id)
        --broker_log:info(0, broker.json_encode(svc))
    elseif event._type == 65550 or event._type == 65538 then
        broker_log:info(0, 'host status event detected')
        broker_log:info(0, 'event data: ' .. broker.json_encode(event))
        broker_log:info(0, 'queue.sc_event event data: ' .. broker.json_encode(queue.sc_event.event))
    elseif event._type == 65560 or event._type == 65565 then
        broker_log:info(0, 'service status event detected')
        broker_log:info(0, 'event data: ' .. broker.json_encode(event))
        broker_log:info(0, 'queue.sc_event event data: ' .. broker.json_encode(queue.sc_event.event))
    else
        return true
    end
    broker_log:info(0, 'configuration of ('.. event.host_id.. ','.. event.service_id.. ')')

    if queue.sc_event:is_valid_category() then
      --broker_log:info(0, 'is_valid_category')
      if queue.sc_event:is_valid_element() then
        --broker_log:info(0, 'is_valid_element')
        -- format event if it is validated
        if queue.sc_event:is_valid_event() then
          broker_log:info(0, 'is_valid_event')
          broker_log:info(0, 'valid event detected and processed')
        end
      --- log why the event has been dropped
      else
        broker_log:info(0, 'is_not_valid_element')
        broker_log:info(0, "dropping event because element is not valid. Event element is: " .. tostring(queue.sc_params.params.reverse_element_mapping[queue.sc_event.event.category][queue.sc_event.event.element]))
        queue.sc_logger:debug("dropping event because element is not valid. Event element is: "
        .. tostring(queue.sc_params.params.reverse_element_mapping[queue.sc_event.event.category][queue.sc_event.event.element]))
      end
    else
      broker_log:info(0, 'is_not_valid_category')
      broker_log:info(0, "dropping event because category is not valid. Event category is: " .. tostring(queue.sc_params.params.reverse_category_mapping[queue.sc_event.event.category]))
      queue.sc_logger:debug("dropping event because category is not valid. Event category is: "
      .. tostring(queue.sc_params.params.reverse_category_mapping[queue.sc_event.event.category]))
    end

    return true
end