#!/usr/bin/lua

--- 
-- Module to help handle events from Centreon broker
-- @module sc_event
-- @alias sc_event

local sc_event = {}

local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_params = require("centreon-stream-connectors-lib.sc_params")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")

local ScEvent = {}

function sc_event.new(event, params, common, logger, broker)
  local self = {}

  self.logger = logger
  if not self.logger then 
    self.logger = sc_logger.new()
  end
  self.sc_common = common
  self.params = params
  self.event = event
  self.sc_broker = broker

  self.event.cache = {}

  setmetatable(self, { __index = ScEvent })

  return self
end

--- is_valid_category: check if the event is in an accepted category
-- @retun true|false (boolean)
function ScEvent:is_valid_category()
  return self:find_in_mapping(self.params.category_mapping, self.params.accepted_categories, self.event.category)
end

--- is_valid_element: check if the event is an accepted element
-- @return true|false (boolean)
function ScEvent:is_valid_element()
  return self:find_in_mapping(self.params.element_mapping[self.event.category], self.params.accepted_elements, self.event.element)
end

--- find_in_mapping: check if item type is in the mapping and is accepted
-- @param mapping (table) the mapping table
-- @param reference (string)  the accepted values for the item
-- @param item (string) the item we want to find in the mapping table and in the reference
-- @return (boolean)
function ScEvent:find_in_mapping(mapping, reference, item)
  for mapping_index, mapping_value in pairs(mapping) do
    for reference_index, reference_value in pairs(self.sc_common:split(reference, ",")) do
      if item == mapping_value and mapping_index == reference_value then
        return true
      end
    end
  end

  return false
end

--- is_valid_event: check if the event is accepted depending on configured conditions
-- @return true|false (boolean) 
function ScEvent:is_valid_event()
  local is_valid_event = false
  
  -- run validation tests depending on the category of the event
  if self.event.category == 1 then
    is_valid_event = self:is_valid_neb_event()
  elseif self.event.category == 3 then
    is_valid_event = self:is_valid_storage_event()
  elseif self.event.category == 6 then
    is_valid_event = self:is_valid_bam_event()
  end

  return is_valid_event
end

--- is_valid_neb_event: check if the event is an accepted neb type event
-- @return true|false (boolean)
function ScEvent:is_valid_neb_event()
  local is_valid_event = false
  
  -- run validation tests depending on the element type of the neb event
  if self.event.element == 14 then
    is_valid_event = self:is_valid_host_status_event()
  elseif self.event.element == 24 then
    is_valid_event = self:is_valid_service_status_event()
  end

  return is_valid_event
end

--- is_valid_host_status_event: check if the host status event is an accepted one
-- @return true|false (boolean)
function ScEvent:is_valid_host_status_event()
  -- return false if we can't get hostname or host id is nil
  if not self:is_valid_host() then
    self.sc_logger:warning("[sc_event:is_valid_host_status_event]: host_id: " .. tostring(self.event.host_id) .. " hasn't been validated")
    return false
  end
  
  -- return false if event status is not accepted
  if not self:is_valid_event_status(self.params.host_status) then
    self.sc_logger:warning("[sc_event:is_valid_host_status_event]: host_id: " .. tostring(self.event.host_id) 
      .. " do not have a validated status. Status: " .. tostring(self.params.status_mapping[self.event.category][self.event.element][self.event.state]))
    return false
  end

  -- return false if one of event ack, downtime or state type (hard soft) aren't valid
  if not self:is_valid_event_states() then
    self.sc_logger:warning("[sc_event:is_valid_host_status_event]: host_id: " .. tostring(self.event.host_id) .. " is not in a validated downtime, ack or hard/soft state")
    return false
  end

  -- return false if host is not monitored from an accepted poller
  if not self:is_valid_poller() then
    self.sc_logger:warning("[sc_event:is_valid_host_status_event]: host_id: " .. tostring(self.event.host_id) .. " is not monitored from an accepted poller")
    return false
  end

  -- return false if host has not an accepted severity
  if not self:is_valid_host_severity() then
    self.sc_logger:warning("[sc_event:is_valid_host_status_event]: service id: " .. tostring(self.event.service_id) 
      .. ". host_id: " .. tostring(self.event.host_id) .. ". Host has not an accepted severity")
    return false
  end

  -- return false if host is not in an accepted hostgroup
  if not self:is_valid_hostgroup() then
    self.sc_logger:warning("[sc_event:is_valid_host_status_event]: host_id: " .. tostring(self.event.host_id) .. " is not in an accepted hostgroup")
    return false
  end
  
  return true
