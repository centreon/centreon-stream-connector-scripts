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

--- Create a new ScEvent instance.
--- This function initializes a new ScEvent object with the provided broker event, parameters, common utilities, logger, and broker.
--- It sets up the event table and meta table for accessing broker event properties.
--- @param broker_event (table) The event data received from the Centreon broker.
--- @param params (sc_params) Configuration parameters for event processing.
--- @param common (sc_common) Common utility functions.
--- @param logger (sc_logger) Logger instance for logging messages.
--- @param broker (sc_broker) Broker instance for interacting with Centreon broker data.
--- @return (sc_event) A new ScEvent instance.
function sc_event.new(broker_event, params, common, logger, broker)
  local self = {}

  -- Initialize logger, or create a new one if not provided.
  self.sc_logger = logger
  if not self.sc_logger then
    self.sc_logger = sc_logger.new()
  end

  -- Assign common utilities, parameters, broker event, and broker instance.
  self.sc_common = common
  self.params = params
  self.broker_event = broker_event
  self.sc_broker = broker
  self.bbdo_version = self.sc_common:get_bbdo_version()

  -- Create the event table with a cache for storing intermediate data.
  self.event = {
    cache = {}
  }

  -- Create a meta table for accessing broker event properties dynamically.
  local event_meta = { __index = function (tbl, key) return self.broker_event[key] end }
  setmetatable(self.event, event_meta)

  -- Set the meta table for the ScEvent instance.
  setmetatable(self, { __index = ScEvent })
  return self
end

--- Check if the event is in an accepted category.
--- This method validates whether the event's category matches the accepted categories defined in the configuration.
--- @return (boolean) true if the event's category is accepted, `false` otherwise.
function ScEvent:is_valid_category()
  return self:find_in_mapping(self.params.category_mapping, self.params.accepted_categories, self.event.category)
end

--- Check if the event is an accepted element.
--- This method validates whether the event's element matches the accepted elements defined in the configuration.
--- @return (boolean) true if the event's element is accepted, `false` otherwise.
function ScEvent:is_valid_element()
  return self:find_in_mapping(self.params.element_mapping[self.event.category], self.params.accepted_elements, self.event.element)
end

--- Check if an item type is in the mapping and is accepted.
--- This method checks whether a given item exists in the mapping table and matches the accepted reference values.
--- @param mapping (table) The mapping table containing item mappings.
--- @param reference (string) A comma-separated list of accepted values for the item.
--- @param item (string) The item to validate
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

--- Check if the event is accepted depending on configured conditions.
--- This method validates the event based on its category and custom code.
--- It ensures the event meets the criteria defined in the configuration parameters.
--- @return (boolean) true if the event has to be handled, false otherwise.
function ScEvent:is_valid_event()
  local is_valid_event = false

  -- Run validation tests depending on the category of the event.
  if self.event.category == self.params.bbdo.categories.neb.id then
    is_valid_event = self:is_valid_neb_event()
  elseif self.event.category == self.params.bbdo.categories.storage.id then
    is_valid_event = self:is_valid_storage_event()
  elseif self.event.category == self.params.bbdo.categories.bam.id then
    is_valid_event = self:is_valid_bam_event()
  end

  -- Drop the event if it was not valid. Custom code does not work on already invalid events.
  if not is_valid_event then
    return is_valid_event
  end

  -- Run custom code if provided in the configuration.
  if self.params.custom_code and type(self.params.custom_code) == "function" then
    self, is_valid_event = self.params.custom_code(self)
  end

  return is_valid_event
end

--- Check if the event is an accepted NEB type event.
--- This method validates NEB events based on their element type.
--- @return (boolean) true if the event's category makes it eligible for being handled, `false` otherwise.
function ScEvent:is_valid_neb_event()
  local is_valid_event = false

  -- Run validation tests depending on the element type of the NEB event.
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

--- Check if the host status event is an accepted one.
--- This method validates host status events based on various criteria, including host validation, event status, and severity.
--- @return (boolean) true if the host status event is valid, `false` otherwise.
function ScEvent:is_valid_host_status_event()
  -- Return `false` if we can't get hostname or host ID is nil.
  if not self:is_valid_host() then
    self.sc_logger:warning("[sc_event:is_valid_host_status_event]: host_id: " .. tostring(self.event.host_id) .. " hasn't been validated")
    return false
  end

  -- Return `false` if event status is not accepted.
  if not self:is_valid_event_status(self.params.host_status) then
    self.sc_logger:warning("[sc_event:is_valid_host_status_event]: host_id: " .. tostring(self.event.host_id)
      .. " does not have a validated status. Status: " .. tostring(self.params.status_mapping[self.event.category][self.event.element][self.event.state]))
    return false
  end

  -- Return `false` if event status is a duplicate and deduplication is enabled.
  if self:is_host_status_event_duplicated() then
    self.sc_logger:warning("[sc_event:is_host_status_event_duplicated]: host_id: " .. tostring(self.event.host_id)
      .. " is sending a duplicated event. Deduplication option (enable_host_status_dedup) is set to: " .. tostring(self.params.enable_host_status_dedup))
    return false
  end

  -- Return `false` if one of event acknowledgment, downtime, state type (hard/soft), or flapping states is not valid.
  if not self:is_valid_event_states() then
    self.sc_logger:warning("[sc_event:is_valid_host_status_event]: host_id: " .. tostring(self.event.host_id) .. " is not in a validated downtime, acknowledgment, or hard/soft state")
    return false
  end

  -- Return `false` if host is not monitored from an accepted poller.
  if not self:is_valid_poller() then
    self.sc_logger:warning("[sc_event:is_valid_host_status_event]: host_id: " .. tostring(self.event.host_id) .. " is not monitored from an accepted poller")
    return false
  end

  -- Return `false` if host does not have an accepted severity.
  if not self:is_valid_host_severity() then
    self.sc_logger:warning("[sc_event:is_valid_host_status_event]: host_id: " .. tostring(self.event.host_id) .. " does not have an accepted severity")
    return false
  end

  -- Return `false` if host is not in an accepted hostgroup.
  if not self:is_valid_hostgroup() then
    self.sc_logger:warning("[sc_event:is_valid_host_status_event]: host_id: " .. tostring(self.event.host_id) .. " is not in an accepted hostgroup")
    return false
  end

  -- Compatibility patch for BBDO versions 2 and 3.
  if not self.event.last_update and self.event.last_check then
    self.event.last_update = self.event.last_check
  elseif not self.event.last_check and self.event.last_update then
    self.event.last_check = self.event.last_update
  end

  self:build_outputs()

  return true
end

