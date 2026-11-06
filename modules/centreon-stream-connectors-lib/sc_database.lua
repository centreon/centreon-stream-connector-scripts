---
-- wrapper for all centreon stream connector database backends
-- @module sc_database

local sc_database = {}
local ScDatabase = {}

--- sc_database.new: module constructor
-- @param db_backend (string) the name of the database backend that must be used (for example: mysql for sc_database_mysql)
-- @param sc_common (object) an instance of the sc_common module
-- @param sc_logger (object) an instance of the sc_logger module
-- @param sc_trigger (object) an instance of the sc_trigger module
-- @param params (table) the stream connectors param table
-- @param db_params (table) a dedicated list of parameters used for the connection to the database (will use values from the params table if mandatory_params are missing)
-- @return false|self (boolean|object) an instance of the sc_database_mysql module or false if we can't load the db_backend module
function sc_database.new(db_backend, sc_common, sc_logger, sc_trigger, params, db_params)
  local self = {}

  self.sc_common = sc_common
  self.sc_logger = sc_logger
  self.sc_trigger = sc_trigger or require("centreon-stream-connectors-lib.sc_trigger").new(params, sc_common, sc_logger)
  self.params = params
  self.db_params = db_params

  -- make sure we are able to load the desired database backend.
  if pcall(require, "centreon-stream-connectors-lib.database_backends.sc_database_" .. tostring(db_backend)) then
    self.sc_logger:debug("[sc_database.new] found database backend sc_database_" .. tostring(db_backend))
    local database_backend = require("centreon-stream-connectors-lib.database_backends.sc_database_" .. db_backend)
    self.database_backend = database_backend.new(self.sc_common, self.sc_logger, self.sc_trigger, self.params, self.db_params)
  else
    self.sc_logger:error("[sc_database.new]: Couldn't load database backend: " .. tostring(db_backend)
      .. ". Make sure that the file sc_database_" .. tostring(db_backend) .. ".lua exists on your server.")
    return false
  end

  setmetatable(self, { __index = ScDatabase})
  return self
end

--- escape: escape a given value for safe use in a SQL query
-- @param value (string|number|boolean|nil) the raw value to escape
-- @return escaped_value (false|string) the SQL value, false if the type is not supported of if escaping failed
function ScDatabase:escape(value)
  local value_type = type(value)

  if value_type == "nil" then
    return self.database_backend:escape_nil()
  elseif value_type == "string" then
    return self.database_backend:escape_string(value)
  elseif value_type == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      self.sc_logger:error("[sc_database:escape]: can't escape NaN or infinite numbers")
      return false
    end

    return self.database_backend:escape_number(value)
  elseif value_type == "boolean" then
    return self.database_backend:escape_boolean(value)
  end

  self.sc_logger:error("[sc_database:escape]: can't escape a value of type: " .. value_type)
  return false
end

--- execute: run the given query
-- @param query (string) the query to run
-- @return result (false|table) false if something went wrong, a table otherwise (empty table if the query is not supposed to return something) 
function ScDatabase:execute(query)
  if type(query) ~= "string" then
    self.sc_logger:error("[sc_database:execute]: query is not a string. Given query: " .. tostring(query))
    return false
  end

  local result = self.database_backend:execute(query)

  if not result then
    self.sc_trigger:run_trigger("sc_database:execute", "on-fail", {
      query = query
    })
  else
    self.sc_trigger:run_trigger("sc_database:execute", "on-success", {
      query = query,
      result = result
    })
  end

  return result
end

--- open_connection: open the db connection
-- @return status (boolean) true if connection has been opened, false otherwise
function ScDatabase:open_connection()
  return self.database_backend:open_connection()
end

--- close_connection: close the db connection
-- @return status (boolean) true if connection has been closed, false otherwise
function ScDatabase:close_connection()
  return self.database_backend:close_connection()
end

return sc_database