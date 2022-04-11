#!/usr/bin/lua

--------------------------------------------------------------------------------
-- Centreon Broker Opsgenie connector
-- documentation available at https://docs.centreon.com/current/en/integrations/stream-connectors/opsgenie.html
--------------------------------------------------------------------------------

-- libraries
local curl = require "cURL"
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_event = require("centreon-stream-connectors-lib.sc_event")
local sc_params = require("centreon-stream-connectors-lib.sc_params")
local sc_macros = require("centreon-stream-connectors-lib.sc_macros")
local sc_flush = require("centreon-stream-connectors-lib.sc_flush")

--------------------------------------------------------------------------------
-- EventQueue class
--------------------------------------------------------------------------------

local EventQueue = {}
EventQueue.__index = EventQueue


--------------------------------------------------------------------------------
-- Constructor
-- @param conf The table given by the init() function and returned from the GUI
-- @return the new EventQueue
--------------------------------------------------------------------------------

function EventQueue.new (params)
  local self = {}

  local mandatory_parameters = {
    "app_api_token",
    "integration_api_token"
  }

  self.fail = false

  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/opsgenie-events.log"
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
  self.sc_params.params.accepted_categories = params.accepted_categories or "neb"
  self.sc_params.params.api_url = params.api_url or "https://api.opsgenie.com"
  self.sc_params.params.app_api_token = params.app_api_token
  self.sc_params.params.integration_api_token = params.integration_api_token
  self.sc_params.params.timestamp_conversion_format = params.timestamp_conversion_format or "%Y-%m-%d %H:%M:%S"
  self.sc_params.params.enable_incident_tags = params.enable_incident_tags or 1
  self.sc_params.params.get_bv = params.get_bv or 1
  self.sc_params.params.enable_severity = params.enable_severity or 0
  self.sc_params.params.priority_must_be_set = params.priority_must_be_set or 0
  self.sc_params.params.priority_matching = params.priority_matching or 'P1=1,P2=2,P3=3,P4=4,P5=5'
  self.sc_params.params.opsgenie_priorities = params.opsgenie_priorities or 'P1,P2,P3,P4,P5'
  self.sc_params.params.ba_incident_tags = params.ba_incident_description or 'centreon,applications'
  self.priority_mapping = {}

  -- apply users params and check syntax of standard ones
  self.sc_params:param_override(params)
  self.sc_params:check_params()

  -- apply check syntax of opgenie spec
  self.sc_params.params.enable_incident_tags = self.sc_common:check_boolean_number_option_syntax(self.sc_params.params.enable_incident_tags, 1)
  self.sc_params.params.get_bv = self.sc_common:check_boolean_number_option_syntax(self.sc_params.params.get_bv, 1)
  self.sc_params.params.enable_severity = self.sc_common:check_boolean_number_option_syntax(self.sc_params.params.enable_severity, 0)
  self.sc_params.params.priority_must_be_set = self.sc_common:check_boolean_number_option_syntax(self.sc_params.params.priority_must_be_set, 0)
  self.sc_params.params.priority_matching = self.sc_common:ifnil_or_empty(self.sc_params.params.priority_matching, 'P1=1,P2=2,P3=3,P4=4,P5=5')
  self.sc_params.params.opsgenie_priorities = self.sc_common:ifnil_or_empty(self.sc_params.params.opsgenie_priorities, 'P1,P2,P3,P4,P5')

  if self.sc_params.params.enable_severity == 1 then
    self.priority_matching_list = self.sc_common:split(self.sc_params.params.priority_matching, ',')

    for i, v in ipairs(self.priority_matching_list) do
      self.severity_to_priority = self.sc_common:split(v, '=')

      if string.match(self.sc_params.params.opsgenie_priorities, self.severity_to_priority[1]) == nil then
        self.sc_logger:warning(1, "[EventQueue.new]: severity is enabled but the priority configuration is wrong. configured matching: " .. tostring(self.priority_matching_list) ..
          ", invalid parsed priority: " .. tostring(self.severity_to_priority[1]) .. ", known Opsgenie priorities: " .. tostring(self.sc_params.params.opsgenie_priorities) ..
          ". Considere adding your priority to the opsgenie_priorities list if the parsed priority is valid")
        break
      end
      self.sc_params.params.priority_mapping[self.severity_to_priority[2]] = self.severity_to_priority[1]
    end
  end

  self.sc_macros = sc_macros.new(self.sc_params.params, self.sc_logger)
  self.format_template = self.sc_params:load_event_format_file(true)
  self.sc_params:build_accepted_elements_info()
  self.sc_flush = sc_flush.new(self.sc_params.params, self.sc_logger)
  local categories = self.sc_params.params.bbdo.categories
  local elements = self.sc_params.params.bbdo.elements

  self.format_event = {
    [categories.neb.id] = {
      [elements.host_status.id] = function () return self:format_event_host() end,
      [elements.service_status.id] = function () return self:format_event_service() end
    },
    [categories.bam.id] = {
      [elements.ba_status.id] = function () return self:format_event_ba() end
    }
  }

  self.send_data_method = {
    [1] = function (payload) return self:send_data(payload) end
  }

  self.build_payload_method = {
    [1] = function (payload, event) return self:build_payload(payload, event) end
  }
  -- return EventQueue object
  setmetatable(self, { __index = EventQueue })
  return self
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
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element
  local severity = tostring(self.sc_broker:get_severity(self.sc_event.event.host_id))
  local matching_priority = self.priority_mapping[severity]

  -- drop event if no severity is found and opsgenie priority must be set

  self.sc_event.event.formated_event = {
    message = self.sc_macros:transform_date(self.sc_event.event.last_update) .. " " .. tostring(self.sc_event.event.cache.host.name) .. " is " .. self.sc_params.params.status_mapping[category][element][self.sc_event.event.state],
    description = tostring(self.sc_event.event.output),
    alias = tostring(self.sc_event.event.cache.host.name) .. "_" .. self.sc_param.params.status_mapping[category][element][self.sc_event.event.state]
  }

  --
  if matching_priority == nil and self.sc_params.params.priority_must_be_set == 1 then
    self.sc_logger:info("[EventQueue:set_priority]: couldn't find a matching priority for severity: " .. severity .. " and priority is mandatory. Dropping event")
    return false
  -- ignore priority if it is not found, opsgenie will affect a default one (P3)
  elseif matching_priority == nil then
    self.sc_logger:info("[EventQueue:set_priority]: could not find matching priority for severity: " .. severity .. ". Skipping priority...")
    return true
  else
    self.sc_event.event.formated_event.priority = matching_priority
  end
