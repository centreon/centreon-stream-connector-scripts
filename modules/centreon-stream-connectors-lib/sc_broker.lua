#!/usr/bin/lua

--- 
-- Module with Centreon broker related methods for easier usage
-- @module sc_broker
-- @alias sc_broker

local sc_broker = {}

local sc_logger = require("centreon-stream-connectors-lib.sc_logger")

local ScBroker = {}

function sc_broker.new(params, logger)
  local self = {}
  
  broker_api_version = 2
  
  self.sc_logger = logger
  if not self.sc_logger then 
    self.sc_logger = sc_logger.new()
  end

  self.params = params

  if params.enable_broker_cache_counter_check == 1 then
    if pcall(require, "luasql.mysql") then
      local db = require("luasql.mysql")
      local db_driver = db.mysql()
      local centreon_db, error = db_driver:connect(params.centreon_db_name, params.centreon_db_user, params.centreon_db_password, params.centreon_db_address, params.centreon_db_port)
      
      if not centreon_db then
        self.sc_logger:error("[sc_broker:new]: couldn't connect to " .. tostring(params.centreon_db_name) .. ". Error is: " .. tostring(error)
          .. "make sure that your parameters are valid: centreon_db_user: " .. tostring(params.centreon_db_user) .. ", centreon_db_address: " .. tostring(params.centreon_db_address) .. ", centreon_db_port: " .. tostring(params.centreon_db_port))
      else
        self.centreon_db = centreon_db
      end
    else
      self.sc_logger:error("[sc_broker:new]: couldn't load luasql.mysql module and you asked for it by using the enable_broker_cache_counter_check parameter."
        .. " Make sure that you have installed this dependency. We are disabling the aformentioned parameter.")
    end
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
  if host_id == nil or host_id == "" then
    self.sc_logger:warning("[sc_broker:get_host_all_infos]: host id is nil")
    return false
  end
  
  -- get host information from broker cache
  local host_info = broker_cache:get_host(host_id)

  -- return false only if no host information were found in broker cache
  if not host_info and self.params.enable_broker_cache_counter_check ~= 1 then
    self.sc_logger:warning("[sc_broker:get_host_all_infos]: No host information found for host_id:  " .. tostring(host_id) .. ". Restarting centengine should fix this.")  
    return false

  -- user is asking to also check in the database for the host. if we find it, we return a limited set of value (the most common ones)
  elseif not host_info and self.params.enable_broker_cache_counter_check == 1 then
    local query = [[
      SELECT h.host_id, 
        h.host_name AS name, 
        h.host_alias AS alias, 
        h.host_address AS address, 
        h.display_name,
        ehi.ehi_notes AS notes,
        ehi.ehi_notes_url AS notes_url,
        ehi.ehi_action_url AS action_url 
      FROM host h,
        extended_host_information ehi
      WHERE ehi.host_host_id = h.host_id
        AND h.host_activate <> '0'
        AND h.host_id = ]] .. tonumber(host_id)

    self.sc_logger:debug("[sc_broker:get_host_all_infos]: no information found in broker cache for host: " .. tostring(host_id) .. ", going to check in the centreon database with query: " .. tostring(query))

    host_info = self:get_centreon_db_info(query)

    if not host_info then
      self.sc_logger:error("[sc_broker:get_host_all_infos]: couldn't find host: " .. tostring(host_id) 
        .. " in your database. Maybe it has been disabled or removed. You should export your configuration.")
      return false
    end
  end

  return host_info
end

