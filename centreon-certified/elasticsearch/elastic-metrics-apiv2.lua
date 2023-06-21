#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker Elastic Connector Metrics
--------------------------------------------------------------------------------


-- Libraries
local curl = require "cURL"
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_event = require("centreon-stream-connectors-lib.sc_event")
local sc_params = require("centreon-stream-connectors-lib.sc_params")
local sc_macros = require("centreon-stream-connectors-lib.sc_macros")
local sc_flush = require("centreon-stream-connectors-lib.sc_flush")
local sc_metrics = require("centreon-stream-connectors-lib.sc_metrics")

--------------------------------------------------------------------------------
-- Classe event_queue
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Classe event_queue
--------------------------------------------------------------------------------

local EventQueue = {}
EventQueue.__index = EventQueue

--------------------------------------------------------------------------------
---- Constructor
---- @param conf The table given by the init() function and returned from the GUI
---- @return the new EventQueue
----------------------------------------------------------------------------------

function EventQueue.new(params)
  local self = {}

  local mandatory_parameters = {
    "elastic_username",
    "elastic_password",
    "http_server_url"
  }

  self.fail = false

  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/elastic-metrics.log"
  local log_level = params.log_level or 1

  -- initiate mandatory objects
  self.sc_logger = sc_logger.new(logfile, log_level)
  self.sc_common = sc_common.new(self.sc_logger)
  self.sc_broker = sc_broker.new(self.sc_logger)
  self.sc_params = sc_params.new(self.sc_common, self.sc_logger)

  -- checking mandatory parameters and setting a fail flag
  if not self.sc_params:is_mandatory_config_set(mandatory_parameters, params) then
    self.fail = true
  end

  -- overriding default parameters for this stream connector if the default values doesn't suit the basic needs
  self.sc_params.params.elastic_username = params.elastic_username
  self.sc_params.params.elastic_password = params.elastic_password
  self.sc_params.params.http_server_url = params.http_server_url
  self.sc_params.params.accepted_categories = params.accepted_categories or "neb"
  self.sc_params.params.accepted_elements = params.accepted_elements or "host_status,service_status"
  self.sc_params.params.max_buffer_size = params.max_buffer_size or 30
  self.sc_params.params.hard_only = params.hard_only or 0
  self.sc_params.params.enable_host_status_dedup = params.enable_host_status_dedup or 0
  self.sc_params.params.enable_service_status_dedup = params.enable_service_status_dedup or 0
  self.sc_params.params.metric_name_regex = params.metric_name_regex or "[^a-zA-Z0-9_%.]"
  self.sc_params.params.metric_replacement_character = params.metric_replacement_character or "_" 

  -- elastic search index parameters
  self.sc_params.params.index_template_api_endpoint = params.index_template_api_endpoint or "/_index_template"
  self.sc_params.params.index_name = params.index_name or "centreon-metrics"
  self.sc_params.params.index_pattern = params.index_pattern or params.index_name .. "*"
  self.sc_params.params.index_priority = params.index_priority or 200
  self.sc_params.params.create_datastream_index_template = params.create_datastream_index_template or 1
  self.sc_params.params.update_datastream_index_template = params.update_datastream_index_template or 0

  -- index dimensions parameters
  self.sc_params.params.add_hostgroups_dimension = params.add_hostgroups_dimension or 1
  self.sc_params.params.add_servicesgroups_dimension = params.accepted_servicegroups or 0
  self.sc_params.params.add_geocoords_dimension = params.add_geocoords_dimension or 0

  -- apply users params and check syntax of standard ones
  self.sc_params:param_override(params)
  self.sc_params:check_params()
  self.sc_macros = sc_macros.new(self.sc_params.params, self.sc_logger)

  -- only load the custom code file, not executed yet
  if self.sc_params.load_custom_code_file and not self.sc_params:load_custom_code_file(self.sc_params.params.custom_code_file) then
    self.sc_logger:error("[EventQueue:new]: couldn't successfully load the custom code file: " .. tostring(self.sc_params.params.custom_code_file))
  end

  self.sc_params:build_accepted_elements_info()
  self.sc_flush = sc_flush.new(self.sc_params.params, self.sc_logger)

  local categories = self.sc_params.params.bbdo.categories
  local elements = self.sc_params.params.bbdo.elements

  self.format_event = {
    [categories.neb.id] = {
      [elements.host_status.id] = function () return self:format_event_host() end,
      [elements.service_status.id] = function () return self:format_event_service() end
    }
  }

  self.format_metric = {
    [categories.neb.id] = {
      [elements.host_status.id] = function (metric) return self:format_metric_host(metric) end,
      [elements.service_status.id] = function (metric) return self:format_metric_service(metric) end
    }
  }

  self.send_data_method = {
    [1] = function (payload, queue_metadata) return self:send_data(payload, queue_metadata) end
  }

  self.build_payload_method = {
    [1] = function (payload, event) return self:build_payload(payload, event) end
  }

  -- return EventQueue object
  setmetatable(self, { __index = EventQueue })
  self:build_index_template(self.sc_params.params)
  self:handle_index(self.sc_params.params)
  return self
