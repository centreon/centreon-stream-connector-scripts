#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker influxdb Connector Events
--------------------------------------------------------------------------------

local metrics = {}
local incomplete_metrics = {}

-- Libraries
local curl = require "cURL"
local mime = require("mime")
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_event = require("centreon-stream-connectors-lib.sc_event")
local sc_params = require("centreon-stream-connectors-lib.sc_params")
local sc_macros = require("centreon-stream-connectors-lib.sc_macros")
local sc_flush = require("centreon-stream-connectors-lib.sc_flush")
local sc_metrics = require("centreon-stream-connectors-lib.sc_metrics")
local sc_storage = require("centreon-stream-connectors-lib.sc_storage")

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
    "http_server_address",
    "influxdb_username",
    "influxdb_password",
    "influxdb_database"
  }

  self.fail = false

  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/infuxdb-metrics.log"
  local log_level = params.log_level or 1

  -- initiate mandatory objects
  self.sc_logger = sc_logger.new(logfile, log_level)
  self.sc_common = sc_common.new(self.sc_logger)
  self.sc_params = sc_params.new(self.sc_common, self.sc_logger)

  -- checking mandatory parameters and setting a fail flag
  if not self.sc_params:is_mandatory_config_set(mandatory_parameters, params) then
    self.fail = true
  end

  -- overriding default parameters for this stream connector if the default values doesn't suit the basic needs
  self.sc_params.params.http_server_address = params.http_server_address
  self.sc_params.params.http_server_protocol = params.http_server_protocol or "http"
  self.sc_params.params.http_server_port = params.http_server_port or 8086
  self.sc_params.params.influxdb_username = params.influxdb_username
  self.sc_params.params.influxdb_password = params.influxdb_password
  self.sc_params.params.influxdb_database = params.influxdb_database
  self.sc_params.params.accepted_categories = params.accepted_categories or "neb"
  self.sc_params.params.accepted_elements = params.accepted_elements or "service_status"
  self.sc_params.params.max_buffer_size = params.max_buffer_size or 100
  self.sc_params.params.hard_only = params.hard_only or 0
  self.sc_params.params.enable_host_status_dedup = params.enable_host_status_dedup or 0
  self.sc_params.params.enable_service_status_dedup = params.enable_service_status_dedup or 0
  self.sc_params.params.metric_name_regex = params.metric_name_regex or "([, =])"
  self.sc_params.params.metric_replacement_character = params.metric_replacement_character or "\\%1"
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
  self.sc_broker = sc_broker.new(self.sc_params.params, self.sc_logger)
  self.sc_storage = sc_storage.new(self.sc_common, self.sc_logger, self.sc_params.params)
  local rc, init_metrics = self.sc_storage:get_all_values_from_property("metric_id")
  if rc == false or type(init_metrics) == "boolean" then
    self.sc_logger:notice("no metric_id found in the sqlite db. That's probably because it is the first time the stream connector is executed")
  else
    metrics = init_metrics
  end

  local categories = self.sc_params.params.bbdo.categories
  local elements = self.sc_params.params.bbdo.elements

  self.format_event = {
    [categories.neb.id] = {
      [elements.host_status.id] = function() return self:format_event_host() end,
      [elements.service_status.id] = function() return self:format_event_service() end
    }
  }

  self.format_metric = {
    [categories.neb.id] = {
      [elements.host_status.id] = function(metric) return self:format_metric_host(metric) end,
      [elements.service_status.id] = function(metric) return self:format_metric_service(metric) end
    }
  }

  self.send_data_method = {
    [1] = function(payload, queue_metadata) return self:send_data(payload, queue_metadata) end
  }

  self.build_payload_method = {
    [1] = function(payload, event) return self:build_payload(payload, event) end
  }

  -- return EventQueue object
  setmetatable(self, { __index = EventQueue })
  return self
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
---- EventQueue:build_metric: use the stream connector format method to parse every metric in the event and remove unwanted metrics based on their name
-- @param format_metric (function) the format method from the stream connector
function EventQueue:build_metric(format_metric)
  self.sc_logger:debug("[EventQueue:build_metric]: start build_metric")
  local metrics_info = self.sc_metrics.metrics_info
  for metric, metric_data in pairs(metrics_info) do
    if metrics_info[metric].instance ~= "" then
      if #metrics_info[metric].subinstance ~= 0 then
        metrics_info[metric].metric_name = metrics_info[metric].instance .. '~' .. table.concat(metrics_info[metric].subinstance, '~') .. '#' .. metrics_info[metric].metric_name
      else
        metrics_info[metric].metric_name = metrics_info[metric].instance .. '#' .. metrics_info[metric].metric_name
      end
    end
    if string.match(metric_data.metric_name, self.sc_params.params.accepted_metrics) then
      metrics_info[metric].metric_name = string.gsub(metric_data.metric_name, self.sc_params.params.metric_name_regex, self.sc_params.params.metric_replacement_character)
      -- use stream connector method to format the metric event
      format_metric(metrics_info[metric])
    else
      self.sc_logger:debug("[ScMetric:build_metric]: metric name is filtered out: " .. tostring(metric_data.metric_name) .. ". Metric name filter is: " .. tostring(self.sc_params.params.accepted_metrics))
    end
  end
  self.sc_logger:debug("[EventQueue:build_metric]: end build_metric")
