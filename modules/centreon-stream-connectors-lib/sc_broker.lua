#!/usr/bin/lua

--- 
-- Module with Centreon broker related methods for easier usage
-- @module sc_broker
-- @alias sc_broker

local sc_broker = {}

local sc_logger = require("centreon-stream-connectors-lib.sc_logger")

local ScBroker = {}

function sc_broker.new(logger)
  local self = {}
  
  self.logger = logger
  if not self.logger then 
    self.logger = sc_logger.new('/var/log/centreon-broker/stream-connector.log', 1, true)
  end

  setmetatable(self, { __index = ScBroker })

  return self
end


--- get_host_all_infos: retrieve all informations from a host 
-- @param host_id (number)
-- @return false (boolean) if host_id isn't valid or no information were found in broker cache
-- @return host_info (table) all the informations from the host
function ScBroker:get_host_all_infos(host_id)
  -- return because host_id isn't valid
  if host_id == nil or host_id == '' then
    self.logger:warning("[sc_broker:get_host_all_infos]: host id is nil")
    return false
  end
  
  -- get host information from broker cache
  local host_info = broker_cache:get_host(host_id)

  -- return false only if no host information were found in broker cache
  if not host_info then
    self.logger:warning("[sc_broker:get_host_all_infos]: No host information found for host_id:  " .. tostring(host_id) .. ". Restarting centengine should fix this.")  
    return false
  end

  return host_info
end

--- get_service_all_infos: retrieve informations from a service
-- @param host_id (number)
-- @params service_id (number)
-- @return false (boolean) if host id or service id aren't valid
-- @return service (table) all the informations from the service
function ScBroker:get_service_all_infos(host_id, service_id)
  -- return because host_id or service_id isn't valid
  if host_id == nil or host_id == '' or service_id == nil or service_id == '' then
    self.logger:warning("[sc_broker:get_host_infos]: host id o service id is nil")
    return false
  end
  
  -- get service information from broker cache
  local service_info = broker_cache:get_host(host_id)

  -- return false only if no service information were found in broker cache
  if not service_info then
    self.logger:warning("[sc_broker:get_service_all_infos]: No service information found for host_id:  " .. tostring(host_id) .. " and service_id: " .. tostring(service_id) .. ". Restarting centengine should fix this.")
    return false
  end

  return service_info
end

--- get_host_infos: retrieve the the desired host informations
-- @param host_id (number)
-- @params info (string|table) the name of the wanted host parameter or a table of all wanted host parameters
-- @return false (boolean) if host_id is nil or empty 
-- @return host {table} a table of all wanted host params
function ScBroker:get_host_infos(host_id, info)
  -- return because host_id isn't valid
  if host_id == nil or host_id == '' then
    self.logger:warning("[sc_broker:get_host_infos]: host id is nil")
    return false
  end
  
  -- prepare return table with host information
  local host = {
    host_id = host_id
  }

  -- return host_id only if no specific param is asked
  if info == nil then
    return host
  end

  -- get host information from broker cache
  local host_info = broker_cache:get_host(host_id)

  -- return host_id only if no host information were found in broker cache
  if not host_info then
    self.logger:warning("[sc_broker:get_host_infos]: No host information found for host_id:  " .. tostring(host_id) .. ". Restarting centengine should fix this.")  
    return host
  end

  -- get the desired param and return the information
  if type(info) == 'string' then
    if host_info[info] then
      host[info] = host_info[info]
    end

    return host
  end

  -- get all the desired params and return the information
  if type(info) == 'table' then
    for _, param in ipairs(info) do
      if host_info[param] then
        host[param] = host_info[param]
      end
    end

    return host
  end
end

--- get_service_infos: retrieve the the desired service informations
-- @param host_id (number)
-- @param service_id (number)
-- @params info (string|table) the name of the wanted host parameter or a table of all wanted service parameters
-- @return false (boolean) if host_id and/or service_id are nil or empty 
-- @return host {table} a table of all wanted service params
function ScBroker:get_service_infos(host_id, service_id, info)
  -- return because host_id or service_id isn't valid
  if host_id == nil or host_id == '' or service_id == nil or service_id == '' then
    self.logger:warning("[sc_broker:get_service_infos]: host id or service id is invalid")
    return false
  end
  
  -- prepare return table with service information
  local service = {
    host_id = host_id,
    service_id = service_id
  }

  -- return host_id and service_id only if no specific param is asked
  if info == nil then
    return service
  end

  -- get service information from broker cache
  local service_info = broker_cache:get_service(host_id, service_id)

  -- return host_id and service_id only if no host information were found in broker cache
  if not service_info then
    self.logger:warning("[sc_broker:get_service_infos]: No service information found for host_id:  " .. tostring(host_id) .. " and service_id: " .. tostring(service_id) .. ". Restarting centengine should fix this.")  
    return service
  end

  -- get the desired param and return the information
  if type(info) == 'string' then
    if service_info[info] then
      service[info] = service_info[info]
    end

    return service
  end

  -- get all the desired params and return the information
  if type(info) == 'table' then
    for _, param in ipairs(info) do
      if service_info[param] then
        service[param] = service_info[param]
      end
    end

    return service
  end
end

return sc_test