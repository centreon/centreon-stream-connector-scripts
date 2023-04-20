#!/usr/bin/lua

-- libraries 
local curl = require "cURL"
local base64 = require("base64")

-- Global variables

-- Useful functions

--------------------------------------------------------------------------------
-- ifnil_or_empty: change a nil or empty variable for a specified value
-- @param var, the variable that needs to be checked
-- @param alt, the value of the variable if it is nil or empty
-- @return alt|var, the alternate value or the variable value
--------------------------------------------------------------------------------
local function ifnil_or_empty (var, alt)
  if var == nil or var == '' then
    return alt
  else
    return var
  end
end


--------------------------------------------------------------------------------
-- ifnumber_not_nan: check if a number is a number (and not a NaN)
-- @param {number} number, the number to check
-- @return {boolean}
--------------------------------------------------------------------------------
local function ifnumber_not_nan (number)
  if (number ~= number) then
    return false
  elseif (type(number) ~= 'number') then
    return false
  else
    return true
  end
end

--------------------------------------------------------------------------------
-- convert_to_openmetric: replace unwanted characters in order to comply with the open metrics format
-- @param {string} string, the string to convert
-- @return {string} string, a string that matches [a-zA-Z0-9_\.]+
--------------------------------------------------------------------------------
local function convert_to_openmetric (string)
  if string == nil or string == '' or type(string) ~= 'string' then
    return false
  end

  return string.gsub(string, '[^a-zA-Z0-9_:]', '_')
end

