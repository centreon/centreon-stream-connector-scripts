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

  self.sc_logger = logger
  if not self.sc_logger then 
    self.sc_logger = sc_logger.new()
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
  if self.event.category == self.params.bbdo.categories.neb.id then
    is_valid_event = self:is_valid_neb_event()
  elseif self.event.category == self.params.bbdo.categories.storage.id then
    is_valid_event = self:is_valid_storage_event()
  elseif self.event.category == self.params.bbdo.categories.bam.id then
    is_valid_event = self:is_valid_bam_event()
  end

  return is_valid_event
end

--- is_valid_neb_event: check if the event is an accepted neb type event
-- @return true|false (boolean)
function ScEvent:is_valid_neb_event()
  local is_valid_event = false
  
  -- run validation tests depending on the element type of the neb event
  if self.event.element == self.params.bbdo.elements.host_status.id then
    is_valid_event = self:is_valid_host_status_event()
  elseif self.event.element == self.params.bbdo.elements.service_status.id then
    is_valid_event = self:is_valid_service_status_event()
  elseif self.event.element == self.params.bbdo.elements.acknowledgement.id then 
    is_valid_event = self:is_valid_acknowledgement_event()
  elseif self.event.element == self.params.bbdo.elements.downtime.id then
    is_valid_event = self:is_valid_downtime_event()
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

  -- return false if event status is a duplicate and dedup is enabled 
  if self:is_host_status_event_duplicated() then
    self.sc_logger:warning("[sc_event:is_host_status_event_duplicated]: host_id: " .. tostring(self.event.host_id)
      .. " is sending a duplicated event. Dedup option (enable_host_status_dedup) is set to: " .. tostring(self.params.enable_host_status_dedup))
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
    self.sc_logger:warning("[sc_event:is_valid_host_status_event]: host_id: " .. tostring(self.event.host_id) .. " has not an accepted severity")
    return false
  end

  -- return false if host is not in an accepted hostgroup
  if not self:is_valid_hostgroup() then
    self.sc_logger:warning("[sc_event:is_valid_host_status_event]: host_id: " .. tostring(self.event.host_id) .. " is not in an accepted hostgroup")
    return false
  end
  
  self:build_outputs()

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

  -- return false if event status is a duplicate and dedup is enabled 
  if self:is_service_status_event_duplicated() then
    self.sc_logger:warning("[sc_event:is_service_status_event_duplicated]: host_id: " .. tostring(self.event.host_id)
      .. " service_id: " .. tostring(self.event.service_id) .. " is sending a duplicated event. Dedup option (enable_service_status_dedup) is set to: " .. tostring(self.params.enable_service_status_dedup))
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

  self:build_outputs()

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
  if (not self.event.cache.host and self.params.skip_anon_events == 1) then
    self.sc_logger:warning("[sc_event:is_valid_host]: No name for host with id: " .. tostring(self.event.host_id) 
      .. " and skip anon events is: " .. tostring(self.params.skip_anon_events))
    return false
  elseif (not self.event.cache.host and self.params.skip_anon_events == 0) then
    self.event.cache.host = {
      name = self.event.host_id
    }
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
  if (not self.event.cache.service and self.params.skip_anon_events == 1) then
    self.sc_logger:warning("[sc_event:is_valid_service]: Invalid description for service with id: " .. tostring(self.event.service_id) 
      .. " and skip anon events is: " .. tostring(self.params.skip_anon_events))
    return false
  elseif (not self.event.cache.service and self.params.skip_anon_events == 0) then
    self.event.cache.service = {
      description = self.event.service_id
    }
  end

  -- force service description to its id if no description has been found
  if not self.event.cache.service.description then
    self.event.cache.service.description = self.event.service_id
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
  local status_list = self.sc_common:split(accepted_status_list, ",")
  
  if not status_list then
    self.sc_logger:error("[sc_event:is_valid_event_status]: accepted_status list is nil or empty")
    return false
  end

  -- start compat patch bbdo2 => bbdo 3
  if (not self.event.state and self.event.current_state) then
    self.event.state = self.event.current_state
  end

  if (not self.event.current_state and self.event.state) then
    self.event.current_state = self.event.state
  end
  -- end compat patch

  for _, status_id in ipairs(status_list) do
    if tostring(self.event.state) == status_id then 
      return true
    end
  end

  -- handle downtime event specific case for logging
  if (self.event.category == self.params.bbdo.categories.neb.id and self.event.element == self.params.bbdo.elements.downtime.id) then
    self.sc_logger:warning("[sc_event:is_valid_event_status] event has an invalid state. Current state: " 
      .. tostring(self.params.status_mapping[self.event.category][self.event.element][self.event.type][self.event.state]) .. ". Accepted states are: " .. tostring(accepted_status_list))
    return false
  end

  -- log for everything else
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
  -- compat patch bbdo 3 => bbdo 2
  if (not self.event.acknowledged and self.event.acknowledgement_type) then
    if self.event.acknowledgement_type >= 1 then
      self.event.acknowledged = true
    else
      self.event.acknowledged = false
    end
  end

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
  -- patch compat bbdo 3 => bbdo 2 
  if (not self.event.scheduled_downtime_depth and self.event.downtime_depth) then 
    self.event.scheduled_downtime_depth = self.event.downtime_depth
  end

  if not self.sc_common:compare_numbers(self.params.in_downtime, self.event.scheduled_downtime_depth, ">=") then
    self.sc_logger:warning("[sc_event:is_valid_event_downtime_state]: event is not in an valid downtime state. Event downtime state must be above or equal to " .. tostring(self.params.in_downtime) 
      .. ". Current downtime state: " .. tostring(self.sc_common:boolean_to_number(self.event.scheduled_downtime_depth)))
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
      .. " matched hostgroup: " .. accepted_hostgroup_name)
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
  end
    
  self.sc_logger:debug("[sc_event:is_valid_servicegroup]: event for service with id: " .. tostring(self.event.service_id)
      .. "matched servicegroup: " .. accepted_servicegroup_name)

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
  elseif (not self.event.cache.ba.ba_name and self.params.skip_anon_events == 0) then 
    self.event.cache.ba = {
      ba_name = self.event.ba_id
    }
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

  -- initiate the severity table in the cache if it doesn't exist
  if not self.event.cache.severity then
    self.event.cache.severity = {}
  end

  -- get severity of the host from broker cache
  self.event.cache.severity.host = self.sc_broker:get_severity(self.event.host_id)

  -- return false if host severity doesn't match 
  if not self.sc_common:compare_numbers(self.params.host_severity_threshold, self.event.cache.severity.host, self.params.host_severity_operator) then
    self.sc_logger:debug("[sc_event:is_valid_host_severity]: dropping event because host with id: " .. tostring(self.event.host_id) .. " has an invalid severity. Severity is: "
      .. tostring(self.event.cache.severity.host) .. ". host_severity_threshold (" .. tostring(self.params.host_severity_threshold) .. ") is " .. self.params.host_severity_operator 
      .. " to the severity of the host (" .. tostring(self.event.cache.severity.host) .. ")")
    return false
  end

  return true
