#!/usr/bin/lua

local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_event = require("centreon-stream-connectors-lib.sc_event")
local sc_params = require("centreon-stream-connectors-lib.sc_params")
local sc_oauth = require("centreon-stream-connectors-lib.google.auth.oauth")
-- local google = require("google.core.oauth")

local EventQueue = {}

function EventQueue.new(params)
  local self = {}

  local mandatory_parameters = {
    [1] = "project_id",
    [2] = "key_file_path",
    [3] = "api_key",
    [4] = "scope_list"
  }

  -- initiate EventQueue variables
  self.events = {}
  self.fail = false

  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/stream-connector.log"
  local log_level = params.log_level or 1
  
  -- initiate mandatory objects
  self.sc_logger = sc_logger.new(logfile, log_level)
  self.sc_common = sc_common.new(self.sc_logger)
  self.sc_broker = sc_broker.new(self.sc_logger)
  self.sc_params = sc_params.new(self.sc_common, self.sc_logger)

    -- checking mandatory parameters and setting a fail flag
  if not self.sc_params:is_mandatory_config_set(mandatory_parameters, params) then
    self.fail = true
  end

  -- overriding default parameters for this stream connector if the default values doesn't suit the basic needs
  params.accepted_categories = "neb,bam"
  params.accepted_elements = "host_status,service_status,downtime,acknowledgement,ba_status"
  self.sc_params.params.proxy_address = params.proxy_address
  self.sc_params.params.proxy_port = params.proxy_port

  -- apply users params and check syntax of standard ones
  self.sc_params:param_override(params)
  self.sc_params:check_params()

  self.sc_oauth = sc_oauth.new(self.sc_params.params, self.sc_common, self.sc_logger) -- , self.sc_common, self.sc_logger)


  -- return EventQueue object
  setmetatable(self, { __index = EventQueue })
  return self
end

--------------------------------------------------------------------------------
-- EventQueue:format_event, build your own table with the desired information
-- @return true (boolean)
--------------------------------------------------------------------------------
function EventQueue:format_event()
  -- for i, v in pairs(self.sc_event.event) do
  --   self.sc_logger:error("index: " .. tostring(i) .. " value: " .. tostring(v))
  -- end
  -- starting to handle shared information between host and service
  self.sc_event.event.formated_event = {
    -- name of host has been stored in a cache table when calling is_valid_even()
    my_host = self.sc_event.event.cache.host.name,
    -- states (critical, ok...) are found and converted to human format thanks to the status_mapping table
    -- my_state = self.sc_params.params.status_mapping[self.sc_event.event.category][self.sc_event.event.element][self.sc_event.event.type][self.sc_event.event.state],
    -- my_author = self.sc_event.event.author,
    -- my_start_time = self.sc_event.event.actual_start_time,
    -- my_end_time = self.sc_event.event.actual_end_time,
  }

  self:add()

  return true
end

--------------------------------------------------------------------------------
-- EventQueue:add, add an event to the sending queue
--------------------------------------------------------------------------------
function EventQueue:add ()
  -- store event in self.events list
  self.events[#self.events + 1] = self.sc_event.event.formated_event
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
  self.sc_params.params.__internal_ts_last_flush = os.time()

  return retval
end

--------------------------------------------------------------------------------
-- EventQueue:send_data, send data to external tool
-- @return (boolean)
--------------------------------------------------------------------------------
function EventQueue:send_data ()
  local data = ""
  local counter = 0

  -- concatenate all stored event in the data variable
  for _, formated_event in ipairs(self.events) do
    if counter == 0 then
      data = broker.json_encode(formated_event) 
      counter = counter + 1
    else
      data = data .. "," .. broker.json_encode(formated_event)
    end
  end

  self.sc_logger:debug("EventQueue:send_data:  creating json: " .. tostring(data))

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
  -- self.sc_logger:debug("EventQueue:call: opening file " .. self.sc_params.params.output_file)

  -- write in the file
  -- local my_oauth = google("/usr/share/centreon-broker/lua/account2.json", "https://www.googleapis.com/auth/bigquery.insertdata")
  self.sc_logger:debug("EventQueue:call: writing message " .. tostring(data))

  self.sc_logger:error(self.sc_oauth:get_access_token())
-- self.sc_logger:error(my_oauth:GetAccessToken())
  -- close the file
  -- self.sc_logger:debug("EventQueue:call: closing file " .. self.sc_params.params.output_file)
  
  
  return true
end

local queue

function init(params)
  queue = EventQueue.new(params)
end

function write(event)
  -- skip event if a mandatory parameter is missing
  if queue.fail then
    queue.sc_logger:error("Skipping event because a mandatory parameter is not set")
    return true
  end
  
  -- initiate event object
  queue.sc_event = sc_event.new(event, queue.sc_params.params, queue.sc_common, queue.sc_logger, queue.sc_broker)

  -- drop event if wrong category
  if not queue.sc_event:is_valid_category() then
    return true
  end

  -- drop event if wrong element
  if not queue.sc_event:is_valid_element() then
    return true
  end

  -- First, are there some old events waiting in the flush queue ?
  if (#queue.events > 0 and os.time() - queue.sc_params.params.__internal_ts_last_flush > queue.sc_params.params.max_buffer_age) then
    queue.sc_logger:debug("write: Queue max age (" .. os.time() - queue.sc_params.params.__internal_ts_last_flush .. "/" .. queue.sc_params.params.max_buffer_age .. ") is reached, flushing data")
    queue:flush()
  end

  -- Then we check that the event queue is not already full
  if (#queue.events >= queue.sc_params.params.max_buffer_size) then
    queue.sc_logger:debug("write: Queue max size (" .. #queue.events .. "/" .. queue.sc_params.params.max_buffer_size .. ") is reached BEFORE APPENDING AN EVENT, trying to flush data before appending more events, after 1 second pause.")
    os.execute("sleep " .. tonumber(1))
    queue:flush()
  end

  -- drop event if it is not validated
  if queue.sc_event:is_valid_event() then
    queue:format_event()
  else
    -- for i, v in pairs(queue.sc_event.event) do
    --   queue.sc_logger:error("index: " .. tostring(i) .. " value: " .. tostring(v))
    -- end
    return true
  end

  -- Then we check whether it is time to send the events to the receiver and flush
  if (#queue.events >= queue.sc_params.params.max_buffer_size) then
    queue.sc_logger:debug("write: Queue max size (" .. #queue.events .. "/" .. queue.sc_params.params.max_buffer_size .. ") is reached, flushing data")
    queue:flush()
  end

  return true
end