end

--- is_valid_service_status_event: check if the service status event is an accepted one
-- @return true|false (boolean)
function ScEvent:is_valid_service_status_event()
  -- return false if we can't get hostname or host id is nil
  if not self:is_valid_host() then
    self.sc_logger:warning("[sc_event:is_valid_service_status_event]: host_id: " .. tostring(self.event.host_id) 
      .. " hasn't been validated for service with id: " .. tostring(self.event.service_id))
    return false
  end

  -- return false if we can't get service description of service id is nil
  if not self:is_valid_service() then
    self.sc_logger:warning("[sc_event:is_valid_service_status_event]: service with id: " .. tostring(self.event.service_id) .. " hasn't been validated")
    return false
  end

  -- return false if event status is not accepted
  if not self:is_valid_event_status(self.params.service_status) then
    self.sc_logger:warning("[sc_event:is_valid_service_status_event]: service with id: " .. tostring(self.event.service_id) 
      .. " hasn't a validated status. Status: " .. tostring(self.params.status_mapping[self.event.category][self.event.element][self.event.state]))
    return false
  end

  -- return false if one of event ack, downtime or state type (hard soft) aren't valid
  if not self:is_valid_event_states() then
    self.sc_logger:warning("[sc_event:is_valid_service_status_event]: service_id: " .. tostring(self.event.service_id) .. " is not in a validated downtime, ack or hard/soft state")
    return false
  end

  -- return false if host is not monitored from an accepted poller
  if not self:is_valid_poller() then
    self.sc_logger:warning("[sc_event:is_valid_service_status_event]: service id: " .. tostring(self.event.service_id) 
      .. ". host_id: " .. tostring(self.event.host_id) .. " is not monitored from an accepted poller")
    return false
  end

  -- return false if host has not an accepted severity
  if not self:is_valid_host_severity() then
    self.sc_logger:warning("[sc_event:is_valid_service_status_event]: service id: " .. tostring(self.event.service_id) 
      .. ". host_id: " .. tostring(self.event.host_id) .. ". Host has not an accepted severity")
    return false
  end

  -- return false if service has not an accepted severity
  if not self:is_valid_service_severity() then
    self.sc_logger:warning("[sc_event:is_valid_service_status_event]: service id: " .. tostring(self.event.service_id) 
      .. ". host_id: " .. tostring(self.event.host_id) .. ". Service has not an accepted severity")
    return false
  end

  -- return false if host is not in an accepted hostgroup
  if not self:is_valid_hostgroup() then
    self.sc_logger:warning("[sc_event:is_valid_service_status_event]: service_id: " .. tostring(self.event.service_id) 
      .. " is not in an accepted hostgroup. Host ID is: " .. tostring(self.event.host_id))
    return false
  end
  
  -- return false if service is not in an accepted servicegroup 
  if not self:is_valid_servicegroup() then
    self.sc_logger:warning("[sc_event:is_valid_service_status_event]: service_id: " .. tostring(self.event.service_id) .. " is not in an accepted servicegroup")
    return false
  end

  return true
end

