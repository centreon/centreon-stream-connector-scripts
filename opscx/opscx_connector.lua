#!/usr/bin/lua
--
-- Copyright 2018 Centreon
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
-- http_server_url (string): the full HTTP URL. Default: https://my.opscx.server:30005/bsmc/rest/events/HPBsmIntCentreon/.
-- http_proxy_string (string): the full proxy URL if needed to reach the OPSCX server. Default: empty.
-- centreon_url (string): the url to access at Centreon, Default: http://x.x.x.x (can be a FQDN).
-- log_path (string): the log file to use
-- log_level (number): the log level (0, 1, 2, 3) where 3 is the maximum level. 0 logs almost nothing. 1 logs only the beginning of the script and errors. 2 logs a reasonable amount of verbose. 3 logs almost everything possible, to be used only for debug. Recommended value in production: 1.
-- max_buffer_size (number): how many events to store before sending them to the server.
-- max_buffer_age (number): flush the events when the specified time (in second) is reach (even if max_size is not reach).
-- max_output_length (number): maximum number of characters of the output field (description in XML event) that must be sent. Default: 1024
-- filter_hostgroups (string): comma-separated whitelist of hosgroups names that are eligible to be sent in the XML event. Default: empty, meaning that all hostgroups are sent.

-- Libraries
local curl = require "cURL"
local new_from_timestamp = require "luatz.timetable".new_from_timestamp
local get_tz = require "luatz.tzcache".get_tz
local http = require("socket.http")
local ltn12 = require("ltn12")

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

local function format_date(time)
  local date = string.format("%02u-%02u-%04u %02u:%02u:%02u", time.day, time.month, time.year, time.hour, time.min, time.sec)
  return date
 end

