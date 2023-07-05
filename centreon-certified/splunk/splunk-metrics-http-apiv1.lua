#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker Splunk Connector Metrics
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Prerequisites
-- You need a Splunk instance
-- You need to create a new HTTP events collector with a metrics index and get a token
--
-- The lua-curl and luatz libraries are required by this script:
-- yum install lua-curl epel-release
-- yum install luarocks
-- luarocks install luatz
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Parameters:
-- [MANDATORY] http_server_url: your splunk API url
-- [MANDATORY] splunk_index: index where you want to store the events
-- [MANDATORY] splunk_token: see above, this will be your authentication token
-- [MANDATORY] splunk_source: source of the HTTP events collector, must be http:something
-- [OPTIONAL] splunk_sourcetype: sourcetype of the HTTP events collector, default _json
-- [OPTIONAL] splunk_host: host field for the HTTP events collector, default Centreon
-- [OPTIONAL] http_proxy_string: default empty
--
--------------------------------------------------------------------------------

-- Libraries
local curl = require "cURL"
local new_from_timestamp = require "luatz.timetable".new_from_timestamp
-- Global variables
local previous_event = ""

-- Useful functions
local function ifnil(var, alt)
  if var == nil then
    return alt
  else
    return var
  end
end

local function ifnil_or_empty(var, alt)
  if var == nil or var == '' then
    return alt
  else
    return var
  end
end

local function get_hostname(host_id)
  local hostname = broker_cache:get_hostname(host_id)
  if not hostname then
    hostname = host_id
  end
  return hostname
end

local function get_service_description(host_id, service_id)
  local service = broker_cache:get_service_description(host_id, service_id)
  if not service then
    service = service_id
  end
  return service
end

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

function EventQueue.new(conf)
  local retval = {
    http_server_url         = "",
    http_proxy_string       = "",
    http_timeout            = 5,
    splunk_sourcetype       = "_json",
    splunk_source           = "",
    splunk_token            = "",
    splunk_index            = "",
    splunk_host             = "Centreon",
    filter_type             = "metric,status",
    max_buffer_size         = 1,
    max_buffer_age          = 5,
    skip_anon_events        = 1
  }
  for i,v in pairs(conf) do
    if retval[i] then
      retval[i] = v
      broker_log:info(2, "EventQueue.new: getting parameter " .. i .. " => " .. v)
    else
      broker_log:warning(1, "EventQueue.new: ignoring unhandled parameter " .. i .. " => " .. v)
    end
  end
  retval.__internal_ts_last_flush = os.time()
  retval.events = {},
  setmetatable(retval, EventQueue)
-- Internal data initialization
  broker_log:info(2, "EventQueue.new: setting the internal timestamp to " .. retval.__internal_ts_last_flush)
  return retval
end

--------------------------------------------------------------------------------
---- EventQueue:add method
---- @param e An event
----------------------------------------------------------------------------------

function EventQueue:add(e)

  local type = "host"
  local hostname = get_hostname(e.host_id)
  if hostname == e.host_id then
    if self.skip_anon_events ~= 1 then
      broker_log:error(0, "EventQueue:add: unable to get hostname for host_id '" .. e.host_id .."'")
      return false
    else
      broker_log:info(3, "EventQueue:add: ignoring that we can't resolve host_id '" .. e.host_id .."'. The event will be sent with the id only")
    end
  end

  local service_description = ""
  if e.service_id then
    type = "service"
    service_description = get_service_description(e.host_id, e.service_id)
    if service_description == e.service_id then
    if self.skip_anon_events ~= 1 then
        broker_log:error(0, "EventQueue:add: unable to get service_description for host_id '" .. e.host_id .."' and service_id '" .. e.service_id .."'")
      else
        broker_log:info(3, "EventQueue:add: ignoring that we can't resolve host_id '" .. e.host_id .."' and service_id '" .. e.service_id .."'")
      end
    end
  end

  local event_data = {
    service_description = service_description,
    hostname = hostname,
    ctime = e.ctime
  }
  
  event_data["metric_name:" .. e.name] = e.value

  self.events[#self.events + 1] = {
    time           = e.ctime,
    source         = self.splunk_source,
    sourcetype     = self.splunk_sourcetype,
    index          = self.splunk_index,
    host           = self.splunk_host,
    fields         = event_data
  }

 return true

end

--------------------------------------------------------------------------------
---- EventQueue:flush method
---- Called when the max number of events or the max age are reached
----------------------------------------------------------------------------------

