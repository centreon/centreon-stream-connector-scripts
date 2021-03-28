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

  setmetatable(self, { __index = ScEvent })

  return self
end

--- is_valid_event: check if the event is accepted depending on various conditions
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
  local host_infos = self.broker:get_host_infos(self.event.host_id, 'name')

    -- return false if we can't get hostname or host id is nil
  if (not host_infos and self.params.skip_nil_id)
    or (not host_infos.name and self.params.skip_anon_events == 1) then
    return false
  end

  -- force host name to be its id if no name has been found
  if not host_infos.name then
    self.event.name = host_infos.host_id or self.event.host_id
  else
    self.event.name = host_infos.name
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
  local service_infos = self.broker:get_service_infos(self.event.host_id, self.event.service_id, 'description')

  -- return false if we can't get service description or if service id is nil
  if (not service_infos and self.params.skip_nil_id)
    or (not service_infos.description and self.params.skip_anon_events == 1) then
    return false
  end

  -- force service description to its id if no description has been found
  if not service_infos.description then
    self.event.description = service_infos.service_id or self.event.service_id
  else
    self.event.description = service_infos.description
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
-- @return accepted_name (string) the name of the first matching servicegroup 
-- @return false (boolean) if no matching servicegroup has been found
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