--- Check if the service status event is an accepted one.
--- This method validates service status events based on various criteria, including host and service validation, event status, and severity.
--- @return (boolean) true if the service status event is valid, `false` otherwise.
function ScEvent:is_valid_service_status_event()
  -- Return `false` if we can't get hostname or host ID is nil.
  if not self:is_valid_host() then
    self.sc_logger:warning("[sc_event:is_valid_service_status_event]: host_id: " .. tostring(self.event.host_id)
      .. " hasn't been validated for service with id: " .. tostring(self.event.service_id))
    return false
  end

  -- Return `false` if we can't get service description or service ID is nil.
  if not self:is_valid_service() then
    self.sc_logger:warning("[sc_event:is_valid_service_status_event]: service with id: " .. tostring(self.event.service_id) .. " hasn't been validated")
    return false
  end

  -- Return `false` if event status is not accepted.
  if not self:is_valid_event_status(self.params.service_status) then
    self.sc_logger:warning("[sc_event:is_valid_service_status_event]: service with id: " .. tostring(self.event.service_id)
      .. " does not have a validated status. Status: " .. tostring(self.params.status_mapping[self.event.category][self.event.element][self.event.state]))
    return false
  end

  -- Return `false` if event status is a duplicate and deduplication is enabled.
  if self:is_service_status_event_duplicated() then
    self.sc_logger:warning("[sc_event:is_service_status_event_duplicated]: host_id: " .. tostring(self.event.host_id)
      .. " service_id: " .. tostring(self.event.service_id) .. " is sending a duplicated event. Deduplication option (enable_service_status_dedup) is set to: " .. tostring(self.params.enable_service_status_dedup))
    return false
  end

  -- Return `false` if one of event acknowledgment, downtime, state type (hard/soft), or flapping states is not valid.
  if not self:is_valid_event_states() then
    self.sc_logger:warning("[sc_event:is_valid_service_status_event]: service_id: " .. tostring(self.event.service_id) .. " is not in a validated downtime, acknowledgment, or hard/soft state")
    return false
  end

  -- Return `false` if host is not monitored from an accepted poller.
  if not self:is_valid_poller() then
    self.sc_logger:warning("[sc_event:is_valid_service_status_event]: service id: " .. tostring(self.event.service_id)
      .. ". host_id: " .. tostring(self.event.host_id) .. " is not monitored from an accepted poller")
    return false
  end

  -- Return `false` if host does not have an accepted severity.
  if not self:is_valid_host_severity() then
    self.sc_logger:warning("[sc_event:is_valid_service_status_event]: service id: " .. tostring(self.event.service_id)
      .. ". host_id: " .. tostring(self.event.host_id) .. ". Host does not have an accepted severity")
    return false
  end

  -- Return `false` if service does not have an accepted severity.
  if not self:is_valid_service_severity() then
    self.sc_logger:warning("[sc_event:is_valid_service_status_event]: service id: " .. tostring(self.event.service_id)
      .. ". host_id: " .. tostring(self.event.host_id) .. ". Service does not have an accepted severity")
    return false
  end

  -- Return `false` if host is not in an accepted hostgroup.
  if not self:is_valid_hostgroup() then
    self.sc_logger:warning("[sc_event:is_valid_service_status_event]: service_id: " .. tostring(self.event.service_id)
      .. " is not in an accepted hostgroup. Host ID is: " .. tostring(self.event.host_id))
    return false
  end

  -- Return `false` if service is not in an accepted servicegroup.
  if not self:is_valid_servicegroup() then
    self.sc_logger:warning("[sc_event:is_valid_service_status_event]: service_id: " .. tostring(self.event.service_id) .. " is not in an accepted servicegroup")
    return false
  end

  -- Compatibility patch for BBDO versions 2 and 3.
  if not self.event.last_update and self.event.last_check then
    self.event.last_update = self.event.last_check
  elseif not self.event.last_check and self.event.last_update then
    self.event.last_check = self.event.last_update
  end

  self:build_outputs()

  return true
end

--- Validate the host name and/or ID.
--- This method checks if the host associated with the event is valid based on its ID and name.
--- It retrieves host information from the broker cache and applies validation rules based on configuration parameters.
--- @return (boolean) Returns `true` if the host is valid, `false` otherwise.
function ScEvent:is_valid_host()

  -- Return `false` if the host ID is nil and the `skip_nil_id` parameter is enabled.
  if (not self.event.host_id and self.params.skip_nil_id == 1) then
    self.sc_logger:warning("[sc_event:is_valid_host]: Invalid host with id: " .. tostring(self.event.host_id) .. " skip nil id is: " .. tostring(self.params.skip_nil_id))
    return false
  end

  -- Retrieve host information from the broker cache.
  self.event.cache.host = self.sc_broker:get_host_all_infos(self.event.host_id)

  -- Return `false` if the host name is not found and the `skip_anon_events` parameter is enabled.
  if (not self.event.cache.host and self.params.skip_anon_events == 1) then
    self.sc_logger:warning("[sc_event:is_valid_host]: No name for host with id: " .. tostring(self.event.host_id)
      .. " and skip anon events is: " .. tostring(self.params.skip_anon_events))
    return false
  elseif (not self.event.cache.host and self.params.skip_anon_events == 0) then
    -- Assign the host ID as the name if the host name is not found and anonymous events are allowed.
    self.event.cache.host = {
      name = self.event.host_id
    }
  end

  -- Force the host name to be its ID if no name has been found.
  if not self.event.cache.host.name then
    self.event.cache.host.name = self.event.cache.host.host_id or self.event.host_id
  end

  -- Return `false` if the event is coming from a fake BAM host and BAM hosts are disabled.
  if string.find(self.event.cache.host.name, "^_Module_BAM_*") and self.params.enable_bam_host == 0 then
    self.sc_logger:debug("[sc_event:is_valid_host]: Host is a BAM fake host: " .. tostring(self.event.cache.host.name))
    return false
  end

  -- Loop through each Lua pattern to check if the host name matches the filter.
  local is_valid_pattern = false
  if self.params.accepted_hosts ~= "" then
    for index, pattern in ipairs(self.params.accepted_hosts_pattern_list) do
      if string.match(self.event.cache.host.name, pattern) then
        self.sc_logger:debug("[sc_event:is_valid_host]: host " .. tostring(self.event.cache.host.name)
          .. " matched pattern: " .. tostring(pattern))
        is_valid_pattern = true
        break
      end
    end
  else
    is_valid_pattern = true
  end

  -- Return `false` if the host name does not match any accepted patterns.
  if not is_valid_pattern then
    self.sc_logger:info("[sc_event:is_valid_host]: Host: " .. tostring(self.event.cache.host.name)
        .. " doesn't match accepted_hosts pattern: " .. tostring(self.params.accepted_hosts)
        .. " or any of the sub-patterns if accepted_hosts_enable_split_pattern is enabled")
    return false
  end

  return true
end

--- Validate the service description and/or ID.
--- This method checks if the service associated with the event is valid based on its ID and description.
--- It retrieves service information from the broker cache and applies validation rules based on configuration parameters.
--- @return (boolean) Returns `true` if the service is valid, `false` otherwise.
function ScEvent:is_valid_service()

  -- Return `false` if the service ID is nil and the `skip_nil_id` parameter is enabled.
  if (not self.event.service_id and self.params.skip_nil_id == 1) then
    self.sc_logger:warning("[sc_event:is_valid_service]: Invalid service with id: " .. tostring(self.event.service_id) .. " skip nil id is: " .. tostring(self.params.skip_nil_id))
    return false
  end

  -- Retrieve service information from the broker cache.
  self.event.cache.service = self.sc_broker:get_service_all_infos(self.event.host_id, self.event.service_id)

  -- Return `false` if the service description is not found and the `skip_anon_events` parameter is enabled.
  if (not self.event.cache.service and self.params.skip_anon_events == 1) then
    self.sc_logger:warning("[sc_event:is_valid_service]: Invalid description for service with id: " .. tostring(self.event.service_id)
      .. " and skip anon events is: " .. tostring(self.params.skip_anon_events))
    return false
  elseif (not self.event.cache.service and self.params.skip_anon_events == 0) then
    -- Assign the service ID as the description if the service description is not found and anonymous events are allowed.
    self.event.cache.service = {
      description = self.event.service_id
    }
  end

  -- Force the service description to be its ID if no description has been found.
  if not self.event.cache.service.description then
    self.event.cache.service.description = self.event.service_id
  end

  -- Loop through each Lua pattern to check if the service description matches the filter.
  local is_valid_pattern = false
  if self.params.accepted_services ~= "" then
    for index, pattern in ipairs(self.params.accepted_services_pattern_list) do
      if string.match(self.event.cache.service.description, pattern) then
        self.sc_logger:debug("[sc_event:is_valid_service]: service " .. tostring(self.event.cache.service.description)
          .. " from host: " .. tostring(self.event.cache.host.name) .. " matched pattern: " .. tostring(pattern))
        is_valid_pattern = true
        break
      end
    end
  else
    is_valid_pattern = true
  end

  -- Return `false` if the service description does not match any accepted patterns.
  if not is_valid_pattern then
    self.sc_logger:info("[sc_event:is_valid_service]: Service: " .. tostring(self.event.cache.service.description) .. " from host: " .. tostring(self.event.cache.host.name)
        .. " doesn't match accepted_services pattern: " .. tostring(self.params.accepted_services)
        .. " or any of the sub-patterns if accepted_services_enable_split_pattern is enabled")
    return false
  end

  -- If BAM hosts are enabled, replace the host name with the BA name for BA status events.
  if string.find(self.event.cache.host.name, "^_Module_BAM_*") and self.params.enable_bam_host == 1 then
    self.sc_logger:debug("[sc_event:is_valid_service]: Host is a fake BAM host. Therefore, host name: "
      .. tostring(self.event.cache.host.name) .. " must be replaced by the name of the BA.")
    self.event.ba_id = string.gsub(self.event.cache.service.description, "ba_", "")
    self.event.ba_id = tonumber(self.event.ba_id)
    self:is_valid_ba()
    self.sc_logger:debug("[sc_event:is_valid_service]: replacing host name: "
      .. tostring(self.event.cache.host.name) .. " by BA name: " .. tostring(self.event.cache.ba.ba_name))
    self.event.cache.host.name = self.event.cache.ba.ba_name
  end

  return true