--- get_service_all_infos: retrieve informations from a service
-- @param host_id (number)
-- @param service_id (number)
-- @return false (boolean) if host id or service id aren't valid
-- @return service (table) all the informations from the service
function ScBroker:get_service_all_infos(host_id, service_id)
  -- return because host_id or service_id isn't valid
  if host_id == nil or host_id == "" or service_id == nil or service_id == "" then
    self.sc_logger:warning("[sc_broker:get_service_all_infos]: host id or service id is nil")
    return false
  end
  
  -- get service information from broker cache
  local service_info = broker_cache:get_service(host_id, service_id)

  -- return false only if no service information were found in broker cache
  if not service_info and self.params.enable_broker_cache_counter_check ~= 1 then
    self.sc_logger:warning("[sc_broker:get_service_all_infos]: No service information found for host_id:  " .. tostring(host_id) 
      .. " and service_id: " .. tostring(service_id) .. ". Restarting centengine should fix this.")
    return false
  elseif not service_info and self.params.enable_broker_cache_counter_check == 1 then
    local query = [[
      SELECT s.service_id, 
        s.service_description AS description, 
        s.service_alias AS alias, 
        s.display_name,
        esi.esi_notes AS notes,
        esi.esi_notes_url AS notes_url,
        esi.esi_action_url AS action_url 
      FROM service s,
        extended_service_information esi
      WHERE esi.service_service_id = s.service_id
        AND s.service_activate <> '0'
        AND s.service_id = ]] .. tonumber(service_id)

    self.sc_logger:debug("[sc_broker:get_host_all_infos]: no information found in broker cache for service: " .. tostring(service_id) .. ", going to check in the centreon database with query: " .. tostring(query))


    service_info = self:get_centreon_db_info(query)

    if not service_info then
      self.sc_logger:error("[sc_broker:get_host_all_infos]: couldn't find service: " .. tostring(service_id) 
        .. " in your database. Maybe it has been disabled or removed. You should export your configuration.")
      return false
    end
  end

  return service_info
end

--- get_host_infos: retrieve the the desired host informations
-- @param host_id (number)
-- @param info (string|table) the name of the wanted host parameter or a table of all wanted host parameters
-- @return false (boolean) if host_id is nil or empty 
-- @return host (any) a table of all wanted host params if input param is a table. The single parameter if input param is a string 
function ScBroker:get_host_infos(host_id, info)
  -- return because host_id isn't valid
  if host_id == nil or host_id == "" then
    self.sc_logger:warning("[sc_broker:get_host_infos]: host id is nil")
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
    self.sc_logger:warning("[sc_broker:get_host_infos]: No host information found for host_id:  " .. tostring(host_id) .. ". Restarting centengine should fix this.")  
    return host
  end

  -- get the desired param and return the information
  if type(info) == "string" then
    if host_info[info] then
      return host_info[info]
    end
  end

  -- get all the desired params and return the information
  if type(info) == "table" then
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
-- @param info (string|table) the name of the wanted host parameter or a table of all wanted service parameters
-- @return false (boolean) if host_id and/or service_id are nil or empty 
-- @return service (any) a table of all wanted service params if input param is a table. A single parameter if input param is a string 
function ScBroker:get_service_infos(host_id, service_id, info)
  -- return because host_id or service_id isn't valid
  if host_id == nil or host_id == "" or service_id == nil or service_id == "" then
    self.sc_logger:warning("[sc_broker:get_service_infos]: host id or service id is invalid")
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
    self.sc_logger:warning("[sc_broker:get_service_infos]: No service information found for host_id:  " .. tostring(host_id) .. " and service_id: " .. tostring(service_id) 
      .. ". Restarting centengine should fix this.")  
    return service
  end

  -- get the desired param and return the information
  if type(info) == "string" then
    if service_info[info] then
      return service_info[info]
    end
  end

  -- get all the desired params and return the information
  if type(info) == "table" then
    for _, param in ipairs(info) do
      if service_info[param] then
        service[param] = service_info[param]
      end
    end

    return service
  end
end

--- get_hostgroups: retrieve hostgroups from host_id
-- @param host_id (number)
-- @return false (boolean) if host id is invalid or no hostgroup found
-- @return hostgroups (table) a table of all hostgroups for the host 
function ScBroker:get_hostgroups(host_id)
  -- return false if host id is invalid
  if host_id == nil or host_id == "" then 
    self.sc_logger:warning("[sc_broker:get_hostgroup]: host id is nil or empty")
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

--- get_servicegroups: retrieve servicegroups from service_id
-- @param host_id (number)
-- @param service_id (number)
-- @return false (boolean) if host_id or service_id are invalid or no service group found
-- @return servicegroups (table) a table of all servicegroups for the service
function ScBroker:get_servicegroups(host_id, service_id)
  -- return false if service id is invalid
  if host_id == nil or host_id == "" or service_id == nil or service_id == "" then 
    self.sc_logger:warning("[sc_broker:get_servicegroups]: service id is nil or empty")
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

