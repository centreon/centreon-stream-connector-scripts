#!/usr/bin/lua
-----------------------------------------------------------------------------
--
-- DESCRIPTION
--
-- Centreon Broker Canopsis Connector
-- Tested with Canopsis 3.42 and Centreon 20.04.6
--
-- References :
--   * https://doc.canopsis.net/interconnexions/#connecteurs
--   * https://docs.centreon.com/docs/centreon/en/19.10/developer/writestreamconnector.html
--   * https://docs.centreon.com/docs/centreon-broker/en/latest/exploit/stream_connectors.html#the-broker-cache-object
--   * https://docs.centreon.com/docs/centreon-broker/en/3.0/dev/mapping.html
--
-- Prerequisites :
--   * install packages gcc + lua-devel
--   * install lua-socket library (http://w3.impa.br/~diego/software/luasocket/)
--   * Centreon version 19.10.5 or >= 20.04.2

-----------------------------------------------------------------------------
-- LIBS
-----------------------------------------------------------------------------

local http = require("socket.http")
local ltn12 = require("ltn12")

-----------------------------------------------------------------------------
-- GLOBAL SETTINGS
-----------------------------------------------------------------------------
version = "1.0.0"

settings = {
  debug_log              = "/var/log/centreon-broker/debug.log",
  verbose                = true,
  connector              = "centreon-stream",
  connector_name         = "centreon-stream-central",
  stream_file            = "/var/log/centreon-broker/bbdo2canopsis.log",
  canopsis_user          = "root",
  canopsis_password      = "root",
  canopsis_event_route   = "/api/v2/event",
  canopsis_downtime_route = "/api/v2/pbehavior",
  canopsis_host          = "localhost",
  canopsis_port          = 8082,
  sending_method         = "api",  -- methods : api = Canopsis HTTP API // file = raw log file
  sending_protocol       = "http",
  timezone               = "Europe/Paris",
  init_spread_timer      = 360     -- time to spread events in seconds at connector starts
}


-----------------------------------------------------------------------------
-- CUSTOM FUNCTIONS
-----------------------------------------------------------------------------
-- Write a debug log when verbose is true
local function debug(output)
  if settings.verbose then broker_log:info(3, "[STREAM-CANOPSIS] " .. output) end
end

-- Write an important log
local function log(output)
  broker_log:info(1, "[STREAM-CANOPSIS] " .. output)
end

-- Dump an error
local function fatal(output)
  broker_log:error(1, "[STREAM-CANOPSIS] " .. output)
end

local function getVersion()
  log("VERSION : ".. version)
end

-- Send an event to stream file
local function writeIntoFile(output)
  local file,err = io.open(settings.stream_file, 'a')
  if file == nil then
    fatal("Couldn't open file: " .. err)
  else
    log("Writting to stream file : " .. settings.stream_file)
    file:write(broker.json_encode(output))
    file:close()
  end
end

local function deleteCanopsisAPI(route)
  local http_result_body = {}

  log("Delete data from Canopsis : " .. route)

  local hr_result, hr_code, hr_header, hr_s = http.request{
    url = settings.sending_protocol .. "://" .. settings.canopsis_user .. ":" .. settings.canopsis_password .. "@" .. settings.canopsis_host .. ":" .. settings.canopsis_port .. route,
    method = "DELETE",
    -- sink is where the request result's body will go
    sink = ltn12.sink.table(result_body),
  }

  -- handling the return code
  if hr_code == 200 then
    log("HTTP DELETE request successful: return code is " .. hr_code)
  else
    fatal("HTTP DELETE FAILED: return code is " .. hr_code)
    for i, v in ipairs(http_result_body) do
      fatal("HTTP DELETE FAILED: message line " .. i .. ' is "' .. v .. '"')
    end
  end

end

-- Send an event to Canopsis API
local function postCanopsisAPI(output, route)
  local post_data = broker.json_encode(output)
  local http_result_body = {}

  route = route or settings.canopsis_event_route

  log("Posting data to Canopsis " .. post_data .. " => To route : ".. route)

  local hr_result, hr_code, hr_header, hr_s = http.request{
    url = settings.sending_protocol .. "://" .. settings.canopsis_user .. ":" .. settings.canopsis_password .. "@" .. settings.canopsis_host .. ":" .. settings.canopsis_port .. route,
    method = "POST",
    -- sink is where the request result's body will go
    sink = ltn12.sink.table(result_body),
    -- request body needs to be formatted as a LTN12 source
    source = ltn12.source.string(post_data),
    headers = {
      -- mandatory for POST request with body
      ["content-length"] = string.len(post_data),
      ["Content-Type"] = "application/json"
    }
  }
  -- handling the return code
  if hr_code == 200 then
    log("HTTP POST request successful: return code is " .. hr_code)
  else
    fatal("HTTP POST FAILED: return code is " .. hr_code)
    for i, v in ipairs(http_result_body) do
      fatal("HTTP POST FAILED: message line " .. i .. ' is "' .. v .. '"')
    end
  end
end


-- Convert Centreon host state to a Canopsis state :
--
-- CENTREON // CANOPSIS
-- ---------------------
--       UP    (0) // INFO     (0)
--     DOWN    (1) // CRITICAL (3)
-- UNREACHABLE (2) // MAJOR    (2)
--
local function hostStateMapping(state)
  local canostate = { 0, 3, 2 }
  return canostate[state+1] -- state + 1 because in lua the index start to one
end

-- Convert Centreon service state to a Canopsis state :
--
-- CENTREON // CANOPSIS
-- ---------------------
--       OK (0) // INFO     (0)
--  WARNING (1) // MINOR    (1)
-- CRITICAL (2) // CRITICAL (3)
-- UNKNOWN  (3) // MAJOR    (2)
--
local function serviceStateMapping(state)
  local canostate = { 0, 1, 3, 2 }
  return canostate[state+1] -- state + 1 because in lua the index start to one
end
-- ****************
-- GET BROKER_CACHE INFORMATIONS :

-- Convert host_id to an hostname (need to restart centengine)
local function getHostname(host_id)
  local host_name = broker_cache:get_hostname(host_id)
  if not host_name then
    debug("Unable to get name of host from broker_cache")
    host_name = host_id
  end
  return host_name
end

-- Convert service_id to a service name (need to restart centengine)
local function getServicename(host_id, service_id)
  local service_description = broker_cache:get_service_description(host_id, service_id)
  if not service_description then
    debug("Unable to get service description from broker_cache")
    service_description = service_id
  end
  return service_description
end

-- Get a service groups list of a service
local function getServiceGroups(host_id, service_id)
  local servicegroups = broker_cache:get_servicegroups(host_id, service_id)
  local servicegroups_list = {}

  if not servicegroups then
    debug("Unable to get servicegroups from broker_cache")
  else
    for servicegroup_id, servicegroup_name in pairs(servicegroups) do
      table.insert(servicegroups_list, servicegroup_name["group_name"])
    end
  end

  return servicegroups_list
end

-- Get a hostgroups list of a host
local function getHostGroups(host_id)
  local hostgroups = broker_cache:get_hostgroups(host_id)
  local hostgroups_list = {}

  if not hostgroups then
    debug("Unable to get hostgroups from broker_cache")
  else
    for hostgroup_id, hostgroup_name in pairs(hostgroups) do
      table.insert(hostgroups_list, hostgroup_name["group_name"])
    end
  end
  
  return hostgroups_list
end

-- Get notes url list from a host or a service
local function getNotesURL(host_id, service_id)
  local notes_url = ''

  if not service_id then
    notes_url = broker_cache:get_notes_url(host_id)
  else
    notes_url = broker_cache:get_notes_url(host_id, service_id)
  end

  if notes_url ~= "" and notes_url then 
    debug("extra information notes_url found for host_id "..host_id.." => "..notes_url)
    return notes_url
  else
    debug("no extra information notes_url found for host_id "..host_id)
    return ""
  end
end

-- Get action url list from a host or a service
local function getActionURL(host_id, service_id)
  local action_url = ''

  if not service_id then
    action_url = broker_cache:get_action_url(host_id)
  else
    notes_url = broker_cache:get_action_url(host_id, service_id)
  end

  if action_url then 
    debug("extra information action_url found for host_id "..host_id.." => "..action_url)
    return notes_url
  else
    debug("no extra information action_url found for host_id "..host_id)
    return ""
  end
end

-- ****************

-- Translate Centreon event to Canopsis event
local function canopsisMapping(d)
  event = {}
  -- HOST STATUS
  if d.element == 14 and stateChanged(d) then
    event = {
      event_type = "check",
      source_type = "component",
      connector = settings.connector,
      connector_name = settings.connector_name,
      component = getHostname(d.host_id),
      resource = "",
      timestamp = d.last_check,
      output = d.output,
      state = hostStateMapping(d.state),
      -- extra informations
      hostgroups = getHostGroups(d.host_id),
      notes_url = getNotesURL(d.host_id),
      action_url = getActionURL(d.host_id)
    }
    debug("Streaming HOST STATUS for host_id ".. d.host_id)
  -- SERVICE STATUS
  elseif d.element == 24 and stateChanged(d) then
    event = {
      event_type = "check",
      source_type = "resource",
      connector = settings.connector,
      connector_name = settings.connector_name,
      component = getHostname(d.host_id),
      resource = getServicename(d.host_id, d.service_id),
      timestamp = d.last_check,
      output = d.output,
      state = serviceStateMapping(d.state),
      -- extra informations
      servicegroups = getServiceGroups(d.host_id, d.service_id),
      notes_url = getNotesURL(d.host_id, d.service_id),
      action_url = getActionURL(d.host_id, d.service_id),
      hostgroups = getHostGroups(d.host_id)
    }
    debug("Streaming SERVICE STATUS for service_id ".. d.service_id)
  -- ACK
  elseif d.element == 1 then
    event = {
      event_type = "ack",
      crecord_type = "ack",
      author = d.author,
      resource = "",
      component = getHostname(d.host_id),
      connector = settings.connector,
      connector_name = settings.connector_name,
      timestamp = d.entry_time,
      output = d.comment_data,
      origin = "centreon",
      ticket = "",
      state_type = 1,
      ack_resources = false
    }
    if d.service_id then
      event['source_type'] = "resource"
      event['resource'] = getServicename(d.host_id, d.service_id)
      event['ref_rk'] = event['resource'] .. "/" .. event['component']
      event['state'] = serviceStateMapping(d.state)
    else
      event['source_type'] = "component"
      event['ref_rk'] = "undefined/" .. event['component']
      event['state'] = hostStateMapping(d.state)
    end

    -- send ackremove
    if d.deletion_time then
      event['event_type'] = "ackremove"
      event['crecord_type'] = "ackremove"
      event['timestamp'] = d.deletion_time
    end

    debug("Streaming ACK for host_id ".. d.host_id)

  -- DOWNTIME (to change with Canopsis "planning" feature when available)
  elseif d.element == 5 then

    local canopsis_downtime_id = "centreon-downtime-".. d.internal_id .. "-" .. d.entry_time

    debug("Streaming DOWNTIME for host_id ".. d.host_id)

    if d.cancelled then
      deleteCanopsisAPI(settings.canopsis_downtime_route .. "/" .. canopsis_downtime_id)
    else
      event = {
        _id = canopsis_downtime_id, 
        author = d.author,
        name = canopsis_downtime_id,
        tstart = d.start_time,
        tstop = d.end_time,
        type_ = "Maintenance",
        reason = "Autre",
        timezone = settings.timezone,
        comments = { { ['author'] = d.author,
                       ['message'] = d.comment_data } },
        filter = { ['$and']= { { ['_id'] = "" }, } },
        exdate = {},
      }
      if not d.service_id then 
        event['filter']['$and'][1]['_id'] = getHostname(d.host_id)
      else
        event['filter']['$and'][1]['_id'] = getServicename(d.host_id, d.service_id).."/"..getHostname(d.host_id)
      end
        -- This event is sent directly and bypass the queue process of a standard event.
        postCanopsisAPI(event, settings.canopsis_downtime_route)
    end

    -- Note : The event can be duplicated by the Centreon broker
    -- See previous commit to get the "duplicated" function if needed

    event = {}
  end
  return event
end


function stateChanged(d)

  if d.service_id then
    debug("Checking state change for service_id event [".. d.service_id .. "]")
  else
    debug("Checking state change for host_id event [".. d.host_id .. "]")
  end

  if d.state_type == 1 and -- if the event is in hard state
     d.last_hard_state_change ~= nil then -- if the event has been in a hard state

    -- if the state has changed 
    -- (like noted in the omi connector, it could have a slight delta between last_check and last_hard_state_change)
    if math.abs(d.last_check - d.last_hard_state_change) < 10 then

      if d.service_id then
        debug("HARD state change detected for service_id [" .. d.service_id .. "]")
      else
        debug("HARD state change detected for host_id [" .. d.host_id .. "]")
      end

      return true

    elseif os.time() - connector_start_time <= settings.init_spread_timer then -- if the connector has just started

      if d.service_id then
        debug("HARD event for service_id [" .. d.service_id .. "] spread")
      else
        debug("HARD for host_id [" .. d.host_id .. "] spread")
      end

      return true

    end

     -- note : No need to send new event without last_hard_state_change because 
     --        there is no state either

  end

  return false
end

-----------------------------------------------------------------------------
-- Queue functions
-----------------------------------------------------------------------------

local event_queue = {
  __internal_ts_last_flush    = nil,
  events                      = {},
  max_buffer_size             = 10,
  max_buffer_age              = 60
}

function event_queue:new(o, conf)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  for i,v in pairs(conf) do
    if self[i] and i ~= "events" and string.sub(i, 1, 11) ~= "__internal_" then
      debug("event_queue:new: getting parameter " .. i .. " => " .. v)
      self[i] = v
    else
      debug("event_queue:new: ignoring parameter " .. i .. " => " .. v)
    end
  end
  self.__internal_ts_last_flush = os.time()
  debug("event_queue:new: setting the internal timestamp to " .. self.__internal_ts_last_flush)
  return o
end

function event_queue:add(e)
  -- we finally append the event to the events table
  if next(e) ~= nil then 
    self.events[#self.events + 1] = e
    debug("Queuing event : " .. broker.json_encode(e))
  end
  -- then we check whether it is time to send the events to the receiver and flush
  if #self.events >= self.max_buffer_size then
    debug("event_queue:add: flushing because buffer size reached " .. self.max_buffer_size .. " elements.")
    self:flush()
    return true
  elseif os.time() - self.__internal_ts_last_flush >= self.max_buffer_age and
         #self.events ~= 0 then
    debug("event_queue:add: flushing " .. #self.events .. " elements because buffer age reached " .. (os.time() - self.__internal_ts_last_flush) .. "s and max age is " .. self.max_buffer_age .. "s.")
    self:flush()
    return true
  else
    return false
  end
end

function event_queue:flush()
  --debug("DUMPING : " .. broker.json_encode(self.events))
  postCanopsisAPI(self.events)
  -- now that the data has been sent, we empty the events array
  self.events = {}
  -- and update the timestamp
  self.__internal_ts_last_flush = os.time()
end

-----------------------------------------------------------------------------
-- Required functions for Broker StreamConnector
-----------------------------------------------------------------------------

-- Init a stream connector
function init(conf)
  connector_start_time = os.time()

  -- merge configuration from the WUI with default values
  for k,v in pairs(conf) do settings[k] = v end

  broker_log:set_parameters(3, settings.debug_log)
  getVersion()
  debug("init : Beginning init() function")
  debug("CONNECTOR:" .. settings.connector .. ";")
  debug("CANOPSIS_HOST:" .. settings.canopsis_host .. ";")

  queue = event_queue:new(nil, conf)
  debug("init : Ending init() function, Event queue created")
end

-- Write events
function write(d)
  debug("write : Beginning write() function")
  if settings.sending_method == "api" then
    --postCanopsisAPI(canopsisMapping(d)) -- for debug only
    queue:add(canopsisMapping(d))
  elseif settings.sending_method == "file" then
    writeIntoFile(canopsisMapping(d))
    --writeIntoFile(d) -- for debug only
  end
  debug("write : Ending write() function")
  return true
end

-- Filter events
function filter(category, element)
  -- Filter NEB category types
  if category == 1 and (element == 1 or -- Acknowledment
                        element == 5 or -- Downtime
                        element == 14 or -- Host status
                        element == 24) then -- Service status
    return true
  end
  return false
end