end

--- is_valid_service_severity: checks if the service severity is accepted
-- @return true|false (boolean)
function ScEvent:is_valid_service_severity()
  -- return true if there is no severity filter
  if self.params.service_severity_threshold == nil then
    return true
  end

  -- initiate the severity table in the cache if it doesn't exist
  if not self.event.cache.severity then
    self.event.cache.severity = {}
  end

  -- get severity of the host from broker cache
  self.event.cache.severity.service = self.sc_broker:get_severity(self.event.host_id, self.event.service_id)

  -- return false if service severity doesn't match 
  if not self.sc_common:compare_numbers(self.params.service_severity_threshold, self.event.cache.severity.service, self.params.service_severity_operator) then
    self.sc_logger:debug("[sc_event:is_valid_service_severity]: dropping event because service with id: " .. tostring(self.event.service_id) .. " has an invalid severity. Severity is: "
      .. tostring(self.event.cache.severity.service) .. ". service_severity_threshold (" .. tostring(self.params.service_severity_threshold) .. ") is " .. self.params.service_severity_operator 
      .. " to the severity of the host (" .. tostring(self.event.cache.severity.service) .. ")")
    return false
  end

  return true
end

---is_valid_acknowledgement_event: checks if the event is a valid acknowledge event 
-- @return true|false (boolean)
function ScEvent:is_valid_acknowledgement_event()
  -- return false if we can't get hostname or host id is nil
  if not self:is_valid_host() then
    self.sc_logger:warning("[sc_event:is_valid_acknowledge_event]: host_id: " .. tostring(self.event.host_id) .. " hasn't been validated")
    return false
  end

  -- check if ack author is valid 
  if not self:is_valid_author() then
    self.sc_logger:warning("[sc_event:is_valid_acknowledgement_event]: acknowledgement on host: " .. tostring(self.event.host_id)
      ..  "and service: " .. tostring(self.event.service_id) .. "(0 means ack is on host) is not made by a valid author. Author is: " 
      .. tostring(self.event.author) .. " Accepted authors are: " .. self.params.accepted_authors)
    return false
  end
  
  -- return false if host is not monitored from an accepted poller
  if not self:is_valid_poller() then
    self.sc_logger:warning("[sc_event:is_valid_acknowledgement_event]: host_id: " .. tostring(self.event.host_id) .. " is not monitored from an accepted poller")
    return false
  end

  -- return false if host has not an accepted severity
  if not self:is_valid_host_severity() then
    self.sc_logger:warning("[sc_event:is_valid_acknowledgement_event]: service id: " .. tostring(self.event.service_id) 
      .. ". host_id: " .. tostring(self.event.host_id) .. ". Host has not an accepted severity")
    return false
  end

  local event_status = ""
  -- service_id = 0 means ack is on a host
  if self.event.type == 0 then
    -- use dedicated ack host status configuration or host_status configuration 
    event_status = self.sc_common:ifnil_or_empty(self.params.ack_host_status, self.params.host_status)

    -- return false if event status is not accepted
    if not self:is_valid_event_status(event_status) then
      self.sc_logger:warning("[sc_event:is_valid_acknowledgement_event]: host_id: " .. tostring(self.event.host_id) 
        .. " do not have a validated status. Status: " .. tostring(self.params.status_mapping[self.event.category][self.params.bbdo.elements.host_status.id][self.event.state]))
      return false
    end
  -- service_id != 0 means ack is on a service
  else 
    -- return false if we can't get service description of service id is nil
    if not self:is_valid_service() then
      self.sc_logger:warning("[sc_event:is_valid_acknowledgement_event]: service with id: " .. tostring(self.event.service_id) .. " hasn't been validated")
      return false
    end

    -- use dedicated ack host status configuration or host_status configuration 
    event_status = self.sc_common:ifnil_or_empty(self.params.ack_service_status, self.params.service_status)

    -- return false if event status is not accepted
    if not self:is_valid_event_status(event_status) then
      self.sc_logger:warning("[sc_event:is_valid_acknowledgement_event]: service with id: " .. tostring(self.event.service_id) 
        .. " hasn't a validated status. Status: " .. tostring(self.params.status_mapping[self.event.category][self.params.bbdo.elements.service_status.id][self.event.state]))
      return false
    end

    -- return false if service has not an accepted severity
    if not self:is_valid_service_severity() then
      self.sc_logger:warning("[sc_event:is_valid_acknowledgement_event]: service id: " .. tostring(self.event.service_id) 
        .. ". host_id: " .. tostring(self.event.host_id) .. ". Service has not an accepted severity")
      return false
    end

    -- return false if service is not in an accepted servicegroup 
    if not self:is_valid_servicegroup() then
      self.sc_logger:warning("[sc_event:is_valid_acknowledgement_event]: service_id: " .. tostring(self.event.service_id) .. " is not in an accepted servicegroup")
      return false
    end
  end

  -- return false if host is not in an accepted hostgroup
  if not self:is_valid_hostgroup() then
    self.sc_logger:warning("[sc_event:is_valid_acknowledgement_event]: service_id: " .. tostring(self.event.service_id) 
      .. " is not in an accepted hostgroup. Host ID is: " .. tostring(self.event.host_id))
    return false
  end
  
  return true