--- get_severity: retrieve severity from host or service
-- @param host_id (number)
-- @param [opt] service_id (number)
-- @return false (boolean) if host id is invalid or no severity were found
-- @return severity (table) all the severity from the host or the service 
function ScBroker:get_severity(host_id, service_id)
  -- return false if host id is invalid
  if host_id == nil or host_id == "" then 
    self.sc_logger:warning("[sc_broker:get_severity]: host id is nil or empty")
    return false
  end

  local service_id = service_id or nil
  local severity = nil

  -- get host severity
  if service_id == nil then
    severity = broker_cache:get_severity(host_id)

    -- return false if no severity were found
    if not severity then
      self.sc_logger:warning("[sc_broker:get_severity]: no severity found in broker cache for host: " .. tostring(host_id))
      return false
    end

    return severity
  end

  -- get severity for service
  severity = broker_cache:get_severity(host_id, service_id)

  -- return false if no severity were found
  if not severity then
    self.sc_logger:warning("[sc_broker:get_severity]: no severity found in broker cache for host id: " .. tostring(host_id) .. " and service id: " .. tostring(service_id))
    return false
  end

  return severity
end

--- get_instance: retrieve poller from instance_id
-- @param host_id (number)
-- @return false (boolean) if host_id is invalid or no instance found in cache
-- @return name (string) the name of the instance
function ScBroker:get_instance(instance_id)
  -- return false if instance_id is invalid
  if instance_id == nil or instance_id == "" then
    self.sc_logger:warning("[sc_broker:get_instance]: instance id is nil or empty")
    return false
  end

  -- get instance name
  local name = broker_cache:get_instance_name(instance_id)

  -- return false if no instance name is found
  if not name then
    self.sc_logger:warning("[sc_broker:get_instance]: couldn't get instance name from broker cache for instance id: " .. tostring(instance_id))
    return false
  end

  return name
end

--- get_ba_info: retrieve ba name and description from ba id
-- @param ba_id (number)
-- @return false (boolean) if the ba_id is invalid or no information were found in the broker cache
-- @return ba_info (table) a table with the name and description of the ba
function ScBroker:get_ba_infos(ba_id)
  -- return false if ba_id is invalid
  if ba_id == nil or ba_id == "" then 
    self.sc_logger:warning("[sc_broker:get_ba_infos]: ba id is nil or empty")
    return false
  end

  -- get ba info
  local ba_info = broker_cache:get_ba(ba_id)

  -- return false if no informations are found
  if ba_info == nil then
    self.sc_logger:warning("[sc_broker:get_ba_infos]: couldn't get ba informations in cache for ba_id: " .. tostring(ba_id))
    return false
  end

  return ba_info
end

--- get_bvs_infos: retrieve bv name and description from ba_id
-- @param ba_id (number) 
-- @param false (boolean) if ba_id is invalid or no information are found in the broker_cache
-- @return bvs (table) name and description of all the bvs 
function ScBroker:get_bvs_infos(ba_id)
  -- return false if ba_id is invalid
  if ba_id == nil or ba_id == "" then 
    self.sc_logger:warning("[sc_broker:get_bvs]: ba id is nil or empty")
    return false
  end

  -- get bvs id
  local bvs_id = broker_cache:get_bvs(ba_id)

  -- return false if no bv id are found for ba_id
  if bvs_id == nil or bvs_id == "" then
    self.sc_logger:warning("[sc_broker:get_bvs]: couldn't get bvs for ba id: " .. tostring(ba_id))
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
      self.sc_logger:warning("[sc_broker:get_bvs]: couldn't get bv information for bv id: " .. tostring(bv_id))
    end
  end

  -- return false if there are no bv information
  if not found_bv then
    return false
  end

  return bvs
end

--- get_centreon_db_info: run a query (that must return only one row) in the centreon database to build a cache from the db when asking to. If the query return multiple rows, only the last one will be returned
-- @param query (string) the sql query that must be executed to build the cache 
-- @return result (table or nil) the result of the query or nil 
function ScBroker:get_centreon_db_info(query)
  local result, error = self.centreon_db:execute(query)

  if not result then
    self.sc_logger:error("[sc_broker:get_centreon_db_info]: query: " .. tostring(query) .. " failed\n error: " .. tostring(error))
    return nil
  end

  local rows = result:fetch({}, "a")
  local db_content

  -- queries are about a single object, we should never have multiple rows returned so we don't care about properly indexing results
  while rows do
    db_content = rows
    rows = result:fetch(rows, "a")
  end

  return db_content
end

return sc_broker