end

--- Validate common aspects of an event such as acknowledgment and state type.
--- This method checks whether the event's state type, acknowledgment state, downtime state, and flapping state are valid.
--- @return (boolean) Returns `true` if all aspects of the event are valid, `false` otherwise.
function ScEvent:is_valid_event_states()
  -- Return `false` if the state type (HARD/SOFT) is not valid.
  if not self:is_valid_event_state_type() then
    return false
  end

  -- Return `false` if the acknowledgment state is not valid.
  if not self:is_valid_event_acknowledge_state() then
    return false
  end

  -- Return `false` if the downtime state is not valid.
  if not self:is_valid_event_downtime_state() then
    return false
  end

  -- Return `false` if the flapping state is not valid.
  if not self:is_valid_event_flapping_state() then
    return false
  end

  return true
end

--- Validate the event's status against a list of accepted statuses.
--- This method checks whether the event's status matches any of the statuses in the provided list.
--- Compatibility patches are applied for BBDO versions 2 and 3 to ensure proper handling of state fields.
--- @param accepted_status_list (string) A comma-separated list of accepted statuses (e.g., "ok,warning,critical").
--- @return (boolean) Returns `true` if the event's status is valid, `false` otherwise.
function ScEvent:is_valid_event_status(accepted_status_list)
  local status_list = self.sc_common:split(accepted_status_list, ",")

  -- Return `false` if the accepted status list is nil or empty.
  if not status_list then
    self.sc_logger:error("[sc_event:is_valid_event_status]: accepted_status list is nil or empty")
    return false
  end

  -- Compatibility patch for BBDO version 2 to version 3.
  if (not self.event.state and self.event.current_state) then
    self.event.state = self.event.current_state
  end

  if (not self.event.current_state and self.event.state) then
    self.event.current_state = self.event.state
  end

  -- Check if the event's state matches any of the accepted statuses.
  for _, status_id in ipairs(status_list) do
    if tostring(self.event.state) == status_id then
      return true
    end
  end

  -- Log a warning for invalid downtime events.
  if (self.event.category == self.params.bbdo.categories.neb.id and self.event.element == self.params.bbdo.elements.downtime.id) then
    self.sc_logger:warning("[sc_event:is_valid_event_status] event has an invalid state. Current state: "
      .. tostring(self.params.status_mapping[self.event.category][self.event.element][self.event.type][self.event.state]) .. ". Accepted states are: " .. tostring(accepted_status_list))
    return false
  end

  -- Log a warning for all other invalid events.
  self.sc_logger:warning("[sc_event:is_valid_event_status] event has an invalid state. Current state: "
    .. tostring(self.params.status_mapping[self.event.category][self.event.element][self.event.state]) .. ". Accepted states are: " .. tostring(accepted_status_list))
  return false
end

--- Validate the event's state type (HARD/SOFT).
--- This method checks whether the event's state type meets the configured criteria.
--- @return (boolean) Returns `true` if the state type is valid, `false` otherwise.
function ScEvent:is_valid_event_state_type()
  if not self.sc_common:compare_numbers(self.event.state_type, self.params.hard_only, ">=") then
    self.sc_logger:warning("[sc_event:is_valid_event_state_type]: event is not in an valid state type. Event state type must be above or equal to " .. tostring(self.params.hard_only)
      .. ". Current state type: " .. tostring(self.event.state_type))
    return false
  end

  return true
end

--- Validate the acknowledgment state of the event.
--- This method checks whether the event's acknowledgment state meets the configured criteria.
--- Compatibility patches are applied for BBDO versions 2 and 3 to ensure proper handling of acknowledgment fields.
--- @return (boolean) Returns `true` if the acknowledgment state is valid, `false` otherwise.
function ScEvent:is_valid_event_acknowledge_state()
  -- Compatibility patch for BBDO version 3 to version 2.
  if (not self.event.acknowledged and self.event.acknowledgement_type) then
    if self.event.acknowledgement_type >= 1 then
      self.event.acknowledged = true
    else
      self.event.acknowledged = false
    end
  end

  -- Validate the acknowledgment state against the configured threshold.
  if not self.sc_common:compare_numbers(self.params.acknowledged, self.sc_common:boolean_to_number(self.event.acknowledged), ">=") then
    self.sc_logger:warning("[sc_event:is_valid_event_acknowledge_state]: event is not in an valid ack state. Event ack state must be below or equal to " .. tostring(self.params.acknowledged)
      .. ". Current ack state: " .. tostring(self.sc_common:boolean_to_number(self.event.acknowledged)))
    return false
  end

  return true
end
--- Check if the event is in an accepted downtime state.
--- This method validates whether the event's downtime state meets the configured criteria.
--- It applies compatibility patches for BBDO versions 2 and 3 to ensure proper handling of downtime depth.
--- @return (boolean) Returns `true` if the event's downtime state is valid, `false` otherwise.
function ScEvent:is_valid_event_downtime_state()
  -- Compatibility patch for BBDO version 3 to version 2.
  if (not self.event.scheduled_downtime_depth and self.event.downtime_depth) then
    self.event.scheduled_downtime_depth = self.event.downtime_depth
  end

  -- Validate the downtime state against the configured threshold.
  if not self.sc_common:compare_numbers(self.params.in_downtime, self.event.scheduled_downtime_depth, ">=") then
    self.sc_logger:warning("[sc_event:is_valid_event_downtime_state]: event is not in a valid downtime state. Event downtime state must be below or equal to " .. tostring(self.params.in_downtime)
      .. ". Current downtime state: " .. tostring(self.sc_common:boolean_to_number(self.event.scheduled_downtime_depth)))
    return false
  end

  return true
end

--- Check if the event is in an accepted flapping state.
--- This method validates whether the event's flapping state meets the configured criteria.
--- @return (boolean) Returns `true` if the event's flapping state is valid, `false` otherwise.
function ScEvent:is_valid_event_flapping_state()
  -- Validate the flapping state against the configured threshold.
  if not self.sc_common:compare_numbers(self.params.flapping, self.sc_common:boolean_to_number(self.event.flapping), ">=") then
    self.sc_logger:warning("[sc_event:is_valid_event_flapping_state]: event is not in a valid flapping state. Event flapping state must be below or equal to " .. tostring(self.params.flapping)
      .. ". Current flapping state: " .. tostring(self.sc_common:boolean_to_number(self.event.flapping)))
    return false
  end

  return true
end

--- Check if the event is in an accepted hostgroup.
--- This method validates whether the host associated with the event belongs to an accepted hostgroup.
--- It retrieves hostgroup information from the broker cache and compares it against the accepted/rejected hostgroup lists.
--- @return (boolean) Returns `true` if the host is in an accepted hostgroup, `false` otherwise.
function ScEvent:is_valid_hostgroup()
  -- Retrieve hostgroup information from the broker cache.
  self.event.cache.hostgroups = self.sc_broker:get_hostgroups(self.event.host_id)

  -- Return `true` if neither accepted nor rejected hostgroup lists are configured, or if both are configured.
  local accepted_hostgroups_isnotempty = self.params.accepted_hostgroups ~= ""
  local rejected_hostgroups_isnotempty = self.params.rejected_hostgroups ~= ""
  if (not accepted_hostgroups_isnotempty and not rejected_hostgroups_isnotempty) or (accepted_hostgroups_isnotempty and rejected_hostgroups_isnotempty) then
    return true
  end

  -- Return `false` if no hostgroups were found.
  if not self.event.cache.hostgroups then
    if accepted_hostgroups_isnotempty then
      self.sc_logger:warning("[sc_event:is_valid_hostgroup]: dropping event because host with id: " .. tostring(self.event.host_id)
        .. " is not linked to a hostgroup. Accepted hostgroups are: " .. self.params.accepted_hostgroups ..".")
      return false
    elseif rejected_hostgroups_isnotempty then
      self.sc_logger:debug("[sc_event:is_valid_hostgroup]: accepting event because host with id: " .. tostring(self.event.host_id)
        .. " is not linked to a hostgroup. Rejected hostgroups are: " .. self.params.rejected_hostgroups ..".")
      return true
    end
  end

  -- Compare the hostgroup name against the accepted and rejected hostgroup lists.
  local accepted_hostgroup_name = self:find_hostgroup_in_list(self.params.accepted_hostgroups)
  local rejected_hostgroup_name = self:find_hostgroup_in_list(self.params.rejected_hostgroups)

  -- Return `false` if the host is not in a valid hostgroup.
  if accepted_hostgroups_isnotempty and not accepted_hostgroup_name then
    self.sc_logger:warning("[sc_event:is_valid_hostgroup]: dropping event because host with id: " .. tostring(self.event.host_id)
      .. " is not in an accepted hostgroup. Accepted hostgroups are: " .. self.params.accepted_hostgroups)
    return false
  elseif rejected_hostgroups_isnotempty and rejected_hostgroup_name then
    self.sc_logger:warning("[sc_event:is_valid_hostgroup]: dropping event because host with id: " .. tostring(self.event.host_id)
      .. " is in a rejected hostgroup. Rejected hostgroups are: " .. self.params.rejected_hostgroups)
    return false
  else
    local debug_msg = "[sc_event:is_valid_hostgroup]: event for host with id: " .. tostring(self.event.host_id)
    if accepted_hostgroups_isnotempty then
      debug_msg = debug_msg .. " matched hostgroup: " .. tostring(accepted_hostgroup_name)
    elseif rejected_hostgroups_isnotempty then
      debug_msg = debug_msg .. " did not match hostgroup: " .. tostring(rejected_hostgroup_name)
    end
    self.sc_logger:debug(debug_msg)
  end

  return true
