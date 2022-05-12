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

  -- get the version of the bbdo protocol (only the first digit, nothing else matters)
  if broker.bbdo_version ~= nil then
    _, _, self.bbdo_version = string.find(broker.bbdo_version(), "(%d+).%d+.%d+")
  else
    self.bbdo_version = 2
  end

  self.bbdo_version = tonumber(self.bbdo_version)
  
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
    max_buffer_age = 5, --deprecated
    max_all_queues_age = 60,
    send_mixed_events = 1,

    -- connection parameters
    connection_timeout = 60,
    allow_insecure_connection = 0,

    -- proxy parameters
    proxy_address = "",
    proxy_port = "",
    proxy_username = "",
    proxy_password = "",

    -- event formatting parameters
    format_file = "",
    use_long_output = 1,
    remove_line_break_in_output = 1,
    output_line_break_replacement_character = " ",

    -- time parameters
    local_time_diff_from_utc = os.difftime(os.time(), os.time(os.date("!*t", os.time()))),
    timestamp_conversion_format = "%Y-%m-%d %X", -- will print 2021-06-11 10:43:38

    -- internal parameters
    __internal_ts_last_flush = os.time(),
    __internal_last_global_flush_date = os.time(),

    -- testing parameters
    send_data_test = 0,

    -- logging parameters
    logfile = "",
    log_level = "",
    
    -- metric
    metric_name_regex = "",
    metric_replacement_character = "_",

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
      neb = {
        id = 1,
        name = "neb"
      },
      storage = {
        id = 3,
        name = "storage"
      },
      bam = {
        id = 6,
        name = "bam"
      }
    }
  }
  
  local categories = self.params.bbdo.categories

  local bbdo2_bbdo3_compat_mapping = {
    [2] = {
      host_status = {
        category_id = categories.neb.id,
        category_name = categories.neb.name,
        id = 14,
        name = "host_status"
      },
      service_status = {
        category_id = categories.neb.id,
        category_name = categories.neb.name,
        id = 24,
        name = "service_status"
      },
    },
    [3] = {
      host_status = {
        category_id = categories.neb.id,
        category_name = categories.neb.name,
        id = 32,
        name = "pb_host_status"
      },
      service_status = {
        category_id = categories.neb.id,
        category_name = categories.neb.name,
        id = 29,
        name = "pb_service_status"
      }
    }
  }

  self.params.bbdo.elements = {
    acknowledgement = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 1,
      name = "acknowledgement"
    },
    comment = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 2,
      name = "comment"
    },
    custom_variable = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 3,
      name = "custom_variable"
    },
    custom_variable_status = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 4,
      name = "custom_variable_status"
    },
    downtime = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 5,
      name = "downtime"
    },
    event_handler = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 6,
      name = "event_handler"
    },
    flapping_status = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 7,
      name = "flapping_status"
    },
    host_check = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 8,
      name = "host_check"
    },
    host_dependency = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 9,
      name = "host_dependency"
    },
    host_group = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 10,
      name = "host_group"
    },
    host_group_member = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 11,
      name = "host_group_member"
    },
    host = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 12,
      name = "host"
    },
    host_parent = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 13,
      name = "host_parent"
    },
    host_status = bbdo2_bbdo3_compat_mapping[self.bbdo_version]["host_status"],
    instance = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 15,
      name = "instance"
    },
    instance_status = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 16,
      name = "instance_status"
    },
    log_entry = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 17,
      name = "log_entry"
    },
    module = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 18,
      name = "module"
    },
    service_check = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 19,
      name = "service_check"
    },
    service_dependency = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 20,
      name = "service_dependency"
    },
    service_group = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 21,
      name = "service_group"
    },
    service_group_member = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 22,
      name = "service_group_member"
    },
    service = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 23,
      name = "service"
    },
    service_status = bbdo2_bbdo3_compat_mapping[self.bbdo_version]["service_status"],
    instance_configuration = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 25,
      name = "instance_configuration"
    },
    responsive_instance = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 26,
      name = "responsive_instance"
    },
    pb_service = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 27,
      name = "pb_service"
    },
    pb_adaptive_service = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 28,
      name = "pb_adaptive_service"
    },
    pb_service_status = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 29,
      name = "pb_service_status"
    },
    pb_host = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 30,
      name = "pb_host"
    },
    pb_adaptive_host = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 31,
      name = "pb_adaptive_host"
    },
    pb_host_status = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 32,
      name = "pb_host_status"
    },
    pb_severity = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 33,
      name = "pb_severity"
    },
    pb_tag = {
      category_id = categories.neb.id,
      category_name = categories.neb.name,
      id = 34,
      name = "pb_tag"
    },
    metric = {
      category_id = categories.storage.id,
      category_name = categories.storage.name,
      id = 1,
      name = "metric"
    },
    rebuild = {
      category_id = categories.storage.id,
      category_name = categories.storage.name,
      id = 2,
      name = "rebuild"
    },
    remove_graph = {
      category_id = categories.storage.id,
      category_name = categories.storage.name,
      id = 3,
      name = "remove_graph"
    },
    status = {
      category_id = categories.storage.id,
      category_name = categories.storage.name,
      id = 4,
      name = "status"
    },
    index_mapping = {
      category_id = categories.storage.id,
      category_name = categories.storage.name,
      id = 5,
      name = "index_mapping"
    },
    metric_mapping = {
      category_id = categories.storage.id,
      category_name = categories.storage.name,
      id = 6,
      name = "metric_mapping"
    },
    ba_status = {
      category_id = categories.bam.id,
      category_name = categories.bam.name,
      id = 1,
      name = "ba_status"
    },
    kpi_status = {
      category_id = categories.bam.id,
      category_name = categories.bam.name,
      id = 2,
      name = "kpi_status"
    },
    meta_service_status = {
      category_id = categories.bam.id,
      category_name = categories.bam.name,
      id = 3,
      name = "meta_service_status"
    },
    ba_event = {
      category_id = categories.bam.id,
      category_name = categories.bam.name,
      id = 4,
      name = "ba_event"
    },
    kpi_event = {
      category_id = categories.bam.id,
      category_name = categories.bam.name,
      id = 5,
      name = "kpi_event"
    },
    ba_duration_event = {
      category_id = categories.bam.id,
      category_name = categories.bam.name,
      id = 6,
      name = "ba_duration_event"
    },
    dimension_ba_event = {
      category_id = categories.bam.id,
      category_name = categories.bam.name,
      id = 7,
      name = "dimension_ba_event"
    },
    dimension_kpi_event = {
      category_id = categories.bam.id,
      category_name = categories.bam.name,
      id = 8,
      name = "dimension_kpi_event"
    },
    dimension_ba_bv_relation_event = {
      category_id = categories.bam.id,
      category_name = categories.bam.name,
      id = 9,
      name = "dimension_ba_bv_relation_event"
    },
    dimension_bv_event = {
      category_id = categories.bam.id,
      category_name = categories.bam.name,
      id = 10,
      name = "dimension_bv_event"
    },
    dimension_truncate_table_signal = {
      category_id = categories.bam.id,
      category_name = categories.bam.name,
      id = 11,
      name = "dimension_truncate_table_signal"
    },
    bam_rebuild = {
      category_id = categories.bam.id,
      category_name = categories.bam.name,
      id = 12,
      name = "bam_rebuild"
    },
    dimension_timeperiod = {
      category_id = categories.bam.id,
      category_name = categories.bam.name,
      id = 13,
      name = "dimension_timeperiod"
    },
    dimension_ba_timeperiod_relation = {
      category_id = categories.bam.id,
      category_name = categories.bam.name,
      id = 14,
      name = "dimension_ba_timeperiod_relation"
    },
    dimension_timeperiod_exception = {
      category_id = categories.bam.id,
      category_name = categories.bam.name,
      id = 15,
      name = "dimension_timeperiod_exception"
    },
    dimension_timeperiod_exclusion = {
      category_id = categories.bam.id,
      category_name = categories.bam.name,
      id = 16,
      name = "dimension_timeperiod_exclusion"
    },
    inherited_downtime = {
      category_id = categories.bam.id,
      category_name = categories.bam.name,
      id = 17,
      name = "inherited_downtime"
    }
  }

  local elements = self.params.bbdo.elements
  
  -- initiate category and element mapping
  self.params.element_mapping = {
    [categories.neb.id] = {},
    [categories.storage.id] = {},
    [categories.bam.id] = {}
  }

  -- maps category id with element name and element id
  -- neb elements
  self.params.element_mapping[categories.neb.id].acknowledgement = elements.acknowledgement.id
  self.params.element_mapping[categories.neb.id].comment = elements.comment.id
  self.params.element_mapping[categories.neb.id].custom_variable = elements.custom_variable.id
  self.params.element_mapping[categories.neb.id].custom_variable_status = elements.custom_variable_status.id
  self.params.element_mapping[categories.neb.id].downtime = elements.downtime.id
  self.params.element_mapping[categories.neb.id].event_handler = elements.event_handler.id
  self.params.element_mapping[categories.neb.id].flapping_status = elements.flapping_status.id
  self.params.element_mapping[categories.neb.id].host_check = elements.host_check.id
  self.params.element_mapping[categories.neb.id].host_dependency = elements.host_dependency.id
  self.params.element_mapping[categories.neb.id].host_group = elements.host_group.id
  self.params.element_mapping[categories.neb.id].host_group_member = elements.host_group_member.id
  self.params.element_mapping[categories.neb.id].host = elements.host.id
  self.params.element_mapping[categories.neb.id].host_parent = elements.host_parent.id
  self.params.element_mapping[categories.neb.id].host_status = elements.host_status.id
  self.params.element_mapping[categories.neb.id].instance = elements.instance.id
  self.params.element_mapping[categories.neb.id].instance_status = elements.instance_status.id
  self.params.element_mapping[categories.neb.id].log_entry = elements.log_entry.id
  self.params.element_mapping[categories.neb.id].module = elements.module.id
  self.params.element_mapping[categories.neb.id].service_check = elements.service_check.id
  self.params.element_mapping[categories.neb.id].service_dependency = elements.service_dependency.id
  self.params.element_mapping[categories.neb.id].service_group = elements.service_group.id
  self.params.element_mapping[categories.neb.id].service_group_member = elements.service_group_member.id
  self.params.element_mapping[categories.neb.id].service = elements.service.id
  self.params.element_mapping[categories.neb.id].service_status = elements.service_status.id
  self.params.element_mapping[categories.neb.id].instance_configuration = elements.instance_configuration.id
  self.params.element_mapping[categories.neb.id].responsive_instance = elements.responsive_instance.id
  self.params.element_mapping[categories.neb.id].pb_service = elements.pb_service.id
  self.params.element_mapping[categories.neb.id].pb_adaptive_service = elements.pb_adaptive_service.id
  self.params.element_mapping[categories.neb.id].pb_service_status = elements.pb_service_status.id
  self.params.element_mapping[categories.neb.id].pb_host = elements.pb_host.id
  self.params.element_mapping[categories.neb.id].pb_adaptive_host = elements.pb_adaptive_host.id
  self.params.element_mapping[categories.neb.id].pb_host_status = elements.pb_host_status.id
  self.params.element_mapping[categories.neb.id].pb_severity = elements.pb_severity.id
  self.params.element_mapping[categories.neb.id].pb_tag = elements.pb_tag.id

  -- metric elements mapping
  self.params.element_mapping[categories.storage.id].metric = elements.metric.id
  self.params.element_mapping[categories.storage.id].rebuild = elements.rebuild.id
  self.params.element_mapping[categories.storage.id].remove_graph = elements.remove_graph.id
  self.params.element_mapping[categories.storage.id].status = elements.status.id
  self.params.element_mapping[categories.storage.id].index_mapping = elements.index_mapping.id
  self.params.element_mapping[categories.storage.id].metric_mapping = elements.metric_mapping.id

  -- bam elements mapping
  self.params.element_mapping[categories.bam.id].ba_status = elements.ba_status.id
  self.params.element_mapping[categories.bam.id].kpi_status = elements.kpi_status.id
  self.params.element_mapping[categories.bam.id].meta_service_status = elements.meta_service_status.id
  self.params.element_mapping[categories.bam.id].ba_event = elements.ba_event.id
  self.params.element_mapping[categories.bam.id].kpi_event = elements.kpi_event.id
  self.params.element_mapping[categories.bam.id].ba_duration_event = elements.ba_duration_event.id
  self.params.element_mapping[categories.bam.id].dimension_ba_event = elements.dimension_ba_event.id
  self.params.element_mapping[categories.bam.id].dimension_kpi_event = elements.dimension_kpi_event.id
  self.params.element_mapping[categories.bam.id].dimension_ba_bv_relation_event = elements.dimension_ba_bv_relation_event.id
  self.params.element_mapping[categories.bam.id].dimension_bv_event = elements.dimension_bv_event.id
  self.params.element_mapping[categories.bam.id].dimension_truncate_table_signal = elements.dimension_truncate_table_signal.id
  self.params.element_mapping[categories.bam.id].bam_rebuild = elements.bam_rebuild.id
  self.params.element_mapping[categories.bam.id].dimension_timeperiod = elements.dimension_timeperiod.id
  self.params.element_mapping[categories.bam.id].dimension_ba_timeperiod_relation = elements.dimension_ba_timeperiod_relation.id
  self.params.element_mapping[categories.bam.id].dimension_timeperiod_exception = elements.dimension_timeperiod_exception.id
  self.params.element_mapping[categories.bam.id].dimension_timeperiod_exclusion = elements.dimension_timeperiod_exclusion.id
  self.params.element_mapping[categories.bam.id].inherited_downtime = elements.inherited_downtime.id

  self.params.reverse_element_mapping = {
    [categories.neb.id] = {
      [elements.acknowledgement.id] = "acknowledgement",
      [elements.comment.id] = "comment",
      [elements.custom_variable.id] = "custom_variable",
      [elements.custom_variable_status.id] = "custom_variable_status",
      [elements.downtime.id] = "downtime",
      [elements.event_handler.id] = "event_handler",
      [elements.flapping_status.id] = "flapping_status",
      [elements.host_check.id] = "host_check",
      [elements.host_dependency.id] = "host_dependency",
      [elements.host_group.id] = "host_group",
      [elements.host_group_member.id] = "host_group_member",
      [elements.host.id] = "host",
      [elements.host_parent.id] = "host_parent",
      [elements.host_status.id] = "host_status",
      [elements.instance.id] = "instance",
      [elements.instance_status.id] = "instance_status",
      [elements.log_entry.id] = "log_entry",
      [elements.module.id] = "module",
      [elements.service_check.id] = "service_check",
      [elements.service_dependency.id] = "service_dependency",
      [elements.service_group.id] = "service_group",
      [elements.service_group_member.id] = "service_group_member",
      [elements.service.id] = "service",
      [elements.service_status.id] = "service_status",
      [elements.instance_configuration.id] = "instance_configuration",
      [elements.pb_service.id] = "pb_service",
      [elements.pb_adaptive_service.id] = "pb_adaptive_service",
      [elements.pb_service_status.id] = "pb_service_status",
      [elements.pb_host.id] = "pb_host",
      [elements.pb_adaptive_host.id] = "pb_adaptive_host",
      [elements.pb_host_status.id] = "pb_host_status",
      [elements.pb_severity.id] = "pb_severity",
      [elements.pb_tag] = "pb_tag"
    },
    [categories.storage.id] = {
      [elements.metric.id] = "metric",
      [elements.rebuild.id] = "rebuild",
      [elements.remove_graph.id] = "remove_graph",
      [elements.status.id] = "status",
      [elements.index_mapping.id] = "index_mapping",
      [elements.metric_mapping.id] = "metric_mapping"
    },
    [categories.bam.id] = {
      [elements.ba_status.id] = "ba_status",
      [elements.kpi_status.id] = "kpi_status",
      [elements.meta_service_status.id] = "meta_service_status",
      [elements.ba_event.id] = "ba_event",
      [elements.kpi_event.id] = "kpi_event",
      [elements.ba_duration_event.id] = "ba_duration_event",
      [elements.dimension_ba_event.id] = "dimension_ba_event",
      [elements.dimension_kpi_event.id] = "dimension_kpi_event",
      [elements.dimension_ba_bv_relation_event.id] = "dimension_ba_bv_relation_event",
      [elements.dimension_bv_event.id] = "dimension_bv_event",
      [elements.dimension_truncate_table_signal.id] = "dimension_truncate_table_signal",
      [elements.bam_rebuild.id] = "bam_rebuild",
      [elements.dimension_timeperiod.id] = "dimension_timeperiod",
      [elements.dimension_ba_timeperiod_relation.id] = "dimension_ba_timeperiod_relation",
      [elements.dimension_timeperiod_exception.id] = "dimension_timeperiod_exception",
      [elements.dimension_timeperiod_exclusion.id] = "dimension_timeperiod_exclusion",
      [elements.inherited_downtime.id] = "inherited_downtime"
    }
  }

  self.params.reverse_category_mapping = {
    [categories.neb.id] = categories.neb.name,
    [2] = "bbdo",
    [categories.storage.id] = categories.storage.id,
    [4] = "correlation",
    [5] = "dumper",
    [categories.bam.id] = categories.bam.name,
    [7] = "extcmd"
  }

  self.params.category_mapping = {
    [categories.neb.name] = categories.neb.id,
    bbdo = 2,
    [categories.storage.name] = categories.storage.id,
    correlation = 4,
    dumper = 5,
    [categories.bam.name] = categories.bam.id,
    extcmd = 7
  }

  -- initiate category and status mapping
  self.params.status_mapping = {
    [categories.neb.id] = {
      [elements.acknowledgement.id] = {
        host_status = {},
        service_status = {}
      },
      [elements.downtime.id] = {
        [1] = {},
        [2] = {}
      },
      [elements.host_status.id] = {
        [0] = "UP",
        [1] = "DOWN",
        [2] = "UNREACHABLE"
      },
      [elements.service_status.id] = {
        [0] = "OK",
        [1] = "WARNING",
        [2] = "CRITICAL",
        [3] = "UNKNOWN"
      },
      [elements.pb_host_status.id] = {
        [0] = "UP",
        [1] = "DOWN",
        [2] = "UNREACHABLE"
      },
      [elements.pb_service_status.id] = {
        [0] = "OK",
        [1] = "WARNING",
        [2] = "CRITICAL",
        [3] = "UNKNOWN"
      }
    },
    [categories.bam.id] = {
      [0] = "OK",
      [1] = "WARNING",
      [2] = "CRITICAL"
    }
  }

  self.params.format_template = {
    [categories.neb.id] = {},
    [categories.bam.id] = {}
  }

  -- downtime status mapping
  self.params.status_mapping[categories.neb.id][elements.downtime.id][1] = self.params.status_mapping[categories.neb.id][elements.service_status.id]
  self.params.status_mapping[categories.neb.id][elements.downtime.id][2] = self.params.status_mapping[categories.neb.id][elements.host_status.id]

  -- acknowledgement status mapping
  self.params.status_mapping[categories.neb.id][elements.acknowledgement.id].host_status = self.params.status_mapping[categories.neb.id][elements.host_status.id]
  self.params.status_mapping[categories.neb.id][elements.acknowledgement.id].service_status = self.params.status_mapping[categories.neb.id][elements.service_status.id]
  

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
  self.params.ack_host_status = self.common:ifnil_or_empty(self.params.ack_host_status, self.params.host_status)
  self.params.ack_service_status = self.common:ifnil_or_empty(self.params.ack_service_status, self.params.service_status)
  self.params.dt_host_status = self.common:ifnil_or_empty(self.params.dt_host_status, self.params.host_status)
  self.params.dt_service_status = self.common:ifnil_or_empty(self.params.dt_service_status, self.params.service_status)
  self.params.enable_host_status_dedup = self.common:check_boolean_number_option_syntax(self.params.enable_host_status_dedup, 0)
  self.params.enable_service_status_dedup = self.common:check_boolean_number_option_syntax(self.params.enable_service_status_dedup, 0)
  self.params.send_data_test = self.common:check_boolean_number_option_syntax(self.params.send_data_test, 0)
  self.params.proxy_address = self.common:if_wrong_type(self.params.proxy_address, "string", "")
  self.params.proxy_port = self.common:if_wrong_type(self.params.proxy_port, "number", "")
  self.params.proxy_username = self.common:if_wrong_type(self.params.proxy_username, "string", "")
  self.params.proxy_password = self.common:if_wrong_type(self.params.proxy_password, "string", "")
  self.params.connection_timeout = self.common:if_wrong_type(self.params.connection_timeout, "number", 60)
  self.params.allow_insecure_connection = self.common:number_to_boolean(self.common:check_boolean_number_option_syntax(self.params.allow_insecure_connection, 0))
  self.params.logfile = self.common:ifnil_or_empty(self.params.logfile, "/var/log/centreon-broker/stream-connector.log")
  self.params.log_level = self.common:ifnil_or_empty(self.params.log_level, 1)
  self.params.use_long_output = self.common:check_boolean_number_option_syntax(self.params.use_longoutput, 1)
  self.params.remove_line_break_in_output = self.common:check_boolean_number_option_syntax(self.params.remove_line_break_in_output, 1)
  self.params.output_line_break_replacement_character = self.common:if_wrong_type(self.params.output_line_break_replacement_character, "string", " ")
  self.params.metric_name_regex = self.common:if_wrong_type(self.params.metric_name_regex, "string", "")
  self.params.metric_replacement_character = self.common:ifnil_or_empty(self.params.metric_replacement_character, "_")
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
    if not params[mandatory_param] or params[mandatory_param] == "" then
      self.logger:error("[sc_param:is_mandatory_config_set]: " .. tostring(mandatory_param) 
        .. " parameter is not set in the stream connector web configuration (or value is empty)")
      return false
    end

    -- add the mandatory param name in the list of the standard params and set its value to the user provided param value
    self.params[mandatory_param] = params[mandatory_param]
  end

  return true