--- is_valid_host: check if host name and/or id are valid
-- @return true|false (boolean)
function ScEvent:is_valid_host()

  -- return false if host id is nil
  if (not self.event.host_id and self.params.skip_nil_id == 1) then
    self.sc_logger:warning("[sc_event:is_valid_host]: Invalid host with id: " .. tostring(self.event.host_id) .. " skip nil id is: " .. tostring(self.params.skip_nil_id))
    return false
  end

  self.event.cache.host = self.sc_broker:get_host_all_infos(self.event.host_id)

    -- return false if we can't get hostname
  if (not self.event.cache.host.name and self.params.skip_anon_events == 1) then
    self.sc_logger:warning("[sc_event:is_valid_host]: Invalid host with id: " .. tostring(self.event.host_id) 
      .. " host name is: " .. tostring(self.event.cache.host.name) .. " and skip anon events is: " .. tostring(self.params.skip_anon_events))
    return false
  end

  -- force host name to be its id if no name has been found
  if not self.event.cache.host.name then
    self.event.cache.host.name = self.event.cache.host.host_id or self.event.host_id
  end

  -- return false if event is coming from fake bam host
  if string.find(self.event.cache.host.name, "^_Module_BAM_*") then
    self.sc_logger:debug("[sc_event:is_valid_host]: Host is a BAM fake host: " .. tostring(self.event.cache.host.name))
    return false
  end

  return true
end

--- is_valid_service: check if service description and/or id are valid
-- @return true|false (boolean)
function ScEvent:is_valid_service()

  -- return false if service id is nil
  if (not self.event.service_id and self.params.skip_nil_id == 1) then
    self.sc_logger:warning("[sc_event:is_valid_service]: Invalid service with id: " .. tostring(self.event.service_id) .. " skip nil id is: " .. tostring(self.params.skip_nil_id))
    return false
  end

  self.event.cache.service = self.sc_broker:get_service_all_infos(self.event.host_id, self.event.service_id)

  -- return false if we can't get service description
  if (not self.event.cache.service.description and self.params.skip_anon_events == 1) then
    self.sc_logger:warning("[sc_event:is_valid_service]: Invalid service with id: " .. tostring(self.event.service_id) 
      .. " service description is: " .. tostring(self.event.cache.service.description) .. " and skip anon events is: " .. tostring(self.params.skip_anon_events))
    return false
  end

  -- force service description to its id if no description has been found
  if not self.event.cache.service.description then
    self.event.cache.service.description = service_infos.service_id or self.event.service_id
  end

  return true
end

--- is_valid_event_states: wrapper method that checks common aspect of an event such as ack and state_type
-- @return true|false (boolean)
function ScEvent:is_valid_event_states()
  -- return false if state_type (HARD/SOFT) is not valid
  if not self:is_valid_event_state_type() then
    return false
  end

  -- return false if acknowledge state is not valid
  if not self:is_valid_event_acknowledge_state() then
    return false
  end

  -- return false if downtime state is not valid
  if not self:is_valid_event_downtime_state() then
    return false
  end

  return true
end

--- is_valid_event_status: check if the event has an accepted status
-- @param accepted_status_list (string) a coma separated list of accepted status ("ok,warning,critical")
-- @return true|false (boolean)
function ScEvent:is_valid_event_status(accepted_status_list)
  for _, status_id in ipairs(self.sc_common:split(accepted_status_list, ",")) do
    if tostring(self.event.state) == status_id then 
      return true
    end
  end

  self.sc_logger:warning("[sc_event:is_valid_event_status] event has an invalid state. Current state: " 
    .. tostring(self.params.status_mapping[self.event.category][self.event.element][self.event.state]) .. ". Accepted states are: " .. tostring(accepted_status_list))
  return false
end

--- is_valid_event_state_type: check if the state type (HARD/SOFT) is accepted
-- @return true|false (boolean)
function ScEvent:is_valid_event_state_type()
  if not self.sc_common:compare_numbers(self.event.state_type, self.params.hard_only, ">=") then
    self.sc_logger:warning("[sc_event:is_valid_event_state_type]: event is not in an valid state type. Event state type must be above or equal to " .. tostring(self.params.hard_only) 
      .. ". Current state type: " .. tostring(self.event.state_type))
    return false
  end

  return true
