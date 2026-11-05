---
-- wrapper for mysql/mariadb DBMS
-- @module sc_database_mysql

local sc_database_mysql = {}
local ScDatabaseMysql = {}

-- TODO add triggers
local mandatory_parameters = {
  ["db_user"] = "string",
  ["db_password"] = "string",
  ["db_address"] = "string",
  ["db_name"] = "string",
  ["db_port"] = "number",
}

--- sc_database_mysql.new: module constructor
-- @param sc_common (object) an instance of the sc_common module
-- @param sc_logger (object) an instane of the sc_logger module
-- @param params (table) the stream connectors param table
-- @param db_params (table) a dedicated list of parameters used for the connection to the database (will use values from the params table if mandatory_params are missing)
-- @return self (object) an instance of the sc_database_mysql module
function sc_database_mysql.new(sc_common, sc_logger, params, db_params)
  local self = {}

  self.sc_logger = sc_logger
  self.sc_common = sc_common
  self.params = params
  self.db_params = db_params or {}
  self.param_prefix = 'sc_database.mysql.'

  setmetatable(self, { __index = ScDatabaseMysql})
  self.is_configuration_valid = self:check_mandatory_params()
  return self
end

--- init_params: check if mandatory params are set
-- @return is_valid (boolean) true if all mandatory parameters are set. False otherwise
function ScDatabaseMysql:check_mandatory_params()
  local is_valid = true
  local errors = ""
  
  for param_name, param_type in pairs(mandatory_parameters) do
    self.db_params[param_name] = self.db_params[param_name] or self.params[self.param_prefix .. param_name]
    local value = self.db_params[param_name]
    
    if type(value) ~= param_type or value == "" then
      errors = errors .. "- param: " .. tostring(param_name) .. " must be a non empty " .. param_type .. ". Current type: " .. type(value) .. "\n"
      is_valid = false
    end
  end

  if not is_valid then
    self.sc_logger:notice("[sc_database:mysql:check_mandatory_params]: you may have one or more invalid parameters. Please check your configuration. Errors: \n" .. errors)
  end

  return is_valid
end

--- open_connection: open the db connection
-- @return status (boolean) true if connection has been opened, false otherwise
function ScDatabaseMysql:open_connection()
  if not self.is_configuration_valid then
    self.sc_logger:error("[sc_database_mysql:open_connection]: Connection to database is not going to be done until parameters are fixed")
    return false
  end

  if self.db then
    self.sc_logger:info("[sc_database_mysql:open_connection]: found an existing connection. We try to close it before reopening it.")
    
    if not self:close_connection() then
      self.sc_logger:error("[sc_database_mysql:open_connection]: we couldn't close the existing connection. A new one is still going to be created. It can lead to memory leaks")
    end
  end

  local db_params = self.db_params
  self.is_db_connection_active = false

  if pcall(require, "luasql.mysql") then
    local mysql = require("luasql.mysql")
    local db_driver = mysql.mysql()
    local db, error_msg = db_driver:connect(
      db_params["db_name"], 
      db_params["db_user"], 
      db_params["db_password"], 
      db_params["db_address"],
      db_params["db_port"]
    )
    
    if not db then
      self.sc_logger:error("[sc_database_mysql:open_connection]: couldn't connect to " .. tostring(db_params.db_name) .. ". Error is: " .. tostring(error_msg)
      .. "make sure that your parameters are valid: db_user: " .. tostring(db_params.db_user) 
      .. ", db_address: " .. tostring(db_params.db_address) 
      .. ", db_port: " .. tostring(db_params.db_port))
    else
      self.db = db
      self.is_db_connection_active = true
    end
  else
    self.sc_logger:error("[sc_database_mysql:open_connection]: couldn't load luasql.mysql module. Make sure that you have installed this dependency.")
    return false
  end

  return self.is_db_connection_active
end

--- close_connection: close the db connection
-- @return status (boolean) true if connection has been closed, false otherwise
function ScDatabaseMysql:close_connection()
  if not self.db then
    self.sc_logger:info("[sc_database_mysql:close_connection]: no active connection found. Nothing to do.")
    return true
  end

  local result, error_msg = self.db:close()

  if not result then
    self.sc_logger:error("[sc_database_mysql:close_connection]: couldn't close db connection. Error: " .. tostring(error_msg))
  else
    self.db = nil
    self.is_db_connection_active = false
  end

  return result
end

--- build_result: build a table from the query result (build an empty table if there is no result)
-- @param result (cursor object) https://lunarmodules.github.io/luasql/manual.html#cursor_object
-- @return db_content (table) empty table if no result
function ScDatabaseMysql:build_result(result)
  local row = result:fetch({}, "a")
  local db_content = {}
  local tmp_row
    
  while row do
    tmp_row = {}
    for column, value in pairs(row) do
      tmp_row[column] = value
    end

    table.insert(db_content, tmp_row)
    row = result:fetch(row, "a")
  end

  return db_content
end

--- execute: run the given query
-- @param query (string) the query to execute
-- @return db_content (false|table) false if something went wrong, a table otherwise (empty if no result for the query)
function ScDatabaseMysql:execute(query)
  if not self.is_db_connection_active then
    self.sc_logger:notice("[sc_database_mysql:execute]: connection to database is not active. We will try to do it again")
    self:open_connection()

    if not self.is_db_connection_active then
      return false
    end
  end

  local result, error_msg = self.db:execute(query)

  if not result then
    self.sc_logger:error("[sc_database_mysql:execute]: query: " .. tostring(query) .. " failed\n error: " .. tostring(error_msg))

    -- we may have just lost the connection. We can try to redo it
    self.sc_logger:notice("[sc_database_mysql:execute]: Connection to db may have just been lost. We try to redo it")
    self:open_connection()
    
    if not self.is_db_connection_active then
      self.sc_logger:error("[sc_database_mysql:execute]: Connection to database is not active")
      return false
    end

    result, error_msg = self.db:execute(query)

    if not result then
      self.sc_logger:error("[sc_database_mysql:execute]: retried to run query: " .. tostring(query) .. " failed\n error: " .. tostring(error_msg))
      return false
    end
  end

  return self:build_result(result)
end


return sc_database_mysql