end

function EventQueue:build_index_template(params)
  self.index_templat_meta = {
    description = "Timeseries index template for Centreon metrics",
    create_by_centreon = true
  }

  self.elastic_index_template = {
    index_patterns = {params.index_pattern},
    data_stream = {},
    priority = params.index_priority,
    _meta = self.index_templat_meta,
    template = {
      settings = {
        ["index.mode"] = "time_series"
      },
      mappings = {
        properties = {
          ["host.name"] = {
            type = "keyword",
            time_series_dimension = true
          },
          ["service.description"] = {
            type = "keyword",
            time_series_dimension = true
          },
          ["metric.name"] = {
            type = "keyword",
            time_series_dimension = true
          },
          ["metric.unit"] = {
            type = "keyword",
            time_series_dimension = false
          },
          ["metric.instance"] = {
            type = "keyword",
            time_series_dimension = true
          },
          ["metric.subinstances"] = {
            type = "keyword",
            time_series_dimension = true
          },
          ["metric.value"] = {
            type = "double",
            time_series_metric = gauge
          },
        }
      }
    }
  }
end

function EventQueue:handle_index(params)
  local index_structure = self:check_index_template(params)
end

function EventQueue:check_index_template(params)
  local metadata = {
    method = "GET",
    endpoint = params.index_template_api_endpoint .. "/" .. params.index_name
  }
  local payload = nil
  local index_state = {
    is_created = false,
    is_up_to_date = false,
  }

  if send_data(payload, metadata) then
    self.sc_logger:debug("[EventQueue:check_index_template]: Elasticsearch index template " .. tostring(params.index_name) .. " has been found")
    index_state.is_created = true
    index_state.is_up_to_date = self:validate_index_template(params)
  else
    self.sc_logger:error("[EventQueue:check_index_template]: Elasticsearch index template " .. tostring(params.index_name) .. " has not been found")
  end

  return retval
end

function EventQueue:validate_index_template(params)
  local index_template_structure, error = broker.json_decode(self.elastic_result)

  if error then
    self.sc_logger:error("[EventQueue:validate_index_template]: Could not decode json: " .. tostring(self.elastic_result) .. ". Error message is: " .. tostring(error))
    return true
  end

  local return_code = true
  local required_index_mappings = {
    "host.name",
    "service.description",
    "metric.value",
    "metric.unit",
    "metric.value",
    "metric.instance",
    "metric.subinstances"
  }

  if params.add_hostgroups_dimension == 1 then
    table.insert(required_index_mappings, "host.groups")
  end

  if params.add_servicesgroups_dimension == 1 then
    table.insert(required_index_mappings, "service.groups")
  end

  if params.add_geocoords_dimension == 1 then
    table.insert(required_index_mappings, "host.geocoords")
  end
  
  -- check if all the mappings are created in the index template
  for _, index_mapping_name in ipairs(required_index_mappings) do
    if not index_template_structure.template.mappings.properties[index_mapping_name] then
      -- we will only try to update the index if it has already been created by centreon
      if (params.update_datastream_index_template == 1 and index_template_structure["_meta"].create_by_centreon) then
        if not self:update_index_template(params) then
          return_code = false
        end
      else
        -- we do not return at the first missing property because we want to display all the missing one in one go instead.
        self.sc_logger:error("[EventQueue:validate_index_template]: Elastic index template is not valid. Missing mapping property: "
          .. tostring(index_mapping_name))
        return_code = false
      end
  end

  return return_code
end

function EventQueue:update_index_template(params)
  local metadata = {
    method = "PUT",
    endpoint = params.index_template_api_endpoint .. "/" .. params.index_name
  }


end

--------------------------------------------------------------------------------
---- EventQueue:format_accepted_event method
--------------------------------------------------------------------------------
function EventQueue:format_accepted_event()
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element

  self.sc_logger:debug("[EventQueue:format_event]: starting format event")

  -- can't format event if stream connector is not handling this kind of event and that it is not handled with a template file
  if not self.format_event[category][element] then
    self.sc_logger:error("[format_event]: You are trying to format an event with category: "
      .. tostring(self.sc_params.params.reverse_category_mapping[category]) .. " and element: "
      .. tostring(self.sc_params.params.reverse_element_mapping[category][element])
      .. ". If it is a not a misconfiguration, you should create a format file to handle this kind of element")
  else
    self.format_event[category][element]()
  end

  self.sc_logger:debug("[EventQueue:format_event]: event formatting is finished")
