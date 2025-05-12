---
-- a storage module that is using LuaSqlite3
-- @module sc_storage_sqlite
-- @module sc_storage_sqlite

local sc_storage_sqlite = {}
local ScStorageSqlite = {}

local sqlite = require("lsqlite3")
local sc_common = require("centreon-stream-connectors-lib.sc_common")

--- sc_storage_sqlite.new: sc_storage_sqlite constructor
-- @param common (object) a sc_common instance
-- @param logger (object) a sc_logger instance 
-- @param params (table) the params table of the stream connector
function sc_storage_sqlite.new(common, logger, params)
  local self = {}

  self.sc_common = common
  self.sc_logger = logger
  self.params = params

  self.sqlite = sqlite.open(params["sc_storage.sqlite.db_file"])

  if not self.sqlite:isopen() then
    self.sc_logger:error("[sc_storage_sqlite:new]: couldn't open sqlite database: " .. tostring(params["sc_storage.sqlite.db_file"]))
  else
    self.sc_logger:notice("[sc_storage_sqlite:new]: successfully loaded sqlite storage database: " .. tostring(params["sc_storage.sqlite.db_file"])
        .. ". Status is: " .. tostring(self.sqlite:isopen()))
  end

  self.last_query_result = {}

  self.callback_functions = {
    get_query_result = function(convert_data, column_count, column_value, column_name)
      return self:get_query_result(convert_data, column_count, column_value, column_name) end
  }

  -- every functions that can be used to convert data retrieved from sc_storage table
  self.convert_data_type = {
    string = function(data) return tostring(data) end,
    number = function(data) return tonumber(data) end,
    boolean = function(data)
      if data == "true" then
        return true
      end

      return false
    end,
    table = function(data) return broker.json_decode(data) end
  }

  -- when you want to convert a data stored in the sdb, you need a column with the value to convert and another telling the expected data type
  self.required_columns_for_data_type_conversion = {
    value_column = "value",
    type_column = "data_type"
  }

  setmetatable(self, { __index = ScStorageSqlite })
  self:check_storage_table()
  return self
end