end

--- Compare accepted hostgroups from parameters with the event hostgroups.
--- This method checks if the hostgroup associated with the event matches any of the hostgroups in the provided list.
--- @param hostgroups_list (string) A comma-separated list of hostgroup names.
--- @return (string|boolean) Returns the name of the first matching hostgroup if found, or `false` if no match is found.
function ScEvent:find_hostgroup_in_list(hostgroups_list)
  -- Return `false` if the hostgroup list is nil or empty.
  if hostgroups_list == nil or hostgroups_list == "" then
    return false
  else
    -- Iterate through the hostgroup list and check for a match with the event hostgroup.
    for _, hostgroup_name in ipairs(self.sc_common:split(hostgroups_list, ",")) do
      for _, event_hostgroup in pairs(self.event.cache.hostgroups) do
        if hostgroup_name == event_hostgroup.group_name then
          return hostgroup_name
        end
      end
    end
  end
  return false
end

--- Check if the event is in an accepted servicegroup.
--- This method validates whether the service associated with the event belongs to an accepted servicegroup.
--- It retrieves servicegroup information from the broker cache and compares it against the accepted/rejected servicegroup lists.
--- @return (boolean) Returns `true` if the service is in an accepted servicegroup, `false` otherwise.
function ScEvent:is_valid_servicegroup()
  -- Retrieve servicegroup information from the broker cache.
  self.event.cache.servicegroups = self.sc_broker:get_servicegroups(self.event.host_id, self.event.service_id)

  -- Return `true` if neither accepted nor rejected servicegroup lists are configured, or if both are configured.
  local accepted_servicegroups_isnotempty = self.params.accepted_servicegroups ~= ""
  local rejected_servicegroups_isnotempty = self.params.rejected_servicegroups ~= ""
  if (not accepted_servicegroups_isnotempty and not rejected_servicegroups_isnotempty) or (accepted_servicegroups_isnotempty and rejected_servicegroups_isnotempty) then
    return true
  end

  -- Return `false` if no servicegroups were found.
  if not self.event.cache.servicegroups then
    if accepted_servicegroups_isnotempty then
      self.sc_logger:debug("[sc_event:is_valid_servicegroup]: dropping event because service with id: " .. tostring(self.event.service_id)
        .. " is not linked to a servicegroup. Accepted servicegroups are: " .. self.params.accepted_servicegroups ..".")
      return false
    elseif rejected_servicegroups_isnotempty then
      self.sc_logger:debug("[sc_event:is_valid_servicegroup]: accepting event because service with id: " .. tostring(self.event.service_id)
        .. " is not linked to a servicegroup. Rejected servicegroups are: " .. self.params.rejected_servicegroups ..".")
      return true
    end
  end

  -- Compare the servicegroup name against the accepted and rejected servicegroup lists.
  local accepted_servicegroup_name = self:find_servicegroup_in_list(self.params.accepted_servicegroups)
  local rejected_servicegroup_name = self:find_servicegroup_in_list(self.params.rejected_servicegroups)

  -- Return `false` if the service is not in a valid servicegroup.
  if accepted_servicegroups_isnotempty and not accepted_servicegroup_name then
    self.sc_logger:debug("[sc_event:is_valid_servicegroup]: dropping event because service with id: " .. tostring(self.event.service_id)
      .. " is not in an accepted servicegroup. Accepted servicegroups are: " .. self.params.accepted_servicegroups)
    return false
  elseif rejected_servicegroups_isnotempty and rejected_servicegroup_name then
    self.sc_logger:debug("[sc_event:is_valid_servicegroup]: dropping event because service with id: " .. tostring(self.event.service_id)
      .. " is in a rejected servicegroup. Rejected servicegroups are: " .. self.params.rejected_servicegroups)
    return false
  end

  local debug_msg = "[sc_event:is_valid_servicegroup]: event for service with id: " .. tostring(self.event.service_id)
  if accepted_servicegroups_isnotempty then
    debug_msg = debug_msg .. " matched servicegroup: " .. tostring(accepted_servicegroup_name)
  elseif rejected_servicegroups_isnotempty then
    debug_msg = debug_msg .. " did not match servicegroup: " .. tostring(rejected_servicegroup_name)
  end
  self.sc_logger:debug(debug_msg)

  return true
end

--- Compare accepted servicegroups from parameters with the event servicegroups.
--- This method checks if the servicegroup associated with the event matches any of the servicegroups in the provided list.
--- @param servicegroups_list (string) A comma-separated list of servicegroup names.
--- @return (string|boolean) Returns the name of the first matching servicegroup if found, or `false` if no match is found.
function ScEvent:find_servicegroup_in_list(servicegroups_list)
  -- Return `false` if the servicegroup list is nil or empty.
  if servicegroups_list == nil or servicegroups_list == "" then
    return false
  else
    -- Iterate through the servicegroup list and check for a match with the event servicegroup.
    for _, servicegroup_name in ipairs(self.sc_common:split(servicegroups_list, ",")) do
      for _, event_servicegroup in pairs(self.event.cache.servicegroups) do
        if servicegroup_name == event_servicegroup.group_name then
          return servicegroup_name
        end
      end
    end
  end
  return false
end

--- Check if the event is an accepted BAM type event.
--- This method validates whether the event is associated with a valid Business Activity Monitoring (BAM) entity.
--- It performs checks on the BA name, status, downtime state, acknowledge state, and associated Business View (BV).
--- @return (boolean) Returns `true` if the BAM event is valid, `false` otherwise.
function ScEvent:is_valid_bam_event()
  -- Return false if the BA name is invalid or the BA ID is nil.
  if not self:is_valid_ba() then
    self.sc_logger:warning("[sc_event:is_valid_bam_event]: ba_id: " .. tostring(self.event.ba_id) .. " hasn't been validated")
    return false
  end

  -- Return false if the BA status is not accepted.
  if not self:is_valid_ba_status_event() then
    self.sc_logger:warning("[sc_event:is_valid_bam_event]: ba_id: " .. tostring(self.event.ba_id) .. " has an invalid state")
    return false
  end

  -- Return false if the BA downtime state is not accepted.
  if not self:is_valid_ba_downtime_state() then
    self.sc_logger:warning("[sc_event:is_valid_bam_event]: ba_id: " .. tostring(self.event.ba_id) .. " is not in a validated downtime state")
    return false
  end

  -- Return false if the BA acknowledge state is not accepted (currently does nothing).
  if not self:is_valid_ba_acknowledge_state() then
    self.sc_logger:warning("[sc_event:is_valid_bam_event]: ba_id: " .. tostring(self.event.ba_id) .. " is not in a validated acknowledge state")
    return false
  end

  -- Return false if the BA is not in an accepted BV.
  if not self:is_valid_bv() then
    self.sc_logger:warning("[sc_event:is_valid_bam_event]: ba_id: " .. tostring(self.event.ba_id) .. " is not in an accepted BV")
    return false
  end

  return true
end

