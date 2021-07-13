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
    ack_service_status = "", -- will use service_status if empty
    dt_host_status = "", -- will use host_status if empty
    dt_service_status = "", -- will use service_status if empty
    
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
    enable_host_status_dedup = 1,
    enable_service_status_dedup = 1,
    
    -- communication parameters
    max_buffer_size = 1,
    max_buffer_age = 5,

    -- event formatting parameters
    format_file = "",

    -- time parameters
    local_time_diff_from_utc = os.difftime(os.time(), os.time(os.date("!*t", os.time()))),
    timestamp_conversion_format = "%Y-%m-%d %X", -- will print 2021-06-11 10:43:38

    -- internal parameters
    __internal_ts_last_flush = os.time(),

    -- testing parameters
    send_data_test = 0,
    
    -- initiate mappings
    element_mapping = {},
    status_mapping = {},
    state_type_mapping = {
      [0] = "SOFT",
      [1] = "HARD"
    },
    validatedEvents = {},
    
    -- FIX BROKER ISSUE 
    max_stored_events = 10 -- do not use values above 100 
  }

  -- maps categories name and id
  self.params.bbdo = {
    categories = {
      neb = 1,
      bbdo = 2,
      storage = 3,
      correlation = 4,
      dumper = 5,
      bam = 6,
      extcmd = 7
    },
    elements = {
      acknowledgement = {
        category = 1,
        element = 1
      },
      comment = {
        category = 1,
        element = 2
      },
      custom_variable = {
        category = 1,
        element = 3
      },
      custom_variable_status = {
        category = 1,
        element = 4
      },
      downtime = {
        category = 1,
        element = 5
      },
      event_handler = {
        category = 1,
        element = 6
      },
      flapping_status = {
        category = 1,
        element = 7
      },
      host_check = {
        category = 1,
        element = 8
      },
      host_dependency = {
        category = 1,
        element = 9
      },
      host_group = {
        category = 1,
        element = 10
      },
      host_group_member = {
        category = 1,
        element = 11
      },
      host = {
        category = 1,
        element = 12,
      },
      host_parent = {
        category = 1,
        element = 13
      },
      host_status = {
        category = 1,
        element = 14
      },
      instance = {
        category = 1,
        element = 15
      },
      instance_status = {
        category = 1,
        element = 16
      },
      log_entry = {
        category = 1,
        element = 17
      },
      module = {
        category = 1,
        element = 18
      },
      service_check = {
        category = 1,
        element = 19
      },
      service_dependency = {
        category = 1,
        element = 20
      },
      service_group = {
        category = 1,
        element = 21
      },
      service_group_member = {
        category = 1,
        element = 22
      },
      service = {
        category = 1,
        element = 23
      },
      service_status = {
        category = 1,
        element = 24
      },
      instance_configuration = {
        category = 1,
        element = 25
      },
      metric = {
        category = 3,
        element = 1
      },
      rebuild = {
        category = 3,
        element = 2
      },
      remove_graph = {
        category = 3,
        element = 3
      },
      status = {
        category = 3,
        element = 4
      },
      index_mapping = {
        category = 3,
        element = 5
      },
      metric_mapping = {
        category = 3,
        element = 6
      },
      ba_status = {
        category = 6,
        element = 1
      },
      kpi_status = {
        category = 6,
        element = 2
      },
      meta_service_status = {
        category = 6,
        element = 3
      },
      ba_event = {
        category = 6,
        element = 4
      },
      kpi_event = {
        category = 6,
        element = 5
      },
      ba_duration_event = {
        category = 6,
        element = 6
      },
      dimension_ba_event = {
        category = 6,
        element = 7
      },
      dimension_kpi_event = {
        category = 6,
        element = 8
      },
      dimension_ba_bv_relation_event = {
        category = 6,
        element = 9
      },
      dimension_bv_event = {
        category = 6,
        element = 10
      },
      dimension_truncate_table_signal = {
        category = 6,
        element = 11
      },
      bam_rebuild = {
        category = 6,
        element = 12
      },
      dimension_timeperiod = {
        category = 6,
        element = 13
      },
      dimension_ba_timeperiod_relation = {
        category = 6,
        element = 14
      },
      dimension_timeperiod_exception = {
        category = 6,
        element = 15
      },
      dimension_timeperiod_exclusion = {
        category = 6,
        element = 16
      },
      inherited_downtime = {
        category = 6,
        element = 17
      }
    }
  }

  local categories = self.params.bbdo.categories
  local elements = self.params.bbdo.elements
  
  -- initiate category and element mapping
  self.params.element_mapping = {
    [categories.neb] = {},
    [categories.storage] = {},
    [categories.bam] = {}
  }

  -- maps category id with element name and element id
  -- neb elements
  self.params.element_mapping[categories.neb].acknowledgement = elements.acknowledgement.element
  self.params.element_mapping[categories.neb].comment = elements.comment.element
  self.params.element_mapping[categories.neb].custom_variable = elements.custom_variable.element
  self.params.element_mapping[categories.neb].custom_variable_status = elements.custom_variable_status.element
  self.params.element_mapping[categories.neb].downtime = elements.downtime.element
  self.params.element_mapping[categories.neb].event_handler = elements.event_handler.element
  self.params.element_mapping[categories.neb].flapping_status = elements.flapping_status.element
  self.params.element_mapping[categories.neb].host_check = elements.host_check.element
  self.params.element_mapping[categories.neb].host_dependency = elements.host_dependency.element
  self.params.element_mapping[categories.neb].host_group = elements.host_group.element
  self.params.element_mapping[categories.neb].host_group_member = elements.host_group_member.element
  self.params.element_mapping[categories.neb].host = elements.host.element
  self.params.element_mapping[categories.neb].host_parent = elements.host_parent.element
  self.params.element_mapping[categories.neb].host_status = elements.host_status.element
  self.params.element_mapping[categories.neb].instance = elements.instance.element
  self.params.element_mapping[categories.neb].instance_status = elements.instance_status.element
  self.params.element_mapping[categories.neb].log_entry = elements.log_entry.element
  self.params.element_mapping[categories.neb].module = elements.module.element
  self.params.element_mapping[categories.neb].service_check = elements.service_check.element
  self.params.element_mapping[categories.neb].service_dependency = elements.service_dependency.element
  self.params.element_mapping[categories.neb].service_group = elements.service_group.element
  self.params.element_mapping[categories.neb].service_group_member = elements.service_group_member.element
  self.params.element_mapping[categories.neb].service = elements.service.element
  self.params.element_mapping[categories.neb].service_status = elements.service_status.element
  self.params.element_mapping[categories.neb].instance_configuration = elements.instance_configuration.element

  -- metric elements mapping
  self.params.element_mapping[categories.storage].metric = elements.metric.element
  self.params.element_mapping[categories.storage].rebuild = elements.rebuild.element
  self.params.element_mapping[categories.storage].remove_graph = elements.remove_graph.element
  self.params.element_mapping[categories.storage].status = elements.status.element
  self.params.element_mapping[categories.storage].index_mapping = elements.index_mapping.element
  self.params.element_mapping[categories.storage].metric_mapping = elements.metric_mapping.element

  -- bam elements mapping
  self.params.element_mapping[categories.bam].ba_status = elements.ba_status.element
  self.params.element_mapping[categories.bam].kpi_status = elements.kpi_status.element
  self.params.element_mapping[categories.bam].meta_service_status = elements.meta_service_status.element
  self.params.element_mapping[categories.bam].ba_event = elements.ba_event.element
  self.params.element_mapping[categories.bam].kpi_event = elements.kpi_event.element
  self.params.element_mapping[categories.bam].ba_duration_event = elements.ba_duration_event.element
  self.params.element_mapping[categories.bam].dimension_ba_event = elements.dimension_ba_event.element
  self.params.element_mapping[categories.bam].dimension_kpi_event = elements.dimension_kpi_event.element
  self.params.element_mapping[categories.bam].dimension_ba_bv_relation_event = elements.dimension_ba_bv_relation_event.element
  self.params.element_mapping[categories.bam].dimension_bv_event = elements.dimension_bv_event.element
  self.params.element_mapping[categories.bam].dimension_truncate_table_signal = elements.dimension_truncate_table_signal.element
  self.params.element_mapping[categories.bam].bam_rebuild = elements.bam_rebuild.element
  self.params.element_mapping[categories.bam].dimension_timeperiod = elements.dimension_timeperiod.element
  self.params.element_mapping[categories.bam].dimension_ba_timeperiod_relation = elements.dimension_ba_timeperiod_relation.element
  self.params.element_mapping[categories.bam].dimension_timeperiod_exception = elements.dimension_timeperiod_exception.element
  self.params.element_mapping[categories.bam].dimension_timeperiod_exclusion = elements.dimension_timeperiod_exclusion.element
  self.params.element_mapping[categories.bam].inherited_downtime = elements.inherited_downtime.element

  self.params.reverse_element_mapping = {
    [categories.neb] = {
      [elements.acknowledgement.element] = "acknowledgement",
      [elements.comment.element] = "comment",
      [elements.custom_variable.element] = "custom_variable",
      [elements.custom_variable_status.element] = "custom_variable_status",
      [elements.downtime.element] = "downtime",
      [elements.event_handler.element] = "event_handler",
      [elements.flapping_status.element] = "flapping_status",
      [elements.host_check.element] = "host_check",
      [elements.host_dependency.element] = "host_dependency",
      [elements.host_group.element] = "host_group",
      [elements.host_group_member.element] = "host_group_member",
      [elements.host.element] = "host",
      [elements.host_parent.element] = "host_parent",
      [elements.host_status.element] = "host_status",
      [elements.instance.element] = "instance",
      [elements.instance_status.element] = "instance_status",
      [elements.log_entry.element] = "log_entry",
      [elements.module.element] = "module",
      [elements.service_check.element] = "service_check",
      [elements.service_dependency.element] = "service_dependency",
      [elements.service_group.element] = "service_group",
      [elements.service_group_member.element] = "service_group_member",
      [elements.service.element] = "service",
      [elements.service_status.element] = "service_status",
      [elements.instance_configuration.element] = "instance_configuration"
    },
    [categories.storage] = {
      [elements.metric.element] = "metric",
      [elements.rebuild.element] = "rebuild",
      [elements.remove_graph.element] = "remove_graph",
      [elements.status.element] = "status",
      [elements.index_mapping.element] = "index_mapping",
      [elements.metric_mapping.element] = "metric_mapping"
    },
    [categories.bam] = {
      [elements.ba_status.element] = "ba_status",
      [elements.kpi_status.element] = "kpi_status",
      [elements.meta_service_status.element] = "meta_service_status",
      [elements.ba_event.element] = "ba_event",
      [elements.kpi_event.element] = "kpi_event",
      [elements.ba_duration_event.element] = "ba_duration_event",
      [elements.dimension_ba_event.element] = "dimension_ba_event",
      [elements.dimension_kpi_event.element] = "dimension_kpi_event",
      [elements.dimension_ba_bv_relation_event.element] = "dimension_ba_bv_relation_event",
      [elements.dimension_bv_event.element] = "dimension_bv_event",
      [elements.dimension_truncate_table_signal.element] = "dimension_truncate_table_signal",
      [elements.bam_rebuild.element] = "bam_rebuild",
      [elements.dimension_timeperiod.element] = "dimension_timeperiod",
      [elements.dimension_ba_timeperiod_relation.element] = "dimension_ba_timeperiod_relation",
      [elements.dimension_timeperiod_exception.element] = "dimension_timeperiod_exception",
      [elements.dimension_timeperiod_exclusion.element] = "dimension_timeperiod_exclusion",
      [elements.inherited_downtime.element] = "inherited_downtime"
    }
  }


  -- initiate category and status mapping
  self.params.status_mapping = {
    [categories.neb] = {
      [elements.downtime] = {
        [1] = {},
        [2] = {}
      },
      [elements.host_status] = {
        [0] = "UP",
        [1] = "DOWN",
        [2] = "UNREACHABLE"
      },
      [elements.service_status] = {
        [0] = "OK",
        [1] = "WARNING",
        [2] = "CRITICAL",
        [3] = "UNKNOWN"
      }
    },
    [categories.bam] = {
      [0] = "OK",
      [1] = "WARNING",
      [2] = "CRITICAL"
    }
  }

  self.params.format_template = {
    [categories.neb] = {
      [elements.acknowledgement.element] = "",
      [elements.downtime.element] = "",
      [elements.host_status.element] = "",
      [elements.service_status.element] = ""
    },
    [categories.bam] = {
      [elements.ba_status.element] = ""
    }
  }

  self.params.status_mapping[categories.neb][elements.downtime.element][1] = self.params.status_mapping[categories.neb][elements.service_status.element]
  self.params.status_mapping[categories.neb][elements.downtime.element][2] = self.params.status_mapping[categories.neb][elements.host_status.element]

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
    if self.params[param_name] or string.find(param_name, "^_sc") ~= nil then
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
  self.params.send_data_test = self.common:check_boolean_number_option_syntax(self.params.send_data_test, 0)
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

    -- add the mandatory param name in the list of the standard params and set its value to the user provided param value
    self.params[mandatory_param] = params[mandatory_param]
  end

  return true
end

--- load_event_format_file: load a json file which purpose is to serve as a template to format events
-- @return true|false (boolean) if file is valid template file or not
function ScParams:load_event_format_file()
  if self.params.format_file == "" or self.params.format_file == nil then
    return false
  end 
  
  local retval, content = self.sc_common:load_json_file(self.params.format_file)
  
  if not retval then
    return false
  end

  local categories = self.params.bbdo.categories
  local elements = self.params.bbdo.elements
  self.params.format_template[categories.neb][elements.host_status.element] = content.host
  self.params.format_template[categories.neb][elements.service_status.element] = content.service
  self.params.format_template[categories.neb][elements.acknowledgement.element] = content.ack
  self.params.format_template[categories.neb][elements.downtime.element] = content.dt
  self.params.format_template[categories.bam][elements.ba_status.element] = content.ba

  return true
end

return sc_params