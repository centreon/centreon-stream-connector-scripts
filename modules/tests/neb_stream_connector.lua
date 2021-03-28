#!/usr/bin/lua

local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_event = require("centreon-stream-connectors-lib.sc_event")
local sc_params = require("centreon-stream-connectors-lib.sc_event")

local EventQueue = {}
function EventQueue.new(params)
  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/stream-connector.log"
  local log_level = params.log_level or 1
  
  -- initiate mandatory objects
  self.sc_logger = sc_logger.new(logfile, log_level)
  self.sc_common = sc_common.new(self.sc_logger)
  self.sc_broker = sc_broker.new(self.sc_logger)
  self.sc_params = sc_params.new(self.sc_common, self.sc_logger)

  -- checking mandatory parameters and setting a fail flag
  if not params.output_file then
    self.sc_logger:error("output_file is a mandatory parameter.")
    self.fail = true
  else
    self.fail = false
  end

  -- setting default parameters for this stream connector
  params.accepted_categories = 'neb'
  params.accepted_elements = 'host_status,service_status'

  -- apply users params and check syntax of standard ones
  self.sc_params:param_override(params)
  self.sc_params:check_params()

  -- return EventQueue object
  setmetatable(self, { __index = EventQueue })
  return self
end

--------------------------------------------------------------------------------
-- EventQueue:format_event, build your own table with the desired information
-- @return true (boolean)
--------------------------------------------------------------------------------
function EventQueue:format_event()
  -- starting to handle shared information between host and service
  self.current_event.formated_event = {
    -- name of host has been stored in a cache table when calling is_valid_even()
    my_host = self.current_event.cache.name,
    -- states (critical, ok...) are found and converted to human format thanks to the status_mapping table
    my_state = self.sc_params.status_mapping[self.current_event.category][self.current_event.element][self.current_event.state],
    -- get output of the event
    my_output = self.sc_common:ifnil_or_empty(string.match(self.current_event.output, "^(.*)\n"), "no output"),
    -- like the name of the host, notes are stored in the cache table of the event
    my_notes = self.sc_common:ifnil_or_empty(self.current_event.cache.notes, "no notes found")
  }

  -- handle service specific information
  if self.sc_event.element == 24 then
    -- like the name of the host, service description is stored in the cache table of the event
    self.current_event.formated_event.my_description = self.current_event.cache.description
    -- if the service doesn't have notes,  we can retrieve the ones from the host by fetching it from the broker cache
    self.current_event.formated_event.my_notes = self.sc_common:ifnil_or_empty(self.sc_broker:get_host_infos(self.current_event.host_id, "notes"), "no notes found")
  end

  queue:add()

  return true
end

--------------------------------------------------------------------------------
-- EventQueue:add, add an event to the sending queue
--------------------------------------------------------------------------------
function EventQueue:add ()
  -- store event in self.events list
  self.events[#self.events + 1] = self.current_event.formated_event
end

--------------------------------------------------------------------------------
-- EventQueue:flush, flush stored events
-- Called when the max number of events or the max age are reached
-- @return (boolean)
--------------------------------------------------------------------------------
function EventQueue:flush ()
  self.sc_logger:debug("EventQueue:flush: Concatenating all the events as one string")

  -- send stored events
  retval = self:send_data()

  -- reset stored events list
  self.events = {}
  
  -- and update the timestamp
  self.sc_params.__internal_ts_last_flush = os.time()

  return retval
end

--------------------------------------------------------------------------------
-- EventQueue:send_data, send data to external tool
-- @return (boolean)
--------------------------------------------------------------------------------
function EventQueue:send_data ()
  local data = ''
  local counter = 0

  -- concatenate all stored event in the data variable
  for _, formated_event in ipairs(self.events) do
    if counter == 0 then
      data = broker.json_encode(formated_event) 
      counter = counter + 1
    else
      data = data .. ',' .. broker.json_encode(formated_event)
    end
  end

  self.logger:debug("EventQueue:send_data:  creating json: " .. tostring(data))

  -- output data to the tool we want
  if self:call(data) then
    return true
  end

  return false
end

--------------------------------------------------------------------------------
-- EventQueue:call send the data where we want it to be
-- @param data (string) the data we want to send
-- @return true (boolean)
--------------------------------------------------------------------------------
function EventQueue:call (data)
  data = data or nil

  -- open a file
  self.logger:debug("EventQueue:call: opening file " .. self.params.output_file)
  local file = io.open(self.params.output_file, "a")
  io.output(file)

  -- write in the file
  self.logger:debug("EventQueue:call: writing message " .. tostring(data))
  io.write(data)

  -- close the file
  self.logger:debug("EventQueue:call: closing file " .. self.params.output_file)
  io.close(data)
  
  return true
end

local queue

function init(params)
  queue = EventQueue.new(parameters)
end

function write(event)
  -- skip event if a mandatory parameter is missing
  if queue.fail then
    self.sc_logger:error("Skipping event because a mandatory parameter is not set")
    return true
  end

  -- initiate event object
  queue.current_event = sc_event.new(event, queue.params, queue.common, queue.logger)

  -- drop event if wrong category
  if not queue.current_event:is_valid_category() then
    return true
  end

  -- drop event if wrong element
  if not queue.current_event:is_valid_element() then
    return true
  end

  -- First, are there some old events waiting in the flush queue ?
  if (#queue.events > 0 and os.time() - queue.params.__internal_ts_last_flush > queue.params.max_buffer_age) then
    queue.logger:debug("write: Queue max age (" .. os.time() - queue.params.__internal_ts_last_flush .. "/" .. queue.params.max_buffer_age .. ") is reached, flushing data")
    queue:flush()
  end

  -- Then we check that the event queue is not already full
  if (#queue.events >= queue..params.max_buffer_size) then
    queue.logger:debug("write: Queue max size (" .. #queue.events .. "/" .. queue.params.max_buffer_size .. ") is reached BEFORE APPENDING AN EVENT, trying to flush data before appending more events, after 1 second pause.")
    os.execute("sleep " .. tonumber(1))
    queue:flush()
  end

  -- drop event if it is not validated
  if queue.event:is_valid_event() then
    queue:format_event()
  else
    return true
  end

  -- Then we check whether it is time to send the events to the receiver and flush
  if (#queue.events >= queue.params.max_buffer_size) then
    queue.logger:debug("write: Queue max size (" .. #queue.events .. "/" .. queue.params.max_buffer_size .. ") is reached, flushing data")
    queue:flush()
  end

  return true
end