end

--- is_valid_event_acknowledge_state: check if the acknowledge state of the event is valid
-- @return true|false (boolean)
function ScEvent:is_valid_event_acknowledge_state()
  if not self.sc_common:compare_numbers(self.params.acknowledged, self.sc_common:boolean_to_number(self.event.acknowledged), ">=") then
    self.sc_logger:warning("[sc_event:is_valid_event_acknowledge_state]: event is not in an valid ack state. Event ack state must be above or equal to " .. tostring(self.params.acknowledged) 
      .. ". Current ack state: " .. tostring(self.sc_common:boolean_to_number(self.event.acknowledged)))
    return false
  end

  return true
end

--- is_valid_event_downtime_state: check if the event is in an accepted downtime state
-- @return true|false (boolean)
function ScEvent:is_valid_event_downtime_state()
  if not self.sc_common:compare_numbers(self.params.in_downtime, self.event.scheduled_downtime_depth, ">=") then
    self.sc_logger:warning("[sc_event:is_valid_event_downtime_state]: event is not in an valid ack state. Event ack state must be above or equal to " .. tostring(self.params.acknowledged) 
      .. ". Current ack state: " .. tostring(self.sc_common:boolean_to_number(self.event.acknowledged)))
    return false
  end

  return true
end

--- is_valid_hostgroup: check if the event is in an accepted hostgroup
-- @return true|false (boolean)
function ScEvent:is_valid_hostgroup()
  -- return true if option is not set
  if self.params.accepted_hostgroups == "" then
    return true
  end

  self.event.cache.hostgroups = self.sc_broker:get_hostgroups(self.event.host_id)

  -- return false if no hostgroups were found
  if not self.event.cache.hostgroups then
    self.sc_logger:warning("[sc_event:is_valid_hostgroup]: dropping event because host with id: " .. tostring(self.event.host_id) 
      .. " is not linked to a hostgroup. Accepted hostgroups are: " .. self.params.accepted_hostgroups)
    return false
  end

  local accepted_hostgroup_name = self:find_hostgroup_in_list()

  -- return false if the host is not in a valid hostgroup
  if not accepted_hostgroup_name then
    self.sc_logger:warning("[sc_event:is_valid_hostgroup]: dropping event because host with id: " .. tostring(self.event.host_id) 
      .. " is not in an accepted hostgroup. Accepted hostgroups are: " .. self.params.accepted_hostgroups)
    return false
  else
    self.sc_logger:debug("[sc_event:is_valid_hostgroup]: event for host with id: " .. tostring(self.event.host_id)
      .. "matched hostgroup: " .. accepted_hostgroup_name)
  end

  return true
end

--- find_hostgroup_in_list: compare accepted hostgroups from parameters with the event hostgroups
-- @return accepted_name (string) the name of the first matching hostgroup 
-- @return false (boolean) if no matching hostgroup has been found
function ScEvent:find_hostgroup_in_list()
  for _, accepted_name in ipairs(self.sc_common:split(self.params.accepted_hostgroups, ",")) do
    for _, event_hostgroup in pairs(self.event.cache.hostgroups) do
      if accepted_name == event_hostgroup.group_name then
        return accepted_name
      end
    end
  end 

  return false
end

