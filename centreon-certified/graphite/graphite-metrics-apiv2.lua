#!/usr/bin/lua

--------------------------------------------------------------------------------
-- Centreon Broker Graphite Connector Events
--------------------------------------------------------------------------------


-- Libraries
local socket = require("socket")
local mime = require("mime") -- for b64 encoding
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_event = require("centreon-stream-connectors-lib.sc_event")
local sc_params = require("centreon-stream-connectors-lib.sc_params")
local sc_macros = require("centreon-stream-connectors-lib.sc_macros")
local sc_flush = require("centreon-stream-connectors-lib.sc_flush")
local sc_metrics = require("centreon-stream-connectors-lib.sc_metrics")
local sc_storage = require("centreon-stream-connectors-lib.sc_storage")

local EventQueue = {}
EventQueue.__index = EventQueue

function EventQueue.new(params)
  local self = {}

  local mandatory_parameters = {
    "address"
  }

  self.fail = false

  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/graphite-metrics.log"
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
  self.sc_params.params.address = params.address
  self.sc_params.params.port = params.port or 2003
  self.sc_params.params.user = params.user or ""
  self.sc_params.params.password = params.password or ""
  self.sc_params.params.accepted_categories = params.accepted_categories or "neb"
  self.sc_params.params.accepted_elements = params.accepted_elements or "host_status,service_status"
  self.sc_params.params.max_buffer_size = params.max_buffer_size or 1000
  self.sc_params.params.hard_only = params.hard_only or 0
  self.sc_params.params.enable_host_status_dedup = params.enable_host_status_dedup or 0
  self.sc_params.params.enable_service_status_dedup = params.enable_service_status_dedup or 0
  self.sc_params.params.add_min_max_mode = params.add_min_max_mode or ""
  self.sc_params.params.add_hostgroups = params.add_hostgroups or 0
  self.sc_params.params.add_state_metric = params.add_state_metric or 0
  self.sc_params.params.add_thresholds_mode = params.add_thresholds_mode or ""

  -- couldn't find an official Graphite documentation regarding the metric_name invalid characters. It looks like usually you have to escape the dot but when using tagged metric it doesn't appear to be needed
  self.sc_params.params.metric_name_regex = params.metric_name_regex or "(no_forbidden_character)" 
  self.sc_params.params.metric_replacement_character = params.metric_replacement_character or "" 
  -- https://graphite.readthedocs.io/en/stable/tags.html#carbon (i'm also removing the ~ to avoid the hassle of checking if it is the first character of the tag)
  self.sc_params.params.metric_tag_regex = params.metric_tag_regex or "[;!^=~]"
  self.sc_params.params.metric_tag_replacement_character = params.metric_tag_replacement_character or "_"
  
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
  self.sc_storage = sc_storage.new(self.sc_common, self.sc_logger, self.sc_params.params)

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
  local params = self.sc_params.params
  self.sc_logger:debug("[EventQueue:format_metric]: start real format metric ")
  local event = self.sc_event.event
  local tags = self:get_tags(metric)

  local tmp_formated_event = {
    metric.metric_name .. ";"
      .. tags .. ";type=metric_value "
      .. metric.value .. " "
      .. event.last_check
  }

  -- create a dedicated metric event if the user wants to be able to have dynmaic display of min/max and thresholds in grafana
  -- metric memory.usage name will become memory.usage.min and will have the same tags than the original metric
  -- WARNING, enabling both thresholds and min max can send up to five events instead of one
  self:generate_min_max_metric_event(metric, tags)
  self:generate_thresholds_metric_event(metric, tags)
  self:generate_state_metric_event(metric, tags)

  self.sc_event.event.formated_event = tmp_formated_event
  self:add()
  self.sc_logger:debug("[EventQueue:format_metric]: end real format metric ")
end