end

function EventQueue:format_event_service()
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element
  self.sc_event.event.formated_event = {
    message = self.sc_macros:transform_date(self.sc_event.event.last_update) .. " " .. tostring(self.sc_event.event.cache.host.name) .. " // " .. tostring(self.sc_event.event.cache.service.description) .. " is" .. self.sc_params.params.status_mapping[category][element][self.sc_event.event.state],
    description = tostring(self.sc_event.event.output),
    alias = tostring(self.sc_event.event.cache.host.name) .. "_" .. tostring(self.sc_event.event.cache.service.description) .. "_" .. self.sc_params.params.status_mapping[category][element][self.sc_event.event.state]
  }
end


function EventQueue:format_event_ba()
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element
  self.sc_event.event.formated_event = {
    message= tostring(self.sc_event.event.cache.ba_name) .. " is " .. self.sc_param.params.status_mapping[category][element][self.sc_event.event.state] .. ", health level reached " .. self.sc_event.event.level_nominal,
    tags = {}
  }

  --Handle tags
  if self.sc_event.event.cache.ba_name and self.sc_event.event.cache.ba_name ~= nil then
    if self.sc_param.params.enable_incident_tags == 1 then
      -- get bvs info (bv_name, bv_description...) if we not have it
      if not self.sc_event.event.cache.bvs then
        self.sc_event.event.cache.bvs =self.sc_broker:get_bvs_infos(self.event.host_id)
      end

      --Insert Tags BV with bvs info
      for i, bv_data in ipairs(self.sc_event.event.cache.bvs) do
        table.insert(self.sc_event.event.formated_event.tags, bv_data.bv_name)
      end

      --Handle custom tags
      if self.sc_params.params.ba_incident_tags ~= '' then
        local custom_tags = self.sc_common:split(self.sc_params.params.ba_incident_tags, ',')
        for i, custom_tag in ipairs(custom_tags) do
          self.sc_logger:info("[EventQueue:is_valid_bam_event: adding " .. tostring(custom_tag) .. " to the list of tags")
          table.insert(self.sc_event.event.formated_event.tags, custom_tag)
        end
      end
    end
  end
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
    payload = payload .. ',' .. broker.json_encode(event)
  end

  return payload
end

--------------------------------------------------------------------------------
-- EventQueue:send_data, send data to external tool
-- @return {boolean}
--------------------------------------------------------------------------------
function EventQueue:send_data(payload)
  self.sc_logger:debug("[EventQueue:send_data]: Starting to send data")

  -- write payload in the logfile for test purpose
  if self.sc_params.params.send_data_test == 1 then
    self.sc_logger:notice("[send_data]: " .. tostring(payload))
    return true
  end

  if self.sc_event.event.categories == 1 then
    local endpoint = self.sc_params.params.api_url .. url_path
  else
    local endpoint = self.sc_params.params.integration_api_token .. url_path
  end
  self.sc_logger:info("[EventQueue:call]: Prepare url " .. endpoint)
  self.sc_logger:info("[EventQueue:send_data]: Going to send the following json " .. tostring(payload))
  self.sc_logger:info("[EventQueue:send_data]: Opsgenie address is: " .. tostring(endpoint))

  local http_response_body = ""
  if self.sc_event.event.category == 1 then
    local http_request = curl.easy()
    :setopt_url(endpoint)
    :setopt_writefunction(
      function (response)
        http_response_body = http_response_body .. tostring(response)
      end
    )
    :setopt(curl.OPT_TIMEOUT, self.sc_params.params.connection_timeout)
    :setopt(
        curl.OPT_HTTPHEADER,
        {
          "Accept: application/json",
          "Content-Type: application/json",
          "Authorization: GenieKey " .. self.sc_params.params.app_api_token
        }
      )
  else
    local http_request = curl.easy()
    :setopt_url(endpoint)
    :setopt_writefunction(
      function (response)
        http_response_body = http_response_body .. tostring(response)
      end
    )
    :setopt(curl.OPT_TIMEOUT, self.sc_params.params.connection_timeout)
        :setopt(
          curl.OPT_HTTPHEADER,
          {
            "Accept: application/json",
            "Content-Type: application/json",
            "Authorization: GenieKey " .. self.sc_params.params.integration_api_token
          }
        )
  end

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
  if http_response_code == 200 then
    self.sc_logger:info("[EventQueue:send_data]: HTTP POST request successful: return code is " .. tostring(http_response_code))
    retval = true
  else
    self.sc_logger:error("[EventQueue:send_data]: HTTP POST request FAILED, return code is " .. tostring(http_response_code) .. ". Message is: " .. tostring(http_response_body))
  end

  return retval
end


local queue

-- Fonction init()
function init(conf)
    queue = EventQueue.new(conf)
  end

--------------------------------------------------------------------------------
-- write,
-- @param {array} event, the event from broker
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