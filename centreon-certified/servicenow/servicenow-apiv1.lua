#!/usr/bin/lua

--------------------------------------------------------------------------------
-- Centreon Broker Service Now connector
-- documentation: https://docs.centreon.com/current/en/integrations/stream-connectors/servicenow.html
--------------------------------------------------------------------------------


-- libraries
local curl = require "cURL"

-- Global variables

-- Useful functions

--------------------------------------------------------------------------------
-- ifnil_or_empty: change a nil or empty variable for a specified value
-- @param var, the variable that needs to be checked
-- @param alt, the value of the variable if it is nil or empty
-- @return alt|var, the alternate value or the variable value
--------------------------------------------------------------------------------
local function ifnil_or_empty(var, alt)
  if var == nil or var == '' then
    return alt
  else
    return var
  end
end

--------------------------------------------------------------------------------
-- boolean_to_number: convert boolean variable to number
-- @param {boolean} boolean, the boolean that will be converted
-- @return {number}, a number according to the boolean value
--------------------------------------------------------------------------------
local function boolean_to_number (boolean)
  return boolean and 1 or 0
end

--------------------------------------------------------------------------------
-- check_boolean_number_option_syntax: make sure the number is either 1 or 0
-- @param {number} number, the boolean number that must be validated
-- @param {number} default, the default value that is going to be return if the default number is not validated
-- @return {number} number, a boolean number
--------------------------------------------------------------------------------
local function check_boolean_number_option_syntax (number, default)
  if number ~= 1 and number ~= 0 then
    number = default
  end

  return number
end

--------------------------------------------------------------------------------
-- get_hostname: retrieve hostname from host_id
-- @param {number} host_id,
-- @return {string} hostname,
--------------------------------------------------------------------------------
local function get_hostname (host_id)
  if host_id == nil then
    broker_log:warning(1, "get_hostname: host id is nil")
    hostname = 0
    return hostname
  end

  local hostname = broker_cache:get_hostname(host_id)
  if not hostname then
    broker_log:warning(1, "get_hostname: hostname for id " .. host_id .. " not found. Restarting centengine should fix this.")
    hostname = host_id
  end

  return hostname
end

--------------------------------------------------------------------------------
-- get_service_description: retrieve the service name from its host_id and service_id
-- @param {number} host_id,
-- @param {number} service_id,
-- @return {string} service, the name of the service
--------------------------------------------------------------------------------
local function get_service_description (host_id, service_id)
  if host_id == nil or service_id ==  nil then
    service = 0
    broker_log:warning(1, "get_service_description: host id or service id has a nil value")

    return service
  end

  local service = broker_cache:get_service_description(host_id, service_id)
  if not service then
    broker_log:warning(1, "get_service_description: service_description for id " .. host_id .. "." .. service_id .. " not found. Restarting centengine should fix this.")
    service = service_id
  end

  return service
end

--------------------------------------------------------------------------------
-- get_hostgroups: retrieve hostgroups from host_id
-- @param {number} host_id,
-- @return {array} hostgroups, 
--------------------------------------------------------------------------------
local function get_hostgroups (host_id)
  if host_id == nil then 
    broker_log:warning(1, "get_hostgroup: host id is nil")
    return false
  end

  local hostgroups = broker_cache:get_hostgroups(host_id)

  if not hostgroups then
    return false
  end
  
  return hostgroups
end

--------------------------------------------------------------------------------
-- split: convert a string into a table
-- @param {string} string, the string that is going to be splitted into a table
-- @param {string} separatpr, the separator character that will be used to split the string
-- @return {table} table,
--------------------------------------------------------------------------------
local function split (text, separator)
  local hash = {}
  -- https://stackoverflow.com/questions/1426954/split-string-in-lua
  for value in string.gmatch(text, "([^" .. separator .. "]+)") do
    table.insert(hash, value)
  end

  return hash
end

--------------------------------------------------------------------------------
-- find_in_mapping: check if item type is in the mapping and is accepted
-- @param {table} mapping, the mapping table
-- @param {string} reference, the accepted values for the item
-- @param {string} item, the item we want to find in the mapping table and in the reference
-- @return {boolean}
--------------------------------------------------------------------------------
local function find_in_mapping (mapping, reference, item)
  for mappingIndex, mappingValue in pairs(mapping) do
    for referenceIndex, referenceValue in pairs(split(reference, ',')) do
      if item == mappingValue and mappingIndex == referenceValue then
        return true
      end
    end
  end

  return false
