#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker Pagerduty Connector Events
--------------------------------------------------------------------------------


-- Libraries
local curl = require "cURL"
local new_from_timestamp = require "luatz.timetable".new_from_timestamp
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
    "pdy_routing_key"
  }

  self.fail = false

  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/pagerduty-events.log"
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
  
  -- force buffer size to 1 to avoid breaking the communication with pagerduty (can't send more than one event at once)
  params.max_buffer_size = 1
  
  -- overriding default parameters for this stream connector if the default values doesn't suit the basic needs
  self.sc_params.params.pdy_centreon_url = params.pdy_centreon_url or "http://set.pdy_centreon_url.parameter"
  self.sc_params.params.http_server_url = params.http_server_url or "https://events.pagerduty.com/v2/enqueue"
  self.sc_params.params.client = params.client or "Centreon Stream Connector"
  self.sc_params.params.accepted_categories = params.accepted_categories or "neb"
  self.sc_params.params.accepted_elements = params.accepted_elements or "host_status,service_status"
  self.sc_params.params.pdy_source = params.pdy_source or nil
  
  -- apply users params and check syntax of standard ones
  self.sc_params:param_override(params)
  self.sc_params:check_params()
  
  self.sc_macros = sc_macros.new(self.sc_params.params, self.sc_logger)
  self.format_template = self.sc_params:load_event_format_file(true)

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
    },
    [categories.bam.id] = {}
  }

  self.send_data_method = {
    [1] = function (payload, queue_metadata) return self:send_data(payload, queue_metadata) end
  }

  self.build_payload_method = {
    [1] = function (payload, event) return self:build_payload(payload, event) end
  }

  self.state_to_severity_mapping = {
    [0] = {
      severity = "info",
      action = "resolve"
    },
    [1] = {
      severity = "warning",
      action = "trigger"
    },
    [2] = {
      severity = "critical",
      action = "trigger"
    }, 
    [3] = {
      severity = "error",
      action = "trigger"
    }
  }

  -- return EventQueue object
  setmetatable(self, { __index = EventQueue })
  return self
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

function EventQueue:format_event_host()
  local event = self.sc_event.event
  local pdy_custom_details = {}

  -- handle hostgroup
  local hostgroups = self.sc_broker:get_hostgroups(event.host_id)
  local pdy_hostgroups = ""

  -- retrieve hostgroups and store them in pdy_custom_details["Hostgroups"]
  if not hostgroups then
    pdy_hostgroups = "empty host group"
  else
    for index, hg_data in ipairs(hostgroups) do
      if pdy_hostgroups ~= "" then
        pdy_hostgroups = pdy_hostgroups .. ", " .. hg_data.group_name
      else
        pdy_hostgroups = hg_data.group_name
      end
    end

    pdy_custom_details["Hostgroups"] = pdy_hostgroups
  end

  -- handle severity
  local host_severity = self.sc_broker:get_severity(event.host_id)
  
  if host_severity then
    pdy_custom_details['Hostseverity'] = host_severity
  end
  
  pdy_custom_details["Output"] = self.sc_common:ifnil_or_empty(event.output, "no output")

  self.sc_event.event.formated_event = {
    payload = {
      summary = tostring(event.cache.host.name) .. ": " .. self.sc_params.params.status_mapping[event.category][event.element][event.state],
      timestamp = new_from_timestamp(event.last_update):rfc_3339(),
      severity = self.state_to_severity_mapping[event.state].severity,
      source = self.sc_params.params.pdy_source or tostring(event.cache.host.name),
      component = tostring(event.cache.host.name),
      group = pdy_hostgroups,
      class = "host",
      custom_details = pdy_custom_details,
    },
    routing_key = self.sc_params.params.pdy_routing_key,
    event_action = self.state_to_severity_mapping[event.state].action,
    dedup_key = event.host_id .. "_H",
    client = self.sc_params.params.client,
    client_url = self.sc_params.params.client_url,
    links = {
      {
        -- should think about using the new resources page but keep it as is for compatibility reasons
        href = self.sc_params.params.pdy_centreon_url .. "/centreon/main.php?p=20202&o=hd&host_name=" .. tostring(event.cache.host.name),
        text = "Link to Centreon host summary"
      }
    }
  }
end