--------------------------------------------------------------------------------
-- unit_mapping: convert perfdata units to openmetrics standard
-- @param {string} unit, the unit value
-- @return {string} unit, the openmetrics unit name
-- @reuturn {boolean}, true if the unit is found in the mapping or empty
--------------------------------------------------------------------------------
local function unit_mapping (unit)
  local unitMapping = {
    s = 'seconds',
    m = 'meters',
    B = 'bytes',
    g = 'grams',
    V = 'volts',
    A = 'amperes',
    K = 'kelvins',
    ratio = 'ratios',
    degres = 'celsius'
  }

  local unhandledUnit = nil

  if unit == nil or unit == '' or type(unit) ~= 'string' then
    unit = ''
  end

  if unit == '%' then 
    unit = unitMapping['ratio']
  elseif unit == '°' then
    unit = unitMapping['degres']
  else
    if (unitMapping[unit] ~= nil) then
      unit = unitMapping[unit]
    end
  end

  return unit, true
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
    broker_log:warning(1, "get_hostgroups: no hostgroup for host id " .. host_id .. " found.")
    return false
  end
  
  return hostgroups
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
    hard_only = 0,
    acknowledged = 1,
    element_type = "service_status", -- could be: metric,host_status,service_status,ba_event,kpi_event" (https://docs.centreon.com/docs/centreon-broker/en/latest/dev/bbdo.html#neb)
    category_type = "storage", -- could be: neb,storage,bam (https://docs.centreon.com/docs/centreon-broker/en/latest/dev/bbdo.html#event-categories)
    accepted_hostgroups = '',
    in_downtime = 1,
    max_buffer_size = 1,
    max_buffer_age = 5,
    skip_anon_events = 1,
    skip_nil_id = 1,
    enable_threshold_metrics = 0,
    enable_status_metrics = 0,
    disable_bam_host = 1,
    add_hostgroups = 1,
    enable_extended_metric_name = 0,
    prometheus_gateway_address = 'http://localhost',
    prometheus_gateway_port = '9091',
    prometheus_gateway_job = 'monitoring',
    http_timeout = 60,
    proxy_address = '',
    proxy_port = '',
    proxy_username = '',
    proxy_password = '',
    current_event = nil,
    element_mapping = {},
    category_mapping = {}
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

  for i,v in pairs(conf) do
    if retval[i] then
      retval[i] = v
      broker_log:info(1, "EventQueue.new: getting parameter " .. i .. " => " .. v)
    else
      broker_log:info(1, "EventQueue.new: ignoring unhandled parameter " .. i .. " => " .. v)
    end
  end

  retval.hard_only = check_boolean_number_option_syntax(retval.hard_only, 1)
  retval.acknowledged = check_boolean_number_option_syntax(retval.acknowledged, 0)
  retval.in_downtime = check_boolean_number_option_syntax(retval.in_downtime, 0)
  retval.skip_anon_events = check_boolean_number_option_syntax(retval.skip_anon_events, 1)
  retval.skip_nil_id = check_boolean_number_option_syntax(retval.skip_nil_id, 1)
  retval.enable_threshold_metrics = check_boolean_number_option_syntax(retval.enable_threshold_metrics, 1)
  retval.enable_status_metrics = check_boolean_number_option_syntax(retval.enable_status_metrics, 1)
  retval.disable_bam_host = check_boolean_number_option_syntax(retval.disable_bam_host, 1)
  retval.enable_extended_metric_name = check_boolean_number_option_syntax(retval.enable_extended_metric_name, 0)
  retval.add_hostgroups = check_boolean_number_option_syntax(retval.add_hostgroups, 1)

  retval.__internal_ts_last_flush = os.time()
  retval.events = {}
  setmetatable(retval, EventQueue)
  -- Internal data initialization
  broker_log:info(2, "EventQueue.new: setting the internal timestamp to " .. retval.__internal_ts_last_flush)

  return retval
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
-- @param {table} event, the event data
-- @return {table} validNebEvent, a table of boolean indexes validating the event
--------------------------------------------------------------------------------
function EventQueue:is_valid_neb_event ()
  if self.current_event.element == 14 or self.current_event.element == 24 then
    self.current_event.hostname = get_hostname(self.current_event.host_id)

    -- can't find hostname in cache
    if self.current_event.hostname == self.current_event.host_id and self.skip_anon_events == 1 then
      return false
    end

    -- can't find host_id in the event
    if self.current_event.hostname == 0 and self.skip_nil_id == 1 then
      return false
    end

    -- host is a BA
    if (string.find(tostring(self.current_event.hostname), '_Module_BAM_') and self.disable_bam_host == 1) then
      return false
    end

    self.current_event.hostname = tostring(self.current_event.hostname)

    -- output isn't required, we only need perfdatas
    -- self.current_event.output = ifnil_or_empty(string.match(self.current_event.output, "^(.*)\n"), 'no output')
  end

  if self.current_event.element == 14 then
    if not check_neb_event_status(self.current_event.state, self.host_status) then
      return false
    end
  elseif self.current_event.element == 24 then
    self.current_event.service_description = get_service_description(self.current_event.host_id, self.current_event.service_id)
    
    -- can't find service description in cache
    if self.current_event.service_description == self.current_event.service_id and self.skip_anon_events == 1 then
      return false
    end
    
    if not check_neb_event_status(self.current_event.state, self.service_status) then
      return false
    end

    -- can't find service_id in the event
    if self.current_event.service_description == 0 and self.skip_nil_id == 1 then
      return false
    end
  end

  -- check hard state
  if not compare_numbers(self.current_event.state_type, self.hard_only, '>=') then
    return false
  end

  -- check ack
  if not compare_numbers(self.acknowledged, boolean_to_number(self.current_event.acknowledged), '>=') then
    return false
  end
  
  -- check downtime
  if not compare_numbers(self.in_downtime, self.current_event.scheduled_downtime_depth, '>=') then
    return false
  end

  self.current_event.service_description = tostring(self.current_event.service_description)

  if not self:is_valid_hostgroup() then
    return false
  end

  return true
end

--------------------------------------------------------------------------------
-- is_valid_storage_event: check if the storage event is valid
-- @param {table} event, the event data
-- @return {table} validStorageEvent, a table of boolean indexes validating the event
--------------------------------------------------------------------------------
function EventQueue:is_valid_storage_event ()
  return true
end

--------------------------------------------------------------------------------
-- is_valid_bam_event: check if the bam event is valid
-- @param {table} event, the event data
-- @return {table} validBamEvent, a table of boolean indexes validating the event
--------------------------------------------------------------------------------
function EventQueue:is_valid_bam_event ()
  return true
end

--------------------------------------------------------------------------------
-- is_valid_event: check if the event is valid
-- @param {table} event, the event data
-- @return {boolean}
--------------------------------------------------------------------------------
function EventQueue:is_valid_event ()
  local validEvent = false
  
  if self.current_event.category == 1 then
    validEvent = self:is_valid_neb_event()
  elseif self.current_event.category == 3 then
    validEvent = self:is_valid_storage_event()
  elseif self.current_event.category == 6 then
    validEvent = self:is_valid_bam_event()
  end

  return validEvent
end

 --------------------------------------------------------------------------------
  -- is_valid_hostgroup: check if the event is associated to an accepted hostgroup
  -- @return {boolean}
  --------------------------------------------------------------------------------
function EventQueue:is_valid_hostgroup ()
  self.current_event.hostgroups = get_hostgroups(self.current_event.host_id)
  
  -- return true if option is not set
  if self.accepted_hostgroups == '' then
    return true
  end

  -- drop event if we can't find any hostgroup on the host
  if not self.current_event.hostgroups then
    broker_log:info(2, 'EventQueue:is_valid_hostgroup: dropping event because no hostgroup has been found for host_id: ' .. self.current_event.host_id)
    return false
  end

  -- check if hostgroup is in the list of the accepted one
  local retval, matchedHostgroup = find_hostgroup_in_list(split(self.accepted_hostgroups, ','), self.current_event.hostgroups)

  if matchedHostgroup == nil then
    broker_log:info(2, 'EventQueue:is_valid_hostgroup: no hostgroup matched provided list: ' .. self.accepted_hostgroups .. ' for host_id: ' .. self.current_event.host_id .. '')
  else
    broker_log:info(2, 'EventQueue:is_valid_hostgroup: host_id: ' .. self.current_event.host_id .. ' matched is in the following hostgroup: ' .. matchedHostgroup)
  end

  return retval
end


--------------------------------------------------------------------------------
-- display_hostgroups: create the hostgroup label for the metric
-- @return {string} hostgroupLabel: the full label for the metric
--------------------------------------------------------------------------------
function EventQueue:display_hostgroups ()
  if not self.current_event.hostgroups then
    return false
  end

  local hostgroupLabel = 'hostgroup="'
  local counter = 0

  for i, v in pairs(self.current_event.hostgroups) do
    if counter == 0 then
      hostgroupLabel = hostgroupLabel .. v.group_name
      counter = 1
    else
      hostgroupLabel = hostgroupLabel .. ',' .. v.group_name
    end
  end

  hostgroupLabel = hostgroupLabel .. '"'

  return hostgroupLabel
end


--------------------------------------------------------------------------------
-- format_data: prepare the event data so it can be sent
-- @return {table|string|number} data, the formated data
--------------------------------------------------------------------------------
function EventQueue:format_data ()
  local perf, error = broker.parse_perfdata(self.current_event.perfdata, true)
  local type = nil
  local data = ''
  local name = nil
  local unit = nil

  -- handle hostgroups
  if self.add_hostgroups == 1 then
    self.current_event.hostgroupsLabel = self:display_hostgroups()
  else
    self.current_event.hostgroupsLabel = false
  end

  for label, metric in pairs(perf) do
    type = self:get_metric_type(metric)
    unit= unit_mapping(metric.uom)
    name = self:create_metric_name(label, unit)
    

    data = data .. '# TYPE ' .. name .. ' ' .. type .. '\n'
    data = data .. self:add_unit_info(label, unit, name)
    
    if not self.current_event.hostgroupsLabel then
      data = data .. name .. '{label="' .. label .. '", host="' .. self.current_event.hostname .. '", service="' .. self.current_event.service_description .. '"} ' .. metric.value .. '\n'
    else
      data = data .. name .. '{label="' .. label .. '", host="' .. self.current_event.hostname .. '", service="' .. self.current_event.service_description .. '", ' ..  self.current_event.hostgroupsLabel .. '} ' .. metric.value .. '\n'
    end

    if (self.enable_threshold_metrics == 1) then 
      data = data .. self:threshold_metrics(metric, label, unit, type)
    end 
  end

  if (self.enable_status_metrics == 1) then
    name = convert_to_openmetric(self.current_event.hostname .. '_' .. self.current_event.service_description .. ':' .. label .. ':monitoring_status')
    data = data .. '# TYPE ' .. name .. ' counter\n'
    data = data .. '# HELP ' .. name .. ' 0 is OK, 1 is WARNING, 2 is CRITICAL, 3 is UNKNOWN\n'
    if not self.current_event.hostgroupsLabel then
      data = data .. name .. '{label="monitoring_status", host="' .. self.current_event.hostname .. '", service="' .. self.current_event.service_description .. '"} ' .. self.current_event.state .. '\n'
    else
      data = data .. name .. '{label="monitoring_status", host="' .. self.current_event.hostname .. '", service="' .. self.current_event.service_description .. '", ' ..  self.current_event.hostgroupsLabel .. '} ' .. self.current_event.state .. '\n'
    end
  end

  return data
end

--------------------------------------------------------------------------------
-- create_metric_name: concatenates data to create the metric name
-- @param {string} label, the name of the perfdata
-- @param {string} unit, the unit name
-- @return {string} name, the prometheus metric name (open metric format)
--------------------------------------------------------------------------------
function EventQueue:create_metric_name (label, unit)
  local name = ''

  if (unit ~= '') then
    if (self.enable_extended_metric_name == 0) then
      name = label .. '_' .. unit
    else
      name = self.current_event.hostname .. '_' .. self.current_event.service_description .. ':' .. label .. '_' .. unit
    end
  else
    if (self.enable_extended_metric_name == 0) then
      name = label
    else
      name = self.current_event.hostname .. '_' .. self.current_event.service_description .. ':' .. label
    end 
  end

  return convert_to_openmetric(name)
end
--------------------------------------------------------------------------------
-- get_metric_type: find out the metric type to match openmetrics standard
-- @param {table} perfdata, the perfdata informations
-- @return {string} metricType, the type of the metric
--------------------------------------------------------------------------------
function EventQueue:get_metric_type (perfdata)
  local metricType = nil;
  if (ifnumber_not_nan(perfdata.max)) then
    metricType = 'gauge'
  else 
    metricType = 'counter'
  end
  
  return metricType
end

--------------------------------------------------------------------------------
-- add_unit_info: add unit metadata to match openmetrics standard
-- @param {string} label, the name of the metric
-- @param {string} unit, the unit name
-- @param {string} name, the name of the metric
-- @return {string} data, the unit metadata information
--------------------------------------------------------------------------------
function EventQueue:add_unit_info (label, unit, name)
  local data = ''

  if (unit ~= '' and unit ~= nil) then
      data = '# UNIT ' .. name .. '\n'
  end

  return data
end

--------------------------------------------------------------------------------
-- add_type_info: add unit metadata to match openmetrics standard
-- @param {string} label, the name of the metric
-- @param {string} unit, the unit name
-- @param {string} suffix, a suffix that is part of the metric name
-- @return {string} name, the full metric name (open metric format)
--------------------------------------------------------------------------------
function EventQueue:add_type_info (label, unit, suffix)
  return self:create_metric_name(label, unit) .. '_' .. suffix
end

--------------------------------------------------------------------------------
-- threshold_metrics: create openmetrics metrics based on alert thresholds from centreon
-- @param {table} perfdata, perfdata informations
-- @param {string} label, the name of the metric
-- @param {string} unit, the unit name
-- @param {string} type, the type of unit (counter, gauge...)
-- @return {string} data, metrics based on alert thresholds
--------------------------------------------------------------------------------
function EventQueue:threshold_metrics (perfdata, label, unit, type)
  local data = ''
  local metricName = nil

  if (ifnumber_not_nan(perfdata.warning_low)) then
    metricName = self:add_type_info(label, unit, 'warning_low')
    message = 'values below this will trigger a warning alert\n'
    data = data .. self:threshold_metrics_format(metricName, label, unit, type, message, perfdata.warning_low)
  end

  if (ifnumber_not_nan(perfdata.warning_high)) then
    metricName = self:add_type_info(label, unit, 'warning_high')
    message = 'alues above this will trigger a warning alert\n'
    data = data .. self:threshold_metrics_format(metricName, label, unit, type, message, perfdata.warning_high)
  end

  if (ifnumber_not_nan(perfdata.critical_low)) then
    metricName = self:add_type_info(label, unit, 'critical_low')
    message = 'values below this will trigger a critical alert\n'
    data = data .. self:threshold_metrics_format(metricName, label, unit, type, message, perfdata.critical_low)
  end

  if (ifnumber_not_nan(perfdata.critical_high)) then
    metricName = self:add_type_info(label, unit, 'critical_high')
    message = 'values above this will trigger a critical alert\n'
    data = data .. self:threshold_metrics_format(metricName, label, unit, type, message, perfdata.critical_high)
  end

  return data
end

--------------------------------------------------------------------------------
-- threshold_metrics_format: create data format for threshold metrics
-- @param {string} metricName, the formated metric name
-- @param {string} label, the name of the metric
-- @param {string} unit, the unit name
-- @param {string} type, the type of unit (counter, gauge...)
-- @return {string} data, metrics based on alert thresholds
--------------------------------------------------------------------------------
function EventQueue:threshold_metrics_format (metricName, label, unit, type, message, perfdata)
  local data = ''

  data = data .. '# TYPE ' .. metricName .. ' ' .. type .. '\n'
  data = data .. '# UNIT ' .. metricName .. ' ' .. unit .. '\n'
  data = data .. '# HELP ' .. metricName .. ' ' .. message

  if not self.current_event.hostgroupsLabel then
    data = data .. metricName .. '{label="' .. label .. '", host="' .. self.current_event.hostname .. '", service="' .. self.current_event.service_description .. '"} ' .. perfdata .. '\n'
  else
    data = data .. metricName .. '{label="' .. label .. '", host="' .. self.current_event.hostname .. '", service="' .. self.current_event.service_description .. '",' .. self.current_event.hostgroupsLabel .. '"} ' .. perfdata .. '\n'
  end

  return data
end

local queue

--------------------------------------------------------------------------------
-- init, initiate stream connector with parameters from the configuration file
-- @param {table} parameters, the table with all the configuration parameters
--------------------------------------------------------------------------------
function init (parameters)
  logfile = parameters.logfile or "/var/log/centreon-broker/connector-prometheus-gateway.log"
  broker_log:set_parameters(1, logfile)
  broker_log:info(1, "Parameters")
  for i,v in pairs(parameters) do
    broker_log:info(1, "Init " .. i .. " : " .. v)
  end

  queue = EventQueue:new(parameters)
end

--------------------------------------------------------------------------------
-- EventQueue:add, add an event to the queue
-- @param {table} event, the event that will be added to the queue
-- @return {boolean}
--------------------------------------------------------------------------------
function EventQueue:add (data)
  self.events[#self.events + 1] = data
  return true
end

--------------------------------------------------------------------------------
-- EventQueue:flush, flush stored events
-- Called when the max number of events or the max age are reached
-- @return {boolean}
--------------------------------------------------------------------------------
function EventQueue:flush ()
  broker_log:info(3, "EventQueue:flush: Concatenating all the events as one string")

  if not self:send_data() then
    broker_log:error(1, "EventQueue:flush: couldn't send data, flushing data anyway")
  end

  self.events = {}
    
  -- and update the timestamp
  self.__internal_ts_last_flush = os.time()

  return true
end

--------------------------------------------------------------------------------
-- EventQueue:send_data, send data to external tool
-- @return {boolean}
--------------------------------------------------------------------------------
function EventQueue:send_data ()
  local httpPostData = ''

  for _, raw_event in ipairs(self.events) do
    httpPostData = httpPostData .. raw_event
  end

  local httpResponseBody = ""
  local httpRequest = curl.easy()
    :setopt_url(self.prometheus_gateway_address .. ':' .. self.prometheus_gateway_port .. '/metrics/job/' .. self.prometheus_gateway_job .. '/instance/' .. self.current_event.hostname .. '/service@base64/' .. base64.encode(self.current_event.service_description))
    :setopt_writefunction(
      function (response)
        httpResponseBody = httpResponseBody .. tostring(response)
      end
    )
    :setopt(curl.OPT_TIMEOUT, self.http_timeout)
    :setopt(
      curl.OPT_HTTPHEADER,
      {
        "content-type: application/openmetrics-text"
      }
    )
  
  -- set proxy address configuration
  if (self.proxy_address ~= '') then
    if (self.proxy_port ~= '') then
      httpRequest:setopt(curl.OPT_PROXY, self.proxy_address .. ':' .. self.proxy_port)
    else 
      broker_log:error(1, "EventQueue:send_data: proxy_port parameter is not set but proxy_address is used")
    end
  end

  -- set proxy user configuration
  if (self.proxy_username ~= '') then
    if (self.proxy_password ~= '') then
      httpRequest:setopt(curl.OPT_PROXYUSERPWD, self.proxy_username .. ':' .. self.proxy_password)
    else
      broker_log:error(1, "EventQueue:send_data: proxy_password parameter is not set but proxy_username is used")
    end
  end

  -- adding the HTTP POST data
  broker_log:info(3, "EventQueue:send_data: POST data: '" .. httpPostData .. "'")
  httpRequest:setopt_postfields(httpPostData)

  -- performing the HTTP request
  httpRequest:perform()

  -- collecting results
  httpResponseCode = httpRequest:getinfo(curl.INFO_RESPONSE_CODE) 

  httpRequest:close()

  -- Handling the return code
  local retval = false
  if httpResponseCode == 200 then
    broker_log:info(2, "EventQueue:send_data: HTTP POST request successful: return code is " .. httpResponseCode)
    -- now that the data has been sent, we empty the events array
    self.events = {}
    retval = true
  else
    broker_log:error(1, "the body request " .. httpPostData)
    broker_log:error(1, "EventQueue:send_data: HTTP POST request FAILED, return code is " .. httpResponseCode .. " message is:\n\"" .. httpResponseBody .. "\n\"\n")
  end

  -- and update the timestamp
  self.__internal_ts_last_flush = os.time()
  return retval
end

--------------------------------------------------------------------------------
-- write, 
-- @param {array} event, the event from broker
-- @return {boolean}
--------------------------------------------------------------------------------
function write (event)
  queue.current_event = event

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

  if not queue:is_valid_category(event.category) then
    broker_log:info(3, 'write: event category is ' .. event.category .. ' and is not valid')
    return true
  end

  if not queue:is_valid_element(event.category, event.element) then
    broker_log:info(3, 'write: event element is ' .. event.element .. ' and is not valid')
    return true
  end

  -- adding event to the queue
  if queue:is_valid_event() then
    queue:add(queue:format_data())
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

