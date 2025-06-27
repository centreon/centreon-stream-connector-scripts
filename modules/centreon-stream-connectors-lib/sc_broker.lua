#!/usr/bin/lua

--- Module providing utility methods to interact with the Centreon broker.
--- Facilitates retrieval of information about hosts, services, groups, severities, instances, BAs, and BVs.
--- @module sc_broker

local sc_broker = {}

local sc_logger = require("centreon-stream-connectors-lib.sc_logger")

local ScBroker = {}

function sc_broker.new(logger)
  local self = {}

  self.logger = logger
  if not self.logger then 
    self.logger = sc_logger.new()
  end

  setmetatable(self, { __index = ScBroker })

  return self
end


--- This function interacts with the broker cache to fetch all available information for a given host.
--- If the host ID is invalid or no information is found, it logs a warning and returns `false`.
--- @param host_id number ID of the host to retrieve information for
--- @return boolean|table Returns `false` if the host ID is invalid or no information is found in the broker cache.
--- Returns a table containing all information about the host if successful.
function ScBroker:get_host_all_infos(host_id)
  -- Check if the host_id is valid (not nil or empty)
  if host_id == nil or host_id == "" then
    self.logger:warning("[sc_broker:get_host_all_infos]: host id is nil")
    return false
  end

  -- Retrieve host information from the broker cache
  local host_info = broker_cache:get_host(host_id)

  -- Check if host information was found in the broker cache
  if not host_info then
    self.logger:warning("[sc_broker:get_host_all_infos]: No host information found for host_id:  " .. tostring(host_id) .. ". Restarting centengine should fix this.")
    return false
  end

  return host_info
end

--- Retrieves all available information for a specific service from the broker cache.
--- Logs a warning and returns `false` if the host or service ID is invalid or if no information is found.
--- @param host_id number The ID of the host associated with the service.
--- @param service_id number The ID of the service to retrieve information for.
--- @return table|boolean Returns a table with all service information if successful, or `false` if the IDs are invalid or no data is found.
function ScBroker:get_service_all_infos(host_id, service_id)
  -- return because host_id or service_id isn't valid
  if host_id == nil or host_id == "" or service_id == nil or service_id == "" then
    self.logger:warning("[sc_broker:get_service_all_infos]: host id or service id is nil")
    return false
  end
  
  -- get service information from broker cache
  local service_info = broker_cache:get_service(host_id, service_id)

  -- return false only if no service information were found in broker cache
  if not service_info then
    self.logger:warning("[sc_broker:get_service_all_infos]: No service information found for host_id:  " .. tostring(host_id) 
      .. " and service_id: " .. tostring(service_id) .. ". Restarting centengine should fix this.")
    return false
  end

  return service_info
end

--- Retrieves the desired information about a host from the broker cache.
--- If the host ID is invalid or empty, logs a warning and returns `false`.
--- If no specific parameter is requested, returns a table with only the host ID.
--- If the host is not found in the cache, returns a table with only the host ID.
--- If a string is provided as `info`, returns the corresponding parameter value if it exists.
--- If a table is provided as `info`, returns a table with the requested parameters.
--- @param host_id number ID of the host.
--- @param info string|table Name of the desired host parameter (string) or a table of all desired host parameters.
--- @return boolean|table Table of all requested host parameters if `info` is a table, the single parameter if `info` is a string, or `false` if `host_id` is nil or empty.
function ScBroker:get_host_infos(host_id, info)
  -- Return false if host_id is not valid
  if host_id == nil or host_id == "" then
    self.logger:warning("[sc_broker:get_host_infos]: host id is nil")
    return false
  end

  -- Prepare return table with host_id
  local host = {
    host_id = host_id
  }

  -- Return host_id only if no specific parameter is requested
  if info == nil then
    return host
  end

  -- Get host information from broker cache
  local host_info = broker_cache:get_host(host_id)

  -- Return host_id only if no host information was found in broker cache
  if not host_info then
    self.logger:warning("[sc_broker:get_host_infos]: No host information found for host_id:  " .. tostring(host_id) .. ". Restarting centengine should fix this.")
    return host
  end

  -- Get the desired parameter and return the information
  if type(info) == "string" then
    if host_info[info] then
      return host_info[info]
    end
  end

  -- Get all the desired parameters and return the information
  if type(info) == "table" then
    for _, param in ipairs(info) do
      if host_info[param] then
        host[param] = host_info[param]
      end
    end

    return host
  end
end

