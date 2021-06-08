local bq_tables = {}

local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_common = require("centreon-stream-connectors-lib.sc_common")

local BQTables = {}


function bigquery.new(sc_logger, sc_common, params)
  local self = {}

  self.sc_logger = sc_logger
  if not self.sc_logger then
    self.sc_logger = sc_logger.new()
  end

  self.params = params
  self.host_structure = {}
  self.service_structure = {}
  self.ba_structure = {}
  self.ack_structure = {}
  self.dt_structure = {}
  
  -- schema event category mapping
  self.schema = {
    [1] = {},
    [6] = {}
  }

  -- schema neb elements mapping
  self.schema[1] = {
    [1] = function() return self:default_ack_table_schema() end,
    [6] = function() return self:default_dt_table_schema() end,
    [14] = function() return self:default_host_table_schema() end,
    [24] = function() return self:default_service_table_schema() end
  }

  -- schema bam elements mapping
  self.schema[6] = {
    [1] = function() return self:default_ba_table_schema() end
  }

  setmetatable(self, { __index = BQTables })

  return self
end

function BQTables:get_tables_schema()
  if self.params._sc_gbq_use_default_schemas then
    self.schema[self.event.category][self.event.element]()
    return true
  end

  if self.params._sc_gbq_use_schema_config_file then
    if self:load_tables_schema_file() then
      return true
    end 
  end

  if not self.params._sc_gbq_use_default_schemas and not self.params._sc_gbq_use_schema_config_file then
    -- build hosts table schema
    self:build_table_schema("^_sc_gbq_host_column_", "_sc_gbq_host_column_", self.schema.host)

    -- build services table schema
    self:build_table_schema("^_sc_gbq_service_column_", "_sc_gbq_service_column_", self.service_structure)

    -- build ba table schema
    self:build_table_schema("^_sc_gbq_ba_column_", "_sc_gbq_ba_column_", self.ba_structure)

    -- build ack table schema
    self:build_table_schema("^_sc_gbq_ack_column_", "_sc_gbq_ack_column_", self.ack_structure)

    -- build dowtime table schema
    self:build_table_schema("^_sc_gbq_dt_column_", "_sc_gbq_dt_column_", self.dt_structure)
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
  self.schema.host = {
    host_id = "{host_id}",
    host_name = "{cache.host.name}",
    status = "{state}",
    last_check = "{last_check}",
    output = "{output}",
    instance_id = "{cache.host.instance_id}"
  }
end

function BQTables:default_service_table_schema()
  self.schema.service = {
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
  self.schema.ack = {
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
  self.schema.dt = {
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
  self.schema.ba = {
    ba_id = "{ba_id}",
    ba_name = "{cache.ba.ba_name}",
    status = "{state}"
  }
end
