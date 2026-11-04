---
-- wrapper for mysql/mariadb DBMS
-- @module sc_

local sc_database_mysql = {}
local ModuleName = {}

local mandatory_parameters = {
  ["sc_database.mysql.db_user"] = "string",
  ["sc_database.mysql.db_password"] = "string",
  ["sc_database.mysql.db_address"] = "string",
  ["sc_database.mysql.db_name"] = "string",
  ["sc_database.mysql.db_port"] = "number",
}

function sc_database_mysql.new(sc_common, sc_logger, params)
  local self = {}

  self.sc_logger = sc_logger
  self.sc_common = sc_common
  self.params = params

  setmetatable(self, { __index = ScDatabaseMysql})
  self:check_mandatory_params()
  return self
end

--- init_params: check if mandatory params are set
-- @return is_valid (boolean) true if all mandatory parameters are set. False otherwise
function ScDatabaseMysql:check_mandatory_params()
  local is_valid = true
  
  for param_name, param_type in pairs(mandatory_parameters) do
    local value = self.params[param_name]
    
    if type(value) ~= param_type or value == "" then
      self.sc_logger:notice("[sc_database_mysql:init_params]: param: " .. tostring(param_name) .. " must be a non empty " .. param_type .. ". Current type: " .. type(value))
      is_valid = false
    end
  end

  return is_valid
end

-- TODO add default value system (port = 3306 for example)
-- TODO add a list of mandatory params (user, password....)

--- open_connection: open the db connection (already done during module initialization)
-- @return status (boolean) true if connection has been opened, false otherwise
function sc_database_mysql:open_connection()
  local db_params = self.db_params
  self.is_db_connection_active = false

  if pcall(require, "luasql.mysql") then
    local db = require("luasql.mysql")
    local db_driver = db.mysql()
    local db, error_msg = db_driver:connect(
      params["sc_database.mysql.db_name"].db_name, 
      params["sc_database.mysql.db_user"].db_user, 
      params["sc_database.mysql.db_password"].db_password, 
      params["sc_database.mysql.db_address"].db_address,
      params["sc_database.mysql.db_port"].db_port
    )
    
    if not db then
      self.sc_logger:error("[sc_database_mysql:open_connection]: couldn't connect to " .. tostring(db_params.db_name) .. ". Error is: " .. tostring(error_msg)
      .. "make sure that your parameters are valid: db_user: " .. tostring(db_params.db_user) 
      .. ", db_address: " .. tostring(params.db_address) 
      .. ", db_port: " .. tostring(params.db_port))
    else
      self.db = db
      self.db_connection_retry_sleep_table:reset()
      self.is_db_connection_active = true
    end
  else
    self.sc_logger:error("[sc_database_mysql:open_connection]: couldn't load luasql.mysql module. Make sure that you have installed this dependency.")
    return false
  end

  -- TODO check if this should be there
  -- if (self.params.create_queue_until_db_is_up == 1 and not self.is_db_connection_active) then
  --   self.db_connection_retry_sleep_table:sleep()
  --   self:open_connection()
  -- end

  return true
end

--- close_connection: close the db connection
-- @return status (boolean) true if connection has been closed, false otherwise
function ScDatabaseMysql:close_connection()
  local result, error_msg = self.db:close()

  if not result then
    self.sc_logger:error("[sc_database_mysql:close_connection]: couldn't close db connection. Error: " .. tostring(error_msg))
  end

  return result
end

--- build_result: build a table from the query result (build an empty table if there is no result)
-- @param result (cursor object) https://lunarmodules.github.io/luasql/manual.html#cursor_object
-- @return db_content (table) empty table if no result
function ScDatabaseMysql:build_result(result)
  local row = result:fetch({}, "a")
  local db_content = {}
    
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

  if not result or result ~= result then
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