--- Check if the BA name and/or ID are valid.
--- This method validates the Business Activity (BA) entity by checking its ID and name.
--- It retrieves BA information from the broker cache and applies validation rules based on configuration parameters.
--- @return (boolean) Returns `true` if the BA is valid, `false` otherwise.
function ScEvent:is_valid_ba()
  -- Return false if the BA ID is nil and the `skip_nil_id` parameter is enabled.
  if (not self.event.ba_id and self.params.skip_nil_id == 1) then
    self.sc_logger:warning("[sc_event:is_valid_ba]: Invalid BA with id: " .. tostring(self.event.ba_id) .. ". And skip nil id is set to: " .. tostring(self.params.skip_nil_id))
    return false
  end

  -- Retrieve BA information from the broker cache.
  self.event.cache.ba = self.sc_broker:get_ba_infos(self.event.ba_id)

  -- Return false if the BA name is not found and the `skip_anon_events` parameter is enabled.
  if (not self.event.cache.ba.ba_name and self.params.skip_anon_events == 1) then
    self.sc_logger:warning("[sc_event:is_valid_ba]: Invalid BA with id: " .. tostring(self.event.ba_id)
      .. ". Found BA name is: " .. tostring(self.event.cache.ba.ba_name) .. ". And skip anon event param is set to: " .. tostring(self.params.skip_anon_events))
    return false
  elseif (not self.event.cache.ba.ba_name and self.params.skip_anon_events == 0) then
    -- Assign the BA ID as the name if the BA name is not found and anonymous events are allowed.
    self.event.cache.ba = {
      ba_name = self.event.ba_id
    }
  end

  return true
end

--- Check if the BA status event is an accepted one.
--- This method validates the status of a Business Activity (BA) entity against the configured accepted states.
--- @return (boolean) Returns `true` if the BA status is valid, `false` otherwise.
function ScEvent:is_valid_ba_status_event()
  if not self:is_valid_event_status(self.params.ba_status) then
    self.sc_logger:warning("[sc_event:is_valid_ba]: Invalid BA status for BA id: " .. tostring(self.event.ba_id) .. ". State is: "
      .. tostring(self.params.status_mapping[self.event.category][self.event.element][self.event.state]) .. ". Accepted states are: " .. tostring(self.params.ba_status))
    return false
  end

  return true
end

--- Check if the BA downtime state is an accepted one.
--- This method validates whether the Business Activity (BA) entity is in an acceptable downtime state.
--- @return (boolean) Returns `true` if the BA downtime state is valid, `false` otherwise.
function ScEvent:is_valid_ba_downtime_state()
  if not self.sc_common:compare_numbers(self.params.in_downtime, self.sc_common:boolean_to_number(self.event.in_downtime), ">=") then
    self.sc_logger:warning("[sc_event:is_valid_ba]: Invalid BA downtime state for BA id: " .. tostring(self.event.ba_id) .. " downtime state is : " .. tostring(self.event.in_downtime)
      .. " and accepted downtime state must be below or equal to: " .. tostring(self.params.in_downtime))
    return false
  end

  return true
end

--- Check if the BA acknowledge state is an accepted one.
--- This method validates whether the Business Activity (BA) entity is in an acceptable acknowledge state.
--- Currently, this method does nothing and always returns `true`.
--- @return (boolean) Returns `true`.
function ScEvent:is_valid_ba_acknowledge_state()
  -- Placeholder for future implementation.
  return true
end

--- Check if the event is in an accepted Business View (BV).
--- This method validates whether the Business Activity (BA) entity is associated with an accepted BV.
--- It retrieves BV information from the broker cache and applies validation rules based on configuration parameters.
--- @return (boolean) Returns `true` if the BA is in an accepted BV, `false` otherwise.
function ScEvent:is_valid_bv()
  -- Retrieve BV information from the broker cache.
  self.event.cache.bvs = self.sc_broker:get_bvs_infos(self.event.host_id)

  -- Return true if neither accepted nor rejected BV lists are configured, or if both are configured.
  local accepted_bvs_isnotempty = self.params.accepted_bvs ~= ""
  local rejected_bvs_isnotempty = self.params.rejected_bvs ~= ""
  if (not accepted_bvs_isnotempty and not rejected_bvs_isnotempty) or (accepted_bvs_isnotempty and rejected_bvs_isnotempty) then
    return true
  end

  -- Return false if no BVs were found.
  if not self.event.cache.bvs then
    if accepted_bvs_isnotempty then
      self.sc_logger:debug("[sc_event:is_valid_bv]: dropping event because host with id: " .. tostring(self.event.host_id)
        .. " is not linked to a BV. Accepted BVs are: " .. self.params.accepted_bvs ..".")
      return false
    elseif rejected_bvs_isnotempty then
      self.sc_logger:debug("[sc_event:is_valid_bv]: accepting event because host with id: " .. tostring(self.event.host_id)
        .. " is not linked to a BV. Rejected BVs are: " .. self.params.rejected_bvs ..".")
      return true
    end
  end

  -- Compare the BV name against the accepted and rejected BV lists.
  local accepted_bv_name = self:find_bv_in_list(self.params.accepted_bvs)
  local rejected_bv_name = self:find_bv_in_list(self.params.rejected_bvs)

  -- Return false if the BA is not in a valid BV.
  if accepted_bvs_isnotempty and not accepted_bv_name then
    self.sc_logger:debug("[sc_event:is_valid_bv]: dropping event because BA with id: " .. tostring(self.event.ba_id)
      .. " is not in an accepted BV. Accepted BVs are: " .. self.params.accepted_bvs)
    return false
  elseif rejected_bvs_isnotempty and rejected_bv_name then
    self.sc_logger:debug("[sc_event:is_valid_bv]: dropping event because BA with id: " .. tostring(self.event.ba_id)
      .. " is in a rejected BV. Rejected BVs are: " .. self.params.rejected_bvs)
    return false
  else
    self.sc_logger:debug("[sc_event:is_valid_bv]: event for BA with id: " .. tostring(self.event.ba_id)
      .. "matched BV: " .. accepted_bv_name)
  end

  return true
end

--- Compare accepted BVs from parameters with the event BVs.
--- This method checks if the BV associated with the event matches any of the BVs in the provided list.
--- @param bvs_list (string) A comma-separated list of BV names.
--- @return (string|boolean) Returns the name of the first matching BV if found, or `false` if no match is found.
function ScEvent:find_bv_in_list(bvs_list)
  -- Return false if the BV list is nil or empty.
  if bvs_list == nil or bvs_list == "" then
    return false
  else
    -- Iterate through the BV list and check for a match with the event BV.
    for _, bv_name in ipairs(self.sc_common:split(bvs_list,",")) do
      for _, event_bv in pairs(self.event.cache.bvs) do
        if bv_name == event_bv.bv_name then
          return bv_name
        end
      end
    end
  end
  return false
end

--- Check if the event is monitored from an accepted poller.
--- This method validates whether the host associated with the event is monitored by an accepted poller.
--- It checks the instance ID, retrieves the poller information, and compares it against the accepted/rejected poller lists.
--- @return (boolean) Returns `true` if the host is monitored by an accepted poller, `false` otherwise.
function ScEvent:is_valid_poller()
  -- Return false if instance ID is not found in the cache.
  if not self.event.cache.host.instance_id then
    self.sc_logger:warning("[sc_event:is_valid_poller]: no instance ID found for host ID: " .. tostring(self.event.host_id))
    return false
  end

  -- Retrieve poller information from the broker cache.
  self.event.cache.poller = self.sc_broker:get_instance(self.event.cache.host.instance_id)

  -- Store poller information in the event cache for easy access.
  self.event.cache.instance = {
    id = self.event.cache.host.instance_id,
    name = self.event.cache.poller
  }

  -- Return true if neither accepted nor rejected poller lists are configured, or if both are configured.
  local accepted_pollers_isnotempty = self.params.accepted_pollers ~= ""
  local rejected_pollers_isnotempty = self.params.rejected_pollers ~= ""
  if (not accepted_pollers_isnotempty and not rejected_pollers_isnotempty) or (accepted_pollers_isnotempty and rejected_pollers_isnotempty) then
    return true
  end

  -- Return false if no poller is found in the cache.
  if not self.event.cache.poller then
    if accepted_pollers_isnotempty then
      self.sc_logger:debug("[sc_event:is_valid_poller]: dropping event because host with id: " .. tostring(self.event.host_id)
        .. " is not linked to an accepted poller (no poller found in cache). Accepted pollers are: " .. self.params.accepted_pollers)
      return false
    elseif rejected_pollers_isnotempty then
      self.sc_logger:debug("[sc_event:is_valid_poller]: accepting event because host with id: " .. tostring(self.event.host_id)
        .. " is not linked to a rejected poller (no poller found in cache). Rejected pollers are: " .. self.params.rejected_pollers)
      return true
    end
  end

  -- Compare the poller name against the accepted and rejected poller lists.
  local accepted_poller_name = self:find_poller_in_list(self.params.accepted_pollers)
  local rejected_poller_name = self:find_poller_in_list(self.params.rejected_pollers)

  -- Return false if the host is not monitored by a valid poller.
  if accepted_pollers_isnotempty and not accepted_poller_name then
    self.sc_logger:debug("[sc_event:is_valid_poller]: dropping event because host with id: " .. tostring(self.event.host_id)
      .. " is not linked to an accepted poller. Host is monitored from: " .. tostring(self.event.cache.poller) .. ". Accepted pollers are: " .. self.params.accepted_pollers)
    return false
  elseif rejected_pollers_isnotempty and rejected_poller_name then
    self.sc_logger:debug("[sc_event:is_valid_poller]: dropping event because host with id: " .. tostring(self.event.host_id)
      .. " is linked to a rejected poller. Host is monitored from: " .. tostring(self.event.cache.poller) .. ". Rejected pollers are: " .. self.params.rejected_pollers)
    return false
  else
    self.sc_logger:debug("[sc_event:is_valid_poller]: event for host with id: " .. tostring(self.event.host_id)
      .. "matched poller: " .. accepted_poller_name)
  end

  return true
