#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker Keep Connector -- https://github.com/keephq/keep
--------------------------------------------------------------------------------

local next_retry_time = 0

-- Required Libraries
local curl = require "cURL"
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_event = require("centreon-stream-connectors-lib.sc_event")
local sc_params = require("centreon-stream-connectors-lib.sc_params")
local sc_macros = require("centreon-stream-connectors-lib.sc_macros")
local sc_flush = require("centreon-stream-connectors-lib.sc_flush")

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
    "keep_api_key"
  }

  self.fail = false

  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/keep-events.log"
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
  
  -- force buffer size to 1 to avoid breaking the communication with keep (can't send more than one event at once)
  params.max_buffer_size = 1

  -- Set default parameters
  self.sc_params.params.http_server_url = params.http_server_url or "https://api.keephq.dev/alerts/event"
  self.sc_params.params.client = params.client or "Centreon Stream Connector"
  self.sc_params.params.accepted_categories = params.accepted_categories or "neb"
  self.sc_params.params.accepted_elements = params.accepted_elements or "host_status,service_status,acknowledgement"
  self.sc_params.params.keep_api_key = params.keep_api_key

  self.sc_params.params.rate_limit_delay_minutes = params.rate_limit_delay_minutes or 5
  self.sc_params.params.max_all_queues_age = params.max_all_queues_age or 30

  self.sc_params:param_override(params)
  self.sc_params:check_params()

  self.sc_macros = sc_macros.new(self.sc_params.params, self.sc_logger)
  self.format_template = self.sc_params:load_event_format_file(true)

  -- Load custom code if available
  if self.sc_params.load_custom_code_file and not self.sc_params:load_custom_code_file(self.sc_params.params.custom_code_file) then
    self.sc_logger:error("[EventQueue:new]: Failed to load custom code file: " .. tostring(self.sc_params.params.custom_code_file))
  end

  self.sc_params:build_accepted_elements_info()
  self.sc_flush = sc_flush.new(self.sc_params.params, self.sc_logger)

  local categories = self.sc_params.params.bbdo.categories
  local elements = self.sc_params.params.bbdo.elements

  -- Define event formatting functions
  self.format_event = {
    [categories.neb.id] = {
      [elements.host_status.id] = function () return self:format_event_host() end,
      [elements.service_status.id] = function () return self:format_event_service() end,
      [elements.acknowledgement.id] = function () return self:format_event_acknowledgement() end
    },
    [categories.bam.id] = {}
  }

  self.send_data_method = {
    [1] = function (payload, queue_metadata) return self:send_data(payload, queue_metadata) end
  }

  self.build_payload_method = {
    [1] = function (payload, event) return self:build_payload(payload, event) end
  }

  -- Map Centreon service states to KeepHQ statuses and severities
  self.state_service_keep = {
    [0] = { severity = "info", status = "resolved" },    -- OK
    [1] = { severity = "warning", status = "firing" },   -- WARNING
    [2] = { severity = "critical", status = "firing" },  -- CRITICAL
    [3] = { severity = "warning", status = "pending" },  -- UNKNOWN
    [4] = { severity = "info", status = "pending" },     -- PENDING
  }

  -- Map Centreon host states to KeepHQ statuses and severities
  self.state_host_keep = {
    [0] = { severity = "info", status = "resolved" },    -- UP
    [1] = { severity = "critical", status = "firing" },  -- DOWN
    [2] = { severity = "critical", status = "firing" },  -- UNREACHABLE
  }

  setmetatable(self, { __index = EventQueue })
  return self
end

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

-- Add groups (hostgroups or servicegroups) to labels
local function add_groups_to_labels(groups, group_key, labels, logger)
  if groups and #groups > 0 then
    local group_names = {}
    for _, group in ipairs(groups) do
      table.insert(group_names, group.group_name)
    end
    labels[group_key] = group_names
  else
    labels[group_key] = {}
    logger:debug(string.format("[add_groups_to_labels]: No %s found.", group_key))
  end
end

-- Add severity to labels
local function add_severity_to_labels(severity, severity_key, labels)
  if severity then
    labels[severity_key] = severity
  end
end

--------------------------------------------------------------------------------
---- EventQueue:format_event method
----------------------------------------------------------------------------------
function EventQueue:format_accepted_event()
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element
  local template = self.sc_params.params.format_template[category][element]

  self.sc_logger:debug("[EventQueue:format_event]: starting format event")
  self.sc_event.event.formated_event = {}

  if self.format_template and template ~= nil and template ~= "" then
    self.sc_event.event.formated_event = self.sc_macros:replace_sc_macro(template, self.sc_event.event, true)
  else
    -- can't format event if stream connector is not handling this kind of event and that it is not handled with a template file
    if not self.format_event[category][element] then
      self.sc_logger:error("[format_event]: You are trying to format an event with category: "
        .. tostring(self.sc_params.params.reverse_category_mapping[category]) .. " and element: "
        .. tostring(self.sc_params.params.reverse_element_mapping[category][element])
        .. ". If it is a not a misconfiguration, you should create a format file to handle this kind of element")
    else
      self.format_event[category][element]()
    end
  end

  self:add()
  self.sc_logger:debug("[EventQueue:format_event]: event formatting is finished")
end

--------------------------------------------------------------------------------
-- Format Acknowledgement Event
--------------------------------------------------------------------------------

function EventQueue:format_event_acknowledgement()
  local event = self.sc_event.event
  local fingerprint, name, hostgroups, host_severity
  local labels = {
    author = event.author or "unknown",
    comment_data = event.comment_data or "no comment",
  }

  if event.service_id > 0 then
    fingerprint = tostring(event.host_id) .. "_" .. tostring(event.service_id)
    name = event.cache.host.name .. "/" .. event.cache.service.description

    -- Add hostgroups and servicegroups
    hostgroups = self.sc_broker:get_hostgroups(event.host_id)
    add_groups_to_labels(hostgroups, "hostgroups", labels, self.sc_logger)

    local servicegroups = self.sc_broker:get_servicegroups(event.host_id, event.service_id)
    add_groups_to_labels(servicegroups, "servicegroups", labels, self.sc_logger)

    -- Add severities
    host_severity = self.sc_broker:get_severity(event.host_id)
    add_severity_to_labels(host_severity, "host_severity", labels)

    local service_severity = self.sc_broker:get_severity(event.host_id, event.service_id)
    add_severity_to_labels(service_severity, "service_severity", labels)
  else
    fingerprint = tostring(event.host_id) .. "_H"
    name = event.cache.host.name

    -- Add hostgroups
    hostgroups = self.sc_broker:get_hostgroups(event.host_id)
    add_groups_to_labels(hostgroups, "hostgroups", labels, self.sc_logger)

    -- Add host severity
    host_severity = self.sc_broker:get_severity(event.host_id)
    add_severity_to_labels(host_severity, "host_severity", labels)
  end

  -- Log key values for debugging
  self.sc_logger:debug(string.format("[format_event_acknowledgement]: Fingerprint: %s", fingerprint))
  self.sc_logger:debug(string.format("[format_event_acknowledgement]: Name: %s", name))
  self.sc_logger:debug(string.format("[format_event_acknowledgement]: Service ID: %d", event.service_id))
  self.sc_logger:debug(string.format("[format_event_acknowledgement]: Host ID: %d", event.host_id))
  self.sc_logger:debug(string.format("[format_event_acknowledgement]: Author: %s", event.author or "unknown"))
  self.sc_logger:debug(string.format("[format_event_acknowledgement]: Comment Data: %s", event.comment_data or "no comment"))

  self.sc_event.event.formated_event = {
    id = fingerprint,
    name = name,
    status = "acknowledged",
    lastReceived = os.date("!%Y-%m-%dT%H:%M:%S.000", event.entry_time),
    duplicateReason = nil,
    source = { "centreon" },
    severity = "info",
    pushed = true,
    fingerprint = fingerprint,
    labels = labels
  }

  -- Log the formatted event
  self.sc_logger:info(string.format("[format_event_acknowledgement]: Formatted event for sending: %s", tostring(self.sc_event.event.formated_event)))
end

--------------------------------------------------------------------------------
-- Format Host Event
--------------------------------------------------------------------------------

function EventQueue:format_event_host()
  local event = self.sc_event.event
  local labels = {}

  -- handle hostgroup
  local hostgroups = self.sc_broker:get_hostgroups(event.host_id)
  add_groups_to_labels(hostgroups, "hostgroups", labels, self.sc_logger)

  -- Add host severity
  local host_severity = self.sc_broker:get_severity(event.host_id)
  add_severity_to_labels(host_severity, "host_severity", labels)

  -- Add output
  labels["output"] = self.sc_common:ifnil_or_empty(event.output, "no output")

  -- Get status and severity
  local status_label = self.state_host_keep[event.state].status
  local severity = self.state_host_keep[event.state].severity

  local name = event.cache.host.name .. ": " .. status_label
  local fingerprint = event.host_id .. "_H"

  self.sc_event.event.formated_event = {
    id = fingerprint,
    name = name,
    status = status_label,
    lastReceived = os.date("!%Y-%m-%dT%H:%M:%S.000", event.last_update),
    source = { "centreon" },
    message = "The host '" .. event.cache.host.name .. "' is in state: " .. status_label,
    description = labels["output"],
    severity = severity,
    pushed = true,
    labels = labels,
    fingerprint = fingerprint
  }
end

--------------------------------------------------------------------------------
-- Format Service Event
--------------------------------------------------------------------------------

function EventQueue:format_event_service()
  local event = self.sc_event.event
  local labels = {}

  -- Add hostgroups and servicegroups
  local hostgroups = self.sc_broker:get_hostgroups(event.host_id)
  add_groups_to_labels(hostgroups, "hostgroups", labels, self.sc_logger)

  local servicegroups = self.sc_broker:get_servicegroups(event.host_id, event.service_id)
  add_groups_to_labels(servicegroups, "servicegroups", labels, self.sc_logger)

  -- Add severities
  local host_severity = self.sc_broker:get_severity(event.host_id)
  add_severity_to_labels(host_severity, "host_severity", labels)

  local service_severity = self.sc_broker:get_severity(event.host_id, event.service_id)
  add_severity_to_labels(service_severity, "service_severity", labels)

  -- Add output
  labels["output"] = self.sc_common:ifnil_or_empty(event.output, "no output")

  -- Get status and severity
  local status_label = self.state_service_keep[event.state].status
  local severity = self.state_service_keep[event.state].severity

  local name = event.cache.host.name .. "/" .. event.cache.service.description .. ": " .. status_label
  local fingerprint = event.host_id .. "_" .. event.service_id

  self.sc_event.event.formated_event = {
    id = fingerprint,
    name = name,
    status = status_label,
    lastReceived = os.date("!%Y-%m-%dT%H:%M:%S.000", event.last_update),
    duplicateReason = nil,
    source = { "centreon" },
    message = "The service '" .. event.cache.service.description .. "' on host '" .. event.cache.host.name .. "' is in state: " .. status_label,
    description = labels["output"],
    severity = severity,
    pushed = true,
    labels = labels,
    fingerprint = fingerprint
  }
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
    payload = broker.json_encode(event)
  else
    payload = payload .. broker.json_encode(event)
  end
  
  return payload
end
--------------------------------------------------------------------------------
-- Send Data to KeepHQ
--------------------------------------------------------------------------------
function EventQueue:send_data(payload, queue_metadata)
  self.sc_logger:debug("[EventQueue:send_data]: Starting to send data")

  local url = self.sc_params.params.http_server_url

  if os.time() < next_retry_time then
    self.sc_logger:info("[EventQueue:send_data]: Rate limit delay active. Not sending now.")
    return false
  end

  queue_metadata.headers = {
    "Content-Type: application/json",
    "Accept: application/json",
    "Content-Length: " .. string.len(payload),
    "X-API-KEY: " .. tostring(self.sc_params.params.keep_api_key)
  }

  self.sc_logger:log_curl_command(url, queue_metadata, self.sc_params.params, payload)

  -- write payload in the logfile for test purpose
  if self.sc_params.params.send_data_test == 1 then
    self.sc_logger:notice("[send_data]: " .. tostring(payload))
    return true
  end

  self.sc_logger:info("[EventQueue:send_data]: Sending JSON: " .. tostring(payload))
  self.sc_logger:info("[EventQueue:send_data]: KeepHQ URL: " .. tostring(url))

  local http_response_body = ""
  local http_request = curl.easy()
    :setopt_url(url)
    :setopt_writefunction(
      function (response)
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
      self.sc_logger:error("[EventQueue:send_data]: Proxy port not set but proxy address is used")
    end
  end

  -- set proxy user configuration
  if (self.sc_params.params.proxy_username ~= '') then
    if (self.sc_params.params.proxy_password ~= '') then
      http_request:setopt(curl.OPT_PROXYUSERPWD, self.sc_params.params.proxy_username .. ':' .. self.sc_params.params.proxy_password)
    else
      self.sc_logger:error("[EventQueue:send_data]: Proxy password not set but proxy username is used")
    end
  end

  -- adding the HTTP POST data
  http_request:setopt_postfields(payload)

  -- performing the HTTP request
  http_request:perform()
  
  -- collecting results
  http_response_code = http_request:getinfo(curl.INFO_RESPONSE_CODE) 

  http_request:close()

  local success = false
  if http_response_code == 429 then
    -- Handle rate limiting
    self.sc_logger:info("[EventQueue:send_data]: Rate limited (429). Will retry later.")
    next_retry_time = os.time() + (self.sc_params.params.rate_limit_delay_minutes * 60)
  elseif http_response_code >= 200 and http_response_code < 300 then
    -- Success
    self.sc_logger:info("[EventQueue:send_data]: Successfully sent data. HTTP code: " .. tostring(http_response_code))
    success = true
  else
    -- Other errors
    self.sc_logger:error("[EventQueue:send_data]: Failed to send data.")
    self.sc_logger:error("[EventQueue:send_data]: HTTP code: " .. tostring(http_response_code))
    self.sc_logger:error("[EventQueue:send_data]: Response body: " .. tostring(http_response_body))
    if payload then
      self.sc_logger:error("[EventQueue:send_data]: Payload sent: " .. tostring(payload))
    end
    -- success remains false
  end

  return success
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

  -- Check event type before accessing downtime
  if event._type == 65565 or event._type == 65538 then
    if event.scheduled_downtime_depth ~= 0 then
      queue.sc_logger:debug("write: " .. event.host_id .. "_" .. (event.service_id or "H") .. " Scheduled downtime. Dropping.")
      return true
    end
  end

  queue.sc_event = sc_event.new(event, queue.sc_params.params, queue.sc_common, queue.sc_logger, queue.sc_broker)

  if queue.sc_event:is_valid_category() then
    if queue.sc_event:is_valid_element() then
      if queue.sc_event:is_valid_event() then
        queue:format_accepted_event()
      else
        queue.sc_logger:debug("Dropping event: Invalid event.")
      end
    else
      queue.sc_logger:debug("Dropping event: Invalid element.")
    end
  else
    queue.sc_logger:debug("Dropping event: Invalid category.")
  end

  local flush_result = flush()
  if type(flush_result) ~= "boolean" then
    queue.sc_logger:error("flush() returned a non-boolean value: " .. tostring(flush_result))
    return false
  end

  return flush_result
end

--------------------------------------------------------------------------------
-- Flush Queue
--------------------------------------------------------------------------------

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