function EventQueue:generate_min_max_metric_event(metric, tags)
  if (self.sc_params.params.add_min_max_mode ~= "as_metric") then
    return
  end

  local event = self.sc_event.event
  
  if (metric.min) then
    self.sc_event.event.formated_event = {
      metric.metric_name .. ".min" ..  ";"
        .. tags .. ";type=metric_min "
        .. metric.min .. " "
        .. event.last_check
    }

    self:add()
  end

  if (metric.max) then
    self.sc_event.event.formated_event = {
      metric.metric_name .. ".max" ..  ";"
        .. tags .. ";type=metric_max "
        .. metric.max .. " "
        .. event.last_check
    }

    self:add()
  end
end

function EventQueue:generate_thresholds_metric_event(metric, tags)
  if (self.sc_params.params.add_thresholds_mode ~= "as_metric") then
    return
  end

  local event = self.sc_event.event
  
  if (metric.warning_high) then
    self.sc_event.event.formated_event = {
      metric.metric_name .. ".warning_threshold" .. ";"
        .. tags .. ";type=metric_warning_threshold "
        .. metric.warning_high .. " "
        .. event.last_check
    }

    self:add()
  end

  if (metric.critical_high) then
    self.sc_event.event.formated_event = {
      metric.metric_name .. ".critical_threshold" .. ";"
        .. tags .. ";type=metric_critical_threshold "
        .. metric.critical_high .. " "
        .. event.last_check
    }

    self:add()
  end
end

function EventQueue:generate_state_metric_event(metric, tags)
  if (self.sc_params.params.add_state_metric ~= 1) then
    return
  end

  local event = self.sc_event.event

  self.sc_event.event.formated_event = {
    metric.metric_name .. ".state" .. ";"
        .. tags .. ";type=metric_state "
        .. event.state .. " "
        .. event.last_check
  }

  self:add()
end

function EventQueue:get_tags(metric)
  local params = self.sc_params.params
  local event = self.sc_event.event
  local tags = {
    "host=" .. self:escape_metric_tag(tostring(event.cache.host.name)),
    "poller=" .. self:escape_metric_tag(tostring(event.cache.poller))
  }

  if (metric.instance ~=  "") then
    table.insert(tags, "metric_instance=" .. self:escape_metric_tag(metric.instance))
  end

  if (metric.subinstance[1]) then
    local subinstances = {}
    for _, subinstance in ipairs(metric.subinstance) do
      table.insert(subinstances, self:escape_metric_tag(subinstance))
    end

    table.insert(tags, "metric_subinstances=" .. table.concat(subinstances, ","))
  end

  if (event.cache.service and event.cache.service.description) then
    table.insert(tags, "service=" .. self:escape_metric_tag(event.cache.service.description))
  end

  if (params.add_hostgroups == 1) then
    local hg_string = ""
    for index, hg_info in pairs(event.cache.hostgroups) do
      if hg_string == "" then
        hg_string = hg_info.group_name
      else
        hg_string = hg_string .. "," .. hg_info.group_name
      end
    end

    table.insert(tags, "hostgroups=" .. self:escape_metric_tag(hg_string))
  end

  if (params.add_min_max_mode == "as_tag") then
    if metric.min then
      table.insert(tags, "min=" .. self:escape_metric_tag(metric.min))
    end

    if metric.max then
      table.insert(tags, "max=" .. self:escape_metric_tag(metric.max))
    end
  end

  if (params.add_thresholds_mode == "as_tag") then
    if metric.warning_high then
      table.insert(tags, "warning_threshold=" .. self:escape_metric_tag(metric.warning_high))
    end

    if metric.critical_high then
      table.insert(tags, "critical_threshold=" .. self:escape_metric_tag(metric.critical_high))
    end
  end

  return table.concat(tags, ";")
end

function EventQueue:escape_metric_tag(str)
  local params = self.sc_params.params
  local escaped_tag = string.gsub(str, params.metric_tag_regex, params.metric_tag_replacement_character)
  return escaped_tag
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
    payload = event[1]
  else
    payload = payload .. "\n" .. event[1]
  end

  return payload
end