function EventQueue:flush()

  broker_log:info(3, "EventQueue:flush: Concatenating all the events as one string")
  local http_post_data = ""
  for _, raw_event in ipairs(self.events) do
    http_post_data = http_post_data .. broker.json_encode(raw_event)
  end
  for s in http_post_data:gmatch("[^\r\n]+") do
    broker_log:info(3, "EventQueue:flush: HTTP POST data:   " .. s .. "")
  end
  
  broker_log:info(3, "EventQueue:flush: HTTP POST url: \"" .. self.http_server_url .. "\"")

  local http_response_body = ""
  local http_request = curl.easy()
    :setopt_url(self.http_server_url)
    :setopt_writefunction(
      function (response)
        http_response_body = http_response_body .. tostring(response)
      end
    )
    :setopt(curl.OPT_TIMEOUT, self.http_timeout)
    :setopt(
      curl.OPT_HTTPHEADER,
      {
        "content-type: application/json",
        "content-length:" .. string.len(http_post_data),
        "authorization: Splunk " .. self.splunk_token,
      }
  )

  -- setting the CURLOPT_PROXY
  if self.http_proxy_string and self.http_proxy_string ~= "" then
    broker_log:info(3, "EventQueue:flush: HTTP PROXY string is '" .. self.http_proxy_string .. "'")
    http_request:setopt(curl.OPT_PROXY, self.http_proxy_string)
  end

  -- adding the HTTP POST data
  http_request:setopt_postfields(http_post_data)

  -- performing the HTTP request
  http_request:perform()

  -- collecting results
  http_response_code = http_request:getinfo(curl.INFO_RESPONSE_CODE)
  
  http_request:close()

  -- Handling the return code
  local retval = false
  if http_response_code == 200 then
    broker_log:info(2, "EventQueue:flush: HTTP POST request successful: return code is " .. http_response_code)
    -- now that the data has been sent, we empty the events array
    self.events = {}
    retval = true
  else
    broker_log:error(0, "EventQueue:flush: HTTP POST request FAILED, return code is " .. http_response_code)
    broker_log:error(1, "EventQueue:flush: HTTP POST request FAILED, message is:\n\"" .. http_response_body .. "\n\"\n")
  end
  -- and update the timestamp
  self.__internal_ts_last_flush = os.time()
  return retval
end

--------------------------------------------------------------------------------
-- Required functions for Broker StreamConnector
--------------------------------------------------------------------------------

local queue

-- Fonction init()
function init(conf)
  local log_level = 1
  local log_path = "/var/log/centreon-broker/stream-connector-splunk-metrics.log"
  for i,v in pairs(conf) do
    if i == "log_level" then
      log_level = v
    end
    if i == "log_path" then
      log_path = v
    end
  end
  broker_log:set_parameters(log_level, log_path)
  broker_log:info(0, "init: Starting Splunk Metrics StreamConnector (log level: " .. log_level .. ")")
  broker_log:info(2, "init: Beginning init() function")
  queue = EventQueue.new(conf)
  broker_log:info(2, "init: Ending init() function, Event queue created")
end

-- Fonction write()
function write(e)
    broker_log:info(3, "write: Beginning function")

    -- First, are there some old events waiting in the flush queue ?
    if (#queue.events > 0 and os.time() - queue.__internal_ts_last_flush > queue.max_buffer_age) then
      broker_log:info(2, "write: Queue max age (" .. os.time() - queue.__internal_ts_last_flush .. "/" .. queue.max_buffer_age .. ") is reached, flushing data")
      queue:flush()
    end

    -- Here come the filters
    -- Host/service status only
    if not (e.category == 3 and e.element == 1) then
      broker_log:info(3, "write: Not a metric event. Dropping.")
      return true
    end

    -- workaround https://github.com/centreon/centreon-broker/issues/201
    current_event = broker.json_encode(e)
    broker_log:info(3, "write: Raw event: " .. current_event)
     --

    -- Once all the filters have been passed successfully, we can add the current event to the queue
    queue:add(e)

    -- Then we check whether it is time to send the events to the receiver and flush
    if (#queue.events >= queue.max_buffer_size) then
      broker_log:info(2, "write: Queue max size (" .. #queue.events .. "/" .. queue.max_buffer_size .. ") is reached, flushing data")
      return queue:flush()
    end
    broker_log:info(3, "write: Ending function")

    return true
end

