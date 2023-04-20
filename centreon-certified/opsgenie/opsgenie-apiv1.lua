#!/usr/bin/lua

--------------------------------------------------------------------------------
-- Centreon Broker Opsgenie connector
-- documentation available at https://docs.centreon.com/current/en/integrations/stream-connectors/opsgenie.html
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
-- get_severity: retrieve severity from host or service
-- @param {number} host_id,
-- @param {number} [optional] service_id
-- @return {array} severity, 
--------------------------------------------------------------------------------
local function get_severity (host_id, service_id)
  local service_id = service_id or nil
  local severity = nil

  if host_id == nil then 
    broker_log:warning(1, "get_severity: host id is nil")
    return false
  end

  if service_id == nil then
    severity = broker_cache:get_severity(host_id)
  else
    severity = broker_cache:get_severity(host_id, service_id)
  end

  return severity
end

--------------------------------------------------------------------------------
-- get_ba_name: retrieve ba name from ba id
-- @param {number} ba_id,
-- @return {string} ba_name, the name of the ba
-- @return {string} ba_description, the description of the ba 
--------------------------------------------------------------------------------
local function get_ba_name (ba_id)
  if ba_id == nil then 
    broker_log:warning(1, "get_ba_name: ba id is nil")
    return false
  end

  local ba_info = broker_cache:get_ba(ba_id)
  if ba_info == nil then
    broker_log:warning(1, "get_ba_name: couldn't get ba informations in cache")
    return false
  end

  return ba_info.ba_name, ba_info.ba_description
end

--------------------------------------------------------------------------------
-- get_bvs: retrieve bv name from ba id
-- @param {number} ba_id,
-- @return {array} bv_names, the bvs' name
-- @return {array} bv_names, the bvs' description
--------------------------------------------------------------------------------
local function get_bvs (ba_id)
  if ba_id == nil then 
    broker_log:warning(1, "get_bvs: ba id is nil")
    return false
  end

  local bv_id = broker_cache:get_bvs(ba_id)

  if bv_id == nil then
    broker_log:warning(1, "get_bvs: couldn't get bvs for ba id: " .. tostring(ba_id))
    return false
  end

  local bv_names = {}
  local bv_descriptions = {}
  local bv_infos = {}

  for i, v in ipairs(bv_id) do
    bv_infos = broker_cache:get_bv(v)
    if (bv_infos.bv_name ~= nil and bv_infos.bv_name ~= '') then
      table.insert(bv_names,bv_infos.bv_name)
      -- handle nil descriptions on BV
      if bv_infos.bv_description ~= nil then
        table.insert(bv_descriptions,bv_infos.bv_description)
      else
        broker_log:info(3, 'get_bvs: BV: ' .. bv_infos.bv_name .. ' has no description')
      end
    end
  end

  return bv_names, bv_descriptions
end

