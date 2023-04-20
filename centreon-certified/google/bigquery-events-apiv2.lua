#!/usr/bin/lua

local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_event = require("centreon-stream-connectors-lib.sc_event")
local sc_params = require("centreon-stream-connectors-lib.sc_params")
local sc_macros = require("centreon-stream-connectors-lib.sc_macros")
local sc_oauth = require("centreon-stream-connectors-lib.google.auth.oauth")
local sc_bq = require("centreon-stream-connectors-lib.google.bigquery.bigquery")
local curl = require("cURL")

local EventQueue = {}

function EventQueue.new(params)
  local self = {}

  local mandatory_parameters = {
    [1] = "dataset",
    [2] = "key_file_path",
    [3] = "api_key",
    [4] = "scope_list"
  }

  
  self.fail = false
  
  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/stream-connector.log"
  local log_level = params.log_level or 2
  
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
  self.sc_params.params.proxy_username = params.proxy_username
  self.sc_params.params.proxy_password = params.proxy_password
  
  -- apply users params and check syntax of standard ones
  self.sc_params:param_override(params)
  self.sc_params:check_params()
  
  self.sc_params.params.__internal_ts_host_last_flush = os.time()
  self.sc_params.params.__internal_ts_service_last_flush = os.time()
  self.sc_params.params.__internal_ts_ack_last_flush = os.time()
  self.sc_params.params.__internal_ts_dt_last_flush = os.time()
  self.sc_params.params.__internal_ts_ba_last_flush = os.time()
  
  self.sc_params.params.host_table = params.host_table or "hosts"
  self.sc_params.params.service_table = params.service_table or "services"
  self.sc_params.params.ack_table = params.ack_table or "acknowledgements"
  self.sc_params.params.downtime_table = params.downtime_table or "downtimes"
  self.sc_params.params.ba_table = params.ba_table or "bas"
  self.sc_params.params._sc_gbq_use_default_schemas = 1
  
  local categories = self.sc_params.params.bbdo.categories
  local elements = self.sc_params.params.bbdo.elements
  
  -- initiate EventQueue variables
  self.events = {
    [categories.neb.id] = {},
    [categories.bam.id] = {}
  }
  
  self.events[categories.neb.id] = {
    [elements.acknowledgement.id] = {},
    [elements.downtime.id] = {},
    [elements.host_status.id] = {},
    [elements.service_status.id] = {}
  }
  
  self.events[categories.bam.id] = {
    [elements.ba_status.id] = {}
  }
  
  self.flush = {
    [categories.neb.id] = {},
    [categories.bam.id] = {}
  }
  
  self.flush[categories.neb.id] = {
    [elements.acknowledgement.id] = function () return self:flush_ack() end,
    [elements.downtime.id] = function () return self:flush_dt() end,
    [elements.host_status.id] = function () return self:flush_host() end,
    [elements.service_status.id] = function () return self:flush_service() end
  }
  
  self.flush[categories.bam.id] = {
    [elements.ba_status.id] = function () return self:flush_ba() end
  }
  
  self.sc_params.params.google_bq_api_url = params.google_bq_api_url or "https://content-bigquery.googleapis.com/bigquery/v2"
  
  self.sc_macros = sc_macros.new(self.sc_params.params, self.sc_logger)
  self.sc_oauth = sc_oauth.new(self.sc_params.params, self.sc_common, self.sc_logger) -- , self.sc_common, self.sc_logger)
  self.sc_bq = sc_bq.new(self.sc_params.params, self.sc_logger)
  self.sc_bq:get_tables_schema()
  
  
  -- return EventQueue object
  setmetatable(self, { __index = EventQueue })
  return self
end

--------------------------------------------------------------------------------
-- EventQueue:format_event, build your own table with the desired information
-- @return true (boolean)
--------------------------------------------------------------------------------
function EventQueue:format_event()
  
  self.sc_event.event.formated_event = {}
  self.sc_event.event.formated_event.json = {}
  
  for column, value in pairs(self.sc_bq.schemas[self.sc_event.event.category][self.sc_event.event.element]) do
    self.sc_event.event.formated_event.json[column] = self.sc_macros:replace_sc_macro(value, self.sc_event.event)
  end
  
  self:add()
  
  return true
end