--- Retrieve the the desired service informations
--- This function fetches specific service information from the broker cache based on the provided host ID, service ID, and requested parameters.
--- Logs warnings if the host ID or service ID is invalid or if no service information is found in the broker cache.
--- @param host_id number ID of the host
--- @param service_id number ID of the service
--- @param info string|table The name of the desired service parameter (string) or a table of all desired service parameters
--- @return boolean|table Returns a table containing the requested service parameters if successful.
--- Returns a single parameter if `info` is a string. Returns `false` if `host_id` or `service_id` are invalid or empty.
function ScBroker:get_service_infos(host_id, service_id, info)
  -- Return false if host_id or service_id is invalid
  if host_id == nil or host_id == "" or service_id == nil or service_id == "" then
    self.logger:warning("[sc_broker:get_service_infos]: host id or service id is invalid")
    return false
  end

  -- Prepare a return table with basic service information
  local service = {
    host_id = host_id,
    service_id = service_id
  }

  -- Return basic service information if no specific parameter is requested
  if info == nil then
    return service
  end

  -- Retrieve service information from the broker cache
  local service_info = broker_cache:get_service(host_id, service_id)

  -- Return basic service information if no data is found in the broker cache
  if not service_info then
    self.logger:warning("[sc_broker:get_service_infos]: No service information found for host_id:  " .. tostring(host_id) .. " and service_id: " .. tostring(service_id)
      .. ". Restarting centengine should fix this.")
    return service
  end

  -- Retrieve and return the requested parameter if `info` is a string
  if type(info) == "string" then
    if service_info[info] then
      return service_info[info]
    end
  end

  -- Retrieve and return all requested parameters if `info` is a table
  if type(info) == "table" then
    for _, param in ipairs(info) do
      if service_info[param] then
        service[param] = service_info[param]
      end
    end

    return service
  end
end

--- Retrieve hostgroups from host_id
--- This function fetches all hostgroups associated with a given host ID from the broker cache.
--- Logs a warning if the host ID is invalid or empty, and returns `false` if no hostgroups are found.
--- @param host_id number ID of the host
--- @return boolean|table Returns a table containing all hostgroups of the host if successful.
--- Returns `false` if the host ID is invalid or no hostgroups are found.
function ScBroker:get_hostgroups(host_id)
  -- return false if host id is invalid
  if host_id == nil or host_id == "" then 
    self.logger:warning("[sc_broker:get_hostgroup]: host id is nil or empty")
    return false
  end

  -- get hostgroups
  local hostgroups = broker_cache:get_hostgroups(host_id)

  -- return false if no hostgroups were found
  if not hostgroups then
    return false
  end
  
  return hostgroups
end

--- Retrieve hostgroup alias from hostgroup_id
--- This function fetches the alias of a specific hostgroup based on its ID from the broker cache.
--- Logs a warning if the hostgroup ID is invalid or empty, and returns `false` if no alias is found.
--- @param hostgroup_id number ID of the host group
--- @return boolean|string Returns the alias of the hostgroup if successful.
--- Returns `false` if the hostgroup ID is invalid or no alias is found.
function ScBroker:get_hostgroup_alias(hostgroup_id)
  -- return false if host id is invalid
  if hostgroup_id == nil or hostgroup_id == "" then
    self.logger:warning("[sc_broker:get_hostgroup_alias]: hostgroup_id is nil or empty")
    return false
  end

  -- get hostgroup alias
  local alias = broker_cache:get_hostgroup_alias(hostgroup_id)

  -- return false if no hostgroups were found
  if not alias then
    return false
  end

  return alias
end

--- Retrieve servicegroups from service_id
--- This function fetches all servicegroups associated with a given service ID and host ID from the broker cache.
--- Logs a warning if the host ID or service ID is invalid or empty, and returns `false` if no servicegroups are found.
--- @param host_id number ID of the host
--- @param service_id number ID of the service
--- @return boolean|table Returns a table containing all servicegroups of the service if successful.
--- Returns `false` if the host ID or service ID is invalid or no servicegroups are found.
function ScBroker:get_servicegroups(host_id, service_id)
  -- return false if service id is invalid
  if host_id == nil or host_id == "" or service_id == nil or service_id == "" then 
    self.logger:warning("[sc_broker:get_servicegroups]: service id is nil or empty")
    return false
  end

  -- get servicegroups
  local servicegroups = broker_cache:get_servicegroups(host_id, service_id)

  -- return false if no servicegroups were found
  if not servicegroups then
    return false
  end
  
  return servicegroups
end

