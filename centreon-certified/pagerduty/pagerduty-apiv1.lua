#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker PagerDuty Connector
-- Tested with the public API on the developer platform:
-- https://events.pagerduty.com/v2/enqueue
--
-- References: 
-- https://developer.pagerduty.com/api-reference/reference/events-v2/openapiv3.json/paths/~1enqueue/post
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Prerequisites:
--
-- You need a PagerDuty instance
-- You need your instance's routing_key. According to the page linked above: "The GUID of one of your Events API V2 integrations. This is the "Integration Key" listed on the Events API V2 integration's detail page."
--
-- The lua-curl and luatz libraries are required by this script:
-- yum install lua-curl epel-release
-- yum install luarocks
-- luarocks install luatz
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Parameters:
-- [MANDATORY] pdy_routing_key: see above, this will be your authentication token
-- [RECOMMENDED] pdy_centreon_url: in order to get links/url that work in your events
-- [RECOMMENDED] log_level: level of verbose. Default is 2 but in production 1 is the recommended value.
-- [OPTIONAL] http_server_url: default "https://events.pagerduty.com/v2/enqueue"
-- [OPTIONAL] http_proxy_string: default empty
--
--------------------------------------------------------------------------------

-- Libraries
local curl = require "cURL"
local new_from_timestamp = require "luatz.timetable".new_from_timestamp

-- Global variables
local previous_event = ""
-- Nagios states to Pagerduty severity conversion table
local from_state_to_severity = { "info", "warning", "critical", "error" }

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
    broker_log:warning(1, "get_hostname: hostname for id " .. host_id .. " not found. Restarting centengine should fix this.")
    hostname = host_id
  end
  return hostname
end

local function get_service_description(host_id, service_id)
  local service = broker_cache:get_service_description(host_id, service_id)
  if not service then
    broker_log:warning(1, "get_service_description: service_description for id " .. host_id .. "." .. service_id .. " not found. Restarting centengine should fix this.")
    service = service_id
  end
  return service
end


--------------------------------------------------------------------------------
-- EventQueue class
--------------------------------------------------------------------------------

local EventQueue = {}
EventQueue.__index = EventQueue

--------------------------------------------------------------------------------
-- Constructor
-- @param conf The table given by the init() function and returned from the GUI
-- @return the new EventQueue
--------------------------------------------------------------------------------