--- sc_storage_sqlite:get_query_result: this is a callback function. It is called for each row found by a sql query
-- @param convert_data (boolean) When set to true, values from the column "value" will have their type converted according to the "data_type" column. Query must be compatible with that.
-- @param column_count (number) the number of columns from the sql query
-- @param column_value (string) the value of a column
-- @param column_name (string) the name of the column
-- @return 0 (number) this is the required return code otherwise the sqlite:exec function will stop calling this callback function
function ScStorageSqlite:get_query_result(convert_data, column_count, column_value, column_name)
  local row = {}

  for i = 1, column_count do
    row[column_name[i]] = column_value[i]
  end

  -- only convert data when possible
  if convert_data
      and self.convert_data_type[row.data_type]
      and row[self.required_columns_for_data_type_conversion.value_column]
      and row[self.required_columns_for_data_type_conversion.type_column]
  then
    row.value = self.convert_data_type[row.data_type](row.value)
  end

  -- store results in a "global" variable 
  self.last_query_result[#self.last_query_result + 1] = row
  return 0
end

--- sc_storage_sqlite:check_storage_table: check if the sc_storage table exists and, if not, create it.
function ScStorageSqlite:check_storage_table()
  local query = "SELECT name FROM sqlite_master WHERE type='table' AND name='sc_storage';"

  self:run_query(query, true, false)

  if #self.last_query_result == 1 then
    self.sc_logger:debug("[sc_storage_sqlite:check_storage_table]: sqlite table sc_storage exists")
  else
    self.sc_logger:notice("[sc_storage_sqlite:check_storage_table]: sqlite table sc_storage does not exist. We are going to create it")
    self:create_storage_table()
  end
end

--- sc_storage_sqlite:create_storage_table: create the sc_storage table.
function ScStorageSqlite:create_storage_table()
  local query = [[
    CREATE TABLE sc_storage (
      object_id TEXT,
      property TEXT,
      value TEXT,
      data_type TEXT,
      PRIMARY KEY (object_id, property)
    )
  ]]

  self.sqlite:exec(query)
end

--- sc_storage_sqlite:run_query: execute the given query
-- @param query (string) the query that must be run
-- @param get_result (boolean) When set to true, the query results will be stored in the self.last_query_result table
-- @param convert_data (boolean) When set to true, values from the column "value" will have their type converted according to the "data_type" column. Query must be compatible with that.
-- @return (boolean) false if query failed, true otherwise
function ScStorageSqlite:run_query(query, get_result, convert_data)
  -- flush old stored query results
  self.last_query_result = {}

  if not get_result then
    self.sqlite:exec(query)
  else
    self.sqlite:exec(query, self.callback_functions.get_query_result, convert_data)
  end

  if self.sqlite:errcode() ~= 0 then
    self.sc_logger:error("[sc_storage_sqlite:run_query]: couldn't run query: " .. tostring(query)
        .. ". [SQL ERROR CODE]: " .. self.sqlite:errcode() .. ". [SQL ERROR MESSAGE]: " .. tostring(self.sqlite:errmsg()))
    return false
  else
    self.sc_logger:debug("[sc_storage_sqlite:run_query]: successfully executed query: " .. tostring(query))
  end

  return true
end

--- sc_storage_sqlite:set: insert or update an object property value in the sc_storage table
-- @param object_id (string) the object identifier.
-- @param property (string) the name of the property
-- @param value (string, number, boolean, table) the value of the property
-- @return (boolean) false if we couldn't store the information in the storage, true otherwise
function ScStorageSqlite:set(object_id, property, value)
  local data_type = type(value)

  if data_type == "table" then
    value = broker.json_encode(value)
  end

  value = string.gsub(tostring(value), "'", " ")
  local query = "INSERT OR REPLACE INTO sc_storage VALUES ('" .. object_id .. "', '" .. property .. "', '" .. value .. "', '" .. data_type .. "');"

  if not self:run_query(query) then
    self.sc_logger:error("[sc_storage_sqlite:set]: couldn't insert property in storage. Object id: " .. tostring(object_id)
        .. ", property name: " .. tostring(property) .. ", property value: " .. tostring(value))
    return false
  end

  return true
end

--- sc_storage_sqlite:set_multiple: insert or update multiple object properties value in the sc_storage table
-- @param object_id (string) the object identifier.
-- @param properties (table) a table of properties and their values
-- @return (boolean) false if we couldn't store the information in the storage, true otherwise
function ScStorageSqlite:set_multiple(object_id, properties)
  local counter = 0
  local sql_values = ""
  local data_type

  for property, value in pairs(properties) do
    data_type = type(value)

    if data_type == "table" then
      value = broker.json_encode(value)
    end

    value = string.gsub(tostring(value), "'", " ")

    if counter == 0 then
      sql_values = "('" .. object_id .. "', '" .. property .. "', '" .. value .. "', '" .. data_type .. "')"
      counter = counter + 1
    else
      sql_values = sql_values .. ", " .. "('" .. object_id .. "', '" .. property .. "', '" .. value .. "', '" .. data_type .. "')"
    end
  end

  local query = "INSERT OR REPLACE INTO sc_storage VALUES " .. sql_values .. ";"

  if not self:run_query(query) then
    self.sc_logger:error("[sc_storage_sqlite:set_multiple]: couldn't insert properties in storage. Object id: " .. tostring(object_id)
        .. ", properties: " .. self.sc_common:dumper(properties))
    return false
  end

  return true
end

--- sc_storage_sqlite:get: retrieve a single property value of an object
-- @param object_id (string) the object identifier.
-- @param property (string) the name of the property
-- @return (boolean) false if we couldn't get the information from the storage, true otherwise
-- @return value (string, number, boolean) the value of the property (an empty string when first return is false or if we didn't find a value for this object property)
function ScStorageSqlite:get(object_id, property)
  local query = "SELECT value, data_type FROM sc_storage WHERE property = '" .. property .. "' AND object_id = '" .. object_id .. "';"

  if not self:run_query(query, true, true) then
    self.sc_logger:error("[sc_storage_sqlite:get]: couldn't get property in storage. Object id: " .. tostring(object_id)
        .. ", property name: " .. tostring(property))
    return false, ""
  end

  local value = ""

  -- if we didn't already store information in the storage, the last_query_result could be an empty table
  if self.last_query_result[1] then
    value = self.last_query_result[1].value
  end

  return true, value
end

--- sc_storage_sqlite:get_multiple: retrieve a list of properties for an object
-- @param object_id (string) the object identifier.
-- @param properties (table) a table of properties to retreive
-- @return (boolean) false if we couldn't get the information from the storage, true otherwise
-- @return values (table) a table of properties and their value if true, empty table otherwise
function ScStorageSqlite:get_multiple(object_id, properties)
  local counter = 0
  local sql_properties_value = ""

  for _, property in ipairs(properties) do
    if counter == 0 then
      sql_properties_value = "'" .. property .. "'"
      counter = counter + 1
    else
      sql_properties_value = sql_properties_value .. ", '" .. property .. "'"
    end
  end

  local query = "SELECT property, value, data_type FROM sc_storage WHERE property IN (" .. sql_properties_value .. ") AND object_id = '" .. object_id .. "';"

  if not self:run_query(query, true, true) then
    self.sc_logger:error("[sc_storage_sqlite:get_multiple]: couldn't get properties in storage. Object id: " .. tostring(object_id)
        .. ", properties: " .. self.sc_common:dumper(properties))
    return false, {}
  end

  local values = {}

  -- if we didn't already store information in the storage, the last_query_result could be an empty table
  if self.last_query_result[1] then
    for index, stored_data in pairs(self.last_query_result) do
      values[stored_data.property] = stored_data.value
    end
  end

  return true, values
end

--- sc_storage_sqlite:delete: delete a single property of an object
-- @param object_id (string) the object identifier.
-- @param property (string) the name of the property
-- @return (boolean) false if we couldn't delete the information from the storage, true otherwise
function ScStorageSqlite:delete(object_id, property)
  local query = "DELETE FROM sc_storage WHERE property = '" .. property .. "' AND object_id = '" .. object_id .. "';"

  if not self:run_query(query) then
    self.sc_logger:error("[sc_storage_sqlite:delete]: couldn't delete property in storage. Object id: " .. tostring(object_id)
        .. ", property name: " .. tostring(property))
    return false
  end

  self.sc_logger:debug("[sc_storage_sqlite:delete]: successfully deleted property in storage for object id: " .. tostring(object_id)
      .. ", property name: " .. tostring(property))

  return true
end

--- sc_storage_sqlite:delete_multiple: delete a multiple properties of an object
-- @param object_id (string) the object identifier.
-- @param properties (table) a table of properties to retreive
-- @return (boolean) false if we couldn't delete the information from the storage, true otherwise
function ScStorageSqlite:delete_multiple(object_id, properties)
  local sql_properties_value = ""

  for _, property in ipairs(properties) do
    if counter == 0 then
      sql_properties_value = "'" .. property .. "'"
      counter = counter + 1
    else
      sql_properties_value = sql_properties_value .. ", '" .. property .. "'"
    end
  end

  local query = "DELETE FROM sc_storage WHERE property IN (" .. sql_properties_value .. ") AND object_id = '" .. object_id .. "';"

  if not self:run_query(query) then
    self.sc_logger:error("[sc_storage_sqlite:delete_multiple]: couldn't delete property in storage. Object id: " .. tostring(object_id)
        .. ", properties: " .. self.sc_common:dumper(properties))
    return false
  end

  self.sc_logger:debug("[sc_storage_sqlite:delete_multiple]: successfully deleted property in storage for object id: " .. tostring(object_id)
      .. ", properties: " .. self.sc_common:dumper(properties))

  return true
end

--- sc_storage_sqlite:show: display all property values of a given object in the stream connector log file.
-- @param object_id (string) the object identifier.
-- @return (boolean) false if we couldn't display the information from the storage, true otherwise
function ScStorageSqlite:show(object_id)
  local query = "SELECT * FROM sc_storage WHERE object_id = '" .. object_id .. "';"

  if not self:run_query(query, true) then
    self.sc_logger:error("[sc_storage_sqlite:show]: couldn't show stored properties for object id: " .. tostring(object_id))
    return false
  end

  self.sc_logger:notice("[sc_storage_sqlite:show]: stored properties for object id: " .. tostring(object_id)
      .. ": " .. broker.json_encode(self.last_query_result))

  return true
end

--- sc_storage_sqlite:clear: delete everything stored in the sc_storage table.
-- @return (boolean) false if we couldn't delete data stored in the sc_storage table, true otherwise
function ScStorageSqlite:clear()
  local query = "DELETE FROM sc_storage;"

  if not self:run_query(query) then
    self.sc_logger:error("[sc_storage_sqlite:CLEAR]: couldn't delete storage stored in the sc_storage table")
    return false
  end

  return true
end

function ScStorageSqlite:get_all_values_from_property(property)
  local query = "SELECT object_id,value, data_type FROM sc_storage WHERE property='" .. tostring(property) .. "'"
  if not self:run_query(query, true, true) then
    self.sc_logger:error("[sc_storage_sqlite:get_all_values_from_property]: couldn't get stored properties for property: " .. tostring(property) .. ", query is: " .. tostring(query))
    return false
  end

  local values = {}

  -- if we didn't already store information in the storage, the last_query_result could be an empty table
  if self.last_query_result[1] then
    for index, stored_data in pairs(self.last_query_result) do
      values[stored_data.object_id] = stored_data.value
    end
  end

  return true, values

end

return sc_storage_sqlite