end

--- Compare accepted pollers from parameters with the event poller.
--- This method checks if the poller associated with the event matches any of the pollers in the provided list.
--- @param pollers_list (string) A comma-separated list of poller names.
--- @return (string|boolean) Returns the name of the first matching poller if found, or `false` if no match is found.
function ScEvent:find_poller_in_list(pollers_list)
  -- Return false if the poller list is nil or empty.
  if pollers_list == nil or pollers_list == "" then
    return false
  else
    -- Iterate through the poller list and check for a match with the event poller.
    for _, poller_name in ipairs(self.sc_common:split(pollers_list, ",")) do
      if poller_name == self.event.cache.poller then
        return poller_name
      end
    end
  end
  return false
end

--- Checks if the host severity is accepted.
--- This method validates the severity of a host against a configured threshold.
--- It retrieves the severity from the broker cache and compares it using the specified operator.
--- @return (boolean) Returns `true` if the host severity is accepted, `false` otherwise.
function ScEvent:is_valid_host_severity()
  -- Initialize the severity table in the cache if it doesn't exist.
  if not self.event.cache.severity then
    self.event.cache.severity = {}
  end

  -- Retrieve the severity of the host from the broker cache.
  self.event.cache.severity.host = self.sc_broker:get_severity(self.event.host_id)

  -- Return `true` if there is no severity filter configured.
  if self.params.host_severity_threshold == nil then
    return true
  end

  -- Return `false` if the host severity does not match the configured threshold.
  if not self.sc_common:compare_numbers(self.params.host_severity_threshold, self.event.cache.severity.host, self.params.host_severity_operator) then
    self.sc_logger:debug("[sc_event:is_valid_host_severity]: dropping event because host with id: " .. tostring(self.event.host_id) .. " has an invalid severity. Severity is: "
      .. tostring(self.event.cache.severity.host) .. ". host_severity_threshold (" .. tostring(self.params.host_severity_threshold) .. ") is " .. self.params.host_severity_operator
      .. " to the severity of the host (" .. tostring(self.event.cache.severity.host) .. ")")
    return false
  end

  return true
end

--- Checks if the service severity is accepted.
--- This method validates the severity of a service against a configured threshold.
--- It retrieves the severity from the broker cache and compares it using the specified operator.
--- @return (boolean) Returns `true` if the service severity is accepted, `false` otherwise.
function ScEvent:is_valid_service_severity()
  -- Initialize the severity table in the cache if it doesn't exist.
  if not self.event.cache.severity then
    self.event.cache.severity = {}
  end

  -- Retrieve the severity of the service from the broker cache.
  self.event.cache.severity.service = self.sc_broker:get_severity(self.event.host_id, self.event.service_id)

  -- Return `true` if there is no severity filter configured.
  if self.params.service_severity_threshold == nil then
    return true
  end

  -- Return `false` if the service severity does not match the configured threshold.
  if not self.sc_common:compare_numbers(self.params.service_severity_threshold, self.event.cache.severity.service, self.params.service_severity_operator) then
    self.sc_logger:debug("[sc_event:is_valid_service_severity]: dropping event because service with id: " .. tostring(self.event.service_id) .. " has an invalid severity. Severity is: "
      .. tostring(self.event.cache.severity.service) .. ". service_severity_threshold (" .. tostring(self.params.service_severity_threshold) .. ") is " .. self.params.service_severity_operator
      .. " to the severity of the host (" .. tostring(self.event.cache.severity.service) .. ")")
    return false
  end

  return true
end

--- Checks if the event is a valid acknowledgement event.
--- This method validates whether an acknowledgement event meets the configured criteria.
--- It performs checks on the host, service, author, poller, severity, and other attributes.
--- @return (boolean) Returns `true` if the acknowledgement event is valid, `false` otherwise.
function ScEvent:is_valid_acknowledgement_event()
  -- Return `false` if the host is invalid or the host ID is nil.
  if not self:is_valid_host() then
    self.sc_logger:warning("[sc_event:is_valid_acknowledge_event]: host_id: " .. tostring(self.event.host_id) .. " hasn't been validated")
    return false
  end

  -- Check if the acknowledgement author is valid.
  if not self:is_valid_author() then
    self.sc_logger:warning("[sc_event:is_valid_acknowledgement_event]: acknowledgement on host: " .. tostring(self.event.host_id)
      ..  "and service: " .. tostring(self.event.service_id) .. "(0 means ack is on host) is not made by a valid author. Author is: "
      .. tostring(self.event.author) .. " Accepted authors are: " .. self.params.accepted_authors)
    return false
  end

  -- Return `false` if the host is not monitored by an accepted poller.
  if not self:is_valid_poller() then
    self.sc_logger:warning("[sc_event:is_valid_acknowledgement_event]: host_id: " .. tostring(self.event.host_id) .. " is not monitored from an accepted poller")
    return false
  end

  -- Return `false` if the host does not have an accepted severity.
  if not self:is_valid_host_severity() then
    self.sc_logger:warning("[sc_event:is_valid_acknowledgement_event]: service id: " .. tostring(self.event.service_id)
      .. ". host_id: " .. tostring(self.event.host_id) .. ". Host has not an accepted severity")
    return false
  end

  local event_status = ""
  -- If `service_id` is 0, the acknowledgement is for a host.
  if self.event.type == 0 then
    -- Use the dedicated acknowledgement host status configuration or the general host status configuration.
    event_status = self.sc_common:ifnil_or_empty(self.params.ack_host_status, self.params.host_status)

    -- Return `false` if the event status is not accepted.
    if not self:is_valid_event_status(event_status) then
      self.sc_logger:warning("[sc_event:is_valid_acknowledgement_event]: host_id: " .. tostring(self.event.host_id)
        .. " do not have a validated status. Status: " .. tostring(self.params.status_mapping[self.event.category][self.params.bbdo.elements.host_status.id][self.event.state]))
      return false
    end
  else
    -- If `service_id` is not 0, the acknowledgement is for a service.

    -- Return `false` if the service description is invalid or the service ID is nil.
    if not self:is_valid_service() then
      self.sc_logger:warning("[sc_event:is_valid_acknowledgement_event]: service with id: " .. tostring(self.event.service_id) .. " hasn't been validated")
      return false
    end

    -- Use the dedicated acknowledgement service status configuration or the general service status configuration.
    event_status = self.sc_common:ifnil_or_empty(self.params.ack_service_status, self.params.service_status)

    -- Return `false` if the event status is not accepted.
    if not self:is_valid_event_status(event_status) then
      self.sc_logger:warning("[sc_event:is_valid_acknowledgement_event]: service with id: " .. tostring(self.event.service_id)
        .. " hasn't a validated status. Status: " .. tostring(self.params.status_mapping[self.event.category][self.params.bbdo.elements.service_status.id][self.event.state]))
      return false
    end

    -- Return `false` if the service does not have an accepted severity.
    if not self:is_valid_service_severity() then
      self.sc_logger:warning("[sc_event:is_valid_acknowledgement_event]: service id: " .. tostring(self.event.service_id)
        .. ". host_id: " .. tostring(self.event.host_id) .. ". Service has not an accepted severity")
      return false
    end

    -- Return `false` if the service is not in an accepted service group.
    if not self:is_valid_servicegroup() then
      self.sc_logger:warning("[sc_event:is_valid_acknowledgement_event]: service_id: " .. tostring(self.event.service_id) .. " is not in an accepted servicegroup")
      return false
    end
  end

  -- Return `false` if the host is not in an accepted host group.
  if not self:is_valid_hostgroup() then
    self.sc_logger:warning("[sc_event:is_valid_acknowledgement_event]: service_id: " .. tostring(self.event.service_id)
      .. " is not in an accepted hostgroup. Host ID is: " .. tostring(self.event.host_id))
    return false
  end

  return true