--- Retrieve severity from host or service
--- This function fetches the severity level of a host or service from the broker cache.
--- Logs a warning if the host ID is invalid or empty, and returns `false` if no severity is found.
--- If a service ID is provided, it retrieves the severity for the service; otherwise, it retrieves the severity for the host.
--- @param host_id number ID of the host
--- @param service_id number OPTIONAL: ID of the service (do not use for a host)
--- @return boolean|table Returns the severity of the host or service if successful.
--- Returns `false` if the host ID is invalid or no severity is found.
function ScBroker:get_severity(host_id, service_id)
  -- return false if host id is invalid
  if host_id == nil or host_id == "" then 
    self.logger:warning("[sc_broker:get_severity]: host id is nil or empty")
    return false
  end

  local service_id = service_id or nil
  local severity = nil

  -- get host severity
  if service_id == nil then
    severity = broker_cache:get_severity(host_id)

    -- return false if no severity were found
    if not severity then
      self.logger:warning("[sc_broker:get_severity]: no severity found in broker cache for host: " .. tostring(host_id))
      return false
    end

    return severity
  end

  -- get severity for service
  severity = broker_cache:get_severity(host_id, service_id)

  -- return false if no severity were found
  if not severity then
    self.logger:warning("[sc_broker:get_severity]: no severity found in broker cache for host id: " .. tostring(host_id) .. " and service id: " .. tostring(service_id))
    return false
  end

  return severity
end

--- Retrieve poller information from instance ID
--- This function fetches the name of the poller/instance associated with a given instance ID from the broker cache.
--- Logs a warning if the instance ID is invalid or empty, and returns `false` if no information is found.
--- @param instance_id number ID of the instance
--- @return boolean|string Returns the name of the poller/instance if successful.
--- Returns `false` if the instance ID is invalid or no information is found in the broker cache.
function ScBroker:get_instance(instance_id)
  -- return false if instance_id is invalid
  if instance_id == nil or instance_id == "" then
    self.logger:warning("[sc_broker:get_instance]: instance id is nil or empty")
    return false
  end

  -- get instance name
  local name = broker_cache:get_instance_name(instance_id)

  -- return false if no instance name is found
  if not name then
    self.logger:warning("[sc_broker:get_instance]: couldn't get instance name from broker cache for instance id: " .. tostring(instance_id))
    return false
  end

  return name
end

--- Retrieve BA information from BA ID
--- This function fetches the name and description of a specific Business Activity (BA) based on its ID from the broker cache.
--- Logs a warning if the BA ID is invalid or empty, and returns `false` if no information is found.
--- @param ba_id number ID of the Business Activity (BA)
--- @return boolean|table Returns a table containing the name and description of the BA if successful.
--- Returns `false` if the BA ID is invalid or no information is found in the broker cache.
function ScBroker:get_ba_infos(ba_id)
  -- return false if ba_id is invalid
  if ba_id == nil or ba_id == "" then 
    self.logger:warning("[sc_broker:get_ba_infos]: ba id is nil or empty")
    return false
  end

  -- get ba info
  local ba_info = broker_cache:get_ba(ba_id)

  -- return false if no informations are found
  if ba_info == nil then
    self.logger:warning("[sc_broker:get_ba_infos]: couldn't get ba informations in cache for ba_id: " .. tostring(ba_id))
    return false
  end

  return ba_info
end

--- Retrieve Business View (BV) names and descriptions associated with a given Business Activity (BA) ID.
--- This function interacts with the broker cache to fetch all BV information linked to the specified BA ID.
--- Logs warnings if the BA ID is invalid or empty, or if no BV information is found.
--- @param ba_id number ID of the Business Activity (BA).
--- @return boolean|table Returns a table containing names and descriptions of all BVs if successful.
--- Returns `false` if the BA ID is invalid or no BV information is found in the broker cache.
function ScBroker:get_bvs_infos(ba_id)
  -- return false if ba_id is invalid
  if ba_id == nil or ba_id == "" then 
    self.logger:warning("[sc_broker:get_bvs]: ba id is nil or empty")
    return false
  end

  -- get bvs id
  local bvs_id = broker_cache:get_bvs(ba_id)

  -- return false if no bv id are found for ba_id
  if bvs_id == nil or bvs_id == "" then
    self.logger:warning("[sc_broker:get_bvs]: couldn't get bvs for ba id: " .. tostring(ba_id))
    return false
  end

  local bv_infos = nil
  local found_bv = false
  local bvs = {}

  -- get bv info (name + description) for each found bv
  for _, id in ipairs(bvs_id) do
    bv_infos = broker_cache:get_bv(id)

    -- add bv information to the list
    if bv_infos then
      table.insert(bvs,bv_infos)
      found_bv = true
    else 
      self.logger:warning("[sc_broker:get_bvs]: couldn't get bv information for bv id: " .. tostring(bv_id))
    end
  end

  -- return false if there are no bv information
  if not found_bv then
    return false
  end

  return bvs
end

return sc_broker
