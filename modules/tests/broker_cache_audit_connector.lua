--[[
  broker cache audit connector (test tool)

  Every audit_frequency hours, compares the pollers, hosts, services, hostgroups and servicegroups
  found in the centreon_storage database with the content of the broker cache.
  The result is written as json in <log_directory>/cache-audit-result.<timestamp>.json
  and only the audit_retention most recent files are kept.
  The json has one entry per object type (pollers, hosts, services, host_groups, service_groups)
  and a metadata entry with the number of missing objects of each type.

  Parameters:

  | name                           | type   | mandatory | default                                  | description                                                                   |
  |--------------------------------|--------|-----------|------------------------------------------|-------------------------------------------------------------------------------|
  | sc_database.mysql.db_password  | string | yes       |                                          | password of the database user                                                 |
  | sc_database.mysql.db_address   | string | yes       |                                          | database address                                                              |
  | sc_database.mysql.db_user      | string | no        | centreon                                 | database user                                                                 |
  | sc_database.mysql.db_name      | string | no        | centreon_storage                         | database name                                                                 |
  | sc_database.mysql.db_port      | number | no        | 3306                                     | database port                                                                 |
  | audit_frequency                | number | no        | 4                                        | time between two audits, in hours                                             |
  | audit_retention                | number | no        | 12                                       | number of audit result files to keep in log_directory                         |
  | only_log_missing_objects       | number | no        | 1                                        | 1: only put missing objects in the result, 0: put every object                |
  | log_directory                  | string | no        | /var/log/centreon-broker/                | directory where the audit result files are written                            |
  | force_json_into_logfile        | number | no        | 1                                        | 1: write the result in logfile if the result file can't be written, 0: don't |
  | logfile                        | string | no        | /var/log/centreon-broker/cache_audit.log | log file of the connector                                                     |
  | log_level                      | number | no        | 1                                        | log level of the connector (1 to 3)                                           |
]]

local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_params = require("centreon-stream-connectors-lib.sc_params")
local sc_trigger = require("centreon-stream-connectors-lib.sc_trigger")
local sc_database = require("centreon-stream-connectors-lib.sc_database")

local EventQueue = {}
EventQueue.__index = EventQueue

--- EventQueue.new: create the EventQueue object, set default parameters and initialize lib objects (logger, params, trigger, database)
-- @param params (table) the stream connector parameters from the broker output configuration
-- @return self (table) the EventQueue object
function EventQueue.new(params)
  local self = {}
  local mandatory_parameters = {
    "sc_database.mysql.db_password",
    "sc_database.mysql.db_address"
  }
  self.last_update = 0

  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/cache_audit.log"
  local log_level = params.log_level or 1
  
  -- initiate mandatory objects
  self.sc_logger = sc_logger.new(logfile, log_level)
  self.sc_common = sc_common.new(self.sc_logger)
  self.sc_broker = sc_broker.new(self.sc_logger)
  self.sc_params = sc_params.new(self.sc_common, self.sc_logger)


  if type(params.audit_frequency) == "number" then
    -- convert value into seconds
    params.audit_frequency = params.audit_frequency * 3600
  else
    params.audit_frequency = nil
  end

  self.sc_params.params.only_log_missing_objects = params.only_log_missing_objects or 1
  self.sc_params.params["sc_database.mysql.db_name"] = params["sc_database.mysql.db_name"] or "centreon_storage"
  self.sc_params.params["sc_database.mysql.db_user"] = params["sc_database.mysql.db_user"] or "centreon"
  self.sc_params.params.log_directory = params.log_directory or "/var/log/centreon-broker/"
  self.sc_params.params.audit_retention = params.audit_retention or 12
  self.sc_params.params.force_json_into_logfile = params.force_json_into_logfile or 1
  self.sc_params.params.audit_frequency = params.audit_frequency or 4 * 3600

  -- checking mandatory parameters and setting a fail flag
  if not self.sc_params:is_mandatory_config_set(mandatory_parameters, params) then
    self.fail = true
  end

  self.sc_params:param_override(params)
  self.sc_params:check_params()

  self.sc_trigger = sc_trigger.new(self.sc_params.params, self.sc_common, self.sc_logger)
  self.sc_database = sc_database.new("mysql", self.sc_common, self.sc_logger, self.sc_trigger, self.sc_params.params)

  -- return EventQueue object
  setmetatable(self, { __index = EventQueue })
  return self
end

--- EventQueue:check_poller_cache: check that every non deleted poller from the database is present in the broker cache
-- results are stored in self.audit_result.pollers (only missing pollers if only_log_missing_objects is 1)
-- and the number of missing pollers in self.audit_result.metadata.poller_missing
-- @return false (boolean) if the database query failed
function EventQueue:check_poller_cache()
  local query = "select instance_id, name from instances where deleted = 0"
  local result = self.sc_database:execute(query)
  
  if not result then
    return false
  end

  for index, poller_info in ipairs(result) do
    local status = "present"
    local cache = broker_cache:get_instance_name(poller_info.instance_id)

    if not cache then
      status = "missing"
      self.audit_result.metadata.poller_missing = self.audit_result.metadata.poller_missing + 1
    end

    if self.sc_params.params.only_log_missing_objects == 1 and status == "present" then
      -- do nothing
    else
      self.audit_result.pollers[poller_info.instance_id] = {
        status = status,
        name = poller_info.name
      }
    end
  end
