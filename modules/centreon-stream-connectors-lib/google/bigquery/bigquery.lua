--- 
-- bigquery module for google bigquery
-- @module bigquery
-- @alias bigquery
local bigquery = {}

local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_common = require("centreon-stream-connectors-lib.sc_common")

local BigQuery = {}

--- module constructor
-- @param params (table) table of all the stream connector parameters
-- @sc_logger (object) instance of the sc_logger module
function bigquery.new(params, sc_logger)
  local self = {}

  -- initiate sc_logger
  self.sc_logger = sc_logger
  if not self.sc_logger then
    self.sc_logger = sc_logger.new()
  end

  -- initiate parameters
  self.params = params

  -- initiate bigquery table schema mapping (1 = neb, 6 = bam)
  self.schemas = {
    [1] = {},
    [6] = {}
  }

  setmetatable(self, { __index = BigQuery })
  return self
end

--- get_tables_schema: load tables schemas according to the stream connector configuration
-- @return true (boolean) 
function BigQuery:get_tables_schema()
  -- use default schema
  if self.params._sc_gbq_use_default_schemas == 1 then
    self.schemas[1][14] = self:default_host_table_schema()
    self.schemas[1][24] = self:default_service_table_schema()
    self.schemas[1][1] = self:default_ack_table_schema()
    self.schemas[1][6] = self:default_dt_table_schema()
    self.schemas[6][1] = self:default_ba_table_schema()
    return true
  end

  -- use a configuration file for all the schema
  if self.params._sc_gbq_schema_config_file_path == 1 then
    if self:load_tables_schema_file() then
      return true
    end 
  end

  -- create tables schemas from stream connector configuration itself (not the best idea)
  if self.params._sc_gbq_use_default_schemas == 0 and self.params._sc_gbq_use_schema_config_file == 0 then
    -- build hosts table schema
    self:build_table_schema("^_sc_gbq_host_column_", "_sc_gbq_host_column_", self.schemas[1][14])

    -- build services table schema
    self:build_table_schema("^_sc_gbq_service_column_", "_sc_gbq_service_column_", self.schemas[1][24])

    -- build ba table schema
    self:build_table_schema("^_sc_gbq_ba_column_", "_sc_gbq_ba_column_", self.schemas[6][1])

    -- build ack table schema
    self:build_table_schema("^_sc_gbq_ack_column_", "_sc_gbq_ack_column_", self.schemas[1][1])

    -- build dowtime table schema
    self:build_table_schema("^_sc_gbq_dt_column_", "_sc_gbq_dt_column_", self.schemas[1][6])
  end

  return true
end

--- build_table_schema: create a table schema using the stream connector tables configuration
-- @param regex (string) the regex that the stream connector param must match in order to identify it as a column name in the table schema
-- @param substract (string) the string that is going to be removed from the parameter name to isolate the name of the column
-- @param structure (table) the schema table in which the column name and value are going to be stored
function BigQuery:build_table_schema(regex, substract, structure)
  for param_name, param_value in pairs(self.params) do
    if string.find(param_name, regex) ~= nil then
      structure[string.gsub(param_name, substract, "")] = param_value
    end
  end
end

--- default_host_table_schema: create a standard schema for a host event table
-- @return host_table (table) the table that is going to be used as a schema for bigquery host table
function BigQuery:default_host_table_schema()
  return {
    host_id = "{host_id}",
    host_name = "{cache.host.name}",
    status = "{state}",
    last_check = "{last_check}",
    output = "{output}",
    instance_id = "{cache.host.instance_id}"
  }
end

--- default_service_table_schema: create a standard schema for a service event table
-- @return service_table (table) the table that is going to be used as a schema for bigquery service table
function BigQuery:default_service_table_schema()
  return {
    host_id = "{host_id}",
    host_name = "{cache.host.name}",
    service_id = "{service_id}",
    service_description = "{cache.service.description}",
    status = "{state}",
    last_check = "{last_check}",
    output = "{output}",
    instance_id = "{cache.host.instance_id}"
  }
end

--- default_ack_table_schema: create a standard schema for an ack event table
-- @return ack_table (table) the table that is going to be used as a schema for bigquery ack table
function BigQuery:default_ack_table_schema()
  return {
    author = "{author}",
    host_id = "{host_id}",
    host_name = "{cache.host.name}",
    service_id = "{service_id}",
    service_description = "{cache.service.description}",
    status = "{state}",
    output = "{output}",
    instance_id = "{cache.host.instance_id}",
    entry_time = "{entry_time}"
  }
end

--- default_dt_table_schema: create a standard schema for a downtime event table
-- @return downtime_table (table) the table that is going to be used as a schema for bigquery downtime table
function BigQuery:default_dt_table_schema()
  return {
    author = "{author}",
    host_id = "{host_id}",
    host_name = "{cache.host.name}",
    service_id = "{service_id}",
    service_description = "{cache.service.description}",
    status = "{state}",
    output = "{output}",
    instance_id = "{cache.host.instance_id}",
    actual_start_time = "{actual_start_time}",
    actual_end_time = "{deletion_time}"
  }
end

--- default_ba_table_schema: create a standard schema for a BA event table
-- @return ba_table (table) the table that is going to be used as a schema for bigquery BA table
function BigQuery:default_ba_table_schema()
  return {
    ba_id = "{ba_id}",
    ba_name = "{cache.ba.ba_name}",
    status = "{state}"
  }
end

--- load_tables_schema_file: load a table schema from a json configuration file
-- @return false (boolean) if we can't open the configuration file or it is not a valid json file
-- @return true (boolean) if everything went fine
function BigQuery:load_tables_schema_file()
  local file = io.open(self.params._sc_gbq_schema_config_file_path, "r")

  -- return false if we can't open the file
  if not file then
    self.sc_logger:error("[google.bq.bq_tabmes:load_tables_schema_file]: couldn't open file "
      .. tostring(self.params._sc_gbq_schema_config_file_path) .. ". Make sure your table schema file is there.")
    return false
  end

  local file_content = file:read("*a")
  io.close(file)

  local schemas = broker.json_decode(file_content)

  -- return false if json couldn't be parsed
  if (type(schemas) ~= "table") then
    self.sc_logger:error("[google.bq.bq_tabmes:load_tables_schema_file]: the table schema file "
      .. tostring(self.params._sc_gbq_schema_config_file_path) .. ". Is not a valid json file.")
    return false
  end

  -- use default schema if we don't find a schema for a dedicated type of event
  self.schemas[1][14] = schemas.host or self:default_host_table_schema()
  self.schemas[1][24] = schemas.service or self:default_service_table_schema()
  self.schemas[1][1] = schemas.ack or self:default_ack_table_schema()
  self.schemas[1][6] = schemas.dt or self:default_dt_table_schema()
  self.schemas[6][1] = schemas.ba or self:default_ba_table_schema()

  return true
end

return bigquery