end

--- is_vaid_downtime_event: check if the event is a valid downtime event
-- return true|false (boolean)
function ScEvent:is_valid_downtime_event()
  -- return false if the event is one of all the "fake" start or end downtime event received from broker
  if not self:is_downtime_event_useless() then
    self.sc_logger:debug("[sc_event:is_valid_downtime_event]: dropping downtime event because it is not a start nor end of downtime event.")
    return false
  end

  -- return false if we can't get hostname or host id is nil
  if not self:is_valid_host() then
    self.sc_logger:warning("[sc_event:is_valid_downtime_event]: host_id: " .. tostring(self.event.host_id) .. " hasn't been validated")
    return false
  end

  -- check if downtime author is valid 
  if not self:is_valid_author() then
    self.sc_logger:warning("[sc_event:is_valid_downtime_event]: downtime with internal ID: " .. tostring(self.event.internal_id)
      .. " is not made by a valid author. Author is: " .. tostring(self.event.author) .. " Accepted authors are: " .. self.params.accepted_authors)
    return false
  end

  -- return false if host is not monitored from an accepted poller
  if not self:is_valid_poller() then
    self.sc_logger:warning("[sc_event:is_valid_downtime_event]: host_id: " .. tostring(self.event.host_id) .. " is not monitored from an accepted poller")
    return false
  end

  -- this is a host event
  if self.event.type == 2 then
    -- store the result in the self.event.state because doing that allow us to use the is_valid_event_status method
    self.event.state = self:get_downtime_host_status()
    
    -- checks if the current host downtime state is an accpeted status
    if not self:is_valid_event_status(self.params.dt_host_status) then
      self.sc_logger:warning("[sc_event:is_valid_downtime_event]: host_id: " .. tostring(self.event.host_id) 
        .. " do not have a validated status. Status: " .. tostring(self.params.status_mapping[self.event.category][self.event.element][self.event.type][self.event.state])
        .. " Accepted states are: " .. tostring(self.params.dt_host_status))
      return false
    end
  else
    -- return false if we can't get service description or service id is nil
    if not self:is_valid_service() then
      self.sc_logger:warning("[sc_event:is_valid_service_status_event]: service with id: " .. tostring(self.event.service_id) .. " hasn't been validated")
      return false
    end

    -- store the result in the self.event.state because doing that allow us to use the is_valid_event_status method
    self.event.state = self:get_downtime_service_status()
    
    -- return false if event status is not accepted
    if not self:is_valid_event_status(self.params.dt_service_status) then
      self.sc_logger:warning("[sc_event:is_valid_downtime_event]: service with id: " .. tostring(self.event.service_id) 
        .. " hasn't a validated status. Status: " .. tostring(self.params.status_mapping[self.event.category][self.event.element][self.event.type][self.event.state])
        .. " Accepted states are: " .. tostring(self.params.dt_service_status))
      return false
    end

    -- return false if service has not an accepted severity
    if not self:is_valid_service_severity() then
      self.sc_logger:warning("[sc_event:is_valid_downtime_event]: service id: " .. tostring(self.event.service_id) 
        .. ". host_id: " .. tostring(self.event.host_id) .. ". Service has not an accepted severity")
      return false
    end

    -- return false if service is not in an accepted servicegroup 
    if not self:is_valid_servicegroup() then
      self.sc_logger:warning("[sc_event:is_valid_downtime_event]: service_id: " .. tostring(self.event.service_id) .. " is not in an accepted servicegroup")
      return false
    end
  end

  -- return false if host is not in an accepted hostgroup
  if not self:is_valid_hostgroup() then
    self.sc_logger:warning("[sc_event:is_valid_downtime_event]: service_id: " .. tostring(self.event.service_id) 
      .. " is not in an accepted hostgroup. Host ID is: " .. tostring(self.event.host_id))
    return false
  end

  return true