function EventQueue.new(conf)
  local retval = {
    http_server_url         = "https://events.pagerduty.com/v2/enqueue",
    http_proxy_string       = "",
    http_timeout            = 5,
    pdy_source              = "",
    pdy_routing_key         = "Please fill pdy_routing_key in StreamConnector parameter",
    pdy_centreon_url     = "http://set.pdy_centreon_url.parameter",
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
-- EventQueue:add method
-- @param e An event
--------------------------------------------------------------------------------

function EventQueue:add(e)

  local type = "host"
  local hostname = get_hostname(e.host_id)
  if hostname == e.host_id then
    if self.skip_anon_events ~= 1 then
      broker_log:error(0, "EventQueue:add: unable to get hotsname for host_id '" .. e.host_id .."'")
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
  
  local pdy_dedup_key 
  if e.service_id then --to remain consistent in the alert handling even in the event of the loss of the broker cache, we should use the ids to link the events
    pdy_dedup_key = e.host_id .. "_" .. e.service_id
  else
    pdy_dedup_key = e.host_id .. "_H"
  end

  -- converting epoch timestamp to UTC time in RFC3339
  local pdy_timestamp = new_from_timestamp(e.last_update):rfc_3339()
  broker_log:info(3, "EventQueue:add: Timestamp converted from " .. e.last_update .. " to \"" .. pdy_timestamp .. "\"")

  -- converting e.state into PagerDuty severity
  -- from_state_to_severity maps between 'critical', 'warning', 'error' or 'info' and e.state. WARNING: if info then "event_action" is not "trigger" but "resolve"
  local pdy_severity =  ifnil_or_empty(from_state_to_severity[e.state + 1], 'error')
  broker_log:info(3, "EventQueue:add: Severity converted from " .. e.state .. " to \"" .. pdy_severity .. "\"")

  -- handling empty output (empty "summary" cannot be sent to PagerDuty)
  local pdy_summary = hostname .. "/" .. service_description .. ": " .. ifnil_or_empty(string.match(e.output, "^(.*)\n"), 'no output')

  -- basic management of "class" attribute
  local pdy_class
  if e.service_id then 
    pdy_class = "service"
  else
    pdy_class = "host"
  end

  -- managing "event_action" (trigger/resolve)
  local pdy_event_action
  if pdy_severity == "info" then
    pdy_event_action = "resolve"
  else
    pdy_event_action = "trigger"
  end
  broker_log:info(3, "EventQueue:add: Since severity is \"" .. pdy_severity .. "\", event_action is \"" .. pdy_event_action .. "\"")

  -- Managing perfdata
  local pdy_custom_details = {}
--  if e.perfdata then
--    broker_log:info(3, "EventQueue:add: Perfdata list: " .. broker.json_encode(e.perfdata) .. " ")
--    -- Case when the perfdata name is delimited with simple quotes: spaces allowed
--    for metric_name, metric_value in e.perfdata:gmatch("%s?'(.+)'=(%d+[%a]?);?[%W;]*%s?") do
--      broker_log:info(3, "EventQueue:add: Perfdata " .. metric_name .. " = " .. metric_value)
--      pdy_custom_details[metric_name] = metric_value
--    end
--    -- Case when the perfdata name is NOT delimited with simple quotes: no spaces allowed
--    for metric_name, metric_value in e.perfdata:gmatch("%s?([^'][%S]+[^'])=(%d+[%a]?);?[%W;]*%s?") do
--      broker_log:info(3, "EventQueue:add: Perfdata " .. metric_name .. " = " .. metric_value)
--      pdy_custom_details[metric_name] = metric_value
--    end
--  end

  -- Hostgroups
  local host_hg_array = broker_cache:get_hostgroups(e.host_id)
  local pdy_hostgroups = ""
  -- case when no filter has been set for hostgroups
  for i = 1, #host_hg_array do
    if pdy_hostgroups ~= ""  then
      pdy_hostgroups = pdy_hostgroups .. ", " .. ifnil_or_empty(host_hg_array[i].group_name, "empty host group")
    else
      pdy_hostgroups = ifnil_or_empty(host_hg_array[i].group_name, "empty host group")
    end
  end

  -- Servicegroups
  if e.service_id then
    local service_hg_array = broker_cache:get_servicegroups(e.host_id, e.service_id)
    local pdy_servicegroups = ""
    -- case when no filter has been set for servicegroups
    for i = 1, #service_hg_array do
      if pdy_servicegroups ~= ""  then
        pdy_servicegroups = pdy_servicegroups .. ", " .. ifnil_or_empty(service_hg_array[i].group_name, "empty service group")
      else
        pdy_servicegroups = ifnil_or_empty(service_hg_array[i].group_name, "empty service group")
      end
    end
  end

  local pdy_custom_details = {}

  local host_severity = broker_cache:get_severity(e.host_id)
  if host_severity ~= nil then
    pdy_custom_details["Hostseverity"] = host_severity
  end

  if e.service_id then
    local service_severity = broker_cache:get_severity(e.host_id, e.service_id)
    if service_severity ~= nil then
      pdy_custom_details["Serviceseverity"] = service_severity
    end
  end

  if pdy_hostgroups ~= "" then
      pdy_custom_details["Hostgroups"] = pdy_hostgroups
  end
  if pdy_servicegroups ~= "" then
      pdy_custom_details["Servicegroups"] = pdy_servicegroups
  end

  local pdy_source_field = hostname
  if self.pdy_source and self.pdy_source ~= "" then
    pdy_source_field = self.pdy_source
  end
  -- Appending the current event to the queue
  self.events[#self.events + 1] = {
    payload = {
      summary = pdy_summary,
      timestamp = pdy_timestamp,
      severity = pdy_severity,
      source = pdy_source_field,
      component = service_description,
      group = pdy_hostgroups,
      class = pdy_class,
      custom_details = pdy_custom_details
    },
    routing_key = self.pdy_routing_key,
    dedup_key = pdy_dedup_key,
    event_action = pdy_event_action,
    client = "Centreon Stream Connector",
    client_url = self.pdy_centreon_url,
    links = {
      {
        href = self.pdy_centreon_url .. "/centreon/main.php?p=20202&o=hd&host_name=" .. hostname,
        text = "Link to host summary."
      }
    }
    --images = {
      --{
        --src = "https://chart.googleapis.com/chart?chs=600x400&chd=t:6,2,9,5,2,5,7,4,8,2,1&cht=lc&chds=a&chxt=y&chm=D,0033FF,0,0,5,1",
        --href = "https://google.com",
        --alt = "An example link with an image"
      --}
    --}
  }
  return true
end

--------------------------------------------------------------------------------
-- EventQueue:flush method
-- Called when the max number of events or the max age are reached
--------------------------------------------------------------------------------

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
        "accept: application/vnd.pagerduty+json;version=2",
        "content-type: application/json",
        --"authorization: Token token=" .. self.pdy_routing_key,
        "x-routing-key: " .. self.pdy_routing_key
      }
  )

  -- setting the CURLOPT_PROXY
  if self.http_proxy_string and self.http_proxy_string ~= "" then
    broker_log:info(3, "EventQueue:flush: HTTP PROXY string is '" .. self.http_proxy_string .. "'")
    http_request:setopt(curl.OPT_PROXY, self.http_proxy_string)
  end

  -- adding the HTTP POST data
  broker_log:info(3, "EventQueue:flush: POST data: '" .. http_post_data .. "'")
  http_request:setopt_postfields(http_post_data)

  -- performing the HTTP request
  http_request:perform()

  -- collecting results
  http_response_code = http_request:getinfo(curl.INFO_RESPONSE_CODE) 

  -- Handling the return code
  local retval = false
  if http_response_code == 202 then
    broker_log:info(2, "EventQueue:flush: HTTP POST request successful: return code is " .. http_response_code)
    -- now that the data has been sent, we empty the events array
    self.events = {}
    retval = true
  else
    broker_log:error(0, "EventQueue:flush: HTTP POST request FAILED, return code is " .. http_response_code .. " message is:\n\"" .. http_response_body .. "\n\"\n")
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
  local log_level = 2
  local log_path = "/var/log/centreon-broker/stream-connector-pagerduty.log"
  for i,v in pairs(conf) do
    if i == "log_level" then
      log_level = v
    end
    if i == "log_path" then
      log_path = v
    end
  end
  broker_log:set_parameters(log_level, log_path)
  broker_log:info(0, "init: Starting PagerDuty StreamConnector (log level: " .. log_level .. ")")
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

    -- Then we check that the event queue is not already full
    if (#queue.events >= queue.max_buffer_size) then
      broker_log:warning(1, "write: Queue max size (" .. #queue.events .. "/" .. queue.max_buffer_size .. ") is reached BEFORE APPENDING AN EVENT, trying to flush data before appending more events, after 1 second pause.")
      os.execute("sleep " .. tonumber(1))
      return queue:flush()
    end

    -- Here come the filters
    -- Host/service status only
    if not (e.category == 1 and (e.element == 24 or e.element == 14)) then
      broker_log:info(3, "write: Neither host nor service status event. Dropping.")
      return true
    end

    -- workaround https://github.com/centreon/centreon-broker/issues/201
    current_event = broker.json_encode(e)
    broker_log:info(3, "write: Raw event: " .. current_event)

    if e.state_type ~= 1 then
      broker_log:info(3, "write: " .. e.host_id .. "_" .. ifnil_or_empty(e.service_id, "H") .. " Not HARD state type. Dropping.")
      return true
    end

    -- Ignore states different from previous hard state only
    if e.last_hard_state_change and e.last_check and e.last_hard_state_change < e.last_check then
      broker_log:info(3, "write: " .. e.host_id .. "_" .. ifnil_or_empty(e.service_id, "H") .. " Last hard state change prior to last check => no state change. Dropping.")
      return true
    end

    -- Ignore objects in downtime
    if e.scheduled_downtime_depth ~= 0 then --we keep only events in hard state and not in downtime
      broker_log:info(3, "write: " .. e.host_id .. "_" .. ifnil_or_empty(e.service_id, "H") .. " Scheduled downtime. Dropping.")
      return true
    end

    -- workaround https://github.com/centreon/centreon-broker/issues/201
    if current_event == previous_event then
      broker_log:info(3, "write: Duplicate event ignored.")
      return true
    end

    -- Ignore pending states
    if e.state and e.state == 4 then
      broker_log:info(3, "write: " .. e.host_id .. "_" .. ifnil_or_empty(e.service_id, "H") .. " Pending state ignored. Dropping.")
      return true
    end
    -- The current event now becomes the previous
    previous_event = current_event
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

