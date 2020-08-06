--
-- Copyright 2020 Centreon
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- For more information : contact@centreon.com
--
-- To work you need to provide to this script a Broker stream connector output configuration
-- with the following informations:
--
-- source_ci (string): Name of the transmiter, usually Centreon server name
-- http_server_url (string): the full HTTP URL. Default: https://my.bsm.server:30005/bsmc/rest/events/ws-centreon/.
-- http_proxy_string (string): the full proxy URL if needed to reach the BSM server. Default: empty.
-- log_path (string): the log file to use
-- log_level (number): the log level (0, 1, 2, 3) where 3 is the maximum level. 0 logs almost nothing. 1 logs only the beginning of the script and errors. 2 logs a reasonable amount of verbose. 3 logs almost everything possible, to be used only for debug. Recommended value in production: 1.
-- max_buffer_size (number): how many events to store before sending them to the server.
-- max_buffer_age (number): flush the events when the specified time (in second) is reached (even if max_size is not reached).

-- Libraries
local curl = require "cURL"
local new_from_timestamp = require "luatz.timetable".new_from_timestamp


-- workaround https://github.com/centreon/centreon-broker/issues/201
local previous_event = ""

-- Useful functions
local function ifnil(var, alt)
  if not var or var == nil then
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
  local objEventQueue = {
    source                  = "Centreon",
    MID_Servers_List        = "set MID_Servers_List",
    MID_Servers             = {},
    MID_Login               = "set MID_Login",
    MID_Password            = "set MID_Password",
    http_proxy_string       = "",
    http_timeout            = 5,
    max_output_length       = 1024,
    max_buffer_size         = 1,
    max_buffer_age          = 5,
    log_level               = 2,
    log_path                = "",
    skip_anon_events        = 1
  }
  for i,v in pairs(conf) do
    if objEventQueue[i] then
      objEventQueue[i] = v
      broker_log:info(2, "EventQueue.new: getting parameter " .. i .. " => " .. v)
    else
      broker_log:warning(1, "EventQueue.new: ignoring unhandled parameter " .. i .. " => " .. v)
    end
  end

  if objEventQueue.MID_Servers_List and objEventQueue.MID_Servers_List:match("set ") then
    broker_log:warning(0, "EventQueue.new: 'MID_Servers_List' has not been set in the Stream Connector parameters")
  else
    for mid_server in string.gmatch(objEventQueue.MID_Servers_List, "%s*([^,]+)%s*") do
      broker_log:info(2, "EventQueue.new: adding to MID_Servers " .. mid_server)
      objEventQueue.MID_Servers[#objEventQueue.MID_Servers + 1] = mid_server
    end
  end

  if objEventQueue.MID_Login and objEventQueue.MID_Login:match("set ") then
    broker_log:warning(0, "EventQueue.new: 'MID_Login' has not been set in the Stream Connector parameters")
  end

  if objEventQueue.MID_Password and objEventQueue.MID_Password:match("set ") then
    broker_log:warning(0, "EventQueue.new: 'MID_Password' has not been set in the Stream Connector parameters")
  end

  objEventQueue.__internal_ts_last_flush = os.time()
  objEventQueue.events = {}
  setmetatable(objEventQueue, EventQueue)
  -- Internal data initialization
  broker_log:info(2, "EventQueue.new: setting the internal timestamp to " .. objEventQueue.__internal_ts_last_flush)
  return objEventQueue
end

--------------------------------------------------------------------------------
-- EventQueue:add method
-- @param e An event
--------------------------------------------------------------------------------

function EventQueue:add(e)

  local type = "HOST"
  local hostname = "Meta"
  if e.host_id then
    hostname = get_hostname(e.host_id)
    if hostname == e.host_id then
      if self.skip_anon_events ~= 1 then
        broker_log:error(0, "EventQueue:add: unable to get hostname for host_id '" .. e.host_id .."'")
        return false
      else
        broker_log:info(1, "EventQueue:add: ignoring that we can't resolve host_id '" .. e.host_id .."'. The event will be sent with the id only")
      end
    end
  end

  local service_description = "HOST"
  if e.service_id then
    type = "service"
    service_description = get_service_description(e.host_id, e.service_id)
    if service_description == e.service_id then
      if self.skip_anon_events ~= 1 then
        broker_log:error(0, "EventQueue:add: unable to get service_description for host_id '" .. e.host_id .."' and service_id '" .. e.service_id .."'")
      else
        broker_log:info(1, "EventQueue:add: ignoring that we can't resolve host_id '" .. e.host_id .."' and service_id '" .. e.service_id .."'")
      end
    end
  elseif hostname == "Meta" then
    service_description = e.output
  end

  -- Getting the host extended information
  -- commented because we might not use them
--  local xml_url = ''
--  local xml_notes = ''
--  local xml_service_severity = ''
--  local xml_host_severity = ''
--  if e.host_id then
--    xml_host_severity = "<host_severity>" .. ifnil(broker_cache:get_severity(e.host_id), '0') .. "</host_severity>"
--    if e.service_id then
--      xml_url = ifnil(broker_cache:get_notes_url(e.host_id, e.service_id), 'no notes url for this service') 
--      xml_service_severity = "<service_severity>" ..ifnil(broker_cache:get_severity(e.host_id, e.service_id), '0') .. "</service_severity>"
--    else 
--      xml_url = ifnil(broker_cache:get_action_url(e.host_id), 'no action url for this host') 
--      xml_notes = "<host_notes>" .. ifnil(broker_cache:get_notes(e.host_id), 'OS not set') .. "</host_notes>"
--    end
--  end
--
--  local hgroups = broker_cache:get_hostgroups(d.host_id)
--  if hgroups and #hgroups > 0 then
--    grps = ""
--    for idx = 1, #hgroups do
--      grps = grps .. hgroups[idx].group_name .. ' '
--    end
--    labels = labels .. "host_groups=" .. grps .. ','
--  end

  -- Event to send
  local event_to_send = {}
  event_to_send["source"] = ifnil_or_empty(self.source, 'Centreon')
  event_to_send["source_instance"] = ifnil_or_empty(self.source_instance, 'Centreon central server')
  event_to_send["node"] = hostname
  event_to_send["resource"] = service_description
  event_to_send["metric_name"] = service_description
  event_to_send["type"] = service_description
  -- Building of the 'message_key'
  -- $HOSTPROBLEMID$ / $SERVICEPROBLEMID$
  -- Determining the message_key...
  -- "host_id / service_id / last_time_(ok|up)" if the current state is not ok / up
  -- "host_id / service_id / max(last_time_warning, last_time_critical, last_time_unknown, last_time_down, last_time_unreachable)" if the current state is ok / up
  if e.state == 0 then
    event_to_send["message_key"] = ifnil_or_empty(e.host_id, 0) .. "/" .. ifnil_or_empty(e.service_id, 0) .. "/" .. math.max(ifnil_or_empty(e.last_time_warning, 0), ifnil_or_empty(e.last_time_critical, 0), ifnil_or_empty(e.last_time_unknown, 0), ifnil_or_empty(e.last_time_down, 0), ifnil_or_empty(e.last_time_unreachable, 0))
  else
    event_to_send["message_key"] = ifnil_or_empty(e.host_id, 0) .. "/" .. ifnil_or_empty(e.service_id, 0) .. "/" .. math.max(ifnil_or_empty(e.last_time_ok, 0), ifnil_or_empty(e.last_time_up, 0))
  end

  -- Determining the severity
  local host_state_to_severity = {0, 1, 1, 5}
  local service_state_to_severity = {0, 4, 2, 5}
  if service_description == "HOST" then
    event_to_send["severity"] = host_state_to_severity[e.state + 1]
  else
    event_to_send["severity"] = service_state_to_severity[e.state + 1]
  end

  -- Gathering the additional_info
  -- additional_info: host_groups
  local additional_info = {}
  local host_groups = {}
  local hg_list = broker_cache:get_hostgroups(e.host_id)
  if #hg_list > 1 then
    for i = 1, #hg_list do
      host_groups[#host_groups + 1] = hg_list[i].group_name
    end
  end
  additional_info["host_groups"] = host_groups

  -- additional_info: service_groups
  if e.service_id then
    local service_groups = {}
    local sg_list = broker_cache:get_servicegroups(e.host_id, e.service_id)
    if #sg_list > 1 then
      for i = 1, #sg_list do
        service_groups[#service_groups + 1] = sg_list[i].group_name
      end
      additional_info["service_groups"] = service_groups
    end
  end

  -- additional_info is added to the event
  event_to_send["additional_info"] = additional_info

  -- time of event, according to localtime
  event_to_send["time_of_event"] = new_from_timestamp(e.last_check):rfc_3339()

  -- Ignoring resolution_state
  --event_to_send["resolution_state"] = ""

  -- description receives the (long) output
  event_to_send["description"] = e.output

  broker_log:info(1, "queue:add: event added " .. broker:json_encode(event_to_send))

  -- Appending to the event queue
  self.events[#self.events + 1] = event_to_send

  return true
end

--------------------------------------------------------------------------------
-- EventQueue:flush method
-- Called when the max number of events or the max age are reached
--------------------------------------------------------------------------------

function EventQueue:flush()

  broker_log:info(3, "EventQueue:flush: Concatenating all the events as one string")

  local http_post_data = broker:json_encode(self.events)
  local http_server_path = "/api/mid/em/jsonv2"
  local servers_tried = 0

  for i, mid_server in ipairs(self.MID_Servers) do
    local http_server_url = mid_server .. http_server_path
    broker_log:info(3, "EventQueue:flush: HTTP url: \"" .. http_server_url .. "\"")
  
    local http_response_body = ""
    local http_request = curl.easy()
      :setopt_url(http_server_url)
      :setopt(curl.OPT_USERNAME, self.MID_Login)
      :setopt(curl.OPT_PASSWORD, self.MID_Password)
      :setopt(curl.OPT_SSL_VERIFYPEER, 0)
      :setopt_writefunction(
        function (response)
          http_response_body = http_response_body .. tostring(response)
        end
      )
      :setopt(curl.OPT_TIMEOUT, self.http_timeout)
      :setopt(
        curl.OPT_HTTPHEADER,
        {
          "Content-Type: application/json",
          "Accept: application/json",
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
    -- broker_log:info(0, "EventQueue:flush: mid_server:" .. mid_server)
    -- broker_log:info(0, "EventQueue:flush: MID_Login: " .. self.MID_Login)
    -- broker_log:info(0, "EventQueue:flush: MID_Password: " .. self.MID_Password)
    -- broker_log:info(0, "EventQueue:flush: http_post_data: " .. http_post_data)
    self.events = {}
    self.__internal_ts_last_flush = os.time()
    -- collecting results
    http_response_code = http_request:getinfo(curl.INFO_RESPONSE_CODE)
  
    -- Handling the return code
    local retval = false
    if http_response_code == 202 or http_response_code == 200 then
      broker_log:info(2, "EventQueue:flush: HTTP POST request successful: return code is " .. http_response_code)
      -- now that the data has been sent, we empty the events array
      self.events = {}
      retval = true
      self.__internal_ts_last_flush = os.time()
      break
    else
      broker_log:error(1, "EventQueue:flush: HTTP request FAILED on " .. http_server_url .. ", return code is " .. http_response_code .. ", message is:\n\"" .. http_response_body .. "\"\n")
    end
    servers_tried = servers_tried + 1
  end
  if retval == false and servers_tried == #self.MID_Servers then
    broker_log:error(0, "EventQueue:flush: HTTP request failed on all servers")
  end
  return retval
end

--------------------------------------------------------------------------------
-- Required functions for Broker StreamConnector
--------------------------------------------------------------------------------

local queue

-- Fonction init()
function init(conf)
  local log_level = 1
  local log_path = "/var/log/centreon-broker/stream-connector-snow-mid-server.log"
  for i,v in pairs(conf) do
    if i == "log_level" then
      log_level = v
    end
    if i == "log_path" then
      log_path = v
    end
  end
  broker_log:set_parameters(log_level, log_path)
  broker_log:info(0, "init: Starting BSM StreamConnector (log level: " .. log_level .. ")")
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

    -- Then we check whether the event queue is already full
    if (#queue.events >= queue.max_buffer_size) then
      broker_log:warning(1, "write: Queue max size (" .. #queue.events .. "/" .. queue.max_buffer_size .. ") is reached BEFORE APPENDING AN EVENT, flushing data after a 1s sleep.")
      os.execute("sleep " .. tonumber(1))
      return queue:flush()
    end

    -- Here come the filters
    -- Host Status/Service Status only
    if not (e.category == 1 and (e.element == 24 or e.element == 14)) then
      broker_log:info(3, "write: Neither host nor service status event. Dropping.")
      return true
    end

    -- on drop les meta services pour le moment
    if not e.host_id then
        return true
    end

    if not e.host_id and not e.output:find("Meta-Service") == 1 then
        broker_log:error(1, "write: Event has no host_id: " .. broker.json_encode(e))
        return true
    end

    -- workaround https://github.com/centreon/centreon-broker/issues/201
    current_event = broker.json_encode(e)
    broker_log:info(3, "write: Raw event: " .. current_event)

    -- Ignore objects in downtime
    if e.scheduled_downtime_depth ~= 0 then --we keep only events in hard state and not in downtime -- Modif du 18/02/2020 => Simon Bomm
      broker_log:info(3, "write: Scheduled downtime. Dropping.")
      return true
    end

    -- Ignore objects with notifications disabled
    if e.notify == false then
      broker_log:info(3, "write: Notifications not enabled. Dropping.")
      return true
    end

    -- Ignore SOFT 
    if e.state_type and e.state_type ~= 1 then
      broker_log:info(3, "write: " .. e.host_id .. "_" .. ifnil_or_empty(e.service_id, "H") .. " Not HARD state type. Dropping.")
      return true
    end

    -- Ignore states different from previous hard state only
    if e.last_hard_state_change and e.last_check and e.last_hard_state_change < e.last_check then
      broker_log:info(3, "write: " .. e.host_id .. "_" .. ifnil_or_empty(e.service_id, "H") .. " Last hard state change prior to last check => no state change. Dropping.")
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

