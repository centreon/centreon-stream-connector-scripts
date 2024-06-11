---
-- a cache module that is using LuaSqlite3
-- @module sc_cache_sqlite
-- @module sc_cache_sqlite

local sc_cache_sqlite = {}
local ScCacheSqlite = {}

local sqlite = require("lsqlite3")

--- sc_cache_sqlite.new: sc_cache_sqlite constructor
-- @param sc_logger (object) a sc_logger instance 
-- @param params (table) the params table of the stream connector
function sc_cache_sqlite.new(logger, params)
  local self = {}

  self.sc_logger = logger
  self.params = params

  self.sqlite = sqlite.open(params["sc_cache.sqlite.db_file"])

  if not self.sqlite:isopen() then
    self.sc_logger:error("[sc_cache_sqlite:new]: couldn't open sqlite database: " .. tostring(params["sc_cache.sqlite.db_file"]))
  else
    self.sc_logger:notice("[sc_cache_sqlite:new]: successfully loaded sqlite cache database: " .. tostring(params["sc_cache.sqlite.db_file"])
      .. ". Status is: " .. tostring(self.sqlite:isopen()))
  end

  self.last_query_result = {}

  self.callback_functions = {
    get_query_result = function (udata, column_count, column_value, column_name) 
      return self:get_query_result(udata, column_count, column_value, column_name) end
  }

  setmetatable(self, { __index = ScCacheSqlite})
  self:check_cache_table()
  return self
end