--------------------------------------------------------------------------------
-- split: convert a string into a table
-- @param {string} string, the string that is going to be splitted into a table
-- @param {string} separatpr, the separator character that will be used to split the string
-- @return {table} table,
--------------------------------------------------------------------------------
local function split (text, separator)
  local hash = {}
  
  -- return empty string if text is nil
  if text == nil then
    broker_log:error(1, 'split: could not split text because it is nil')
    return ''
  end
  
  -- set default separator
  seperator = ifnil_or_empty(separator, ',')

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
-- check_event_status: check the status of an event (ok, critical...)
-- @param {number} eventStatus, the status of the event
-- @param {string} acceptedStatus, the event statuses that are going to be accepted
-- @return {boolean}
--------------------------------------------------------------------------------
local function check_event_status (eventStatus, acceptedStatuses)
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
    service_status = "0,1,2,3", -- = ok, warning, critical, unknown,
    ba_status = "0,1,2", -- = ok, warning, critical
    hard_only = 1,
    acknowledged = 0,
    element_type = "host_status,service_status,ba_status", -- could be: metric,host_status,service_status,ba_event,kpi_event" (https://docs.centreon.com/docs/centreon-broker/en/latest/dev/bbdo.html#neb)
    category_type = "neb,bam", -- could be: neb,storage,bam (https://docs.centreon.com/docs/centreon-broker/en/latest/dev/bbdo.html#event-categories)
    accepted_hostgroups = '',
    in_downtime = 0,
    max_buffer_size = 1,
    max_buffer_age = 5,
    max_stored_events = 10, -- do not use values above 100 
    skip_anon_events = 1,
    skip_nil_id = 1,
    element_mapping = {},
    category_mapping = {},
    status_mapping = {},
    proxy_address = '',
    proxy_port = '',
    proxy_username = '',
    proxy_password = '',
    validatedEvents = {},
    app_api_token = '',
    integration_api_token = '',
    api_url = 'https://api.opsgenie.com',
    date_format = '%Y-%m-%d %H:%M:%S',
    host_alert_message = '{last_update_date} {hostname} is {state}',
    host_alert_description = '',
    host_alert_alias = '{hostname}_{state}',
    service_alert_message = '{last_update_date} {hostname} // {serviceDescription} is {state}',
    service_alert_description = '',
    service_alert_alias = '{hostname}_{serviceDescription}_{state}',
    ba_incident_message = '{baName} is {state}, health level reached {level_nominal}',
    ba_incident_description = '',
    ba_incident_tags = 'centreon,applications',
    enable_incident_tags = 1,
    get_bv = 1,
    enable_severity = 0,
    priority_must_be_set = 0,
    priority_matching = 'P1=1,P2=2,P3=3,P4=4,P5=5',
    opsgenie_priorities = 'P1,P2,P3,P4,P5',
    priority_mapping = {}
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

  retval.status_mapping = {
    [1] = {},
    [3] = {},
    [6] = {}
  }

  retval.status_mapping[1][14] = {
    [0] = 'UP',
    [1] = 'DOWN',
    [2] = 'UNREACHABLE'
  }

  retval.status_mapping[1][24] = {
    [0] = 'OK',
    [1] = 'WARNING',
    [2] = 'CRITICAL',
    [3] = 'UNKNOWN'
  }

  retval.status_mapping[6][1] = {
    [0] = 'OK',
    [1] = 'WARNING',
    [2] = 'CRITICAL'
  }

  -- retval.status_mapping[14] = {
  --   [0] = 'UP',
  --   [1] = 'DOWN',
  --   [2] = 'UNREACHABLE'
  -- }

  -- retval.status_mapping[24] = {
  --   [0] = 'OK',
  --   [1] = 'WARNING',
  --   [2] = 'CRITICAL',
  --   [3] = 'UNKNOWN'
  -- }

  for i,v in pairs(conf) do
    if retval[i] then
      retval[i] = v
      if i == 'app_api_token' or i == 'integration_api_token' then
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
  retval.host_alert_message = ifnil_or_empty(retval.host_alert_message, '{last_update_date} {hostname} is {state}')
  retval.service_alert_message = ifnil_or_empty(retval.service_alert_message, '{last_update_date} {hostname} // {serviceDescription} is {state}')
  retval.enable_severity = check_boolean_number_option_syntax(retval.enable_severity, 1)
  retval.priority_must_be_set = check_boolean_number_option_syntax(retval.priority_must_be_set, 0)
  retval.priority_matching = ifnil_or_empty(retval.priority_matching, 'P1=1,P2=2,P3=3,P4=4,P5=5')
  retval.opsgenie_priorities = ifnil_or_empty(retval.opsgenie_priorities, 'P1,P2,P3,P4,P5')
  retval.host_alert_alias = ifnil_or_empty(retval.host_alert_alias, '{hostname}_{state}')
  retval.service_alert_alias = ifnil_or_empty(retval.service_alert_alias, '{hostname}_{serviceDescription}_{state}')
  retval.ba_incident_message = ifnil_or_empty(retval.ba_incident_message, '{baName} is {state}, health level reached {level_nominal}')
  retval.enable_incident_tags = check_boolean_number_option_syntax(retval.enable_incident_tags, 1)
  retval.get_bv = check_boolean_number_option_syntax(retval.get_bv, 1)

  local severity_to_priority = {}
  
  if retval.enable_severity == 1 then
    retval.priority_matching_list = split(retval.priority_matching, ',')

    for i, v in ipairs(retval.priority_matching_list) do
      severity_to_priority = split(v, '=')

      if string.match(retval.opsgenie_priorities, severity_to_priority[1]) == nil then
        broker_log:warning(1, "EventQueue.new: severity is enabled but the priority configuration is wrong. configured matching: " .. retval.priority_matching_list .. 
          ", invalid parsed priority: " .. severity_to_priority[1] .. ", known Opsgenie priorities: " .. opsgenie_priorities .. 
          ". Considere adding your priority to the opsgenie_priorities list if the parsed priority is valid")
        break
      end

      retval.priority_mapping[severity_to_priority[2]] = severity_to_priority[1]  
    end
  end

  retval.__internal_ts_last_flush = os.time()
  retval.events = {}
  setmetatable(retval, EventQueue)
  -- Internal data initialization
  broker_log:info(2, "EventQueue.new: setting the internal timestamp to " .. retval.__internal_ts_last_flush)

  return retval
end

--------------------------------------------------------------------------------
-- EventQueue:call run api call
-- @param {string} data, the data we want to send to opsgenie
-- @return {array} decoded output
-- @throw exception if http call fails or response is empty
--------------------------------------------------------------------------------
function EventQueue:call (data, url_path, token)
  method = method or "GET"
  data = data or nil

  local endpoint = self.api_url .. url_path
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

  broker_log:info(3, "Add JSON header")
  request:setopt(
    curl.OPT_HTTPHEADER,
    {
      "Accept: application/json",
      "Content-Type: application/json",
      "Authorization: GenieKey " .. token
    }
  )

  broker_log:info(3, "EventQueue:call: Add post data")
  request:setopt_postfields(data)

  broker_log:info(3, "EventQueue:call: request body " .. tostring(data))
  broker_log:info(3, "EventQueue:call: request header " .. tostring(token))
  broker_log:info(3, "EventQueue:call: Call url " .. tostring(endpoint))
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
    -- prepare api info
    self.currentEvent.endpoint = '/v2/alerts'
    self.currentEvent.token = self.integration_api_token

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

    if not self:is_valid_hostgroup() then
      return false
    end
  
    if self.enable_severity == 1 then   
      if not self:set_priority() then
        return false
      end
    end

    self.currentEvent.output = ifnil_or_empty(string.match(self.currentEvent.output, "^(.*)\n"), 'no output')
  end

  if self.currentEvent.element == 14 then

    if not check_event_status(self.currentEvent.state, self.host_status) then
      return false
    end

    self.sendData.message = self:buildMessage(self.host_alert_message, nil)
    self.sendData.description = self:buildMessage(self.host_alert_description, self.currentEvent.output)
    self.sendData.alias = self:buildMessage(self.host_alert_alias, nil)

  elseif self.currentEvent.element == 24 then
  
    self.currentEvent.serviceDescription = get_service_description(self.currentEvent.host_id, self.currentEvent.service_id)

    -- can't find service description in cache
    if self.currentEvent.serviceDescription == self.currentEvent.service_id and self.skip_anon_events == 1 then
      return false
    end
  
    if not check_event_status(self.currentEvent.state, self.service_status) then
      return false
    end

    -- can't find service_id in the event
    if self.currentEvent.serviceDescription == 0 and self.skip_nil_id == 1 then
      return false
    end

    self.sendData.message = self:buildMessage(self.service_alert_message, nil) 
    self.sendData.description = self:buildMessage(self.service_alert_description, self.currentEvent.output) 
    self.sendData.alias = self:buildMessage(self.service_alert_alias, nil)
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
-- @return {boolean} validBamEvent, a table of boolean indexes validating the event
--------------------------------------------------------------------------------
function EventQueue:is_valid_bam_event ()
  if self.currentEvent.element == 1 then
    broker_log:info(3, 'EventQueue:is_valid_bam_event: starting BA treatment 1')   
    -- prepare api info
    self.currentEvent.endpoint = '/v1/incidents/create'
    self.currentEvent.token = self.app_api_token 

    -- check if ba event status is valid
    broker_log:info(3, 'EventQueue:is_valid_bam_event: starting BA treatment 2')
    if not check_event_status(self.currentEvent.state, self.ba_status) then
      return false
    end

    self.currentEvent.baName, self.currentEvent.baDescription = get_ba_name(self.currentEvent.ba_id)

    if self.currentEvent.baName and self.currentEvent.baName ~= nil then
      if self.enable_incident_tags == 1 then
        self.currentEvent.bv_names, self.currentEvent.bv_descriptions = get_bvs(self.currentEvent.ba_id)
        self.sendData.tags = self.currentEvent.bv_names

        if ba_incident_tags ~= '' then
          local custom_tags = split(self.ba_incident_tags, ',')
          for i, v in ipairs(custom_tags) do
            broker_log:info(3, 'EventQueue:is_valid_bam_event: adding ' .. tostring(v) .. ' to the list of tags')
            table.insert(self.sendData.tags, v)
          end
        end
      end

      self.sendData.message = self:buildMessage(self.ba_incident_message, nil)
      return true
    end
  end 
  return false
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
  logfile = parameters.logfile or "/var/log/centreon-broker/connector-opsgenie.log"
  log_level = parameters.log_level or 1

  if not parameters.app_api_token or not parameters.integration_api_token then
    broker_log:error(1,'Required parameters are: api_token. There type must be string')
  end

  broker_log:set_parameters(log_level, logfile)
  broker_log:info(1, "Parameters")
  for i,v in pairs(parameters) do
    if i == 'app_api_token' or i == 'integration_api_token' then
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
  local counter = 0

  for _, raw_event in ipairs(self.events) do
    if counter == 0 then
      data = broker.json_encode(raw_event) 
      counter = counter + 1
    else
      data = data .. ',' .. broker.json_encode(raw_event)
    end
  end

  broker_log:info(2, 'EventQueue:send_data:  creating json: ' .. data)

  if self:call(data, self.currentEvent.endpoint, self.currentEvent.token) then
    return true
  end

  return false
end

--------------------------------------------------------------------------------
-- EventQueue:buildMessage, creates a message from a template
-- @param {string} template, the message template that needs to be converted
-- @param {string} default_template, a default message that will be parsed if template is empty
-- @return {string} template, the template vith converted values
--------------------------------------------------------------------------------
function EventQueue:buildMessage (template, default_template)
  if template == '' then
    template = default_template
  end

  for variable in string.gmatch(template, "{(.-)}") do
    -- converts from timestamp to human readable date
    if string.match(variable, '.-_date') then
      template = template:gsub("{" .. variable .. "}", os.date(self.date_format, self.currentEvent[variable:sub(1, -6)]))
    -- replaces numeric state value for human readable state (warning, critical...)
    elseif variable == 'state' then
      template = template:gsub("{" .. variable .. "}", self.status_mapping[self.currentEvent.category][self.currentEvent.element][self.currentEvent.state])
    else
      if self.currentEvent[variable] ~= nil then
        template = template:gsub("{" .. variable .. "}", self.currentEvent[variable])
      else
        broker_log:warning(1, "EventQueue:buildMessage: {" .. variable .. "} is not a valid template variable")
      end
    end
  end

  return template
end

--------------------------------------------------------------------------------
-- EventQueue:set_priority, set opsgenie priority using centreon severity
-- @return {boolean}
--------------------------------------------------------------------------------
function EventQueue:set_priority ()
  local severity = nil
  
  -- get host severity
  if self.currentEvent.service_id == nil then
    broker_log:info(3, "EventQueue:set_priority: getting severity for host: " .. self.currentEvent.host_id)
    severity = get_severity(self.currentEvent.host_id)
  -- get service severity
  else
    broker_log:info(3, "EventQueue:set_priority: getting severity for service: " .. self.currentEvent.service_id)
    severity = get_severity(self.currentEvent.host_id, self.currentEvent.service_id)
  end

  -- find the opsgenie priority depending on the found severity
  local matching_priority = self.priority_mapping[tostring(severity)]

  -- drop event if no severity is found and opsgenie priority must be set  
  if matching_priority == nil and self.priority_must_be_set == 1 then
    broker_log:info(3, "EventQueue:set_priority: couldn't find a matching priority for severity: " .. tostring(severity) .. " and priority is mandatory. Dropping event")
    return false
  -- ignore priority if it is not found, opsgenie will affect a default one (P3)
  elseif matching_priority == nil then
    broker_log:info(3, 'EventQueue:set_priority: could not find matching priority for severity: ' .. tostring(severity) .. '. Skipping priority...')
    return true
  else
    self.sendData.priority = matching_priority
  end

  return true
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
    if queue.currentEvent.element == 14 and queue.currentEvent.category == 1 then
      eventId = tostring(queue.currentEvent.host_id) .. '_' .. tostring(queue.currentEvent.last_check)
    elseif queue.currentEvent.element == 24 and queue.currentEvent.category == 1 then
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

