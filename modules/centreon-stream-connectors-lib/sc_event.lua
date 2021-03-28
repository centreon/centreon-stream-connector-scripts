#!/usr/bin/lua

--- 
-- Module to help handle events from Centreon broker
-- @module sc_event
-- @alias sc_event

local sc_event = {}

local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_params = require("centreon-stream-connectors-lib.sc_params")

local ScEvent = {}

function sc_event.new(event, params, common, logger)
  self.logger = logger
  self.common = common

  self.event = event
  self.event.cache = {}

  setmetatable(self, { __index = ScEvent })

  return self
end

--- is_valid_category: check if the event is in an accepted category
-- @retun true|false (boolean)
function ScEvent:is_valid_category()
  return find_in_mapping(self.params.category_mapping, self.params.accepted_categories, self.event.category)
end

--- is_valid_element: check if the event is an accepted element
-- @return true|false (boolean)
function ScEvent:is_valid_element()
  return find_in_mapping(self.params.element_mapping[self.event.cateogory], self.params.accepted_elements, self.event.element)
end

--- find_in_mapping: check if item type is in the mapping and is accepted
-- @param mapping (table) the mapping table
-- @param reference (string)  the accepted values for the item
-- @param item (string) the item we want to find in the mapping table and in the reference
-- @return (boolean)
function ScEvent:find_in_mapping (mapping, reference, item)
  for mapping_index, mapping_value in pairs(mapping) do
    for reference_index, reference_value in pairs(self.common:split(reference, ',')) do
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
    is_valid_event = self:handle_service_status_event()
  end

  return is_valid_event
end

--- is_valid_host_status_event: check if the host status event is an accepted one
-- @return true|false (boolean)
function ScEvent:is_valid_host_status_event()
  -- return false if we can't get hostname or host id is nil
  if not ScBroker:is_host_valid() then
    return false
  end
  
  -- return false if event status is not accepted
  if not self:is_valid_event_status(self.params.host_status) then
    return false
  end

  -- return false if one of event ack, downtime or state type (hard soft) aren't valid
  if not self:are_all_event_states_valid() then
    return false
  end

  -- return false if host is not in an accepted hostgroup
  if not self:is_valid_hostgroup() then
    return false
  end
  
  return true
end

--- is_valid_service_status_event: check if the service status event is an accepted one
-- @return true|false (boolean)
function ScEvent:is_valid_service_status_event()
  -- return false if we can't get hostname or host id is nil
  if not self:is_host_valid() then
    return false
  end

  -- return false if we can't get service description of service id is nil
  if not self:is_service_valid() then 
    return false
  end

  -- return false if event status is not accepted
  if not self:is_valid_event_status(self.params.service_status) then
    return false
  end

  -- return false if one of event ack, downtime or state type (hard soft) aren't valid
  if not self:are_all_event_states_valid() then
    return false
  end

  -- return false if host is not in an accepted hostgroup
  if not self:is_valid_hostgroup() then
    return false
  end
  
  -- return false if service is not in an accepted servicegroup 
  if not self:is_valid_servicegroup() then
    return false
  end

  return true
end

--- is_host_valid: check if host name and/or id are valid
-- @return true|false (boolean)
function ScBroker:is_host_valid()
  local host_infos = self.broker:get_host_all_infos(self.event.host_id)

    -- return false if we can't get hostname or host id is nil
  if (not host_infos and self.params.skip_nil_id)
    or (not host_infos.name and self.params.skip_anon_events == 1) then
    return false
  end

  -- force host name to be its id if no name has been found
  if not host_infos.name then
    self.event.cache.name = host_infos.host_id or self.event.host_id
  else
    self.event.cache = host_infos
  end

  -- return false if event is coming from fake bam host
  if string.find(self.event.name, '^_Module_BAM_*') then
    return false
  end

  return true
end

--- is_service_valid: check if service description and/or id are valid
-- @return true|false (boolean)
function ScBroker:is_service_valid()
  local service_infos = self.broker:get_service_all_infos(self.event.host_id, self.event.service_id, 'description')

  -- return false if we can't get service description or if service id is nil
  if (not service_infos and self.params.skip_nil_id)
    or (not service_infos.description and self.params.skip_anon_events == 1) then
    return false
  end

  -- force service description to its id if no description has been found
  if not service_infos.description then
    self.event.cache.description = service_infos.service_id or self.event.service_id
  else
    self.event.cache = service_infos
  end

  return true
end