end

--- load_event_format_file: load a json file which purpose is to serve as a template to format events
-- @param json_string [opt] (boolean) convert template from a lua table to a json string
-- @return true|false (boolean) if file is valid template file or not
function ScParams:load_event_format_file(json_string)
  -- return if there is no file configured
  if self.params.format_file == "" or self.params.format_file == nil then
    return false
  end 
  
  local retval, content = self.common:load_json_file(self.params.format_file)
  
  -- return if we couldn't load the json file
  if not retval then
    return false
  end

  -- initiate variables
  local categories = self.params.bbdo.categories
  local elements = self.params.bbdo.elements
  local tpl_category
  local tpl_element
  
  -- store format template in their appropriate category/element table
  for cat_el, format in pairs(content) do
    tpl_category, tpl_element = string.match(cat_el, "^(%w+)_(.*)")
    
    -- convert back to json if 
    if json_string then
      format = broker.json_encode(format)
    end
    
    self.params.format_template[categories[tpl_category].id][elements[tpl_element].id] = format
  end

  return true
end

function ScParams:build_accepted_elements_info()
  categories = self.params.bbdo.categories
  self.params.accepted_elements_info = {}

  -- list all accepted elements
  for _, accepted_element in ipairs(self.common:split(self.params.accepted_elements, ",")) do
    -- try to find element in known categories
    for category_name, category_info in pairs(categories) do        
      if self.params.element_mapping[category_info.id][accepted_element] then
        -- if found, store information in a dedicated table
        self.params.accepted_elements_info[accepted_element] = {
          category_id = category_info.id,
          category_name = category_name,
          element_id = self.params.element_mapping[category_info.id][accepted_element],
          element_name = accepted_element
        }
      end
    end
  end
end

return sc_params