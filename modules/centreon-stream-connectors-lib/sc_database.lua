---
-- wrapper for all centreon stream connector database backends
-- @module sc_database

local sc_database = {}
local ScDatabase = {}

--- sc_database.new: instantiate a new database connection
-- 
function sc_database.new(db_backend, sc_common, sc_logger, params)
  local self = {}

  self.sc_common = sc_common
  self.sc_logger = sc_logger
  self.params = params

  -- make sure we are able to load the desired database backend.
  if pcall(require, "centreon-stream-connectors-lib.database_backends.sc_database_" .. db_backend) then
    self.sc_logger:debug("[sc_database.new] found database backend sc_database_" .. tostring(db_backend))
    local database_backend = require("centreon-stream-connectors-lib.database_backends.sc_database_" .. db_backend)
    self.database_backend = database_backend.new(self.sc_common, self.sc_logger, self.params)
  else
    self.sc_logger:error("[sc_database.new]: Couldn't load database backend: " .. tostring(db_backend)
      .. ". Make sure that the file sc_database_" .. tostring(db_backend) .. ".lua exists on your server.")
    return false
  end

  setmetatable(self, { __index = ScDatabase})
  return self
end

--- execute: run the given query
-- @param query (string) the query to run
-- @return result (false|table) false if something went wrong, a table otherwise (empty table if the query is not supposed to return something) 
function ScDatabase:execute(query)
  if type(query) ~= "string" then
    self.sc_logger:error("[sc_database:execute]: query is not a string. Given query: " .. tostring(query))
    return false
  end

  return self.database_backend:execute(query)
end

--- open_connection: open the db connection (already done during module initialization)
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