--- sc_cache_sqlite:get_query_result: this is a callback function. It is called for each row found by a sql query
-- @param udata (string) I'm sorry, I have no explanation apart from http://lua.sqlite.org/index.cgi/doc/tip/doc/lsqlite3.wiki#db_exec
-- @param column_count (number) the number of columns from the sql query
-- @param column_value (string) the value of a column
-- @param column_name (string) the name of the column
-- @return 0 (number) this is the required return code otherwise the sqlite:exec function will stop calling this callback function
function ScCacheSqlite:get_query_result(udata, column_count, column_value, column_name)
  local row = {}

  for i = 1, column_count do
    row[column_name[i]] = column_value[i]
  end

  -- store results in a "global" variable 
  self.last_query_result[#self.last_query_result + 1] = row
  return 0
end


--- sc_cache_sqlite:check_cache_table: check if the sc_cache table exists and, if not, create it.
function ScCacheSqlite:check_cache_table()
  local query = "SELECT name FROM sqlite_master WHERE type='table' AND name='sc_cache';"
  
  self:run_query(query, true)

  if #self.last_query_result == 1 then
    self.sc_logger:debug("[sc_cache_sqlite:check_cache_table]: sqlite table sc_cache exists")
  else
    self.sc_logger:notice("[sc_cache_sqlite:check_cache_table]: sqlite table sc_cache does not exist. We are going to create it")
    self:create_cache_table()
  end
end

--- sc_cache_sqlite:create_cache_table: create the sc_cache table.
function ScCacheSqlite:create_cache_table()
  local query = [[
    CREATE TABLE sc_cache (
      object_id TEXT,
      property TEXT,
      value TEXT,
      PRIMARY KEY (object_id, property)
    )
  ]]

  self.sqlite:exec(query)
end

--- sc_cache_sqlite:run_query: execute the given query
-- @param query (string) the query that must be run
-- @param get_result (boolean) default value is false. When set to true, the query results will be stored in the self.last_query_result table
-- @return (boolean) false if query failed, true otherwise
function ScCacheSqlite:run_query(query, get_result)
  -- flush old stored query results
  self.last_query_result = {}

  if not get_result then
    self.sqlite:exec(query)
  else
    self.sqlite:exec(query, self.callback_functions.get_query_result, 'udata')
  end

  if self.sqlite:errcode() ~= 0 then
    self.sc_logger:error("[sc_cache_sqlite:run_query]: couldn't run query: " .. tostring(query)
      .. ". [SQL ERROR CODE]: " .. self.sqlite:errcode() .. ". [SQL ERROR MESSAGE]: " .. tostring(self.sqlite:errmsg()))
    return false
  else
    self.sc_logger:debug("[sc_cache_sqlite:run_query]: successfully executed query: " .. tostring(query))
  end

  return true
end

--- sc_cache_sqlite:set: insert or update an object property value in the sc_cache table
-- @param object_id (string) the object identifier.
-- @param property (string) the name of the property
-- @param value (string) the value of the property (will be converted to string anyway)
-- @return (boolean) false if we couldn't store the information in the cache, true otherwise
function ScCacheSqlite:set(object_id, property, value)
  value = string.gsub(tostring(value), "'", " ")
  local query = "INSERT OR REPLACE INTO sc_cache VALUES ('" .. object_id .. "', '" .. property .. "', '" .. value .. "');"
  
  if not self:run_query(query) then
    self.sc_logger:error("[sc_cache_sqlite:set]: couldn't insert property in cache. Object id: " ..tostring(object_id)
      .. ", property name: " .. tostring(property) .. ", property value: " .. tostring(value))
    return false
  end

  return true
end

--- sc_cache_sqlite:get: retrieve a single property value of an object
-- @param object_id (string) the object identifier.
-- @param property (string) the name of the property
-- @return (boolean) false if we couldn't get the information from the cache, true otherwise
-- @return value (string) the value of the property (an empty string when first return is false or if we didn't find a value for this object property)
function ScCacheSqlite:get(object_id, property)
  local query = "SELECT value FROM sc_cache WHERE property = '" .. property .. "' AND object_id = '" .. object_id .. "';"

  if not self:run_query(query, true) then
    self.sc_logger:error("[sc_cache_sqlite:get]: couldn't get property in cache. Object id: " .. tostring(object_id)
      .. ", property name: " .. tostring(property))
    return false, ""
  end

  local value = ""

  -- if we didn't already store information in the cache, the last_query_result could be an empty table
  if self.last_query_result[1] then
    value = self.last_query_result[1].value
  end

  return true, value
end

--- sc_cache_sqlite:delete: delete a single property of an object
-- @param object_id (string) the object identifier.
-- @param property (string) the name of the property
-- @return (boolean) false if we couldn't delete the information from the cache, true otherwise
function ScCacheSqlite:delete(object_id, property)
  local query = "DELETE FROM sc_cache WHERE property = '" .. property .. "' AND object_id = '" .. object_id .. "';"

  if not self:run_query(query) then
    self.sc_logger:error("[sc_cache_sqlite:delete]: couldn't delete property in cache. Object id: " ..tostring(object_id)
      .. ", property name: " .. tostring(property))
    return false
  end

  self.sc_logger:debug("[sc_cache_sqlite:delete]: successfully deleted property in cache for object id: ".. tostring(object_id)
    .. ", property name: " .. tostring(property))

  return true
end

--- sc_cache_sqlite:show: display all property values of a given object in the stream connector log file.
-- @param object_id (string) the object identifier.
-- @return (boolean) false if we couldn't display the information from the cache, true otherwise
function ScCacheSqlite:show(object_id)
  local query = "SELECT * FROM sc_cache WHERE object_id = '" .. object_id .. "';"

  if not self:run_query(query, true) then
    self.sc_logger:error("[sc_cache_sqlite:show]: couldn't show stored properties for object id: " .. tostring(object_id))
    return false
  end

  self.sc_logger:notice("[sc_cache_sqlite:show]: stored properties for object id: " .. tostring(object_id)
    .. ": " .. broker.json_encode(self.last_query_result))

  return true
end

--- sc_cache_sqlite:clear: delete everything stored in the sc_cache table.
-- @return (boolean) false if we couldn't delete data stored in the sc_cache table, true otherwise
function ScCacheSqlite:clear()
  local query = "DELETE FROM sc_cache;"

  if not self:run_query(query) then
    self.sc_logger:error("[sc_cache_sqlite:CLEAR]: couldn't delete cache stored in the sc_cache table")
    return false
  end

  return true
end

return sc_cache_sqlite