end

--- is_valid_author: check if the author of a comment is valid based on contact alias in Centreon
-- return true|false (boolean)
function ScEvent:is_valid_author()
  -- do not handle authors if it is not configured
  if self.params.accepted_authors == "" then
    return true
  end

  -- check if author is accepted
  if not self:find_author_in_list() then
    self.sc_logger:debug("[sc_event:is_valid_author]: dropping event because author: " .. tostring(self.event.author) 
      .. " is not in an accepted authors list. Accepted authorss are: " .. self.params.accepted_authors)
    return false
  end

  return true
end

--- find_author_in_list: compare accepted authors from parameters with the event author
-- @return accepted_alias or false (string|boolean) the alias of the first matching author if found or false if not found
function ScEvent:find_author_in_list()
  for _, accepted_alias in ipairs(self.sc_common:split(self.params.accepted_authors, ",")) do
    if accepted_alias == self.event.author then
      return accepted_alias
    end
  end

  return false
end

--- get_downtime_host_status: retrieve the status of a host based on last_time_up/down dates found in cache (self.event.cache.host must be set)
-- return status (number) the status code of the host
function ScEvent:get_downtime_host_status()
  -- if cache is not filled we can't get the state of the host
  if not self.event.cache.host.last_time_up or not self.event.cache.host.last_time_down then
    return "N/A"
  end

  -- affect the status known dates to their respective status code
  local timestamp = {
    [0] = tonumber(self.event.cache.host.last_time_up),
    [1] = tonumber(self.event.cache.host.last_time_down)
  }

  return self:get_most_recent_status_code(timestamp)