end

--------------------------------------------------------------------------------
-- find_hostgroup_in_list: check if hostgroups from hosts are in an accepted list from the stream connector configuration
-- @param {table} acceptedHostgroups, the table with the name of accepted hostgroups 
-- @param {table} hostHostgroups, the hostgroups associated to an host
-- @return {boolean}
-- @return {string} [optional] acceptedHostgroupsName, the hostgroup name that matched
--------------------------------------------------------------------------------
local function find_hostgroup_in_list (acceptedHostgroups, hostHostgroups)
  for _, acceptedHostgroupsName in ipairs(acceptedHostgroups) do
    for _, hostHostgroupsInfo in pairs(hostHostgroups) do
      if acceptedHostgroupsName == hostHostgroupsInfo.group_name then
        return true, acceptedHostgroupsName
      end
    end
  end
  
  return false
end

--------------------------------------------------------------------------------
-- check_neb_event_status: check the status of a neb event (ok, critical...)
-- @param {number} eventStatus, the status of the event
-- @param {string} acceptedStatus, the event statuses that are going to be accepted
-- @return {boolean}
--------------------------------------------------------------------------------
local function check_neb_event_status (eventStatus, acceptedStatuses)
  for i, v in ipairs(split(acceptedStatuses, ',')) do
    if tostring(eventStatus) == v then
      return true
    end
  end

  return false
end

--------------------------------------------------------------------------------
-- compare_numbers: compare two numbers, if comparison is valid, then return true
-- @param {number} firstNumber
-- @param {number} secondNumber
-- @param {string} operator, the mathematical operator that is used for the comparison
-- @return {boolean}
--------------------------------------------------------------------------------
local function compare_numbers (firstNumber, secondNumber, operator)
  if type(firstNumber) ~= 'number' or type(secondNumber) ~= 'number' then
    return false
  end

  if firstNumber .. operator .. secondNumber then
    return true
  end

  return false
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