end

--- EventQueue:check_host_cache: check that every enabled host from the database is present in the broker cache
-- results are stored in self.audit_result.hosts (only missing hosts if only_log_missing_objects is 1)
-- and the number of missing hosts in self.audit_result.metadata.host_missing
-- every host name is also stored in self.full_host_list so check_service_cache() can resolve it
-- @return false (boolean) if the database query failed
function EventQueue:check_host_cache()
  local query = "select host_id, name from hosts where enabled = 1"
  local result = self.sc_database:execute(query)
  self.full_host_list = {}
  
  if not result then 
    return false
  end
  
  for index, host_info in ipairs(result) do
    local status = "present"
    local cache = broker_cache:get_hostname(host_info.host_id)

    if not cache then
      status = "missing"
      self.audit_result.metadata.host_missing = self.audit_result.metadata.host_missing + 1
    end

    if self.sc_params.params.only_log_missing_objects == 1 and status == "present" then
      self.full_host_list[host_info.host_id] = host_info.name
    else
      self.full_host_list[host_info.host_id] = host_info.name
      self.audit_result.hosts[host_info.host_id] = {
        status = status,
        name = host_info.name
      }
    end
  end
end

--- EventQueue:check_service_cache: check that every enabled service from the database is present in the broker cache
-- results are stored in self.audit_result.services (only missing services if only_log_missing_objects is 1)
-- and the number of missing services in self.audit_result.metadata.service_missing
-- must be called after check_host_cache() since it uses self.full_host_list to resolve host names
-- @return false (boolean) if the database query failed
function EventQueue:check_service_cache()
  local query = "select host_id, service_id, description from services where enabled = 1"
  local result = self.sc_database:execute(query)
  
  if not result then
    return false
  end

  local missing_hosts = {}
  
  for index, service_info in ipairs(result) do
    local status = "present"
    local cache = broker_cache:get_service_description(service_info.host_id, service_info.service_id)

    if not cache then
      status = "missing"
      self.audit_result.metadata.service_missing = self.audit_result.metadata.service_missing + 1
    end

    if not self.full_host_list[service_info.host_id] then
      -- only log the missing error once for each host instead of logging a hundred time for the same host if there are a hundred service linked to said host
      if not missing_hosts[service_info.host_id] then
        self.sc_logger:error("[EventQueue:check_service_cache]: couldn't find host with id: " .. service_info.host_id 
          .. " for service with id " .. service_info.service_id 
          .. ". Perhaps because the host is disabled."
        )
        missing_hosts[service_info.host_id] = true
      end
    end

    if self.sc_params.params.only_log_missing_objects == 1 and status == "present" then
      -- do nothing
    else
      self.audit_result.services[service_info.service_id] = {
        status = status,
        host_name = self.full_host_list[service_info.host_id] or "unknown",
        service_description = service_info.description
      }
    end
  end
end

--- EventQueue:check_hostgroups_cache: check that every hostgroup from the database is present in the broker cache
-- results are stored in self.audit_result.host_groups (only missing hostgroups if only_log_missing_objects is 1)
-- and the number of missing hostgroups in self.audit_result.metadata.hg_missing
-- @return false (boolean) if the database query failed
function EventQueue:check_hostgroups_cache()
  local query = "select hostgroup_id, name from hostgroups"
  local result = self.sc_database:execute(query)
  
  if not result then
    return false
  end
  
  for index, hg_info in pairs(result) do
    local status = "present"
    local cache = broker_cache:get_hostgroup_name(hg_info.hostgroup_id)

    if not cache then
      status = "missing"
      self.audit_result.metadata.hg_missing = self.audit_result.metadata.hg_missing + 1
    end

    if self.sc_params.params.only_log_missing_objects == 1 and status == "present" then
      -- do nothing
    else
      self.audit_result.host_groups[hg_info.hostgroup_id] = {
        name = hg_info.name,
        status = status
      }
    end
  end
end

--- EventQueue:check_servicegroups_cache: check that every servicegroup from the database is present in the broker cache
-- results are stored in self.audit_result.service_groups (only missing servicegroups if only_log_missing_objects is 1)
-- and the number of missing servicegroups in self.audit_result.metadata.sg_missing
-- @return false (boolean) if the database query failed
function EventQueue:check_servicegroups_cache()
  local query = "select servicegroup_id, name from servicegroups"
  local result = self.sc_database:execute(query)
  
  if not result then
    return false
  end
  
  for index, sg_info in pairs(result) do
    local status = "present"
    local cache = broker_cache:get_servicegroup_name(sg_info.servicegroup_id)

    if not cache then
      status = "missing"
      self.audit_result.metadata.sg_missing = self.audit_result.metadata.sg_missing + 1
    end

    if self.sc_params.params.only_log_missing_objects == 1 and status == "present" then
      -- do nothing
    else
      self.audit_result.service_groups[sg_info.servicegroup_id] = {
        name = sg_info.name,
        status = status
      }
    end
  end