end
--- Check if the event is a valid downtime event.
--- This method validates whether the event represents a legitimate downtime event.
--- It performs checks on the event type, host, author, poller, and other attributes to ensure the event meets the configured criteria.
--- Host and service-specific validations are applied based on the event type.
--- @return (boolean) Returns `true` if the event is a valid downtime event, `false` otherwise.
function ScEvent:is_valid_downtime_event()
  -- Return false if the event is not a start or end downtime event.
  if not self:is_downtime_event_useless() then
    self.sc_logger:debug("[sc_event:is_valid_downtime_event]: dropping downtime event because it is not a start nor end of downtime event.")
    return false
  end

  -- Return false if the host is invalid or host ID is nil.
  if not self:is_valid_host() then
    self.sc_logger:warning("[sc_event:is_valid_downtime_event]: host_id: " .. tostring(self.event.host_id) .. " hasn't been validated")
    return false
  end

  -- Return false if the downtime author is invalid.
  if not self:is_valid_author() then
    self.sc_logger:warning("[sc_event:is_valid_downtime_event]: downtime with internal ID: " .. tostring(self.event.internal_id)
      .. " is not made by a valid author. Author is: " .. tostring(self.event.author) .. " Accepted authors are: " .. self.params.accepted_authors)
    return false
  end

  -- Return false if the host is not monitored by an accepted poller.
  if not self:is_valid_poller() then
    self.sc_logger:warning("[sc_event:is_valid_downtime_event]: host_id: " .. tostring(self.event.host_id) .. " is not monitored from an accepted poller")
    return false
  end

  -- Check if the event is a host event.
  if self.event.type == 2 then
    -- Store the host downtime status in the event state for validation.
    self.event.state = self:get_downtime_host_status()

    -- Return false if the host downtime status is not accepted.
    if not self:is_valid_event_status(self.params.dt_host_status) then
      self.sc_logger:warning("[sc_event:is_valid_downtime_event]: host_id: " .. tostring(self.event.host_id)
        .. " do not have a validated status. Status: " .. tostring(self.params.status_mapping[self.event.category][self.event.element][self.event.type][self.event.state])
        .. " Accepted states are: " .. tostring(self.params.dt_host_status))
      return false
    end
  else
    -- Return false if the service description or service ID is invalid.
    if not self:is_valid_service() then
      self.sc_logger:warning("[sc_event:is_valid_service_status_event]: service with id: " .. tostring(self.event.service_id) .. " hasn't been validated")
      return false
    end

    -- Store the service downtime status in the event state for validation.
    self.event.state = self:get_downtime_service_status()

    -- Return false if the service downtime status is not accepted.
    if not self:is_valid_event_status(self.params.dt_service_status) then
      self.sc_logger:warning("[sc_event:is_valid_downtime_event]: service with id: " .. tostring(self.event.service_id)
        .. " hasn't a validated status. Status: " .. tostring(self.params.status_mapping[self.event.category][self.event.element][self.event.type][self.event.state])
        .. " Accepted states are: " .. tostring(self.params.dt_service_status))
      return false
    end

    -- Return false if the service severity is not accepted.
    if not self:is_valid_service_severity() then
      self.sc_logger:warning("[sc_event:is_valid_downtime_event]: service id: " .. tostring(self.event.service_id)
        .. ". host_id: " .. tostring(self.event.host_id) .. ". Service has not an accepted severity")
      return false
    end

    -- Return false if the service is not in an accepted service group.
    if not self:is_valid_servicegroup() then
      self.sc_logger:warning("[sc_event:is_valid_downtime_event]: service_id: " .. tostring(self.event.service_id) .. " is not in an accepted servicegroup")
      return false
    end
  end

  -- Return false if the host is not in an accepted host group.
  if not self:is_valid_hostgroup() then
    self.sc_logger:warning("[sc_event:is_valid_downtime_event]: service_id: " .. tostring(self.event.service_id)
      .. " is not in an accepted hostgroup. Host ID is: " .. tostring(self.event.host_id))
    return false
  end

  return true
end

--- Check if the author of a comment is valid based on contact alias in Centreon.
--- This method validates the event author against accepted and rejected author lists.
--- If both lists are empty or both are populated, the author is considered valid.
--- @return (boolean) Returns `true` if the author is valid, `false` otherwise.
function ScEvent:is_valid_author()
  -- Return true if both accepted and rejected author lists are empty or both are populated.
  local accepted_authors_isnotempty = self.params.accepted_authors ~= ""
  local rejected_authors_isnotempty = self.params.rejected_authors ~= ""
  if (not accepted_authors_isnotempty and not rejected_authors_isnotempty) or (accepted_authors_isnotempty and rejected_authors_isnotempty) then
    return true
  end

  -- Check if the author is in the accepted list.
  local accepted_author_name = self:find_author_in_list(self.params.accepted_authors)
  local rejected_author_name = self:find_author_in_list(self.params.rejected_authors)
  if accepted_authors_isnotempty and not accepted_author_name then
    self.sc_logger:debug("[sc_event:is_valid_author]: dropping event because author: " .. tostring(self.event.author)
      .. " is not in an accepted authors list. Accepted authors are: " .. self.params.accepted_authors)
    return false
  elseif rejected_authors_isnotempty and rejected_author_name then
    self.sc_logger:debug("[sc_event:is_valid_author]: dropping event because author: " .. tostring(self.event.author)
      .. " is in a rejected authors list. Rejected authors are: " .. self.params.rejected_authors)
    return false
  end

  return true
end
--- Compare accepted authors from parameters with the event author.
--- This method checks if the event's author matches any of the accepted authors provided in the list.
--- It splits the `authors_list` into individual author aliases and compares them with the event's author.
--- @param authors_list (string) A comma-separated list of author names.
--- @return (string|boolean) Returns the alias of the first matching author if found, or `false` if no match is found.
function ScEvent:find_author_in_list(authors_list)
  -- Return false if the authors list is nil or empty.
  if authors_list == nil or authors_list == "" then
    return false
  else
    -- Iterate through the list of author aliases and check for a match with the event's author.
    for _, author_alias in ipairs(self.sc_common:split(authors_list, ",")) do
      if author_alias == self.event.author then
        return author_alias
      end
    end
  end
  -- Return false if no matching author is found.
  return false
end

--- Retrieve the status of a host based on last_time_up/down dates found in cache.
--- This method determines the host's status by comparing the timestamps of its last known "up" and "down" states.
--- It uses the `get_most_recent_status_code` method to identify the most recent status.
--- @return (number|string) Returns the status code of the host, or "N/A" if the cache is not filled.
function ScEvent:get_downtime_host_status()
  -- Return "N/A" if the cache does not contain the required timestamps.
  if not self.event.cache.host.last_time_up or not self.event.cache.host.last_time_down then
    return "N/A"
  end

  -- Map the timestamps to their respective status codes.
  local timestamp = {
    [0] = tonumber(self.event.cache.host.last_time_up),
    [1] = tonumber(self.event.cache.host.last_time_down)
  }

  -- Retrieve the most recent status code based on the timestamps.
  return self:get_most_recent_status_code(timestamp)
end