--- is_valid_servicegroup: check if the event is in an accepted servicegroup
-- @return true|false (boolean)
function ScEvent:is_valid_servicegroup()
  -- return true if option is not set
  if self.params.accepted_servicegroups == "" then
    return true
  end

  self.event.cache.servicegroups = self.sc_broker:get_servicegroups(self.event.host_id, self.event.service_id)

  -- return false if no servicegroups were found
  if not self.event.cache.servicegroups then
    self.sc_logger:debug("[sc_event:is_valid_servicegroup]: dropping event because service with id: " .. tostring(self.event.service_id) 
      .. " is not linked to a servicegroup. Accepted servicegroups are: " .. self.params.accepted_servicegroups)
    return false
  end

  local accepted_servicegroup_name = self:find_servicegroup_in_list()

  -- return false if the host is not in a valid servicegroup
  if not accepted_servicegroup_name then
    self.sc_logger:debug("[sc_event:is_valid_servicegroup]: dropping event because service with id: " .. tostring(self.event.service_id) 
      .. " is not in an accepted servicegroup. Accepted servicegroups are: " .. self.params.accepted_servicegroups)
    return false
  else
    self.sc_logger:debug("[sc_event:is_valid_servicegroup]: event for service with id: " .. tostring(self.event.service_id)
      .. "matched servicegroup: " .. accepted_servicegroup_name)
  end

  return true
end

--- find_servicegroup_in_list: compare accepted servicegroups from parameters with the event servicegroups
-- @return accepted_name or false (string|boolean) the name of the first matching servicegroup if found or false if not found
function ScEvent:find_servicegroup_in_list()
  for _, accepted_name in ipairs(self.sc_common:split(self.params.accepted_servicegroups, ",")) do
    for _, event_servicegroup in pairs(self.event.cache.servicegroups) do
      if accepted_name == event_servicegroup.group_name then
        return accepted_name
      end
    end
  end 

  return false
end

--- is_valid_bam_event: check if the event is an accepted bam type event
-- @return true|false (boolean)
function ScEvent:is_valid_bam_event()
  -- return false if ba name is invalid or ba_id is nil 
  if not self:is_valid_ba() then
    self.sc_logger:warning("[sc_event:is_valid_bam_event]: ba_id: " .. tostring(self.event.ba_id) .. " hasn't been validated")
    return false
  end

  -- return false if BA status is not accepted
  if not self:is_valid_ba_status_event() then
    self.sc_logger:warning("[sc_event:is_valid_bam_event]: ba_id: " .. tostring(self.event.ba_id) .. " has an invalid state")
    return false
  end

  -- return false if BA downtime state is not accepted
  if not self:is_valid_ba_downtime_state() then
    self.sc_logger:warning("[sc_event:is_valid_bam_event]: ba_id: " .. tostring(self.event.ba_id) .. " is not in a validated downtime state")
    return false
  end

  -- DO NOTHING FOR THE MOMENT
  if not self:is_valid_ba_acknowledge_state() then
    self.sc_logger:warning("[sc_event:is_valid_bam_event]: ba_id: " .. tostring(self.event.ba_id) .. " is not in a validated acknowledge state")
    return false
  end

  -- return false if BA is not in an accepted BV
  if not self:is_valid_bv() then
    self.sc_logger:warning("[sc_event:is_valid_bam_event]: ba_id: " .. tostring(self.event.ba_id) .. " is not in an accepted BV")
    return false
  end
  
  return true
end

--- is_valid_ba: check if ba name and/or id are valid
-- @return true|false (boolean)
function ScEvent:is_valid_ba()

  -- return false if ba_id is nil
  if (not self.event.ba_id and self.params.skip_nil_id == 1) then
    self.sc_logger:warning("[sc_event:is_valid_ba]: Invalid BA with id: " .. tostring(self.event.ba_id) .. ". And skip nil id is set to: " .. tostring(self.params.skip_nil_id))
    return false
  end

  self.event.cache.ba = self.sc_broker:get_ba_infos(self.event.ba_id)
  
  -- return false if we can't get ba name
  if (not self.event.cache.ba.ba_name and self.params.skip_anon_events == 1) then
    self.sc_logger:warning("[sc_event:is_valid_ba]: Invalid BA with id: " .. tostring(self.event.ba_id)
      .. ". Found BA name is: " .. tostring(self.event.cache.ba.ba_name) .. ". And skip anon event param is set to: " .. tostring(self.params.skip_anon_events))
    return false
  end

  -- force ba name to be its id if no name has been found
  if not self.event.cache.ba.ba_name then
    self.event.cache.ba.ba_name = self.event.cache.ba.ba_name or self.event.ba_id
  end

  return true