end

--- get_downtime_service_status: retrieve the status of a service based on last_time_ok/warning/critical/unknown dates found in cache (self.event.cache.host must be set)
-- return status (number) the status code of the service
function ScEvent:get_downtime_service_status()
  -- if cache is not filled we can't get the state of the service
  if 
    not self.event.cache.host.last_time_ok 
    or not self.event.cache.host.last_time_warning 
    or not self.event.cache.service.last_time_critical 
    or not self.event.cache.service.last_time_unknown 
  then
    return "N/A"
  end

  -- affect the status known dates to their respective status code
  local timestamp = {
    [0] = tonumber(self.event.cache.service.last_time_ok),
    [1] = tonumber(self.event.cache.service.last_time_warning),
    [2] = tonumber(self.event.cache.service.last_time_critical),
    [3] = tonumber(self.event.cache.service.last_time_unknown)
  }

  return self:get_most_recent_status_code(timestamp)
end

--- get_most_recent_status_code: retrieve the last status code from a list of status and timestamp 
-- @param timestamp (table) a table with the association of the last known timestamp of a status and its corresponding status code
-- @return status (number) the most recent status code of the object
function ScEvent:get_most_recent_status_code(timestamp)

  -- prepare the table in wich the latest known status timestamp and status code will be stored
  local status_info = {
    highest_timestamp = 0,
    status = nil
  }
  
  -- compare all status timestamp and keep the most recent one and the corresponding status code
  for status_code, status_timestamp in ipairs(timestamp) do
    if status_timestamp > status_info.highest_timestamp then
      status_info.highest_timestamp = status_timestamp
      status_info.status = status_code
    end
  end

  return status_info.status
end

--- is_service_status_event_duplicated: check if the service event is the same than the last one (will not work for OK(H) -> CRITICAL(S) -> OK(H))
-- @return true|false (boolean)
function ScEvent:is_service_status_event_duplicated()
  -- return false if option is not activated
  if self.params.enable_service_status_dedup ~= 1 then
    self.sc_logger:debug("[sc_event:is_service_status_event_duplicated]: service status is not enabled option enable_service_status_dedup is set to: " .. tostring(self.params.enable_service_status_dedup))
    return false
  end

  -- if last check is the same than last_hard_state_change, it means the event just change its status so it cannot be a duplicated event
  if self.event.last_hard_state_change == self.event.last_check or self.event.last_hard_state_change == self.event.last_update then
    return false
  end
  
  return true
  --[[
    IT LOOKS LIKE THIS PIECE OF CODE IS USELESS

  -- map the status known dates to their respective status code
  local timestamp = {
    [0] = tonumber(self.event.cache.service.last_time_ok),
    [1] = tonumber(self.event.cache.service.last_time_warning),
    [2] = tonumber(self.event.cache.service.last_time_critical),
    [3] = tonumber(self.event.cache.service.last_time_unknown)
  }

  -- if we find a last time status older than the last_hard_state_change then we are not facing a duplicated event
  for status_code, status_timestamp in ipairs(timestamp) do
    -- of course it needs to be a different status code than the actual one
    if status_code ~= self.event.state and status_timestamp >= self.event.last_hard_state_change then
      return false
    end
  end

  -- at the end, it only remains two cases, the first one is a duplicated event. The second one is when we have:
  -- OK(H) --> NOT-OK(S) --> OK(H) 
  ]]-- 
end