-- Array for mapping state
local from_host_state_to_severity = {"UP", "DOWN", "UNREACHABLE" }
local from_service_state_to_severity = {"OK", "WARNING", "CRITICAL", "UNKNOWN" }

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
    source_ci               = "Centreon",
    centreon_url            = "http://x.x.x.x",
    http_server_url         = "https://my.opscx.server:30005/bsmc/rest/events/HPBsmIntCentreon/",
    http_proxy_string       = "",
    http_timeout            = 5,
    filter_type             = "metric,status",
    filter_hostgroups       = "",
    max_output_length       = 1024,
    max_buffer_size         = 1,
    max_buffer_age          = 5,
    log_level               = 2, -- already processed in init function
    log_path                = "", -- already processed in init function
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
  retval.events = {}
  -- Storing the allowed hostgroups in an array
  retval.filter_hostgroups_array = {}
  if retval.filter_hostgroups and retval.filter_hostgroups ~= "" then
    filter_hostgroups_regex = "^("
    for hg in string.gmatch(retval.filter_hostgroups, "([^,]+)") do
      table.insert(retval.filter_hostgroups_array, hg)
    end
    broker_log:info(3, "EventQueue.new: Allowed hostgroups are: " .. table.concat(retval.filter_hostgroups_array, ' - '))
  end
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
  local state = ""
  local source_event_url = self.centreon_url
  local hostname = get_hostname(e.host_id)
  local host_severity = ifnil_or_empty(broker_cache:get_severity(e.host_id), 'no category found')
  if hostname == e.host_id then
    if self.skip_anon_events ~= 1 then
      broker_log:error(0, "EventQueue:add: unable to get hotsname for host_id '" .. e.host_id .."'")
      return false
    else
      broker_log:info(1, "EventQueue:add: ignoring that we can't resolve host_id '" .. e.host_id .."'. The event will be sent with the id only")
    end
    source_event_url = source_event_url.. "/centreon/main.php?p=20202&amp;o=hd&amp;host_name=" .. hostname
  end

  local service_description = "host"
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
    source_event_url = source_event_url .. "/centreon/main.php?p=20201&amp;o=svcd&amp;host_name=".. hostname  .. "&amp;service_description=" .. service_description
  end
 
  local hostgroup_to_send = ""
  local host_hg_array = broker_cache:get_hostgroups(e.host_id)
  if #self.filter_hostgroups_array > 0 then
    for i = 1, #host_hg_array do
      local host_hg_name = host_hg_array[i].group_name
      for j = 1, #self.filter_hostgroups_array do
        if self.filter_hostgroups_array[j] and host_hg_name == self.filter_hostgroups_array[j] then
          hostgroup_to_send = host_hg_name
          broker_log:info(3, "EventQueue:add: first common HG between " .. broker.json_encode(host_hg_array) .. " and " .. broker.json_encode(self.filter_hostgroups_array) .. " is " .. hostgroup_to_send)
          break
        end
      end
      if hostgroup_to_send ~= "" then
        break
      end
    end
    if hostgroup_to_send == "" then
      broker_log:info(3, "EventQueue:add: NO common HG found between " .. broker.json_encode(host_hg_array) .. " and " .. broker.json_encode(self.filter_hostgroups_array))
    end
  else
    -- case when no filter has been set for hostgroups
    for i = 1, #host_hg_array do
      hostgroup_to_send = hostgroup_to_send .. host_hg_array[i].group_name .. " - "
      broker_log:info(3, "EventQueue:add: no filter hostgroups found, sending all of them (" .. hostgroup_to_send .. ")")
    end
  end

  -- Managing perfdata
  local metrics = ""
  if e.perfdata then
    local perf, err_str = broker.parse_perfdata(e.perfdata, true)
    if perf then
      for key,v in pairs(perf) do
        metrics = metrics .. key .. " : " .. tostring(v.value) .. tostring(v.uom) .. "\n"
      end
    end
  end

  -- Creating a omi_event_key to use the Close Events with Key feature
  local omi_event_key = ""
  if e.service_id then
    omi_event_key = e.host_id .. "_" .. e.service_id
  else
    omi_event_key = e.host_id .. "_H"
  end

  -- Get state except for downtime
  if e.state and type == "host" then
    state = ifnil_or_empty(from_host_state_to_severity[e.state + 1], 'error')
  elseif e.state and type == "service" then
    state = ifnil_or_empty(from_service_state_to_severity[e.state + 1], 'error')
  end

  -- Event to send
  local event_to_send = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"

  -- Handling Acknowledgement
  if e.element == 1 then
    local is_acknowledged = "true"
    local acknowledge_output = "[" .. e.author .. "] " .. e.comment_data
    local time_created = e.entry_time
    if e.deletion_time then
      is_acknowledged = "false"
      acknowledge_output = "[CANCEL] " .. acknowledge_output
      time_created = e.deletion_time
    end
    event_to_send = event_to_send .. 
      "<event_data xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:noNamespaceSchemaLocation=\"../docs/schema/event.xsd\">" ..
      "<title>" .. service_description .. "</title>" ..
      "<description>" .. string.sub(ifnil_or_empty(string.match(acknowledge_output, "^(.*)"), 'no output'), 1, self.max_output_length) .. "</description>" ..
      "<severity>" .. state .. "</severity>" .. 
      "<state></state>" ..
      "<time_created>" .. time_created .. "</time_created>" ..
      "<category></category>" ..
      "<subcategory></subcategory>" ..
      "<eti></eti>" ..
      "<node>" .. hostname .. "</node>" ..
      "<related_ci></related_ci>" ..
      "<subcomponent></subcomponent>" ..
      "<source_ci>" .. self.source_ci .. "</source_ci>" ..
      "<source_event_id></source_event_id>" ..
      "<source_event_url>" .. source_event_url .. "</source_event_url>" ..
      "<omi_event_key>" .. omi_event_key .. "</omi_event_key>" ..
      "<custom_attributes>" ..
      "<name01>is_acknowledged</name01>" ..
      "<value01>" .. is_acknowledged .. "</value01>" ..
      "<name02></name02>"..
      "<value02></value02>" ..
      "<name03></name03>"..
      "<value03></value03>" ..
      "<name04></name04>"..
      "<value04></value04>" ..
      "<name05></name05>"..
      "<value05></value05>" ..
      "<name06></name06>"..
      "<value06></value06>" ..
      "<name07>hostgroup</name07>" ..
      "<value07>" .. hostgroup_to_send .. "</value07>" ..
      "<name08>host_severity</name08>" ..
      "<value08>" .. host_severity .. "</value08>" ..
      "<name09></name09>"..
      "<value09></value09>" ..
      "<name10></name10>"..
      "<value10></value10>" ..
      "</custom_attributes>" ..
      "</event_data>"
  end

  -- Handling downtimes
  if e.element == 5 then

    local downtime_output = ""
    local downtime_actual
    local time_created = e.entry_time
    if e.cancelled then
      downtime_output = "[CANCELLED] "
      downtime_actual = "false"
    else
      downtime_actual = "true"
    end

    local downtime_start_time
    if e.actual_start_time then
      time_created = e.actual_start_time
      downtime_start_time = e.actual_start_time
    else
      time_created = e.start_time
      downtime_start_time = e.start_time
    end

    local downtime_end_time
    if e.actual_end_time then
      downtime_end_time = e.actual_end_time
      downtime_actual = "false"
      downtime_output = "[ENDED] "
    else
      downtime_end_time = e.end_time
    end

    downtime_output = downtime_output .. e.comment_data .. " (" .. e.author .. ")"

    broker_log:info(3, "queue:add: A downtime event has been received: " .. downtime_output )

    event_to_send = event_to_send ..
      "<event_data xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:noNamespaceSchemaLocation=\"../docs/schema/event.xsd\">" ..
      "<title>" .. service_description .. "</title>" .. 
      "<description>" .. string.sub(ifnil_or_empty(string.match(downtime_output, "^(.*)\n?"), 'no output'), 1, self.max_output_length) .. "</description>" ..
      "<severity></severity>" ..
      "<state></state>" ..
      "<time_created>" .. time_created .. "</time_created>" ..
      "<category></category>" ..
      "<subcategory></subcategory>" ..
      "<eti></eti>" ..
      "<node>" .. hostname .. "</node>" ..
      "<related_ci></related_ci>" ..
      "<subcomponent></subcomponent>" ..
      "<source_ci>" .. self.source_ci .. "</source_ci>" ..
      "<source_event_id></source_event_id>" ..
      "<source_event_url>" .. source_event_url .. "</source_event_url>" ..
      "<omi_event_key>" .. omi_event_key .. "</omi_event_key>" ..
      "<custom_attributes>" ..
      "<name01></name01>" ..
      "<value01></value01>" ..
      "<name02>is_downtime</name02>" ..
      "<value02>" .. downtime_actual .. "</value02>" ..
      "<name03>time_end</name03>" ..
      "<value03>" .. format_date(new_from_timestamp(get_tz():localise(e.last_state_change))) .. "</value03>" ..
      "<name04></name04>"..
      "<value04></value04>" ..
      "<name05></name05>"..
      "<value05></value05>" ..
      "<name06></name06>"..
      "<value06></value06>" ..
      "<name07>hostgroup</name07>" ..
      "<value07>" .. hostgroup_to_send .. "</value07>" ..
      "<name08>host_severity</name08>" ..
      "<value08>" .. host_severity .. "</value08>" ..
      "<name09></name09>"..
      "<value09></value09>" ..
      "<name10></name10>"..
      "<value10></value10>" ..
      "</custom_attributes>" ..
      "</event_data>"
  end

  -- Handling Flapping
  if e.element == 7 then
    local flapping_output = "Flapping stopped"
    local is_flapping = "false"
    local time_created = e.event_time
    if e.event_type == 1000 then
      flapping_output = "Flapping started"
      is_flapping = "true"
    end 
    event_to_send = event_to_send ..
      "<event_data xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:noNamespaceSchemaLocation=\"../docs/schema/event.xsd\">" ..
      "<title>" .. service_description .. "</title>" ..
      "<description>" .. string.sub(ifnil_or_empty(string.match(flapping_output, "^(.*)\n?"), 'no output'), 1, self.max_output_length) .. "</description>" ..
      "<severity></severity>" ..
      "<state></state>" ..
      "<time_created>" .. time_created .. "</time_created>" ..
      "<category></category>" ..
      "<subcategory></subcategory>" ..
      "<eti></eti>" ..
      "<node>" .. hostname .. "</node>" ..
      "<related_ci></related_ci>" ..
      "<subcomponent></subcomponent>" ..
      "<source_ci>" .. self.source_ci .. "</source_ci>" ..
      "<source_event_id></source_event_id>" ..
      "<source_event_url>" .. source_event_url .. "</source_event_url>" ..
      "<omi_event_key>" .. omi_event_key .. "</omi_event_key>" ..
      "<custom_attributes>" ..
      "<name01></name01>" ..
      "<value01></value01>" ..
      "<name02></name02>"..
      "<value02></value02>" ..
      "<name03></name03>"..
      "<value03></value03>" ..
      "<name04>is_flapping</name04>" ..
      "<value04>" .. is_flapping .. "</value04>" ..
      "<name05></name05>"..
      "<value05></value05>" ..
      "<name06></name06>"..
      "<value06></value06>" ..
      "<name07>hostgroup</name07>" ..
      "<value07>" .. hostgroup_to_send .. "</value07>" ..
      "<name08>host_severity</name08>" ..
      "<value08>" .. host_severity .. "</value08>" ..
      "<name09></name09>"..
      "<value09></value09>" ..
      "<name10></name10>"..
      "<value10></value10>" ..
      "</custom_attributes>" ..
      "</event_data>"
  end

  -- Host and Service Status 
  if e.element == 14 or e.element == 24 then
    local is_downtime = "false"
    local is_acknowledged = "false"
    local is_flapping = "false"
    local check_type = "active"
    local output = string.gsub(e.output,"\\n","\n") .. metrics
    if e.check_type == 1 then
      check_type = "passive"
    end
    if e.is_flapping then
      is_flapping = "true"
    end
    if e.acknowledged then
      is_acknowledged = "true"
    end
    if e.scheduled_downtime_depth and e.scheduled_downtime_depth == 1 then
      is_downtime = "true"
    end
    event_to_send = event_to_send ..
      "<event_data xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:noNamespaceSchemaLocation=\"../docs/schema/event.xsd\">" ..
      "<title>" .. service_description .. "</title>" .. 
      "<description>" .. string.sub(ifnil_or_empty(string.match(output, "^(.*)\n"), 'no output'), 1, self.max_output_length) .. "</description>" .. 
      "<severity>" .. state .. "</severity>" .. 
      "<state></state>" ..
      "<time_created>" .. e.last_state_change .. "</time_created>" ..
      "<category></category>" ..
      "<subcategory></subcategory>" ..
      "<eti></eti>" ..
      "<node>" .. hostname .. "</node>" .. 
      "<related_ci></related_ci>" ..
      "<subcomponent></subcomponent>" ..
      "<source_ci>" .. self.source_ci .. "</source_ci>" .. 
      "<source_event_id></source_event_id>" ..
      "<source_event_url>" .. source_event_url .. "</source_event_url>" .. 
      "<omi_event_key>" .. omi_event_key .. "</omi_event_key>" ..
      "<custom_attributes>" ..
      "<name01>is_acknowledged</name01>" ..
      "<value01>" .. is_acknowledged .. "</value01>" ..
      "<name02>is_downtime</name02>" ..
      "<value02>" .. is_downtime .. "</value02>" ..
      "<name03></name03>" ..
      "<value03></value03>" ..
      "<name04>is_flapping</name04>" ..
      "<value04>" .. is_flapping .. "</value04>" ..
      "<name05>check_type</name05>" ..
      "<value05>" .. check_type .. "</value05>" ..
      "<name06>time_updated</name06>" ..
      "<value06>" .. format_date(new_from_timestamp(get_tz():localise(e.last_state_change))) .. "</value06>" ..
      "<name07>hostgroup</name07>" ..
      "<value07>" .. hostgroup_to_send .. "</value07>" ..
      "<name08>host_severity</name08>" ..
      "<value08>" .. host_severity .. "</value08>" ..
      "<name09></name09>"..
      "<value09></value09>" ..
      "<name10></name10>"..
      "<value10></value10>" ..
      "</custom_attributes>" ..
      "</event_data>"
  end

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
  local http_post_data = table.concat(self.events, "")
  for s in http_post_data:gmatch("[^\r\n]+") do
    broker_log:info(2, "EventQueue:flush: HTTP POST data:   " .. s .. "")
  end

  broker_log:info(2, "EventQueue:flush: HTTP POST url: \"" .. self.http_server_url .. "\"")

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
        "Content-Type: application/xml",
      }
  )

  -- setting the CURLOPT_PROXY
  if self.http_proxy_string and self.http_proxy_string ~= "" then
    broker_log:info(2, "EventQueue:flush: HTTP PROXY string is '" .. self.http_proxy_string .. "'")
    http_request:setopt(curl.OPT_PROXY, self.http_proxy_string)
  end

  -- adding the HTTP POST data
  http_request:setopt_postfields(http_post_data)

  -- performing the HTTP request
  http_request:perform()

  -- collecting results
  http_response_code = http_request:getinfo(curl.INFO_RESPONSE_CODE)

  -- Handling the return code
  local retval = false
  if http_response_code == 202 or http_response_code == 200 then
    broker_log:info(2, "EventQueue:flush: HTTP POST request successful: return code is " .. http_response_code)
    -- now that the data has been sent, we empty the events array
    self.events = {}
    retval = true
  else
    broker_log:error(0, "EventQueue:flush: HTTP POST request to " .. self.http_server_url .. " FAILED, return code is " .. http_response_code)
    broker_log:error(1, "EventQueue:flush: HTTP POST request to " .. self.http_server_url .. " FAILED, message is:\n\"" .. http_response_body .. "\n\"\n")
  end
  
  broker_log:info(2, "EventQueue:flush: HTTP REQUEST is '" .. http_post_data .. "'")

  http_post_data = ""

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
  local log_path = "/var/log/centreon-broker/stream-connector-opscx.log"
  for i,v in pairs(conf) do
    if i == "log_level" then
      log_level = v
    end
    if i == "log_path" then
      log_path = v
    end
  end
  broker_log:set_parameters(log_level, log_path)
  broker_log:info(0, "init: Starting OPSCX StreamConnector (log level: " .. log_level .. ")")
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
    -- ACK/DWT/Flapping/Host Status/Service Status
    if not (e.category == 1 and (e.element == 1 or e.element == 5 or e.element == 7 or e.element == 24 or e.element == 14)) then
      broker_log:info(3, "write: Neither host nor service status event. Dropping.")
      return true
    end

    -- workaround https://github.com/centreon/centreon-broker/issues/201
    current_event = broker.json_encode(e)
    broker_log:info(3, "write: Raw event: " .. current_event)

    -- Ignore SOFT 
    if e.state_type and e.state_type ~= 1 then
      broker_log:info(3, "write: " .. e.host_id .. "_" .. ifnil_or_empty(e.service_id, "H") .. " Not HARD state type. Dropping.")
      return true
    end

    -- Ignore states different from previous hard state only
    if e.last_hard_state_change and e.last_hard_state_change < e.last_check then
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