end

--------------------------------------------------------------------------------
---- EventQueue:format_event_host method
--------------------------------------------------------------------------------
function EventQueue:format_event_host()
  local event = self.sc_event.event
  self.sc_logger:debug("[EventQueue:format_event_host]: call build_metric ")
  self:build_metric(self.format_metric[event.category][event.element])
end

--------------------------------------------------------------------------------
---- EventQueue:format_event_service method
--------------------------------------------------------------------------------
function EventQueue:format_event_service()
  self.sc_logger:debug("[EventQueue:format_event_service]: call build_metric ")
  local event = self.sc_event.event
  self:build_metric(self.format_metric[event.category][event.element])
end

--------------------------------------------------------------------------------
---- EventQueue:format_metric_host method
-- @param metric {table} a single metric data
--------------------------------------------------------------------------------
function EventQueue:format_metric_host(metric)
  self.sc_logger:debug("[EventQueue:format_metric_host]: start format_metric host")
  local event = self.sc_event.event
  -- status
  self.sc_event.event.formated_event = "status value=" .. tostring(event.state) .. ",host_id=" .. tostring(event.host_id) .. " " .. tostring(event.last_check)
  self:add()
  -- metrics
  local metric_key = "metric_" .. mime.b64(tostring(event.host_id) .. ':0:' .. tostring(metric.metric_name))
  if not metrics[metric_key] then
    local category = self.sc_event.event.category
    local element = self.sc_event.event.element
    table.insert(incomplete_metrics, {
      entry_creation_date = os.time(),
      metric_name = metric.metric_name,
      metric_value = metric.value,
      metric_key = metric_key,
      last_check = event.last_check
    })
  else
    self.sc_event.event.formated_event = metric.metric_name .. ",metric_id=" .. metrics[metric_key] .. " value=" .. metric.value .. " " .. event.last_check
    self:add()
  end
  self.sc_logger:debug("[EventQueue:format_metric_service]: end format_metric host")
end

--------------------------------------------------------------------------------
---- EventQueue:format_metric_service method
-- @param metric {table} a single metric data
--------------------------------------------------------------------------------
function EventQueue:format_metric_service(metric)
  self.sc_logger:debug("[EventQueue:format_metric_service]: start format_metric service")
  local event = self.sc_event.event
  -- status
  self.sc_event.event.formated_event = "status value=" .. tostring(event.state) .. ",host_id=" .. tostring(event.host_id) .. ",service_id=" .. tostring(event.cache.service.service_id) .. " " .. tostring(event.last_check)
  self:add()
  -- metrics
  local metric_key = "metric_" .. mime.b64(tostring(event.host_id) .. ':' .. tostring(event.cache.service.service_id) .. ':' .. tostring(metric.metric_name))
  if not metrics[metric_key] then
    table.insert(incomplete_metrics, {
      entry_creation_date = os.time(),
      metric_name = metric.metric_name,
      metric_value = metric.value,
      metric_key = metric_key,
      last_check = event.last_check
    })
  else
    self.sc_event.event.formated_event = metric.metric_name .. ",metric_id=" .. metrics[metric_key] .. " value=" .. metric.value .. " " .. event.last_check
    self:add()
  end
  self.sc_logger:debug("[EventQueue:format_metric_service]: end format_metric service")
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
    .. ", max is: " .. tostring(self.sc_params.params.max_buffer_size))