--------------------------------------------------------------------------------
-- EventQueue:add, add an event to the sending queue
--------------------------------------------------------------------------------
function EventQueue:add ()
  -- store event in self.events lists
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element
  self.events[category][element][#self.events[category][element] + 1] = self.sc_event.event.formated_event
end

--------------------------------------------------------------------------------
-- EventQueue:flush, flush stored host events
-- Called when the max number of events or the max age are reached
-- @return (boolean)
--------------------------------------------------------------------------------
function EventQueue:flush_host ()
  local categories = self.sc_params.params.bbdo.categories
  local elements = self.sc_params.params.bbdo.elements

  self.sc_logger:debug("EventQueue:flush: Concatenating all the host events as one string")

  -- send stored events
  retval = self:send_data(self.sc_params.params.host_table)

  -- reset stored events list
  self.events[categories.neb.id][elements.host_status.id] = {}
  
  -- and update the timestamp
  self.sc_params.params.__internal_ts_host_last_flush = os.time()

  return retval
end

--------------------------------------------------------------------------------
-- EventQueue:flush, flush stored host events
-- Called when the max number of events or the max age are reached
-- @return (boolean)
--------------------------------------------------------------------------------
function EventQueue:flush_service ()
  local categories = self.sc_params.params.bbdo.categories
  local elements = self.sc_params.params.bbdo.elements

  self.sc_logger:debug("EventQueue:flush: Concatenating all the service events as one string")

  -- send stored events
  retval = self:send_data(self.sc_params.params.service_table)

  -- reset stored events list
  self.events[categories.neb.id][elements.service_status.id] = {}
  
  -- and update the timestamp
  self.sc_params.params.__internal_ts_service_last_flush = os.time()

  return retval
end

--------------------------------------------------------------------------------
-- EventQueue:flush, flush stored ack events
-- Called when the max number of events or the max age are reached
-- @return (boolean)
--------------------------------------------------------------------------------
function EventQueue:flush_ack ()
  local categories = self.sc_params.params.bbdo.categories
  local elements = self.sc_params.params.bbdo.elements

  self.sc_logger:debug("EventQueue:flush: Concatenating all the ack events as one string")

  -- send stored events
  retval = self:send_data(self.sc_params.params.ack_table)

  -- reset stored events list
  self.events[categories.neb.id][elements.acknowledgement.id] = {}
  
  -- and update the timestamp
  self.sc_params.params.__internal_ts_ack_last_flush = os.time()

  return retval
end

--------------------------------------------------------------------------------
-- EventQueue:flush, flush stored downtime events
-- Called when the max number of events or the max age are reached
-- @return (boolean)
--------------------------------------------------------------------------------
function EventQueue:flush_dt ()
  local categories = self.sc_params.params.bbdo.categories
  local elements = self.sc_params.params.bbdo.elements

  self.sc_logger:debug("EventQueue:flush: Concatenating all the downtime events as one string")

  -- send stored events
  retval = self:send_data(self.sc_params.params.downtime_table)

  -- reset stored events list
  self.events[categories.neb.id][elements.downtime.id] = {}
  
  -- and update the timestamp
  self.sc_params.params.__internal_ts_dt_last_flush = os.time()

  return retval
end

--------------------------------------------------------------------------------
-- EventQueue:flush, flush stored BA events
-- Called when the max number of events or the max age are reached
-- @return (boolean)
--------------------------------------------------------------------------------
function EventQueue:flush_ba ()
  local categories = self.sc_params.params.bbdo.categories
  local elements = self.sc_params.params.bbdo.elements

  self.sc_logger:debug("EventQueue:flush: Concatenating all the BA events as one string")

  -- send stored events
  retval = self:send_data(self.sc_params.params.ba_table)

  -- reset stored events list
  self.events[categories.bam.id][elements.ba_status.id] = {}
  
  -- and update the timestamp
  self.sc_params.params.__internal_ts_ba_last_flush = os.time()

  return retval
end

function EventQueue:flush_old_queues()
  local categories = self.sc_params.params.bbdo.categories
  local elements = self.sc_params.params.bbdo.elements
  local current_time = os.time()
  
  -- flush old ack events
  if #self.events[categories.neb.id][elements.acknowledgement.id] > 0 and os.time() - self.sc_params.params.__internal_ts_ack_last_flush > self.sc_params.params.max_buffer_age then
    self:flush_ack()
    self.sc_logger:debug("write: Queue max age (" .. os.time() - self.sc_params.params.__internal_ts_ack_last_flush .. "/" .. self.sc_params.params.max_buffer_age .. ") is reached, flushing data")
  end

  -- flush old downtime events
  if #self.events[categories.neb.id][elements.downtime.id] > 0 and os.time() - self.sc_params.params.__internal_ts_dt_last_flush > self.sc_params.params.max_buffer_age then
    self:flush_dt()
    self.sc_logger:debug("write: Queue max age (" .. os.time() - self.sc_params.params.__internal_ts_dt_last_flush .. "/" .. self.sc_params.params.max_buffer_age .. ") is reached, flushing data")
  end

  -- flush old host events
  if #self.events[categories.neb.id][elements.host_status.id] > 0 and os.time() - self.sc_params.params.__internal_ts_host_last_flush > self.sc_params.params.max_buffer_age then
    self:flush_host()
    self.sc_logger:debug("write: Queue max age (" .. os.time() - self.sc_params.params.__internal_ts_host_last_flush .. "/" .. self.sc_params.params.max_buffer_age .. ") is reached, flushing data")
  end

  -- flush old service events
  if #self.events[categories.neb.id][elements.service_status.id] > 0 and os.time() - self.sc_params.params.__internal_ts_service_last_flush > self.sc_params.params.max_buffer_age then
    self:flush_service()
    self.sc_logger:debug("write: Queue max age (" .. os.time() - self.sc_params.params.__internal_ts_service_last_flush .. "/" .. self.sc_params.params.max_buffer_age .. ") is reached, flushing data")
  end

  -- flush old BA events
  if #self.events[categories.bam.id][elements.ba_status.id] > 0 and os.time() - self.sc_params.params.__internal_ts_ba_last_flush > self.sc_params.params.max_buffer_age then
    self:flush_ba()
    self.sc_logger:debug("write: Queue max age (" .. os.time() - self.sc_params.params.__internal_ts_ba_last_flush .. "/" .. self.sc_params.params.max_buffer_age .. ") is reached, flushing data")
  end
end

--------------------------------------------------------------------------------
-- EventQueue:send_data, send data to external tool
-- @return (boolean)
--------------------------------------------------------------------------------
function EventQueue:send_data (table_name)
  local data = {
    rows = {}
  }

  -- concatenate all stored event in the data variable
  for index, formated_event in ipairs(self.events[self.sc_event.event.category][self.sc_event.event.element]) do
      data.rows[index] = formated_event
  end

  self.sc_logger:info("EventQueue:send_data:  creating json: " .. tostring(broker.json_encode(data)))

  -- output data to the tool we want
  if self:call(broker.json_encode(data), table_name) then
    return true
  end

  return false
end

--------------------------------------------------------------------------------
-- EventQueue:call send the data where we want it to be
-- @param data (string) the data we want to send
-- @return true (boolean)
--------------------------------------------------------------------------------
function EventQueue:call (data, table_name)
  local res = ""
  local headers = {
    "Authorization: Bearer " .. self.sc_oauth:get_access_token(),
    "Content-Type: application/json"
  }
  local url = self.sc_params.params.google_bq_api_url .. "/projects/" .. self.sc_oauth.key_table.project_id .. "/datasets/"
    .. self.sc_params.params.dataset .. "/tables/" .. table_name .. "/insertAll?alt=json&key=" .. self.sc_params.params.api_key

    -- initiate curl
  local request = curl.easy()
    :setopt_url(url)
    :setopt_writefunction(function (response) 
      res = res .. response
    end)
  
  -- add  postfields url params
  if data then
    request:setopt_postfields(data)
  end

  self.sc_logger:info("[EventQueue:call]: URL: " .. tostring(url))
  
  -- set proxy address configuration
  if (self.sc_params.params.proxy_address ~= "" and self.sc_params.params.proxy_address) then
    if (self.sc_params.params.proxy_port ~= "" and self.sc_params.params.proxy_port) then
      request:setopt(curl.OPT_PROXY, self.sc_params.params.proxy_address .. ':' .. self.sc_params.params.proxy_port)
    else 
      self.sc_logger:error("[EventQueue:call]: proxy_port parameter is not set but proxy_address is used")
    end
  end

  -- set proxy user configuration
  if (self.sc_params.params.proxy_username ~= '' and self.sc_params.params.proxy_username) then
    if (self.sc_params.params.proxy_password ~= '' and self.sc_params.params.proxy_username) then
      request:setopt(curl.OPT_PROXYUSERPWD, self.sc_params.params.proxy_username .. ':' .. self.sc_params.params.proxy_password)
    else
      self.sc_logger:error("[EventQueue:call]: proxy_password parameter is not set but proxy_username is used")
    end
  end

  -- set up headers
  request:setopt(curl.OPT_HTTPHEADER, headers)

  -- run query
  request:perform()
  self.sc_logger:info("EventQueue:call: sending data: " .. tostring(data))

  local code = request:getinfo(curl.INFO_RESPONSE_CODE)

  if code ~= 200 then
    self.sc_logger:error("[EventQueue:call]: http code is: " .. tostring(code) .. ". Result is: " ..tostring(res))
  end

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
  queue:flush_old_queues()

  -- Then we check that the event queue is not already full
  if (#queue.events[queue.sc_event.event.category][queue.sc_event.event.element] >= queue.sc_params.params.max_buffer_size) then
    queue.sc_logger:debug("write: Queue max size (" .. #queue.events[queue.sc_event.event.category][queue.sc_event.event.element] .. "/" .. queue.sc_params.params.max_buffer_size .. ") is reached BEFORE APPENDING AN EVENT, trying to flush data before appending more events, after 1 second pause.")
    queue.flush[queue.sc_event.event.category][queue.sc_event.event.element]()
  end


  -- drop event if it is not validated
  if queue.sc_event:is_valid_event() then
    queue:format_event()
  else
    return true
  end

  -- Then we check whether it is time to send the events to the receiver and flush
  if (#queue.events[queue.sc_event.event.category][queue.sc_event.event.element] >= queue.sc_params.params.max_buffer_size) then
    queue.sc_logger:debug("write: Queue max size (" .. #queue.events[queue.sc_event.event.category][queue.sc_event.event.element] .. "/" .. queue.sc_params.params.max_buffer_size .. ") is reached BEFORE APPENDING AN EVENT, trying to flush data before appending more events, after 1 second pause.")
    queue.flush[queue.sc_event.event.category][queue.sc_event.event.element]()
  end

  return true
end