--- are_all_event_states_valid: wrapper method that checks common aspect of an event such as ack and state_type
-- @return true|false (boolean)
function ScEvent:are_all_event_states_valid()
  -- return false if state_type (HARD/SOFT) is not valid
  if not self.is_valid_event_state_type() then
    return false
  end

  -- return false if acknowledge state is not valid
  if not self.is_valid_event_acknowledge_state() then
    return false
  end

  -- return false if downtime state is not valid
  if not self.is_valid_event_downtime_state() then
    return false
  end

  return true
end

--- is_valid_event_status: check if the event has an accepted status
-- @param accepted_status_list (string) a coma separated list of accepted status ("ok,warning,critical")
-- @return true|false (boolean)
function ScEvent:is_valid_event_status(accepted_status_list)
  for _, status_id in ipairs(self.common:split(accepted_status_list, ',')) do
    if tostring(self.event.state) == status_id then 
      return true
    end
  end

  return false
end

--- is_valid_event_state_type: check if the state type (HARD/SOFT) is accepted
-- @return true|false (boolean)
function ScEvent:is_valid_event_state_type()
  if not self.common:compare_numbers(self.event.state_type, self.params.hard_only, '>=') then
    return false
  end

  return true
end

--- is_valid_event_acknowledge_state: check if the acknowledge state of the event is valid
-- @return true|false (boolean)
function ScEvent:is_valid_event_acknowledge_state()
  if not self.common:compare_numbers(self.params.acknowledged, self.common:boolean_to_number(self.event.acknowledged), '>=') then
    return false
  end

  return true
end

--- is_valid_event_downtime_state: check if the event is in an accepted downtime state
-- @return true|false (boolean)
function ScEvent:is_valid_event_downtime_state()
  if not self.common:compare_numbers(self.params.in_downtime, self.event.scheduled_downtime_depth, '>=') then
    return false
  end

  return true
end

--- is_valid_hostgroup: check if the event is in an accepted hostgroup
-- @return true|false (boolean)
function ScEvent:is_valid_hostgroup()
  -- return true if option is not set
  if self.params.accepted_hostgroups == '' then
    return true
  end

  self.event.hostgroups = self.broker:get_hostgroups(self.event.host_id)

  -- return false if no hostgroups were found
  if not self.event.hostgroups then
    self.logger:debug("[sc_event:is_valid_hostgroup]: dropping event because host with id: " .. tostring(self.event.host_id) 
      .. " is not linked to a hostgroup. Accepted hostgroups are: " .. self.params.accepted_hostgroups)
    return false
  end

  local accepted_hostgroup_name = self:find_hostgroup_in_list()

  -- return false if the host is not in a valid hostgroup
  if not accepted_hostgroup_name then
    self.logger:debug("[sc_event:is_valid_hostgroup]: dropping event because host with id: " .. tostring(self.event.host_id) 
      .. " is not in an accepted hostgroup. Accepted hostgroups are: " .. self.params.accepted_hostgroups)
    return false
  else
    self.logger:debug("[sc_event:is_valid_hostgroup]: event for host with id: " .. tostring(self.event.host_id)
      .. "matched hostgroup: " .. accepted_hostgroup_name)
  end

  return true
end

--- find_hostgroup_in_list: compare accepted hostgroups from parameters with the event hostgroups
-- @return accepted_name (string) the name of the first matching hostgroup 
-- @return false (boolean) if no matching hostgroup has been found
function ScEvent:find_hostgroup_in_list()
  for _, accepted_name in ipairs(self.common:split(self.params.accepted_hostgroups, ',')) do
    for _, event_hostgroup in pairs(self.event.hostgroups) do
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
  if self.params.accepted_servicegroups == '' then
    return true
  end

  self.event.servicegroups = self.broker:get_servicegroups(self.event.host_id, self.event.service_id)

  -- return false if no servicegroups were found
  if not self.event.servicegroups then
    self.logger:debug("[sc_event:is_valid_servicegroup]: dropping event because service with id: " .. tostring(self.event.service_id) 
      .. " is not linked to a servicegroup. Accepted servicegroups are: " .. self.params.accepted_servicegroups)
    return false
  end

  local accepted_servicegroup_name = self:find_servicegroup_in_list()

  -- return false if the host is not in a valid servicegroup
  if not accepted_servicegroup_name then
    self.logger:debug("[sc_event:is_valid_servicegroup]: dropping event because service with id: " .. tostring(self.event.service_id) 
      .. " is not in an accepted servicegroup. Accepted servicegroups are: " .. self.params.accepted_servicegroups)
    return false
  else
    self.logger:debug("[sc_event:is_valid_servicegroup]: event for service with id: " .. tostring(self.event.service_id)
      .. "matched servicegroup: " .. accepted_servicegroup_name)
  end

  return true