end

--- EventQueue:write_result: write the audit result as json in log_directory/cache-audit-result.<timestamp>.json
-- if the file can't be opened and force_json_into_logfile is 1, the json is written in the log file instead
function EventQueue:write_result()
  local file = self.sc_params.params.log_directory .. "/cache-audit-result." .. os.time() .. ".json"
  local fh, error = io.open(file, "w")
  local json = broker.json_encode(self.audit_result)

  if not fh then
    self.sc_logger:error("[EventQueue:write_result]: Couldn't open file: " .. file .. ". Error is: " .. tostring(error))

    if self.sc_params.params.force_json_into_logfile == 1 then
      self.sc_logger:notice("[EventQueue:write_result]: audit result: " .. json)
    end
  else
    fh:write(json)
    fh:close()
  end
end

--- EventQueue:list_files: list the audit result files (cache-audit-result.<timestamp>.json) in log_directory
-- @return files (table) list of {name = (string) file name, timestamp = (number) timestamp from the file name}
-- @return false (boolean) if the directory couldn't be listed
function EventQueue:list_files()
  local params = self.sc_params.params

  local file_list = io.popen("ls -1 '" .. params.log_directory .. "' 2>/dev/null")
  
  if not file_list then
    self.sc_logger:error("[EventQueue:list_files]: couldn't list file in directory: " .. tostring(params.log_directory))
    return false
  end

  local files = {}
  for file_name in file_list:lines() do
    local timestamp = string.match(file_name, "^cache%-audit%-result%.(%d+)%.json$")
    
    if timestamp then
      table.insert(files, {name = file_name, timestamp = tonumber(timestamp)})
    else
      self.sc_logger:debug("[EventQueue:list_files]: couldn't get timestamp in filename: " .. tostring(file_name))
    end
  end

  file_list:close()

  return files
end

--- EventQueue:remove_old_files: keep only the audit_retention most recent audit result files and delete the others
function EventQueue:remove_old_files()
  local params = self.sc_params.params
  
  if type(params.audit_retention) ~= "number" or params.audit_retention < 1 then
    self.sc_logger:error("[EventQueue:remove_old_files]: invalid audit_retention parameter type/value. Will default back to 12 files")
    params.audit_retention = 12
  end

  local files = self:list_files()

  if not files then
    return
  end

  -- sort files in table putting most recent one first
  table.sort(files, function(file_a, file_b) return file_a.timestamp > file_b.timestamp end)

  if #files > params.audit_retention then
    for i = params.audit_retention + 1, #files do
      local file_to_remove = params.log_directory .. "/" .. files[i].name
      local result, error = os.remove(file_to_remove)
      
      if not result then
        self.sc_logger:error("[EventQueue:remove_old_files]: couldn't delete file: " .. tostring(file_to_remove) .. ". Error: " .. tostring(error))
      end
    end
  end
end

local queue

--- init: called by broker when the stream connector starts, instantiates the global queue
-- @param conf (table) the stream connector parameters from the broker output configuration
function init(conf)
  queue = EventQueue.new(conf)
end

--- write: called by broker for each event. Runs the cache audit (pollers, hosts, services, hostgroups, servicegroups)
-- when audit_frequency is elapsed since the last run, then logs a summary of the missing objects
-- @param event (table) the broker event (unused, it only acts as a clock)
-- @return true (boolean) always, so broker considers the event as handled
function write(event)
  if queue.fail then
    return true
  end

  if os.time() - queue.sc_params.params.audit_frequency >= queue.last_update then
    queue.audit_result = {
      pollers = {},
      hosts = {},
      services = {},
      host_groups = {},
      service_groups = {},
      metadata = {
        host_missing = 0,
        service_missing = 0,
        hg_missing = 0,
        sg_missing = 0,
        poller_missing = 0
      }
    }

    queue:check_poller_cache()
    queue:check_host_cache()
    queue:check_service_cache()
    queue:check_hostgroups_cache()
    queue:check_servicegroups_cache()
    queue:write_result()
    queue:remove_old_files()
    queue.last_update = os.time()
    queue.sc_logger:notice("[write]:\nmissing pollers: " .. tostring(queue.audit_result.metadata.poller_missing)
      .. "\nmissing hosts: " .. tostring(queue.audit_result.metadata.host_missing)
      .. "\nmissing services: " .. tostring(queue.audit_result.metadata.service_missing)
      .. "\nmissing host groups: " .. tostring(queue.audit_result.metadata.hg_missing)
      .. "\nmissing service groups: " .. tostring(queue.audit_result.metadata.sg_missing)
    )
  end

  return true
end

--- flush: called by broker to flush the queue. Nothing is queued in this connector
-- @return true (boolean)
function flush()
  return true
end