end

--- is_valid_ba_status_event: check if the ba status event is an accepted one
-- @return true|false (boolean)
function ScEvent:is_valid_ba_status_event()
  if not self:is_valid_event_status(self.params.ba_status) then
    self.sc_logger:warning("[sc_event:is_valid_ba]: Invalid BA status for BA id: " .. tostring(self.event.ba_id) .. ". State is: " 
      .. tostring(self.params.status_mapping[self.event.category][self.event.element][self.event.state]) .. ". Acceptes states are: " .. tostring(self.params.ba_status)) 
    return false
  end

  return true
end

--- is_valid_ba_downtime_state: check if the ba downtime state is an accepted one
-- @return true|false (boolean)
function ScEvent:is_valid_ba_downtime_state()
  if not self.sc_common:compare_numbers(self.params.in_downtime, self.sc_common:boolean_to_number(self.event.in_downtime), ">=") then
    self.sc_logger:warning("[sc_event:is_valid_ba]: Invalid BA downtime state for BA id: " .. tostring(self.event.ba_id) .. " downtime state is : " .. tostring(self.event.in_downtime) 
      .. " and accepted downtime state must be below or equal to: " .. tostring(self.params.in_downtime))
    return false
  end

  return true
end

--- is_valid_ba_acknowledge_state: check if the ba acknowledge state is an accepted one
-- @return true|false (boolean)
function ScEvent:is_valid_ba_acknowledge_state()
  -- if not self.sc_common:compare_numbers(self.params.in_downtime, self.event.in_downtime, '>=') then
  --   return false
  -- end

  return true
end

--- is_valid_bv: check if the event is in an accepted BV
-- @return true|false (boolean)
function ScEvent:is_valid_bv()
  -- return true if option is not set
  if self.params.accepted_bvs == "" then
    return true
  end

  self.event.cache.bvs = self.sc_broker:get_bvs_infos(self.event.host_id)

  -- return false if no hostgroups were found
  if not self.event.cache.bvs then
    self.sc_logger:debug("[sc_event:is_valid_bv]: dropping event because BA with id: " .. tostring(self.event.ba_id) 
      .. " is not linked to a BV. Accepted BVs are: " .. self.params.accepted_bvs)
    return false
  end

  local accepted_bv_name = self:find_bv_in_list()

  -- return false if the BA is not in a valid BV
  if not accepted_bv_name then
    self.sc_logger:debug("[sc_event:is_valid_bv]: dropping event because BA with id: " .. tostring(self.event.ba_id) 
      .. " is not in an accepted BV. Accepted BVs are: " .. self.params.accepted_bvs)
    return false
  else
    self.sc_logger:debug("[sc_event:is_valid_bv]: event for BA with id: " .. tostring(self.event.ba_id)
      .. "matched BV: " .. accepted_bv_name)
  end

  return true
end

--- find_bv_in_list: compare accepted BVs from parameters with the event BVs
-- @return accepted_name (string) the name of the first matching BV
-- @return false (boolean) if no matching BV has been found
function ScEvent:find_bv_in_list()
  for _, accepted_name in ipairs(self.sc_common:split(self.params.accepted_bvs,",")) do
    for _, event_bv in pairs(self.event.cache.bvs) do
      if accepted_name == event_bv.bv_name then
        return accepted_name
      end
    end
  end 

  return false
end