end

--------------------------------------------------------------------------------
-- EventQueue:build_payload, concatenate data so it is ready to be sent
-- @param payload {string} json encoded string
-- @param event {table} the event that is going to be added to the payload
-- @return payload {string} json encoded string
--------------------------------------------------------------------------------
function EventQueue:build_payload(payload, event)
  if not payload then
    payload = event
  else
    payload = payload .. "\n" .. event
  end
  return payload
end

function EventQueue:send_data(payload, queue_metadata)
  self.sc_logger:debug("[EventQueue:send_data]: Starting to send data")
  local params = self.sc_params.params

  local url = params.http_server_protocol .. "://" .. params.http_server_address .. ":" .. tostring(params.http_server_port)
    .. "/write?u=" .. broker.url_encode(params.influxdb_username)
    .. "&p=" .. broker.url_encode(params.influxdb_password)
    .. "&db=" .. broker.url_encode(params.influxdb_database)
    .. "&precision=s"

  queue_metadata.headers = {
    "content-type: text/plain; charset=utf-8"
  }

  self.sc_logger:log_curl_command(url, queue_metadata, params, payload)

  -- write payload in the logfile for test purpose
  if self.sc_params.params.send_data_test == 1 then
    self.sc_logger:notice("[send_data]: " .. tostring(payload))
    return true
  end

  self.sc_logger:info("[EventQueue:send_data]: Going to send the following data " .. tostring(payload))
  self.sc_logger:info("[EventQueue:send_data]: Influxdb address is: " .. tostring(url))

  local http_response_body = ""
  local http_request = curl.easy()
                           :setopt_url(url)
                           :setopt_writefunction(
    function(response)
      http_response_body = http_response_body .. tostring(response)
    end
  )
                           :setopt(curl.OPT_TIMEOUT, self.sc_params.params.connection_timeout)
                           :setopt(curl.OPT_SSL_VERIFYPEER, self.sc_params.params.verify_certificate)
                           :setopt(curl.OPT_HTTPHEADER, queue_metadata.headers)

  -- set proxy address configuration
  if (self.sc_params.params.proxy_address ~= '') then
    if (self.sc_params.params.proxy_port ~= '') then
      http_request:setopt(curl.OPT_PROXY, self.sc_params.params.proxy_address .. ':' .. self.sc_params.params.proxy_port)
    else
      self.sc_logger:error("[EventQueue:send_data]: proxy_port parameter is not set but proxy_address is used")
    end
  end

  -- set proxy user configuration
  if (self.sc_params.params.proxy_username ~= '') then
    if (self.sc_params.params.proxy_password ~= '') then
      http_request:setopt(curl.OPT_PROXYUSERPWD, self.sc_params.params.proxy_username .. ':' .. self.sc_params.params.proxy_password)
    else
      self.sc_logger:error("[EventQueue:send_data]: proxy_password parameter is not set but proxy_username is used")
    end
  end

  -- adding the HTTP POST data
  http_request:setopt_postfields(payload)

  -- performing the HTTP request
  http_request:perform()

  -- collecting results
  http_response_code = http_request:getinfo(curl.INFO_RESPONSE_CODE)

  http_request:close()

  -- Handling the return code
  local retval = false
  -- https://docs.influxdata.com/influxdb/cloud/api/#operation/PostWrite other than 204 is not good
  if http_response_code == 204 then
    self.sc_logger:info("[EventQueue:send_data]: HTTP POST request successful: return code is " .. tostring(http_response_code))
    retval = true
  else
    self.sc_logger:error("[EventQueue:send_data]: HTTP POST request FAILED, return code is " .. tostring(http_response_code) .. ". Message is: " .. tostring(http_response_body))

    if payload then
      self.sc_logger:error("[EventQueue:send_data]: sent payload was: " .. tostring(payload))
    end
  end

  return retval
