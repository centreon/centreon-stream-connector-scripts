---
-- a cache module that is using LuaSqlite3
-- @module sc_cache_sqlite
-- @module sc_cache_sqlite

local sc_cache_sqlite = {}
local ScCacheSqlite = {}

local sqlite = require("lsqlite3")

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

function ScCacheSqlite:get_query_result(data, column_count, column_value, column_name)
  local row = {}

  for i = 1, column_count do
    row[column_name[i]] = column_value[i]
  end

  self.last_query_result[#self.last_query_result + 1] = row
  return 0
end


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


function ScCacheSqlite:set(object_id, property, value)
  value = value:gsub("'", " ")
  local query = "INSERT OR REPLACE INTO sc_cache VALUES ('" .. object_id .. "', '" .. property .. "', '" .. value .. "');"
  
  if not self:run_query(query) then
    self.sc_logger:error("[sc_cache_sqlite:set]: couldn't insert property in cache. Object id: " ..tostring(object_id)
      .. ", property name: " .. tostring(property) .. ", property value: " .. tostring(value))
    return false
  end

  return true
end

function ScCacheSqlite:get(object_id, property)
  local query = "SELECT value FROM sc_cache WHERE property = '" .. property .. "' AND object_id = '" .. object_id .. "';"

  if not self:run_query(query, true) then
    self.sc_logger:error("[sc_cache_sqlite:get]: couldn't get property in cache. Object id: " .. tostring(object_id)
      .. ", property name: " .. tostring(property))
    return false, ""
  end

  local value = ""

  if self.last_query_result[1] then
    value = self.last_query_result[1].value
  end

  return true, value
end

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

function ScCacheSqlite:clear()
  local query = "TRUNCATE sc_cache;"

  if not self:run_query(query) then
    self.sc_logger:error("[sc_cache_sqlite:CLEAR]: couldn't truncate table sc_cache")
    return false
  end

  return true
end

return sc_cache_sqlite