--- is_valid_poller: check if the event is monitored from an accepted poller
-- @return true|false (boolean)
function ScEvent:is_valid_poller()
  -- return true if option is not set
  if self.params.accepted_pollers == "" then
    return true
  end

  -- return false if instance id is not found in cache
  if not self.event.cache.host.instance then
    self.sc_logger:warning("[sc_event:is_valid_poller]: no instance ID found for host ID: " .. tostring(self.event.host_id))
    return false
  end

  self.event.cache.poller = self.sc_broker:get_instance(self.event.cache.host.instance)

  -- return false if no poller found in cache
  if not self.event.cache.poller then
    self.sc_logger:debug("[sc_event:is_valid_poller]: dropping event because host with id: " .. tostring(self.event.host_id) 
      .. " is not linked to an accepted poller (no poller found in cache). Accepted pollers are: " .. self.params.accepted_pollers)
    return false
  end

  local accepted_poller_name = self:find_poller_in_list()

  -- return false if the host is not monitored from a valid poller
  if not accepted_poller_name then
    self.sc_logger:debug("[sc_event:is_valid_poller]: dropping event because host with id: " .. tostring(self.event.host_id) 
      .. " is not linked to an accepted poller. Host is monitored from: " .. tostring(self.event.cache.poller) .. ". Accepted pollers are: " .. self.params.accepted_pollers)
    return false
  else
    self.sc_logger:debug("[sc_event:is_valid_poller]: event for host with id: " .. tostring(self.event.host_id)
      .. "matched poller: " .. accepted_poller_name)
  end

  return true
end

--- find_poller_in_list: compare accepted pollers from parameters with the event poller
-- @return accepted_name or false (string|boolean) the name of the first matching poller if found or false if not found
function ScEvent:find_poller_in_list()
  for _, accepted_name in ipairs(self.sc_common:split(self.params.accepted_pollers, ",")) do
    if accepted_name == self.event.cache.poller then
      return accepted_name
    end
  end 

  return false
end

--- is_valid_host_severity: checks if the host severity is accepted
-- @return true|false (boolean)
function ScEvent:is_valid_host_severity()
  -- return true if there is no severity filter
  if self.params.host_severity_threshold == nil then
    return true
  end

  -- get severity of the host from broker cache
  self.event.cache.host_severity = self.sc_broker:get_severity(self.event.host_id)

  -- return false if host severity doesn't match 
  if not self.sc_common:compare_numbers(self.params.host_severity_threshold, self.event.cache.host_severity, self.params.host_severity_operator) then
    self.sc_logger:debug("[sc_event:is_valid_host_severity]: dropping event because host with id: " .. tostring(self.event.host_id) .. " has an invalid severity. Severity is: "
      .. tostring(self.event.cache.host_severity) .. ". host_severity_threshold (" .. tostring(self.params.host_severity_threshold) .. ") is " .. self.params.host_severity_operator 
      .. " to the severity of the host (" .. tostring(self.event.cache.host_severity) .. ")")
    return false
  end

  return true
end

--- is_valid_service_severity: checks if the  service severity is accepted
-- @return true|false (boolean)
function ScEvent:is_valid_host_severity()
  -- return true if there is no severity filter
  if self.params.service_severity_threshold == nil then
    return true
  end

  -- get severity of the host from broker cache
  self.event.cache.service_severity = self.sc_broker:get_severity(self.event.host_id, self.event.service_id)

  -- return false if service severity doesn't match 
  if not self.sc_common:compare_numbers(self.params.service_severity_threshold, self.event.cache.service_severity, self.params.service_severity_operator) then
    self.sc_logger:debug("[sc_event:is_valid_service_severity]: dropping event because service with id: " .. tostring(self.event.service_id) .. " has an invalid severity. Severity is: "
      .. tostring(self.event.cache.service_severity) .. ". service_severity_threshold (" .. tostring(self.params.service_severity_threshold) .. ") is " .. self.params.service_severity_operator 
      .. " to the severity of the host (" .. tostring(self.event.cache.service_severity) .. ")")
    return false
  end

  return true
end

--- is_valid_storage: DEPRECATED method, use NEB category to get metric data instead
-- return true (boolean)
function ScEvent:is_valid_storage_event()
  return true
end

return sc_event