function EventQueue:format_event_service()
  local event = self.sc_event.event
  local pdy_custom_details = {}

  -- handle hostgroup
  local hostgroups = self.sc_broker:get_hostgroups(event.host_id)
  local pdy_hostgroups = ""

  -- retrieve hostgroups and store them in pdy_custom_details["Hostgroups"]
  if not hostgroups then
    pdy_hostgroups = "empty host group"
  else
    for index, hg_data in ipairs(hostgroups) do
      if pdy_hostgroups ~= "" then
        pdy_hostgroups = pdy_hostgroups .. ", " .. hg_data.group_name
      else
        pdy_hostgroups = hg_data.group_name
      end
    end

    pdy_custom_details["Hostgroups"] = pdy_hostgroups
  end

  -- handle servicegroups
  local servicegroups = self.sc_broker:get_servicegroups(event.host_id, event.service_id)
  local pdy_servicegroups = ""

  -- retrieve servicegroups and store them in pdy_custom_details["Servicegroups"]
  if not servicegroups then
    pdy_servicegroups = "empty service group"
  else
    for index, sg_data in ipairs(servicegroups) do
      if pdy_servicegroups ~= "" then
        pdy_servicegroups = pdy_servicegroups .. ", " .. sg_data.group_name
      else
        pdy_servicegroups = sg_data.group_name
      end
    end

    pdy_custom_details["Servicegroups"] = pdy_servicegroups
  end

  -- handle host severity
  local host_severity = self.sc_broker:get_severity(event.host_id)
  
  if host_severity then
    pdy_custom_details["Hostseverity"] = host_severity
  end

  -- handle service severity
  local service_severity = self.sc_broker:get_severity(event.host_id, event.service_id)

  if service_severity then
    pdy_custom_details["Serviceseverity"] = service_severity
  end

  pdy_custom_details["Output"] = self.sc_common:ifnil_or_empty(event.output, "no output")

  self.sc_event.event.formated_event = {
    payload = {
      summary = tostring(event.cache.host.name) .. "/" .. tostring(event.cache.service.description) .. ": " .. self.sc_params.params.status_mapping[event.category][event.element][event.state],
      timestamp = new_from_timestamp(event.last_update):rfc_3339(),
      severity = self.state_to_severity_mapping[event.state].severity,
      source = self.sc_params.params.pdy_source or tostring(event.cache.host.name),
      component = tostring(event.cache.service.description),
      group = pdy_hostgroups,
      class = "service",
      custom_details = pdy_custom_details,
    },
    routing_key = self.sc_params.params.pdy_routing_key,
    event_action = self.state_to_severity_mapping[event.state].action,
    dedup_key = event.host_id .. "_" .. event.service_id,
    client = self.sc_params.params.client,
    client_url = self.sc_params.params.client_url,
    links = {
      {
        -- should think about using the new resources page but keep it as is for compatibility reasons
        href = self.sc_params.params.pdy_centreon_url .. "/centreon/main.php?p=20202&o=hd&host_name=" .. tostring(event.cache.host.name),
        text = "Link to Centreon host summary"
      }
    }
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
    payload = broker.json_encode(event)
  else
    payload = payload .. broker.json_encode(event)
  end
  
  return payload
end

function EventQueue:send_data(payload, queue_metadata)
  self.sc_logger:debug("[EventQueue:send_data]: Starting to send data")

  -- write payload in the logfile for test purpose
  if self.sc_params.params.send_data_test == 1 then
    self.sc_logger:notice("[send_data]: " .. tostring(payload))
    return true
  end

  self.sc_logger:info("[EventQueue:send_data]: Going to send the following json " .. tostring(payload))
  self.sc_logger:info("[EventQueue:send_data]: Pagerduty address is: " .. tostring(self.sc_params.params.http_server_url))

  local http_response_body = ""
  local http_request = curl.easy()
    :setopt_url(self.sc_params.params.http_server_url)
    :setopt_writefunction(
      function (response)
        http_response_body = http_response_body .. tostring(response)
      end
    )
    :setopt(curl.OPT_TIMEOUT, self.sc_params.params.connection_timeout)
    :setopt(curl.OPT_SSL_VERIFYPEER, self.sc_params.params.allow_insecure_connection)
    :setopt(
      curl.OPT_HTTPHEADER,
      {
        "content-type: application/json",
        "content-length:" .. string.len(payload),
      }
  )

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
  -- pagerduty use 202 https://developer.pagerduty.com/api-reference/reference/events-v2/openapiv3.json/paths/~1enqueue/post
  if http_response_code == 202 then
    self.sc_logger:info("[EventQueue:send_data]: HTTP POST request successful: return code is " .. tostring(http_response_code))
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
  queue.sc_event = sc_event.new(event, queue.sc_params.params, queue.sc_common, queue.sc_logger, queue.sc_broker)

  if queue.sc_event:is_valid_category() then
    if queue.sc_event:is_valid_element() then
      -- format event if it is validated
      if queue.sc_event:is_valid_event() then
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