--------------------------------------------------------------------------------
-- EventQueue:connect, open a TCP connection to the Graphite address, going
-- through an HTTP proxy (CONNECT tunnel) when one is configured
-- @return connection {userdata} a connected luasocket object, or nil on failure
--------------------------------------------------------------------------------
function EventQueue:connect()
  local params = self.sc_params.params
  local connection, err

  -- no proxy configured, connect directly to the Graphite address
  if params.proxy_address == '' then
    connection, err = socket.connect(params.address, params.port)
    if not connection then
      self.sc_logger:error("[EventQueue:connect]: couldn't connect to " .. tostring(params.address) .. ":" .. tostring(params.port) .. ". Error is: " .. tostring(err))
      return nil
    end

    connection:settimeout(params.connection_timeout)
    return connection
  end

  -- a proxy is configured, make sure the associated port is set too
  if params.proxy_port == '' then
    self.sc_logger:error("[EventQueue:connect]: proxy_port parameter is not set but proxy_address is used")
    return nil
  end

  if params.proxy_protocol ~= 'http' then
    self.sc_logger:error("[EventQueue:connect]: unsupported proxy_protocol '" .. tostring(params.proxy_protocol) .. "', only 'http' is supported for a TCP connection")
    return nil
  end

  connection, err = socket.connect(params.proxy_address, params.proxy_port)
  if not connection then
    self.sc_logger:error("[EventQueue:connect]: couldn't connect to proxy " .. tostring(params.proxy_address) .. ":" .. tostring(params.proxy_port) .. ". Error is: " .. tostring(err))
    return nil
  end

  connection:settimeout(params.connection_timeout)

  -- ask the proxy to open a TCP tunnel to the real Graphite address
  local connect_request = "CONNECT " .. params.address .. ":" .. params.port .. " HTTP/1.1\r\n"
    .. "Host: " .. params.address .. ":" .. params.port .. "\r\n"

  if params.proxy_username ~= '' then
    if params.proxy_password ~= '' then
      connect_request = connect_request .. "Proxy-Authorization: Basic " .. mime.b64(params.proxy_username .. ':' .. params.proxy_password) .. "\r\n"
    else
      self.sc_logger:error("[EventQueue:connect]: proxy_password parameter is not set but proxy_username is used")
    end
  end

  connect_request = connect_request .. "\r\n"

  connection:send(connect_request)

  local status_line, receive_err = connection:receive("*l")
  if not status_line or not string.find(status_line, " 200 ") then
    self.sc_logger:error("[EventQueue:connect]: proxy CONNECT to " .. params.address .. ":" .. tostring(params.port) .. " failed. Response is: " .. tostring(status_line or receive_err))
    connection:close()
    return nil
  end

  -- consume the remaining proxy response headers until the blank line
  repeat
    local header_line = connection:receive("*l")
  until not header_line or header_line == ""

  return connection
end

function EventQueue:send_data(payload, queue_metadata)
  self.sc_logger:debug("[EventQueue:send_data]: Starting to send data")
  local params = self.sc_params.params
  local data = ""

  -- write payload in the logfile for test purpose
  if params.send_data_test == 1 then
    self.sc_logger:notice("[send_data]: " .. tostring(payload))
    return true
  end

  if params.user ~= "" and params.password ~= "" then
    data = "Authorization: Basic " .. mime.b64(params.user .. ":" .. params.password) .. "\n"
  end

  data = data .. payload

  self.sc_logger:info("[EventQueue:send_data]: Going to send the following payload: " .. tostring(payload))
  self.sc_logger:info("[EventQueue:send_data]: Graphite address is: " .. tostring(params.address) .. ":" .. tostring(params.port))

  if params.log_curl_commands == 1 then
    self.sc_logger:notice("[EventQueue:send_data]: test command:\necho -n '" .. tostring(data) .. "' | nc -z -v " .. params.address .. " " .. params.port)
  end

  local connection = self:connect()
  if not connection then
    return false
  end

  local retval = false
  local sent, err = connection:send(data .. "\n")

  if sent then
    self.sc_logger:info("[EventQueue:send_data]: data successfully sent to Graphite")
    retval = true
  else
    self.sc_logger:error("[EventQueue:send_data]: couldn't send data to Graphite. Error is: " .. tostring(err))
  end

  connection:close()

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
  queue.sc_metrics = sc_metrics.new(event, queue.sc_params.params, queue.sc_common, queue.sc_broker, queue.sc_storage, queue.sc_logger)
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