end

--------------------------------------------------------------------------------
---- EventQueue:format_event_host method
--------------------------------------------------------------------------------
function EventQueue:format_event_host()
  local event = self.sc_event.event
  self.sc_logger:debug("[EventQueue:format_event_host]: call build_metric ")
  self.sc_metrics:build_metric(self.format_metric[event.category][event.element])
end

--------------------------------------------------------------------------------
---- EventQueue:format_event_service method
--------------------------------------------------------------------------------
function EventQueue:format_event_service()
  self.sc_logger:debug("[EventQueue:format_event_service]: call build_metric ")
  local event = self.sc_event.event
  self.sc_metrics:build_metric(self.format_metric[event.category][event.element])
end

--------------------------------------------------------------------------------
---- EventQueue:format_metric_host method
-- @param metric {table} a single metric data
--------------------------------------------------------------------------------
function EventQueue:format_metric_host(metric)
  self.sc_logger:debug("[EventQueue:format_metric_host]: call format_metric ")
  self:format_metric_event(metric)
end

--------------------------------------------------------------------------------
---- EventQueue:format_metric_service method
-- @param metric {table} a single metric data
--------------------------------------------------------------------------------
function EventQueue:format_metric_service(metric)
  self.sc_logger:debug("[EventQueue:format_metric_service]: call format_metric ")
  self:format_metric_event(metric)
end

--------------------------------------------------------------------------------
---- EventQueue:format_metric_service method
-- @param metric {table} a single metric data
-------------------------------------------------------------------------------
function EventQueue:format_metric_event(metric)
  self.sc_logger:debug("[EventQueue:format_metric]: start real format metric ")
  local event = self.sc_event.event
  self.sc_event.event.formated_event = {
    host = tostring(event.cache.host.name),
    metric = metric.metric_name,
    points = {{event.last_check, metric.value}},
    tags = self:build_metadata(metric)
  }

  self:add()
  self.sc_logger:debug("[EventQueue:format_metric]: end real format metric ")
end

--------------------------------------------------------------------------------
---- EventQueue:build_metadata method
-- @param metric {table} a single metric data
-- @return tags {table} a table with formated metadata 
--------------------------------------------------------------------------------
function EventQueue:build_metadata(metric)
  local tags = {}

  -- add service name in tags
  if self.sc_event.event.cache.service.description then
    table.insert(tags, "service:" .. self.sc_event.event.cache.service.description)
  end

  -- add metric instance in tags
  if metric.instance ~= "" then
    table.insert(tags, "instance:" .. metric.instance)
  end

  -- add metric subinstances in tags
  if metric.subinstance[1] then
    for _, subinstance in ipairs(metric.subinstance) do
      table.insert(tags, "subinstance:" .. subinstance)
    end
  end

  return tags
end

