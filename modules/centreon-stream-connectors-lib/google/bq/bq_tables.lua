local bq_tables = {}

local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_common = require("centreon-stream-connectors-lib.sc_common")

local BQTables = {}

function bigquery.new(sc_common, params, sc_logger)
  local self = {}

  self.sc_logger = sc_logger
  if not self.sc_logger then
    self.sc_logger = sc_logger.new()
  end

  self.params = params

  self.schemas = {
    [1] = {},
    [6] = {}
  }

  setmetatable(self, { __index = BQTables })
  return self
end

function BQTables:get_tables_schema()
  if self.params._sc_gbq_use_default_schemas then
    self.schemas[1][14] = self:default_host_table_schema()
    self.schemas[1][24] = self:default_service_table_schema()
    self.schemas[1][1] = self:default_ack_table_schema()
    self.schemas[1][6] = self:default_dt_table_schema()
    self.schemas[6][1] = self:default_ba_table_schema()
    return true
  end

  if self.params._sc_gbq_schema_config_file_path then
    if self:load_tables_schema_file() then
      return true
    end 
  end

  if not self.params._sc_gbq_use_default_schemas and not self.params._sc_gbq_use_schema_config_file then
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

  return false
end

function BQTables:build_table_schema(regex, substract, structure)
  for param_name, param_value in pairs(self.params) do
    if string.find(param_name, regex) ~= nil then
      structure[string.gsub(param_name, substract, "")] = param_value
    end
  end
end

function BQTables:default_host_table_schema()
  return {
    host_id = "{host_id}",
    host_name = "{cache.host.name}",
    status = "{state}",
    last_check = "{last_check}",
    output = "{output}",
    instance_id = "{cache.host.instance_id}"
  }
end

function BQTables:default_service_table_schema()
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

function BQTables:default_ack_table_schema()
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

function BQTables:default_dt_table_schema()
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

function BQTables:default_ba_table_schema()
  return {
    ba_id = "{ba_id}",
    ba_name = "{cache.ba.ba_name}",
    status = "{state}"
  }
end

function BQTables:load_tables_schema_file()
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

  self.schemas[1][14] = schemas.host or self:default_host_table_schema()
  self.schemas[1][24] = schemas.service or self:default_service_table_schema()
  self.schemas[1][1] = schemas.ack or self:default_ack_table_schema()
  self.schemas[1][6] = schemas.dt or self:default_dt_table_schema()
  self.schemas[6][1] = schemas.ba or self:default_ba_table_schema()
end