end

function EventQueue:check_incomplete_metrics()
  self.sc_logger:debug("[EventQueue:check_incomplete_metrics]: start check_incomplete_metrics")
  local incomplete_metrics_queue_size = 0
  local incomplete_metrics_payload = ""
  local queue_metadata = {
    headers = {
      "content-type: text/plain; charset=utf-8"
    }
  }
  for metric_index = #incomplete_metrics, 1, -1 do
    local metric_data = incomplete_metrics[metric_index]
    if metrics[metric_data.metric_key] then
      self.sc_logger:debug("[EventQueue:check_incomplete_metrics]: metric_key " .. tostring(metric_data.metric_key) .. " found: sending metric")
      incomplete_metrics_payload = incomplete_metrics_payload .. metric_data.metric_name .. ",metric_id=" .. metrics[metric_data.metric_key] .. " value=" .. metric_data.metric_value .. " " .. metric_data.last_check .. "\n"
      incomplete_metrics_queue_size = incomplete_metrics_queue_size + 1
      table.remove(incomplete_metrics, metric_index)
    elseif os.time() - metric_data.entry_creation_date > 30 then
      self.sc_logger:debug("[EventQueue:check_incomplete_metrics]: metric_key " .. tostring(metric_data.metric_key) .. " is too old, removing it")
      table.remove(incomplete_metrics, metric_index)
    else
      self.sc_logger:debug("[EventQueue:check_incomplete_metrics]: keeping metric_key " .. tostring(metric_data.metric_key) .. " in the incomplete metrics list")
    end
    if incomplete_metrics_queue_size > self.sc_params.params.max_buffer_size then
      self.sc_logger:debug("[EventQueue:check_incomplete_metrics]: sending incomplete metrics payload")
      self:send_data(incomplete_metrics_payload, queue_metadata)
      incomplete_metrics_payload = ""
      incomplete_metrics_queue_size = 0
    end
  end
  if incomplete_metrics_payload ~= "" then
    self.sc_logger:debug("[EventQueue:check_incomplete_metrics]: sending incomplete metrics payload")
    self:send_data(incomplete_metrics_payload, queue_metadata)
  end
  self.sc_logger:debug("[EventQueue:check_incomplete_metrics]: end check_incomplete_metrics")
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
  if queue.sc_params.params.bbdo.categories["storage"].id == event.category and queue.sc_params.params.bbdo.elements["metric"].id == event.element then
    local mname = event.name
    local metric_key = ""
    mname = string.gsub(mname, queue.sc_params.params.metric_name_regex, queue.sc_params.params.metric_replacement_character)
    if not event.service_id or event.service_id == 0 then
      metric_key = "metric_" .. mime.b64(tostring(event.host_id) .. ':0:' .. mname)
    else
      metric_key = "metric_" .. mime.b64(tostring(event.host_id) .. ':' .. event.service_id .. ':' .. mname)
    end
    -- check if the metric is already in the metrics table
    if not metrics[metric_key] then
      queue.sc_logger:notice("write: no metric_id found for 'metric_key': " .. tostring(metric_key) .. ", info:  " .. tostring(event.host_id) .. ':' .. tostring(event.service_id) .. ':' .. mname .. ", going to save metric_id : " .. tostring(event.metric_id) .. " in sqlite db and memory")
      metrics[metric_key] = event.metric_id
      queue.sc_storage:set(metric_key, "metric_id", event.metric_id)
    end
  end

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

local last_check_incomplete_metrics = 0

-- flush method is called by broker every now and then (more often when broker has nothing else to do)
function flush()
  local queues_size = queue.sc_flush:get_queues_size()

  -- retry to send the incomplete metrics table every 10 seconds, if there are some
  if #incomplete_metrics > 0 and os.time() - last_check_incomplete_metrics > 1 then
    last_check_incomplete_metrics = os.time()
    queue:check_incomplete_metrics()
  end

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