--- Retrieve the status of a service based on last_time_ok/warning/critical/unknown dates found in cache.
--- This method determines the service's status by comparing the timestamps of its last known states.
--- It uses the `get_most_recent_status_code` method to identify the most recent status.
--- @return (number|string) Returns the status code of the service, or "N/A" if the cache is not filled.
function ScEvent:get_downtime_service_status()
  -- Return "N/A" if the cache does not contain the required timestamps.
  if
    not self.event.cache.service.last_time_ok
    or not self.event.cache.service.last_time_warning
    or not self.event.cache.service.last_time_critical
    or not self.event.cache.service.last_time_unknown
  then
    return "N/A"
  end

  -- Map the timestamps to their respective status codes.
  local timestamp = {
    [0] = tonumber(self.event.cache.service.last_time_ok),
    [1] = tonumber(self.event.cache.service.last_time_warning),
    [2] = tonumber(self.event.cache.service.last_time_critical),
    [3] = tonumber(self.event.cache.service.last_time_unknown)
  }

  -- Retrieve the most recent status code based on the timestamps.
  return self:get_most_recent_status_code(timestamp)
end

--- Retrieve the last status code from a list of status and timestamp.
--- This method iterates through a table of timestamps associated with status codes
--- and determines the most recent status code based on the highest timestamp value.
--- @param timestamp (table) A table where keys are status codes and values are their corresponding timestamps.
--- @return (number) The most recent status code based on the highest timestamp.
function ScEvent:get_most_recent_status_code(timestamp)

  -- Prepare the table to store the latest known status timestamp and status code.
  local status_info = {
    highest_timestamp = 0,
    status = nil
  }

  -- Iterate through the timestamps and find the most recent status code.
  for status_code, status_timestamp in ipairs(timestamp) do
    if status_timestamp > status_info.highest_timestamp then
      status_info.highest_timestamp = status_timestamp
      status_info.status = status_code
    end
  end

  return status_info.status
end

--- Check if the service status event is a duplicate.
--- This method determines whether the current service status event is identical to the previous one.
--- It does not work for transitions like OK(H) -> CRITICAL(S) -> OK(H).
--- @return (boolean) Returns `true` if the event is a duplicate, `false` otherwise.
function ScEvent:is_service_status_event_duplicated()
  -- Return false if the deduplication option is not activated.
  if self.params.enable_service_status_dedup ~= 1 then
    self.sc_logger:debug("[sc_event:is_service_status_event_duplicated]: Service status deduplication is not enabled. Option enable_service_status_dedup is set to: " .. tostring(self.params.enable_service_status_dedup))
    return false
  end

  -- Check if the last check timestamp is the same as the last hard state change timestamp.
  -- If true, the event is not a duplicate.
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

--- Check if the host status event is a duplicate.
--- This method determines whether the current host status event is identical to the previous one.
--- It does not work for transitions like UP(H) -> DOWN(S) -> UP(H).
--- @return boolean Returns `true` if the event is a duplicate, `false` otherwise.
function ScEvent:is_host_status_event_duplicated()
  -- Return false if the deduplication option is not activated.
  if self.params.enable_host_status_dedup ~= 1 then
    self.sc_logger:debug("[sc_event:is_host_status_event_duplicated]: host status deduplication is not enabled. Option enable_host_status_dedup is set to: " .. tostring(self.params.enable_host_status_dedup))
    return false
  end

  -- Check if the last check timestamp is the same as the last hard state change timestamp, allowing for a delta.
  -- If true, the event is not a duplicate.
  if math.abs(self.event.last_hard_state_change - self.event.last_check) <= self.params.delta_host_status_change_allow
      or (self.event.last_update ~= nil and math.abs(self.event.last_hard_state_change - self.event.last_update) <= self.params.delta_host_status_change_allow) then
    return false
  end

  -- If none of the above conditions are met, the event is considered a duplicate.
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

--- Filter out unnecessary downtime events.
--- This method checks whether a downtime event is valid and necessary.
--- It ensures that only start or end downtime events are processed.
--- @return boolean Returns `true` if the downtime event is valid, `false` otherwise.
function ScEvent:is_downtime_event_useless()
  -- Return true if the downtime event is a valid start of downtime event.
  if self:is_valid_downtime_event_start() then
    return true
  end

  -- Return true if the downtime event is a valid end of downtime event.
  if self:is_valid_downtime_event_end() then
    return true
  end

  -- If neither condition is met, the downtime event is considered unnecessary.
  return false
end

--- Make sure that the event is the one notifying us that a downtime has just started.
--- This method checks the `actual_end_time` and `actual_start_time` fields of the event to determine if it represents the start of a downtime.
--- It also applies compatibility patches for BBDO versions 2 and 3 to ensure proper handling of event IDs.
--- @return boolean Returns `true` if the event is a valid downtime start event, `false` otherwise.
function ScEvent:is_valid_downtime_event_start()
  -- Check if the event is about the end of the downtime.
  -- For BBDO version 3, `actual_end_time` should be -1. For BBDO version 2, it should not exist.
  if (self.bbdo_version > 2 and self.event.actual_end_time ~= -1) or (self.bbdo_version == 2 and self.event.actual_end_time) then
    self.sc_logger:debug("[sc_event:is_valid_downtime_event_start]: actual_end_time found in the downtime event and value equal to -1 or bbdo v2 in use. It can't be a downtime start event")
    return false
  end

  -- Check if the event has actually started.
  -- For BBDO version 2, `actual_start_time` must exist. For BBDO version 3, it must be a valid timestamp.
  if (not self.event.actual_start_time and self.bbdo_version == 2) or (self.event.actual_start_time == -1 and self.bbdo_version > 2) then
    self.sc_logger:debug("[sc_event:is_valid_downtime_event_start]: actual_start_time not found in the downtime event (or value set to -1). The downtime hasn't yet started")
    return false
  end

  -- Compatibility patch for BBDO versions 2 and 3.
  -- Ensure `internal_id` and `id` fields are properly set.
  if (not self.event.internal_id and self.event.id) then
    self.event.internal_id = self.event.id
  end

  if (not self.event.id and self.event.internal_id) then
    self.event.id = self.event.internal_id
  end

  return true
end

--- Make sure that the event is the one notifying us that a downtime has just ended.
--- This method checks the `deletion_time` field of the event to determine if it represents the end of a downtime.
--- It also applies compatibility patches for BBDO versions 2 and 3 to ensure proper handling of event IDs.
--- @return boolean Returns `true` if the event is a valid downtime end event, `false` otherwise.
function ScEvent:is_valid_downtime_event_end()
  -- Check if the event is about the end of the downtime.
  -- For BBDO version 2, `deletion_time` must exist. For BBDO version 3, it must not be -1.
  if (self.bbdo_version == 2 and self.event.deletion_time) or (self.bbdo_version > 2 and self.event.deletion_time ~= -1) then
    -- Compatibility patch for BBDO versions 2 and 3.
    -- Ensure `internal_id` and `id` fields are properly set.
    if (not self.event.internal_id and self.event.id) then
      self.event.internal_id = self.event.id
    end

    if (not self.event.id and self.event.internal_id) then
      self.event.id = self.event.internal_id
    end

    return true
  end

  -- Any other downtime event is not about the actual end of a downtime.
  self.sc_logger:debug("[sc_event:is_valid_downtime_event_end]: deletion_time not found in the downtime event or equal to -1. The downtime event is not about the end of a downtime")
  return false
end
--- Adds short_output and long_output entries in the event table.
--- This method processes the `output` field of the event table to generate `short_output` and `long_output` entries.
--- Depending on the configuration parameters, it modifies the `output` field to use either the short or long output,
--- replaces line breaks, or truncates the output to a specified size limit.
--- @return void
function ScEvent:build_outputs()
  -- build long output
  if self.event.long_output and self.event.long_output ~= "" then
    self.event.long_output = self.event.output .. "\n" .. self.event.long_output
  else
    self.event.long_output = self.event.output
  end

  -- no short output if there is no line break
  local short_output = string.match(self.event.output, "^(.*)\n")
  if short_output then
    self.event.short_output = short_output
  else
    self.event.short_output = self.event.output
  end

  -- use short output if it exists
  if self.params.use_long_output == 0 and short_output then
    self.event.output = short_output

  -- replace line break if asked to and we are not already using a short output
  elseif not short_output and self.params.remove_line_break_in_output == 1 then
    self.event.output = string.gsub(self.event.output, "\n", self.params.output_line_break_replacement_character)
  end

  if self.params.output_size_limit ~= "" then
    self.event.output = string.sub(self.event.output, 1, self.params.output_size_limit)
    self.event.short_output = string.sub(self.event.short_output, 1, self.params.output_size_limit)
  end

end

--- **DEPRECATED METHOD**
--- This method is deprecated and should not be used. It always returns `true`.
--- Use the NEB category to retrieve metric data instead.
--- @return boolean Always returns `true`.
function ScEvent:is_valid_storage_event()
  return true
end

return sc_event