end

--- find_servicegroup_in_list: compare accepted servicegroups from parameters with the event servicegroups
-- @return accepted_name or false (string|boolean) the name of the first matching servicegroup if found or false if not found
function ScEvent:find_servicegroup_in_list()
  for _, accepted_name in ipairs(self.common:split(self.params.accepted_servicegroups, ',')) do
    for _, event_servicegroup in pairs(self.event.servicegroups) do
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
  if not self:is_ba_valid() then
    return false
  end

  -- return false if BA status is not accepted
  if not self:is_valid_ba_status_event() then
    return false
  end

  -- return false if BA downtime state is not accepted
  if not self:is_valid_ba_downtime_state() then
    return false
  end

  -- DO NOTHING FOR THE MOMENT
  if not self:is_valid_ba_acknowledge_state() then
    return false
  end

  -- return false if BA is not in an accepted BV
  if not self:is_valid_bv() then
    return false
  end
  
  return true
end

--- is_ba_valid: check if ba name and/or id are valid
-- @return true|false (boolean)
function ScBroker:is_ba_valid()
  self.event.name, self.event.description = self.broker:get_ba_infos(self.event.ba_id)

  -- return false if we can't get ba name or ba id is nil
  if (not self.event.name and self.params.skip_nil_id)
    or (not self.event.name and self.params.skip_anon_events == 1) then
    return false
  end

  -- force ba name to be its id if no name has been found
  if not self.event.name then
    self.event.name = self.event.name or self.event.ba_id
  end

  return true
end

--- is_valid_ba_status_event: check if the ba status event is an accepted one
-- @return true|false (boolean)
function ScEvent:is_valid_ba_status_event()
  if not self:is_valid_event_status(self.params.ba_status) then
    return false
  end

  return true
end

--- is_valid_ba_downtime_state: check if the ba downtime state is an accepted one
-- @return true|false (boolean)
function ScEvent:is_valid_ba_downtime_state()
  if not self.common:compare_numbers(self.params.in_downtime, self.event.in_downtime, '>=') then
    return false
  end

  return true
end

--- is_valid_ba_acknowledge_state: check if the ba acknowledge state is an accepted one
-- @return true|false (boolean)
function ScEvent:is_valid_ba_acknowledge_state()
  -- if not self.common:compare_numbers(self.params.in_downtime, self.event.in_downtime, '>=') then
  --   return false
  -- end

  return true
end

--- is_valid_bv: check if the event is in an accepted BV
-- @return true|false (boolean)
function ScEvent:is_valid_bv()
  -- return true if option is not set
  if self.params.accepted_bv == '' then
    return true
  end

  self.event.bvs = self.broker:get_hostgroups(self.event.host_id)

  -- return false if no hostgroups were found
  if not self.event.bvs then
    self.logger:debug("[sc_event:is_valid_bv]: dropping event because BA with id: " .. tostring(self.event.ba_id) 
      .. " is not linked to a BV. Accepted BVs are: " .. self.params.accepted_bvs)
    return false
  end

  local accepted_bv_name = self:find_bv_in_list()

  -- return false if the BA is not in a valid BV
  if not accepted_bv_name then
    self.logger:debug("[sc_event:is_valid_bv]: dropping event because BA with id: " .. tostring(self.event.ba_id) 
      .. " is not in an accepted BV. Accepted BVs are: " .. self.params.accepted_bvs)
    return false
  else
    self.logger:debug("[sc_event:is_valid_bv]: event for BA with id: " .. tostring(self.event.ba_id)
      .. "matched BV: " .. accepted_bv_name)
  end

  return true
end

--- find_bv_in_list: compare accepted BVs from parameters with the event BVs
-- @return accepted_name (string) the name of the first matching BV
-- @return false (boolean) if no matching BV has been found
function ScEvent:find_bv_in_list()
  for _, accepted_name in ipairs(self.common:split(self.params.accepted_bvs, ',')) do
    for _, event_bv in pairs(self.event.bvs) do
      if accepted_name == event_bv.bv_name then
        return accepted_name
      end
    end
  end 

  return false
end

--- is_valid_storage: DEPRECATED method, use NEB category to get metric data instead
-- return true (boolean)
function ScEvent:is_valid_storage_event()
  return true
end

return sc_event