--- is_host_status_event_duplicated: check if the host event is the same than the last one (will not work for UP(H) -> DOWN(S) -> UP(H))
-- @return true|false (boolean)
function ScEvent:is_host_status_event_duplicated()
  -- return false if option is not activated
  if self.params.enable_host_status_dedup ~= 1 then
    self.sc_logger:debug("[sc_event:is_host_status_event_duplicated]: host status is not enabled option enable_host_status_dedup is set to: " .. tostring(self.params.enable_host_status_dedup))
    return false
  end

  -- if last check is the same than last_hard_state_change, it means the event just change its status so it cannot be a duplicated event
  if self.event.last_hard_state_change == self.event.last_check or self.event.last_hard_state_change == self.event.last_update then
    return false
  end

  return true
  --[[
    IT LOOKS LIKE THIS PIECE OF CODE IS USELESS
  -- map the status known dates to their respective status code
  local timestamp = {
    [0] = tonumber(self.event.cache.service.last_time_up),
    [1] = tonumber(self.event.cache.service.last_time_down),
    [2] = tonumber(self.event.cache.service.last_time_unreachable),
  }

  -- if we find a last time status older than the last_hard_state_change then we are not facing a duplicated event
  for status_code, status_timestamp in ipairs(timestamp) do
    -- of course it needs to be a different status code than the actual one
    if status_code ~= self.event.state and status_timestamp >= self.event.last_hard_state_change then
      return false
    end
  end

  -- at the end, it only remains two cases, the first one is a duplicated event. The second one is when we have:
  -- UP(H) --> NOT-UP(S) --> UP(H) 
  ]]--
end


--- is_downtime_event_useless: the purpose of this method is to filter out unnecessary downtime event. It appears that broker
-- is sending many downtime events before sending the one we want
-- @return true|false (boolean)
function ScEvent:is_downtime_event_useless()
  -- return false if downtime event is not a valid start of downtime event
  if self:is_valid_downtime_event_start() then
    return true
  end
  
  -- return false if downtime event is not a valid end of downtime event
  if self:is_valid_downtime_event_end() then
    return true
  end

  return false
end

--- is_valid_downtime_event_start: make sure that the event is the one notifying us that a downtime has just started
-- @return true|false (boolean)
function ScEvent:is_valid_downtime_event_start()
  -- event is about the end of the downtime (actual_end_time key is not present in a start downtime event)
  if self.event.actual_end_time then
    self.sc_logger:debug("[sc_event:is_valid_downtime_event_start]: actual_end_time found in the downtime event. It can't be a downtime start event")
    return false
  end

  -- event hasn't actually started until the actual_start_time key is present in the start downtime event
  if not self.event.actual_start_time then
    self.sc_logger:debug("[sc_event:is_valid_downtime_event_start]: actual_start_time not found in the downtime event. The downtime hasn't yet started")
    return false
  end

  return true
end

--- is_valid_downtime_event_end: make sure that the event is the one notifying us that a downtime has just ended
-- @return true|false (boolean)
function ScEvent:is_valid_downtime_event_end()
  -- event is about the end of the downtime (deletion_time key is only present in a end downtime event)
  if self.event.deletion_time then
    return true
  end
  
  -- any other downtime event is not about the actual end of a downtime so we return false
  self.sc_logger:debug("[sc_event:is_valid_downtime_event_end]: deletion_time not found in the downtime event. The downtime event is not about the end of a downtime")
  return false
end

--- build_outputs: adds short_output and long_output entries in the event table. output entry will be equal to one or another depending on the use_longoutput param
function ScEvent:build_outputs()
  self.event.long_output = self.event.output
  self.event.long_output = self.event.output

  -- no short output if there is no line break
  local short_output = string.match(self.event.output, "^(.*)\n")
  if short_output then
    self.event.short_output = short_output
  else
    self.event.short_output = self.event.output
  end

  -- use shortoutput if it exists
  if self.params.use_long_output == 0 and short_output then
    self.event.output = short_output

  -- replace line break if asked to and we are not already using a short output
  elseif not short_output and  self.params.remove_line_break_in_output == 1 then
    self.event.output = string.gsub(self.event.output, "\n", self.params.output_line_break_replacement_character)
  end

end

--- is_valid_storage: DEPRECATED method, use NEB category to get metric data instead
-- @return true (boolean)
function ScEvent:is_valid_storage_event()
  return true
end

return sc_event
