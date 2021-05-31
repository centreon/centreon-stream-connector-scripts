#!/usr/bin/lua

--- 
-- Module to help initiate a stream connector with all paramaters
-- @module sc_params
-- @alias sc_params

local sc_params = {}

local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_common = require("centreon-stream-connectors-lib.sc_common")

local ScParams = {}

--- sc_params.new: sc_params constructor
-- @param common (object) object instance from sc_common module
-- @param logger (object) object instance from sc_logger module 
function sc_params.new(common, logger)
  local self = {}

  -- initiate mandatory libs
  self.logger = logger
  if not self.logger then 
    self.logger = sc_logger.new()
  end
  self.common = common

  -- initiate params
  self.params = {
    -- filter broker events
    accepted_categories = "neb,bam", -- could be: neb,storage,bam (https://docs.centreon.com/docs/centreon-broker/en/latest/dev/bbdo.html#event-categories)
    accepted_elements = "host_status,service_status,ba_status", -- could be: metric,host_status,service_status,ba_event,kpi_event" (https://docs.centreon.com/docs/centreon-broker/en/latest/dev/bbdo.html#neb)
    
    -- filter status
    host_status = "0,1,2", -- = ok, down, unreachable
    service_status = "0,1,2,3", -- = ok, warning, critical, unknown,
    ba_status = "0,1,2", -- = ok, warning, critical
    ack_host_status = "", -- will use host_status if empty
    ack_service_status = "", -- wil use service_status if empty
    
    -- filter state type 
    hard_only = 1,
    acknowledged = 0,
    in_downtime = 0,
    
    -- objects filter
    accepted_hostgroups = "",
    accepted_servicegroups = "",
    accepted_bvs = "",
    accepted_pollers = "",
    accepted_authors = "",
    service_severity_threshold = nil,
    service_severity_operator = ">=",
    host_severity_threshold = nil,
    host_severity_operator = ">=",

    -- filter anomalous events
    skip_anon_events = 1,
    skip_nil_id = 1,

    -- enable or disable dedup
    enable_host_status_dedup = 0,
    enable_service_status_dedup = 0,
    
    -- communication parameters
    max_buffer_size = 1,
    max_buffer_age = 5,

    -- internal parameters
    __internal_ts_last_flush = os.time(),
    
    -- initiate mappings
    element_mapping = {},
    category_mapping = {},
    status_mapping = {},
    state_type_mapping = {
      [0] = "SOFT",
      [1] = "HARD"
    },
    validatedEvents = {},
    
    -- FIX BROKER ISSUE 
    max_stored_events = 10 -- do not use values above 100 
  }

  -- maps category id and name
  self.params.category_mapping = {
    neb = 1,
    bbdo = 2,
    storage = 3,
    correlation = 4,
    dumper = 5,
    bam = 6,
    extcmd = 7
  }

  -- initiate category and element mapping
  self.params.element_mapping = {
    [1] = {},
    [3] = {},
    [6] = {}
  }

  -- maps category id with element name and element id
  -- neb elements
  self.params.element_mapping[1].acknowledgement = 1
  self.params.element_mapping[1].comment = 2
  self.params.element_mapping[1].custom_variable = 3
  self.params.element_mapping[1].custom_variable_status = 4
  self.params.element_mapping[1].downtime = 5
  self.params.element_mapping[1].event_handler = 6
  self.params.element_mapping[1].flapping_status = 7
  self.params.element_mapping[1].host_check = 8
  self.params.element_mapping[1].host_dependency = 9
  self.params.element_mapping[1].host_group = 10
  self.params.element_mapping[1].host_group_member = 11
  self.params.element_mapping[1].host = 12
  self.params.element_mapping[1].host_parent = 13
  self.params.element_mapping[1].host_status = 14
  self.params.element_mapping[1].instance = 15
  self.params.element_mapping[1].instance_status = 16
  self.params.element_mapping[1].log_entry = 17
  self.params.element_mapping[1].module = 18
  self.params.element_mapping[1].service_check = 19
  self.params.element_mapping[1].service_dependency = 20
  self.params.element_mapping[1].service_group = 21
  self.params.element_mapping[1].service_group_member = 22
  self.params.element_mapping[1].service = 23
  self.params.element_mapping[1].service_status = 24
  self.params.element_mapping[1].instance_configuration = 25

  -- metric elements mapping
  self.params.element_mapping[3].metric = 1
  self.params.element_mapping[3].rebuild = 2
  self.params.element_mapping[3].remove_graph = 3
  self.params.element_mapping[3].status = 4
  self.params.element_mapping[3].index_mapping = 5
  self.params.element_mapping[3].metric_mapping = 6

  -- bam elements mapping
  self.params.element_mapping[6].ba_status = 1
  self.params.element_mapping[6].kpi_status = 2
  self.params.element_mapping[6].meta_service_status = 3
  self.params.element_mapping[6].ba_event = 4
  self.params.element_mapping[6].kpi_event = 5
  self.params.element_mapping[6].ba_duration_event = 6
  self.params.element_mapping[6].dimension_ba_event = 7
  self.params.element_mapping[6].dimension_kpi_event = 8
  self.params.element_mapping[6].dimension_ba_bv_relation_event = 9
  self.params.element_mapping[6].dimension_bv_event = 10
  self.params.element_mapping[6].dimension_truncate_table_signal = 11
  self.params.element_mapping[6].bam_rebuild = 12
  self.params.element_mapping[6].dimension_timeperiod = 13
  self.params.element_mapping[6].dimension_ba_timeperiod_relation = 14
  self.params.element_mapping[6].dimension_timeperiod_exception = 15
  self.params.element_mapping[6].dimension_timeperiod_exclusion = 16
  self.params.element_mapping[6].inherited_downtime = 17

  -- initiate category and status mapping
  self.params.status_mapping = {
    [1] = {},
    [3] = {},
    [6] = {}
  }

  -- maps neb category statuses with host status element 
  self.params.status_mapping[1][14] = {
    [0] = "UP",
    [1] = "DOWN",
    [2] = "UNREACHABLE"
  }

  -- maps neb category statuses with service status element 
  self.params.status_mapping[1][24] = {
    [0] = "OK",
    [1] = "WARNING",
    [2] = "CRITICAL",
    [3] = "UNKNOWN"
  }

  -- maps bam category statuses with ba status element
  self.params.status_mapping[6][1] = {
    [0] = "OK",
    [1] = "WARNING",
    [2] = "CRITICAL"
  }

  -- map downtime category statuses 
  self.params.status_mapping[1][5] = {
    [1] = {},
    [2] = {}
  }

  -- service downtime mapping
  self.params.status_mapping[1][5][1] = {
    [0] = "OK",
    [1] = "WARNING",
    [2] = "CRITICAL",
    [3] = "UNKNOWN"
  }
  
  -- host donwtime mapping
  self.params.status_mapping[1][5][2] = {
    [0] = "UP",
    [1] = "DOWN",
    [2] = "UNREACHABLE"
  }


  setmetatable(self, { __index = ScParams })

  return self
end

--- param_override: change default param values with the one provides from the web configuration
-- @param user_params (table) the table of all parameters from the web interface
function ScParams:param_override(user_params)
  if type(user_params) ~= "table" then
    self.logger:error("User parameters are not a table. Using default parameters instead")
    return
  end

  for param_name, param_value in pairs(user_params) do
    if self.params[param_name] or string.find(param_name, "^_sc_kafka_") ~= nil then
      self.params[param_name] = param_value
      self.logger:notice("[sc_params:param_override]: overriding parameter: " .. tostring(param_name) .. " with value: " .. tostring(param_value))
    else 
      self.logger:notice("[sc_params:param_override]: User parameter: " .. tostring(param_name) .. " is not handled by this stream connector")
    end
  end
end

--- check_params: check standard params syntax
function ScParams:check_params()
  self.params.hard_only = self.common:check_boolean_number_option_syntax(self.params.hard_only, 1)
  self.params.acknowledged = self.common:check_boolean_number_option_syntax(self.params.acknowledged, 0)
  self.params.in_downtime = self.common:check_boolean_number_option_syntax(self.params.in_downtime, 0)
  self.params.skip_anon_events = self.common:check_boolean_number_option_syntax(self.params.skip_anon_events, 1)
  self.params.skip_nil_id = self.common:check_boolean_number_option_syntax(self.params.skip_nil_id, 1)
  self.params.accepted_authors = self.common:if_wrong_type(self.params.accepted_authors, "string", "")
  self.params.accepted_hostgroups = self.common:if_wrong_type(self.params.accepted_hostgroups, "string", "")
  self.params.accepted_servicegroups = self.common:if_wrong_type(self.params.accepted_servicegroups, "string", "")
  self.params.accepted_bvs = self.common:if_wrong_type(self.params.accepted_bvs, "string", "")
  self.params.accepted_pollers = self.common:if_wrong_type(self.params.accepted_pollers, "string", "")
  self.params.host_severity_threshold = self.common:if_wrong_type(self.params.host_severity_threshold, "number", nil)
  self.params.service_severity_threshold = self.common:if_wrong_type(self.params.service_severity_threshold, "number", nil)
  self.params.host_severity_operator = self.common:if_wrong_type(self.params.host_severity_operator, "string", ">=")
  self.params.service_severity_operator = self.common:if_wrong_type(self.params.service_severity_operator, "string", ">=")
  self.params.ack_host_status = self.common:ifnil_or_empty(self.params.ack_host_status,self.params.host_status)
  self.params.ack_service_status = self.common:ifnil_or_empty(self.params.ack_service_status,self.params.service_status)
  self.params.dt_host_status = self.common:ifnil_or_empty(self.params.dt_host_status,self.params.host_status)
  self.params.dt_service_status = self.common:ifnil_or_empty(self.params.dt_service_status,self.params.service_status)
  self.params.enable_host_status_dedup = self.common:check_boolean_number_option_syntax(self.params.enable_host_status_dedup, 0)
  self.params.enable_service_status_dedup = self.common:check_boolean_number_option_syntax(self.params.enable_service_status_dedup, 0)
end

--- get_kafka_params: retrieve the kafka parameters and store them the self.params.kafka table
-- @param kafka_config (object) object instance of kafka_config
-- @param params (table) the list of parameters from broker web configuration
function ScParams:get_kafka_params(kafka_config, params)
  for param_name, param_value in pairs(params) do
    -- check if param starts with sc_kafka (meaning it is a parameter for kafka)
    if string.find(param_name, "^_sc_kafka_") ~= nil then
      -- remove the _sc_kafka_ prefix and store the param in a dedicated kafka table
      kafka_config[string.gsub(param_name, "_sc_kafka_", "")] = param_value
      self.logger:notice("[sc_param:get_kafka_params]: " .. tostring(param_name) 
        .. " parameter with value " .. tostring(param_value) .. " added to kafka_config")
    end
  end
end

--- is_mandatory_config_set: check if the mandatory parameters required by a stream connector are set
-- @param mandatory_params (table) the list of mandatory parameters
-- @param params (table) the list of parameters from broker web configuration
-- @eturn true|false (boolean) 
function ScParams:is_mandatory_config_set(mandatory_params, params)
  for index, mandatory_param in ipairs(mandatory_params) do
    if not params[mandatory_param] then
      self.logger:error("[sc_param:is_mandatory_config_set]: " .. tostring(mandatory_param) 
        .. " parameter is not set in the stream connector web configuration")
      return false
    end
  end

  return true
end

return sc_params