function EventQueue:new (conf)
  local retval = {
    host_status = "0,1,2", -- = ok, down, unreachable
    service_status = "0,1,2,3", -- = ok, warning, critical, unknown
    hard_only = 1,
    acknowledged = 0,
    element_type = "host_status,service_status", -- could be: metric,host_status,service_status,ba_event,kpi_event" (https://docs.centreon.com/docs/centreon-broker/en/latest/dev/bbdo.html#neb)
    category_type = "neb", -- could be: neb,storage,bam (https://docs.centreon.com/docs/centreon-broker/en/latest/dev/bbdo.html#event-categories)
    accepted_hostgroups = '',
    in_downtime = 0,
    max_buffer_size = 10,
    max_buffer_age = 5,
    max_stored_events = 10, -- do not use values above 100 
    skip_anon_events = 1,
    skip_nil_id = 1,
    element_mapping = {},
    category_mapping = {},
    instance = '',
    username = '',
    password = '',
    client_id = '',
    client_secret = '',
    proxy_address = '',
    proxy_port = '',
    proxy_username = '',
    proxy_password = '',
    validatedEvents = {},
    tokens = {}
  }

  retval.category_mapping = {
    neb = 1,
    bbdo = 2,
    storage = 3,
    correlation = 4,
    dumper = 5,
    bam = 6,
    extcmd = 7
  }

  retval.element_mapping = {
    [1] = {},
    [3] = {},
    [6] = {}
  }

  retval.element_mapping[1].acknowledgement = 1
  retval.element_mapping[1].comment = 2
  retval.element_mapping[1].custom_variable = 3
  retval.element_mapping[1].custom_variable_status = 4
  retval.element_mapping[1].downtime = 5
  retval.element_mapping[1].event_handler = 6
  retval.element_mapping[1].flapping_status = 7
  retval.element_mapping[1].host_check = 8
  retval.element_mapping[1].host_dependency = 9
  retval.element_mapping[1].host_group = 10
  retval.element_mapping[1].host_group_member = 11
  retval.element_mapping[1].host = 12
  retval.element_mapping[1].host_parent = 13
  retval.element_mapping[1].host_status = 14
  retval.element_mapping[1].instance = 15
  retval.element_mapping[1].instance_status = 16
  retval.element_mapping[1].log_entry = 17
  retval.element_mapping[1].module = 18
  retval.element_mapping[1].service_check = 19
  retval.element_mapping[1].service_dependency = 20
  retval.element_mapping[1].service_group = 21
  retval.element_mapping[1].service_group_member = 22
  retval.element_mapping[1].service = 23
  retval.element_mapping[1].service_status = 24
  retval.element_mapping[1].instance_configuration = 25

  retval.element_mapping[3].metric = 1
  retval.element_mapping[3].rebuild = 2
  retval.element_mapping[3].remove_graph = 3
  retval.element_mapping[3].status = 4
  retval.element_mapping[3].index_mapping = 5
  retval.element_mapping[3].metric_mapping = 6

  retval.element_mapping[6].ba_status = 1
  retval.element_mapping[6].kpi_status = 2
  retval.element_mapping[6].meta_service_status = 3
  retval.element_mapping[6].ba_event = 4
  retval.element_mapping[6].kpi_event = 5
  retval.element_mapping[6].ba_duration_event = 6
  retval.element_mapping[6].dimension_ba_event = 7
  retval.element_mapping[6].dimension_kpi_event = 8
  retval.element_mapping[6].dimension_ba_bv_relation_event = 9
  retval.element_mapping[6].dimension_bv_event = 10
  retval.element_mapping[6].dimension_truncate_table_signal = 11
  retval.element_mapping[6].bam_rebuild = 12
  retval.element_mapping[6].dimension_timeperiod = 13
  retval.element_mapping[6].dimension_ba_timeperiod_relation = 14
  retval.element_mapping[6].dimension_timeperiod_exception = 15
  retval.element_mapping[6].dimension_timeperiod_exclusion = 16
  retval.element_mapping[6].inherited_downtime = 17

  retval.tokens.authToken = nil
  retval.tokens.refreshToken = nil
  

  for i,v in pairs(conf) do
    if retval[i] then
      retval[i] = v
      if i == 'client_secret' or i == 'password' then
        broker_log:info(1, "EventQueue.new: getting parameter " .. i .. " => *********")
      else
        broker_log:info(1, "EventQueue.new: getting parameter " .. i .. " => " .. v)
      end
    else
      broker_log:info(1, "EventQueue.new: ignoring unhandled parameter " .. i .. " => " .. v)
    end
  end

  retval.hard_only = check_boolean_number_option_syntax(retval.hard_only, 1)
  retval.acknowledged = check_boolean_number_option_syntax(retval.acknowledged, 0)
  retval.in_downtime = check_boolean_number_option_syntax(retval.in_downtime, 0)
  retval.skip_anon_events = check_boolean_number_option_syntax(retval.skip_anon_events, 1)
  retval.skip_nil_id = check_boolean_number_option_syntax(retval.skip_nil_id, 1)

  retval.__internal_ts_last_flush = os.time()
  retval.events = {}
  setmetatable(retval, EventQueue)
  -- Internal data initialization
  broker_log:info(2, "EventQueue.new: setting the internal timestamp to " .. retval.__internal_ts_last_flush)

  return retval
end

--------------------------------------------------------------------------------
-- getAuthToken: obtain a auth token
-- @return {string} self.tokens.authToken.token, the auth token
--------------------------------------------------------------------------------
function EventQueue:getAuthToken ()
  if not self:refreshTokenIsValid() then
    self:authToken()
  end

  if not self:accessTokenIsValid() then
    self:refreshToken(self.tokens.refreshToken.token)
  end

  return self.tokens.authToken.token
end

--------------------------------------------------------------------------------
-- authToken: obtain auth token
--------------------------------------------------------------------------------
function EventQueue:authToken ()
  local data = "grant_type=password&client_id=" .. self.client_id .. "&client_secret=" .. self.client_secret .. "&username=" .. self.username .. "&password=" .. self.password

  local res = self:call(
    "oauth_token.do",
    "POST",
    data
  )

  if not res.access_token then
    broker_log:error(1, "EventQueue:authToken: Authentication failed, couldn't get tokens")
    return false
  end

  self.tokens.authToken = {
    token = res.access_token,
    expTime = os.time(os.date("!*t")) + 1700
  }

  self.tokens.refreshToken = {
    token = res.refresh_token,
    expTime = os.time(os.date("!*t")) + 360000
  }
end

--------------------------------------------------------------------------------
-- refreshToken: refresh auth token
--------------------------------------------------------------------------------
function EventQueue:refreshToken (token)
  local data = "grant_type=refresh_token&client_id=" .. self.client_id .. "&client_secret=" .. self.client_secret .. "&username=" .. self.username .. "&password=" .. self.password .. "&refresh_token=" .. token
  
  local res = self:call(
    "oauth_token.do",
    "POST",
    data
  )

  if not res.access_token then
    broker_log:error(1, 'EventQueue:refreshToken Bad access token')
    return false
  end

  self.tokens.authToken = {
    token = res.access_token,
    expTime = os.time(os.date("!*t")) + 1700
  }
end

--------------------------------------------------------------------------------
-- refreshTokenIsValid: obtain auth token
--------------------------------------------------------------------------------
function EventQueue:refreshTokenIsValid ()
  if not self.tokens.refreshToken then
    return false
  end

  if os.time(os.date("!*t")) > self.tokens.refreshToken.expTime then
    self.tokens.refreshToken = nil
    return false
  end

  return true
end

--------------------------------------------------------------------------------
-- accessTokenIsValid: obtain auth token
--------------------------------------------------------------------------------
function EventQueue:accessTokenIsValid ()
  if not self.tokens.authToken then
    return false
  end

  if os.time(os.date("!*t")) > self.tokens.authToken.expTime then
    self.tokens.authToken = nil
    return false
  end

  return true
end

--------------------------------------------------------------------------------
-- EventQueue:call run api call
-- @param {string} url, the service now instance url
-- @param {string} method, the HTTP method that is used
-- @param {string} data, the data we want to send to service now
-- @param {string} authToken, the api auth token
-- @return {array} decoded output
-- @throw exception if http call fails or response is empty
--------------------------------------------------------------------------------
function EventQueue:call (url, method, data, authToken)
  method = method or "GET"
  data = data or nil
  authToken = authToken or nil

  local endpoint = "https://" .. tostring(self.instance) .. ".service-now.com/" .. tostring(url)
  broker_log:info(3, "EventQueue:call: Prepare url " .. endpoint)

  local res = ""
  local request = curl.easy()
    :setopt_url(endpoint)
    :setopt_writefunction(function (response)
      res = res .. tostring(response)
    end)

  broker_log:info(3, "EventQueue:call: Request initialize")

  -- set proxy address configuration
  if (self.proxy_address ~= '') then
    if (self.proxy_port ~= '') then
      request:setopt(curl.OPT_PROXY, self.proxy_address .. ':' .. self.proxy_port)
    else 
      broker_log:error(1, "EventQueue:call: proxy_port parameter is not set but proxy_address is used")
    end
  end

  -- set proxy user configuration
  if (self.proxy_username ~= '') then
    if (self.proxy_password ~= '') then
      request:setopt(curl.OPT_PROXYUSERPWD, self.proxy_username .. ':' .. self.proxy_password)
    else
      broker_log:error(1, "EventQueue:call: proxy_password parameter is not set but proxy_username is used")
    end
  end

  if not authToken then
    if method ~= "GET" then
      broker_log:info(3, "EventQueue:call: Add form header")
      request:setopt(curl.OPT_HTTPHEADER, { "Content-Type: application/x-www-form-urlencoded" })
    end
  else
    broker_log:info(3, "Add JSON header")
    request:setopt(
      curl.OPT_HTTPHEADER,
      {
        "Accept: application/json",
        "Content-Type: application/json",
        "Authorization: Bearer " .. authToken
      }
    )
  end

  if method ~= "GET" then
    broker_log:info(3, "EventQueue:call: Add post data")
    request:setopt_postfields(data)
  end

  broker_log:info(3, "EventQueue:call: request body " .. tostring(data))
  broker_log:info(3, "EventQueue:call: request header " .. tostring(authToken))
  broker_log:info(3, "EventQueue:call: Call url " .. endpoint)
  request:perform()

  respCode = request:getinfo(curl.INFO_RESPONSE_CODE)
  broker_log:info(3, "EventQueue:call: HTTP Code : " .. respCode)
  broker_log:info(3, "EventQueue:call: Response body : " .. tostring(res))

  request:close()

  if respCode >= 300 then
    broker_log:info(1, "EventQueue:call: HTTP Code : " .. respCode)
    broker_log:info(1, "EventQueue:call: HTTP Error : " .. res)
    return false
  end

  if res == "" then
    broker_log:info(1, "EventQueue:call: HTTP Error : " .. res)
    return false
  end

  return broker.json_decode(res)
end

--------------------------------------------------------------------------------
-- is_valid_category: check if the event category is valid
-- @param {number} category, the category id of the event
-- @return {boolean}
--------------------------------------------------------------------------------
function EventQueue:is_valid_category (category)
  return find_in_mapping(self.category_mapping, self.category_type, category)
end

--------------------------------------------------------------------------------
-- is_valid_element: check if the event element is valid
-- @param {number} category, the category id of the event
-- @param {number} element, the element id of the event
-- @return {boolean}
--------------------------------------------------------------------------------
function EventQueue:is_valid_element (category, element)
  return find_in_mapping(self.element_mapping[category], self.element_type, element)
end

--------------------------------------------------------------------------------
-- is_valid_neb_event: check if the neb event is valid
-- @return {table} validNebEvent, a table of boolean indexes validating the event
--------------------------------------------------------------------------------
function EventQueue:is_valid_neb_event ()
  if self.currentEvent.element == 14 or self.currentEvent.element == 24 then
    self.currentEvent.hostname = get_hostname(self.currentEvent.host_id)

    -- can't find hostname in cache
    if self.currentEvent.hostname == self.currentEvent.host_id and self.skip_anon_events == 1 then
      return false
    end

    -- can't find host_id in the event
    if self.currentEvent.hostname == 0 and self.skip_nil_id == 1 then
      return false
    end

    if (string.find(self.currentEvent.hostname, '^_Module_BAM_*')) then
      return false
    end

    self.currentEvent.output = ifnil_or_empty(string.match(self.currentEvent.output, "^(.*)\n"), 'no output')
    self.sendData.source = 'centreon'
    self.sendData.event_class = 'centreon'
    self.sendData.severity = 5
    self.sendData.node = self.currentEvent.hostname
    self.sendData.time_of_event = os.date("!%Y-%m-%d %H:%M:%S", self.currentEvent.last_check)
    self.sendData.description = self.currentEvent.output
  end

  if self.currentEvent.element == 14 then
    if not check_neb_event_status(self.currentEvent.state, self.host_status) then
      return false
    end

    self.sendData.resource = self.currentEvent.hostname
    if self.currentEvent.state == 0 then
      self.sendData.severity = 0
    elseif self.currentEvent.state == 1 then
      self.sendData.severity = 1
    end

  elseif self.currentEvent.element == 24 then
    self.currentEvent.serviceDescription = get_service_description(self.currentEvent.host_id, self.currentEvent.service_id)

    -- can't find service description in cache
    if self.currentEvent.serviceDescription == self.currentEvent.service_id and self.skip_anon_events == 1 then
      return false
    end

    if not check_neb_event_status(self.currentEvent.state, self.service_status) then
      return false
    end

    -- can't find service_id in the event
    if self.currentEvent.serviceDescription == 0 and self.skip_nil_id == 1 then
      return false
    end

    self.currentEvent.svc_severity = broker_cache:get_severity(self.currentEvent.host_id,self.currentEvent.service_id)
  
  end

  -- check hard state
  if not compare_numbers(self.currentEvent.state_type, self.hard_only, '>=') then
    return false
  end

  -- check ack
  if not compare_numbers(self.acknowledged, boolean_to_number(self.currentEvent.acknowledged), '>=') then
    return false
  end

  -- check downtime
  if not compare_numbers(self.in_downtime, self.currentEvent.scheduled_downtime_depth, '>=') then
    return false
  end

  local my_retval = self:is_valid_hostgroup()

  if not self:is_valid_hostgroup() then
    return false
  end

  self.sendData.resource = self.currentEvent.serviceDescription
  if self.currentEvent.state == 0 then
    self.sendData.severity = 0
  elseif self.currentEvent.state == 1 then
    self.sendData.severity = 3
  elseif self.currentEvent.state == 2 then
    self.sendData.severity = 1
  elseif self.currentEvent.state == 3 then
    self.sendData.severity = 4
  end
  
  return true
end

--------------------------------------------------------------------------------
-- is_valid_storage_event: check if the storage event is valid
-- @return {table} validStorageEvent, a table of boolean indexes validating the event
--------------------------------------------------------------------------------
function EventQueue:is_valid_storage_event ()
  return true
end

--------------------------------------------------------------------------------
-- is_valid_bam_event: check if the bam event is valid
-- @return {table} validBamEvent, a table of boolean indexes validating the event
--------------------------------------------------------------------------------
function EventQueue:is_valid_bam_event ()
  return true
end

--------------------------------------------------------------------------------
-- is_valid_event: check if the event is valid
-- @return {boolean}
--------------------------------------------------------------------------------
function EventQueue:is_valid_event ()
  local validEvent = false
  self.sendData = {}
  if self.currentEvent.category == 1 then
    validEvent = self:is_valid_neb_event()
  elseif self.currentEvent.category == 3 then
    validEvent = self:is_valid_storage_event()
  elseif self.currentEvent.category == 6 then
    validEvent = self:is_valid_bam_event()
  end

  return validEvent
end

--------------------------------------------------------------------------------
-- : check if the event is associated to an accepted hostgroup
-- @return {boolean}
--------------------------------------------------------------------------------
function EventQueue:is_valid_hostgroup ()
  self.currentEvent.hostgroups = get_hostgroups(self.currentEvent.host_id)

  -- return true if option is not set
  if self.accepted_hostgroups == '' then
    return true
  end

  -- drop event if we can't find any hostgroup on the host
  if not self.currentEvent.hostgroups then
    broker_log:info(2, 'EventQueue:is_valid_hostgroup: dropping event because no hostgroup has been found for host_id: ' .. self.currentEvent.host_id)
    return false
  end

  -- check if hostgroup is in the list of the accepted one
  local retval, matchedHostgroup = find_hostgroup_in_list(split(self.accepted_hostgroups, ','), self.currentEvent.hostgroups)
  if matchedHostgroup == nil then
    broker_log:info(2, 'EventQueue:is_valid_hostgroup: no hostgroup matched provided list: ' .. self.accepted_hostgroups .. ' for host_id: ' .. self.currentEvent.host_id .. '')
  else
    broker_log:info(2, 'EventQueue:is_valid_hostgroup: host_id: ' .. self.currentEvent.host_id .. ' matched is in the following hostgroup: ' .. matchedHostgroup)
  end

  return retval
end


local queue

--------------------------------------------------------------------------------
-- init, initiate stream connector with parameters from the configuration file
-- @param {table} parameters, the table with all the configuration parameters
--------------------------------------------------------------------------------
function init (parameters)
  logfile = parameters.logfile or "/var/log/centreon-broker/connector-servicenow.log"

  if not parameters.instance or not parameters.username or not parameters.password
    or not parameters.client_id or not parameters.client_secret then
    broker_log:error(1,'Required parameters are: instance, username, password, client_id and client_secret. There type must be string')
  end

  broker_log:set_parameters(1, logfile)
  broker_log:info(1, "Parameters")
  for i,v in pairs(parameters) do
    if i == 'client_secret' or i == 'password' then
      broker_log:info(1, "Init " .. i .. " : *********")
    else
      broker_log:info(1, "Init " .. i .. " : " .. v)
    end
  end

  queue = EventQueue:new(parameters)
end

--------------------------------------------------------------------------------
-- EventQueue:add, add an event to the queue
-- @param {table} eventData, the data related to the event 
-- @return {boolean}
--------------------------------------------------------------------------------
function EventQueue:add ()
  self.events[#self.events + 1] = self.sendData
  return true
end

--------------------------------------------------------------------------------
-- EventQueue:flush, flush stored events
-- Called when the max number of events or the max age are reached
-- @return {boolean}
--------------------------------------------------------------------------------
function EventQueue:flush ()
  broker_log:info(3, "EventQueue:flush: Concatenating all the events as one string")

  retval = self:send_data()

  self.events = {}
  
  -- and update the timestamp
  self.__internal_ts_last_flush = os.time()
  return retval
end

--------------------------------------------------------------------------------
-- EventQueue:send_data, send data to external tool
-- @return {boolean}
--------------------------------------------------------------------------------
function EventQueue:send_data ()
  local data = ''
  local authToken = self:getAuthToken()
  local counter = 0

  for _, raw_event in ipairs(self.events) do
    if counter == 0 then
      data = broker.json_encode(raw_event) 
      counter = counter + 1
    else
      data = data .. ',' .. broker.json_encode(raw_event)
    end
  end

  data = '{"records":[' .. data .. ']}'
  broker_log:info(2, 'EventQueue:send_data:  creating json: ' .. data)

  if self:call(
      "api/global/em/jsonv2",
      "POST",
      data,
      authToken
    ) then
    return true
  end

  return false
end

--------------------------------------------------------------------------------
-- write,
-- @param {array} event, the event from broker
-- @return {boolean}
--------------------------------------------------------------------------------
function write (event)

  -- drop event if wrong category
  if not queue:is_valid_category(event.category) then
    return true
  end

  -- drop event if wrong element
  if not queue:is_valid_element(event.category, event.element) then
    return false
  end

  queue.currentEvent = event

  -- START FIX FOR BROKER SENDING DUPLICATED EVENTS
  -- do not compute event if it is duplicated
  if queue:is_event_duplicated() then
    return true
  end
  -- END OF FIX
  
  -- First, are there some old events waiting in the flush queue ?
  if (#queue.events > 0 and os.time() - queue.__internal_ts_last_flush > queue.max_buffer_age) then
    broker_log:info(2, "write: Queue max age (" .. os.time() - queue.__internal_ts_last_flush .. "/" .. queue.max_buffer_age .. ") is reached, flushing data")
    queue:flush()
  end

  -- Then we check that the event queue is not already full
  if (#queue.events >= queue.max_buffer_size) then
    broker_log:warning(2, "write: Queue max size (" .. #queue.events .. "/" .. queue.max_buffer_size .. ") is reached BEFORE APPENDING AN EVENT, trying to flush data before appending more events.")
    queue:flush()
  end

  -- adding event to the queue
  if queue:is_valid_event() then

    -- START FIX FOR BROKER SENDING DUPLICATED EVENTS
    -- create id from event data
    if queue.currentEvent.element == 14 then
      eventId = tostring(queue.currentEvent.host_id) .. '_' .. tostring(queue.currentEvent.last_check)
    else 
      eventId = tostring(queue.currentEvent.host_id) .. '_' .. tostring(queue.currentEvent.service_id) .. '_' .. tostring(queue.currentEvent.last_check)
    end

    -- remove oldest event from sent events list
    if #queue.validatedEvents >= queue.max_stored_events then
      table.remove(queue.validatedEvents, 1)
    end

    -- add event in the sent events list and add list to queue
    table.insert(queue.validatedEvents, eventId)
    -- END OF FIX

    queue:add()
  else
    return true
  end

  -- Then we check whether it is time to send the events to the receiver and flush
  if (#queue.events >= queue.max_buffer_size) then
    broker_log:info(2, "write: Queue max size (" .. #queue.events .. "/" .. queue.max_buffer_size .. ") is reached, flushing data")
    return queue:flush()
  end

  return true
end

--------------------------------------------------------------------------------
-- EventQueue:is_event_duplicated, create an id from the neb event and check if id is in an already sent events list
-- @return {boolean}
--------------------------------------------------------------------------------
function EventQueue:is_event_duplicated() 
  local eventId = ''
  if self.currentEvent.element == 14 then
    eventId = tostring(self.currentEvent.host_id) .. '_' .. tostring(self.currentEvent.last_check)
  else 
    eventId = tostring(self.currentEvent.host_id) .. '_' .. tostring(self.currentEvent.service_id) .. '_' .. tostring(self.currentEvent.last_check)
  end

  for i, v in ipairs(self.validatedEvents) do
    if eventId == v then
      return true
    end
  end
  
  return false
end