--------------------------------------------------------------------------------
-- EventQueue:add, add an event to the sending queue
--------------------------------------------------------------------------------
function EventQueue:add()
  -- store event in self.events lists
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element

  self.sc_logger:debug("[EventQueue:add]: add event in queue category: " .. tostring(self.sc_params.params.reverse_category_mapping[category])
    .. " element: " .. tostring(self.sc_params.params.reverse_element_mapping[category][element]))

  self.sc_logger:debug("[EventQueue:add]: queue size before adding event: " .. tostring(#self.sc_flush.queues[category][element].events))
  self.sc_flush.queues[category][element].events[#self.sc_flush.queues[category][element].events + 1] = self.sc_event.event.formated_event

  self.sc_logger:info("[EventQueue:add]: queue size is now: " .. tostring(#self.sc_flush.queues[category][element].events) 
    .. "max is: " .. tostring(self.sc_params.params.max_buffer_size))
end

--------------------------------------------------------------------------------
-- EventQueue:build_payload, concatenate data so it is ready to be sent
-- @param payload {string} json encoded string
-- @param event {table} the event that is going to be added to the payload
-- @return payload {string} json encoded string
--------------------------------------------------------------------------------
function EventQueue:build_payload(payload, event)
  if not payload then
    payload = {
      series = {event}
    }
  else
    table.insert(payload.series, event)
  end
  
  return payload
end

function EventQueue:send_data(payload, queue_metadata)
  self.sc_logger:debug("[EventQueue:send_data]: Starting to send data")

  local params = self.sc_params.params
  local url = params.http_server_url .. queue_metadata.endpoint
  local basic_auth = {
    username = params.elastic_username,
    password = params.elastic_password
  }

  
  if payload then
    local payload_json = broker.json_encode(payload)
    
    -- write payload in the logfile for test purpose
    if params.send_data_test == 1 then
      self.sc_logger:notice("[send_data]: " .. tostring(payload_json))
      self.sc_logger:info("[EventQueue:send_data]: Going to send the following json " .. tostring(payload_json))
      return true
    end
  end
  
  self.sc_logger:info("[EventQueue:send_data]: Elastic address is: " .. tostring(url))
  self.sc_logger:log_curl_command(url, queue_metadata, self.sc_params.params, payload_json, basic_auth)

  local http_response_body = ""
  local http_request = curl.easy()
    :setopt_url(url)
    :setopt_writefunction(
      function (response)
        http_response_body = http_response_body .. tostring(response)
      end
    )
    :setopt(curl.OPT_TIMEOUT, params.connection_timeout)
    :setopt(curl.OPT_SSL_VERIFYPEER, params.allow_insecure_connection)
    :setopt(
      curl.OPT_HTTPHEADER,
      {
        "content-type: application/json"
      }
  )

  -- set proxy address configuration
  if (params.proxy_address ~= '') then
    if (params.proxy_port ~= '') then
      http_request:setopt(curl.OPT_PROXY, params.proxy_address .. ':' .. params.proxy_port)
    else 
      self.sc_logger:error("[EventQueue:send_data]: proxy_port parameter is not set but proxy_address is used")
    end
  end

  -- set proxy user configuration
  if (params.proxy_username ~= '') then
    if (params.proxy_password ~= '') then
      http_request:setopt(curl.OPT_PROXYUSERPWD, params.proxy_username .. ':' .. params.proxy_password)
    else
      self.sc_logger:error("[EventQueue:send_data]: proxy_password parameter is not set but proxy_username is used")
    end
  end

  -- adding the HTTP POST data
  if payload_json then
    http_request:setopt_postfields(payload_json)
  end

  -- performing the HTTP request
  http_request:perform()
  
  -- collecting results
  http_response_code = http_request:getinfo(curl.INFO_RESPONSE_CODE) 

  http_request:close()
  
  -- Handling the return code
  local retval = false
  
  if http_response_code == 202 then
    self.sc_logger:info("[EventQueue:send_data]: HTTP POST request successful: return code is " .. tostring(http_response_code))
    self.elastic_result = http_response_body
    retval = true
  else
    self.sc_logger:error("[EventQueue:send_data]: HTTP POST request FAILED, return code is " .. tostring(http_response_code) .. ". Message is: " .. tostring(http_response_body))
  end
  
  return retval
end

--------------------------------------------------------------------------------
-- Required functions for Broker StreamConnector
--------------------------------------------------------------------------------

local queue

-- Fonction init()
function init(conf)
  queue = EventQueue.new(conf)
end

-- --------------------------------------------------------------------------------
-- write,
-- @param {table} event, the event from broker
-- @return {boolean}
--------------------------------------------------------------------------------
function write (event)
  -- skip event if a mandatory parameter is missing
  if queue.fail then
    queue.sc_logger:error("Skipping event because a mandatory parameter is not set")
    return false
  end

  -- initiate event object
  queue.sc_metrics = sc_metrics.new(event, queue.sc_params.params, queue.sc_common, queue.sc_broker, queue.sc_logger)
  queue.sc_event = queue.sc_metrics.sc_event

  if queue.sc_event:is_valid_category() then
    if queue.sc_metrics:is_valid_bbdo_element() then
      -- format event if it is validated
      if queue.sc_metrics:is_valid_metric_event() then
        queue:format_accepted_event()
      end
  --- log why the event has been dropped 
    else
      queue.sc_logger:debug("dropping event because element is not valid. Event element is: "
        .. tostring(queue.sc_params.params.reverse_element_mapping[queue.sc_event.event.category][queue.sc_event.event.element]))
    end    
  else
    queue.sc_logger:debug("dropping event because category is not valid. Event category is: "
      .. tostring(queue.sc_params.params.reverse_category_mapping[queue.sc_event.event.category]))
  end
  
  return flush()
end


-- flush method is called by broker every now and then (more often when broker has nothing else to do)
function flush()
  local queues_size = queue.sc_flush:get_queues_size()
  
  -- nothing to flush
  if queues_size == 0 then
    return true
  end

  -- flush all queues because last global flush is too old
  if queue.sc_flush.last_global_flush < os.time() - queue.sc_params.params.max_all_queues_age then
    if not queue.sc_flush:flush_all_queues(queue.build_payload_method[1], queue.send_data_method[1]) then
      return false
    end

    return true
  end

  -- flush queues because too many events are stored in them
  if queues_size > queue.sc_params.params.max_buffer_size then
    if not queue.sc_flush:flush_all_queues(queue.build_payload_method[1], queue.send_data_method[1]) then
      return false
    end

    return true
  end

  -- there are events in the queue but they were not ready to be send
  return false
end
