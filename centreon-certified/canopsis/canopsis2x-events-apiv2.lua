#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker Canopsis Connector Events
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

--------------------------------------------------------------------------------
-- Misc function
--------------------------------------------------------------------------------

local function table_extract_and_remove_key(table, key)
  local element = table[key]
  table[key] = nil
  return element
end

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
    "canopsis_authkey",
    "canopsis_host"
  }

  self.fail = false

  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/canopsis4-events.log"
  local log_level = params.log_level or 1

  -- initiate mandatory objects
  self.sc_logger = sc_logger.new(logfile, log_level)
  self.sc_common = sc_common.new(self.sc_logger)
  self.sc_broker = sc_broker.new(self.sc_logger)
  self.sc_params = sc_params.new(self.sc_common, self.sc_logger)
  self.bbdo_version = self.sc_common:get_bbdo_version()

  -- checking mandatory parameters and setting a fail flag
  if not self.sc_params:is_mandatory_config_set(mandatory_parameters, params) then
    self.fail = true
  end

  -- force buffer size to 1 because this SC does not allows the event bulk at this moment. (can't send more than one event at once)
  params.max_buffer_size = 1
  self.sc_logger:notice("[EventQueue:new]: max_buffer_size = 1 (force buffer size to 1 because this SC does not allows the event bulk at this moment)")

  -- mandatory parameter
  self.sc_params.params.canopsis_authkey = params.canopsis_authkey
  self.sc_params.params.canopsis_host = params.canopsis_host
  -- overriding default parameters for this stream connector if the default values doesn't suit the basic needs
  self.sc_params.params.accepted_categories = params.accepted_categories or "neb"
  self.sc_params.params.accepted_elements = params.accepted_elements or "host_status,service_status,acknowledgement,downtime"
  self.sc_params.params.canopsis_downtime_comment_route = params.canopsis_downtime_comment_route or "/api/v4/pbehavior-comments"
  self.sc_params.params.canopsis_downtime_reason_name =  params.canopsis_downtime_reason_name or "Centreon_downtime"
  self.sc_params.params.canopsis_downtime_reason_route = params.canopsis_downtime_reason_route or "/api/v4/pbehavior-reasons"
  self.sc_params.params.canopsis_downtime_route = params.canopsis_downtime_route or "/api/v4/pbehaviors"
  self.sc_params.params.canopsis_downtime_send_pbh = params.canopsis_downtime_send_pbh or 1
  self.sc_params.params.canopsis_downtime_type_name = params.canopsis_downtime_type_name or "Default maintenance"
  self.sc_params.params.canopsis_downtime_type_route = params.canopsis_downtime_type_route or "/api/v4/pbehavior-types"
  self.sc_params.params.canopsis_event_route = params.canopsis_event_route or "/api/v4/event"
  self.sc_params.params.canopsis_port = params.canopsis_port or 443
  self.sc_params.params.canopsis_sort_list_hostgroups = params.canopsis_sort_list_hostgroups or 0
  self.sc_params.params.canopsis_sort_list_servicegroups = params.canopsis_sort_list_servicegroups or 0
  self.sc_params.params.connector = params.connector or "centreon-stream"
  self.sc_params.params.connector_name = params.connector_name or "centreon-stream-central"
  self.sc_params.params.connector_name_type =  params.connector_name_type or "poller"
  self.sc_params.params.sending_method = params.sending_method or "api"
  self.sc_params.params.sending_protocol = params.sending_protocol or "https"
  -- self.sc_params.params.timezone = params.timezone or "Europe/Paris"
  self.sc_params.params.use_severity_as_state = params.use_severity_as_state or 0

  -- apply users params and check syntax of standard ones
  self.sc_params:param_override(params)
  self.sc_params:check_params()
  self.sc_params.params.send_mixed_events = 0

  if self.sc_params.params.connector_name_type ~= "poller" and self.sc_params.params.connector_name_type ~= "custom" then
    self.sc_params.params.connector_name_type = "poller"
  end

  self.sc_macros = sc_macros.new(self.sc_params.params, self.sc_logger)
  self.format_template = self.sc_params:load_event_format_file(true)

  -- only load the custom code file, not executed yet
  if self.sc_params.load_custom_code_file
    and not self.sc_params:load_custom_code_file(self.sc_params.params.custom_code_file)
  then
    self.sc_logger:error("[EventQueue:new]: couldn't successfully load the custom code file: "
      .. tostring(self.sc_params.params.custom_code_file))
  end

  self.sc_params:build_accepted_elements_info()
  self.sc_flush = sc_flush.new(self.sc_params.params, self.sc_logger)

  local categories = self.sc_params.params.bbdo.categories
  local elements = self.sc_params.params.bbdo.elements

  self.sc_flush:add_queue_metadata(categories.neb.id, elements.host_status.id, {event_route = self.sc_params.params.canopsis_event_route})
  self.sc_flush:add_queue_metadata(categories.neb.id, elements.service_status.id, {event_route = self.sc_params.params.canopsis_event_route})
  self.sc_flush:add_queue_metadata(categories.neb.id, elements.acknowledgement.id, {event_route = self.sc_params.params.canopsis_event_route})
  self.sc_flush:add_queue_metadata(categories.neb.id, elements.downtime.id, {event_route = self.sc_params.params.canopsis_downtime_route})

  self.format_event = {
    [categories.neb.id] = {
      [elements.host_status.id] = function () return self:format_event_host() end,
      [elements.service_status.id] = function () return self:format_event_service() end,
      [elements.downtime.id] = function () return self:format_event_downtime() end,
      [elements.acknowledgement.id] = function () return self:format_event_acknowledgement() end
    },
    [categories.bam.id] = {}
  }

  self.centreon_to_canopsis_state = {
    [categories.neb.id] = {
      [elements.host_status.id] = {
        [0] = 0,
        [1] = 3,
        [2] = 2
      },
      [elements.service_status.id] = {
        [0] = 0,
        [1] = 1,
        [2] = 3,
        [3] = 2
      }
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

  --Check if downtime are wanted
  if self.sc_params.params.canopsis_downtime_send_pbh ~= 0 and self.sc_params.params.accepted_elements_info["downtime"] then
    local metadata_reason = {
      method = "GET",
      event_route = self.sc_params.params.canopsis_downtime_reason_route
    }

    pbh_maintenance_reason_id = self:getCanopsisAPI(metadata_reason, self.sc_params.params.canopsis_downtime_reason_route, "", self.sc_params.params.canopsis_downtime_reason_name)

    -- 1. Reason : Ensure reason "centreon_reason" exists, if not create it and post it
    if pbh_maintenance_reason_id == false then
      self.sc_logger:notice("Reason for Centreon downtimes doesn't exist in Canopsis API: Creating pbehavior-reason 'centreon_reason")
      new_reason = {
          name = self.sc_params.params.canopsis_downtime_reason_name,
          description = "Activation Maintenance Centreon",
      }
      metadata_post = {
        method = "POST",
        event_route = self.sc_params.params.canopsis_downtime_reason_route
      }
      self:postCanopsisAPI(metadata_post, self.sc_params.params.canopsis_downtime_reason_route, new_reason)
    else
      -- If the reason id is reachable with downtime_reason_route
      if pbh_maintenance_reason_id ~= false and self.sc_params.params.send_data_test ~= 1 then
        self.sc_params.params.canopsis_downtime_reason_id = pbh_maintenance_reason_id
      elseif pbh_maintenance_reason_id ~= false and self.sc_params.params.send_data_test == 1 then
        self.sc_params.params.canopsis_downtime_reason_id = "RRRR"
      else
        -- if unable to get reason id, disable pbehavior management
        self.sc_params.params.canopsis_downtime_send_pbh = 0
      end
    end

    -- 2. Type : Dynamically get pbehavior type id for canopsis_downtime_type_name
    local metadata_type = {
      method = "GET",
      event_route = self.sc_params.params.canopsis_downtime_type_route
    }
    pbh_maintenance_type_id = self:getCanopsisAPI(metadata_type, self.sc_params.params.canopsis_downtime_type_route, self.sc_params.params.canopsis_downtime_type_name, "")
    -- If the type id is reachable with downtime_type_route
    if pbh_maintenance_type_id ~= false and self.sc_params.params.send_data_test ~= 1 then
      self.sc_params.params.canopsis_downtime_type_id = pbh_maintenance_type_id
    elseif pbh_maintenance_type_id ~= false and self.sc_params.params.send_data_test == 1 then
      self.sc_params.params.canopsis_downtime_type_id = "TTTT"
    else
      -- if unable to get type id, disable pbehavior management
      self.sc_params.params.canopsis_downtime_send_pbh = 0
    end

    -- 3. Type : Check Canopsis version to add or not the color value
    local metadata_type = {
      method = "GET",
      event_route = "/api/v4/app-info"
    }
    canopsis_version = self:getCanopsisAPI(metadata_type, "/api/v4/app-info", "", "")
  end

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

function EventQueue:list_servicegroups()
  local servicegroups =  {}

  for _, sg in pairs(self.sc_event.event.cache.servicegroups) do
    table.insert(servicegroups, sg.group_name)
  end

  if self.sc_params.params.canopsis_sort_list_servicegroups == 1 then
    table.sort(servicegroups)
  end

  return servicegroups
end

function EventQueue:list_hostgroups()
  local hostgroups =  {}

  for _, hg in pairs(self.sc_event.event.cache.hostgroups) do
    table.insert(hostgroups, hg.group_name)
  end

  if self.sc_params.params.canopsis_sort_list_hostgroups == 1 then
    table.sort(hostgroups)
  end

  return hostgroups
end

function EventQueue:get_state(event, severity)
  -- return standard centreon state
  if severity and self.sc_params.params.use_severity_as_state == 1 then
    return severity
  end

  return self.centreon_to_canopsis_state[event.category][event.element][event.state]
end

function EventQueue:get_connector_name()
  -- use poller name as a connector name
  if self.sc_params.params.connector_name_type == "poller" then
    return tostring(self.sc_event.event.cache.poller)
  end

  return tostring(self.sc_params.params.connector_name)
end

function EventQueue:format_event_host()
  local event = self.sc_event.event

  self.sc_event.event.formated_event = {
    event_type = "check",
    source_type = "component",
    connector = self.sc_params.params.connector,
    connector_name = self:get_connector_name(),
    component = tostring(event.cache.host.name),
    output = event.short_output,
    long_output = event.long_output,
    state = self:get_state(event, event.cache.severity.host),
    timestamp = event.last_check,
    hostgroups = self:list_hostgroups(),
    notes_url = tostring(event.cache.host.notes_url),
    action_url = tostring(event.cache.host.action_url),
    host_id = tostring(event.cache.host.host_id)
  }
end

function EventQueue:format_event_service()
  local event = self.sc_event.event

  self.sc_event.event.formated_event = {
    event_type = "check",
    source_type = "resource",
    connector = self.sc_params.params.connector,
    connector_name = self:get_connector_name(),
    component = tostring(event.cache.host.name),
    resource = tostring(event.cache.service.description),
    output = event.short_output,
    long_output = event.long_output,
    state = self:get_state(event, event.cache.severity.service),
    timestamp = event.last_check,
    servicegroups = self:list_servicegroups(),
    notes_url = event.cache.service.notes_url,
    action_url = event.cache.service.action_url,
    service_id = tostring(event.cache.service.service_id),
    host_id = tostring(event.cache.host.host_id),
    hostgroups = self:list_hostgroups()
  }
end

function EventQueue:format_event_acknowledgement()
  local event = self.sc_event.event
  local elements = self.sc_params.params.bbdo.elements

  self.sc_event.event.formated_event = {
    event_type = "ack",
    author = event.author,
    resource = "",
    component = tostring(event.cache.host.name),
    connector = self.sc_params.params.connector,
    connector_name = self:get_connector_name(),
    timestamp = event.entry_time,
    output = event.comment_data,
    long_output = event.comment_data
    -- no available in api v4 ?
    -- crecord_type = "ack",
    -- origin = "centreon",
    -- ticket = "",
    -- state_type = 1,
    -- ack_resources = false
  }

  if event.service_id then
    self.sc_event.event.formated_event['source_type'] = "resource"
    self.sc_event.event.formated_event['resource'] = tostring(event.cache.service.description)
    -- only with v2 api ?
    -- self.sc_event.event.formated_event['ref_rk'] = tostring(event.cache.service.description)
    --   .. "/" .. tostring(event.cache.host.name)
    self.sc_event.event.formated_event['state'] = self.centreon_to_canopsis_state[event.category]
      [elements.service_status.id][event.state]
  else
    self.sc_event.event.formated_event['source_type'] = "component"
    -- only with v2 api ?
    -- self.sc_event.event.formated_event['ref_rk'] = "undefined/" .. tostring(event.cache.host.name)
    self.sc_event.event.formated_event['state'] = self.centreon_to_canopsis_state[event.category]
      [elements.host_status.id][event.state]
  end

  -- send ackremove
  -- Acknowledgement (deletion_time) Time at which the acknowledgement was deleted. If 0, it was not deleted.
  if event.deletion_time ~= 0 then
    self.sc_event.event.formated_event['event_type'] = "ackremove"
  end
end

function EventQueue:format_event_downtime()

  local event = self.sc_event.event
  local elements = self.sc_params.params.bbdo.elements
  local downtime_name = "centreon-downtime-" .. event.internal_id .. "-" .. event.entry_time

  if event.cancelled == true or (self.bbdo_version == 2 and event.deletion_time == 1) or (self.bbdo_version > 2 and event.deletion_time ~= -1) then
    local metadata = {
      method = "DELETE",
      event_route = self.sc_params.params.canopsis_downtime_route
    }
    self:send_data({name = downtime_name}, metadata)
  else
    self.sc_event.event.formated_event = {
      _id = downtime_name,
      author = event.author,
      enabled = true,
      name = downtime_name,
      reason = self.sc_params.params.canopsis_downtime_reason_id,
      rrule = "",
      tstart = event.start_time,
      tstop = event.end_time,
      type = self.sc_params.params.canopsis_downtime_type_id,
      -- timezone = self.sc_params.params.timezone,
      comment = {
        {
          --['author'] = event.author,
          ['pbehavior'] = downtime_name,
          ['message'] = event.comment_data
        }
      },
      entity_pattern = {
        {
          {
            field = "_id",
            cond = {
              type = "eq"
            }
          }
        }
      }
      -- exdates = {}
    }

    if event.service_id then
      self.sc_event.event.formated_event["entity_pattern"][1][1]["cond"]["value"] = tostring(event.cache.service.description)
        .. "/" .. tostring(event.cache.host.name)
    else
      self.sc_event.event.formated_event["entity_pattern"][1][1]["cond"]["value"] = tostring(event.cache.host.name)
    end

    -- In case of Canopsis version 22.10.X a color value is add in downtime:
    if string.find(canopsis_version, "22.10.") ~= nil then
      self.sc_event.event.formated_event["color"] = "#73D8FF"
    end
  end
end

--------------------------------------------------------------------------------
-- EventQueue:add, add an event to the sending queue
--------------------------------------------------------------------------------
function EventQueue:add()
  -- store event in self.events lists
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element
  local next = next

  if next(self.sc_event.event.formated_event) ~= nil then
    self.sc_logger:debug("[EventQueue:add]: add event in queue category: " .. tostring(self.sc_params.params.reverse_category_mapping[category])
      .. " element: " .. tostring(self.sc_params.params.reverse_element_mapping[category][element]))
    self.sc_logger:debug("[EventQueue:add]: queue size before adding event: " .. tostring(#self.sc_flush.queues[category][element].events))

    self.sc_flush.queues[category][element].events[#self.sc_flush.queues[category][element].events + 1] = self.sc_event.event.formated_event

    self.sc_logger:info("[EventQueue:add]: queue size is now: " .. tostring(#self.sc_flush.queues[category][element].events)
    .. ", max is: " .. tostring(self.sc_params.params.max_buffer_size))
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
    payload = {event}
  else
    table.insert(payload, event)
  end

  return payload
end

function EventQueue:send_data(payload, queue_metadata)
  self.sc_logger:debug("[EventQueue:send_data]: Starting to send data")

  local params = self.sc_params.params
  local downtime_comment = ""
  local send_downtime_comment = false
  local http_method = "POST"
  local url = params.sending_protocol .. "://" .. params.canopsis_host .. ':' .. params.canopsis_port .. queue_metadata.event_route

  -- Deletion (for downtimes)
  if queue_metadata.method ~= nil and queue_metadata.method == "DELETE" then
    http_method = queue_metadata.method
    url = url .. "?name=" .. payload.name
    queue_metadata.headers = {
      "accept: */*",
      "x-canopsis-authkey: " .. tostring(self.sc_params.params.canopsis_authkey)
    }
    payload = broker.json_encode(payload)
    self.sc_logger:log_curl_command(url, queue_metadata, self.sc_params.params, "")

  -- Downtime events creation
  elseif queue_metadata.event_route == self.sc_params.params.canopsis_downtime_route then
    payload = payload[1]
    queue_metadata.headers = {
      "content-type: application/json",
      "x-canopsis-authkey: " .. tostring(self.sc_params.params.canopsis_authkey)
    }
    downtime_comment = table_extract_and_remove_key(payload,"comment")
    send_downtime_comment = true
    payload = broker.json_encode(payload)

    self.sc_logger:log_curl_command(url, queue_metadata, self.sc_params.params, payload)

  -- Other Event than downtimes
  else
    payload = broker.json_encode(payload)
    queue_metadata.headers = {
      "content-length: " .. string.len(payload),
      "content-type: application/json",
      "x-canopsis-authkey: " .. tostring(self.sc_params.params.canopsis_authkey)
    }
    self.sc_logger:log_curl_command(url, queue_metadata, self.sc_params.params, payload)
  end

  -- write payload in the logfile for test purpose
  if self.sc_params.params.send_data_test == 1 then
    self.sc_logger:notice("[send_data]: " .. tostring(payload))
    return true
  end

  self.sc_logger:info("[EventQueue:send_data]: Going to send the following json " .. payload)
  self.sc_logger:info("[EventQueue:send_data]: Canopsis address is: " .. tostring(url))

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
    :setopt(curl.OPT_SSL_VERIFYHOST, self.sc_params.params.verify_certificate)
    :setopt(curl.OPT_HTTPHEADER, queue_metadata.headers)
    :setopt(curl.OPT_CUSTOMREQUEST, http_method)

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
      http_request:setopt(curl.OPT_PROXYUSERPWD, self.sc_params.params.proxy_username
        .. ':' .. self.sc_params.params.proxy_password)
    else
      self.sc_logger:error("[EventQueue:send_data]: proxy_password parameter is not set but proxy_username is used")
    end
  end

  http_request:setopt_postfields(payload)

  -- performing the HTTP request
  http_request:perform()

  -- collecting results
  http_response_code = http_request:getinfo(curl.INFO_RESPONSE_CODE)

  http_request:close()

  -- Handling the return code
  local retval = false

  if http_response_code >= 200 and http_response_code <= 299 then
    self.sc_logger:info("[EventQueue:send_data]: HTTP " .. http_method .. " request successful: return code is "
      .. tostring(http_response_code))

    -- in case of Downtime event post, an other post is required
    if send_downtime_comment == true then
      self.sc_logger:info("[EventQueue:send_data]: Comment to send is " .. tostring(downtime_comment))
      local metadata_comment = {
        method = "POST",
        event_route = self.sc_params.params.canopsis_downtime_comment_route
      }
      self:postCanopsisAPI(metadata_comment, self.sc_params.params.canopsis_downtime_comment_route, downtime_comment)
    end

    retval = true
  elseif http_response_code == 400 and string.match(http_response_body, "Trying to insert PBehavior with already existing _id") then
    self.sc_logger:notice("[EventQueue:send_data]: Ignoring downtime with id: " .. tostring(payload._id)
      .. ". Canopsis result: " .. tostring(http_response_body))
    self.sc_logger:info("[EventQueue:send_data]: duplicated downtime event: " .. tostring(data))
    retval = true
  else
    self.sc_logger:error("[EventQueue:send_data]: HTTP " .. http_method .. " request FAILED, return code is "
      .. tostring(http_response_code) .. ". Message is: " .. tostring(http_response_body))

    if payload then
      self.sc_logger:error("[EventQueue:send_data]: sent payload was: " .. tostring(payload))
    end
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

--------------------------------------------------------------------------------
-- Function to send a Post Request to Canopsis API for Reason route
--------------------------------------------------------------------------------

function EventQueue:postCanopsisAPI(self_metadata, route, data_to_send)
  self.sc_logger:debug("[postCanopsisAPI]:Posting data to Canopsis route: ".. route)

  -- Handling the return code
  local retval = false
  local data_to_send = data_to_send
  local params = self.sc_params.params
  local url = params.sending_protocol .. "://" .. params.canopsis_host .. ':' .. params.canopsis_port .. route

  if route == self.sc_params.params.canopsis_downtime_comment_route then
    data_to_send = data_to_send[1]
    self_metadata.headers = {
      "accept: application/json",
      "content-type: application/json",
      "x-canopsis-authkey: " .. tostring(self.sc_params.params.canopsis_authkey)
    }
    data_to_send = broker.json_encode(data_to_send)
  else
    data_to_send = broker.json_encode(data_to_send)
    self_metadata.headers = {
      "content-length: " .. string.len(data_to_send),
      "content-type: application/json",
      "x-canopsis-authkey: " .. tostring(self.sc_params.params.canopsis_authkey)
    }
  end

  self.sc_logger:log_curl_command(url, self_metadata, self.sc_params.params, data_to_send)

  -- write payload in the logfile for test purpose
  if self.sc_params.params.send_data_test == 1 then
    self.sc_logger:notice("[postCanopsisAPI]: " .. tostring(data_to_send))
    return true
  end

  self.sc_logger:info("[postCanopsisAPI]: Going to send the following json: " .. data_to_send)
  self.sc_logger:info("[postCanopsisAPI]: Canopsis address is: " .. tostring(url))

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
    :setopt(curl.OPT_SSL_VERIFYHOST, self.sc_params.params.verify_certificate)
    :setopt(curl.OPT_HTTPHEADER, self_metadata.headers)
    :setopt(curl.OPT_CUSTOMREQUEST, "POST")

  -- set proxy address configuration
  if (self.sc_params.params.proxy_address ~= '') then
    if (self.sc_params.params.proxy_port ~= '') then
      http_request:setopt(curl.OPT_PROXY, self.sc_params.params.proxy_address .. ':' .. self.sc_params.params.proxy_port)
    else
      self.sc_logger:error("[postCanopsisAPI]: proxy_port parameter is not set but proxy_address is used")
    end
  end

  -- set proxy user configuration
  if (self.sc_params.params.proxy_username ~= '') then
    if (self.sc_params.params.proxy_password ~= '') then
      http_request:setopt(curl.OPT_PROXYUSERPWD, self.sc_params.params.proxy_username
        .. ':' .. self.sc_params.params.proxy_password)
    else
      self.sc_logger:error("[postCanopsisAPI]: proxy_password parameter is not set but proxy_username is used")
    end
  end

  http_request:setopt_postfields(data_to_send)

  -- performing the HTTP request
  http_request:perform()

  -- collecting results
  http_response_code = http_request:getinfo(curl.INFO_RESPONSE_CODE)

  http_request:close()

  if http_response_code >= 200 and http_response_code <= 299 then
    self.sc_logger:info("[postCanopsisAPI]: HTTP POST request successful: return code is "
      .. tostring(http_response_code))
    self.sc_logger:notice("[postCanopsisAPI]: HTTP POST request successful: return code is "
    .. tostring(http_response_code))
    retval = true
  elseif http_response_code == 400 and string.find(tostring(http_response_body), "ID already exists") then
    self.sc_logger:notice("[EventQueue:send_data]: Tried to send duplicate data. It is going to be ignored. "
      .. "return code is: " .. tostring(http_response_body) .. ". Message is: " .. tostring(http_response_body))
    
    if payload then
      self.sc_logger:notice("[EventQueue:send_data]: sent payload was: " .. tostring(data_to_send))
    end
    
    retval = true
  else
    self.sc_logger:error("[postCanopsisAPI]: HTTP POST request FAILED, return code is "
      .. tostring(http_response_code) .. ". Message is: " .. tostring(http_response_body))

    if payload then
      self.sc_logger:error("[EventQueue:send_data]: sent payload was: " .. tostring(data_to_send))
    end
  end

  return retval
end

--------------------------------------------------------------------------------
-- Function to send a Get Request to Canopsis API for Reason, type and version routes
--------------------------------------------------------------------------------

function EventQueue:getCanopsisAPI(self_metadata, route, type_name, reason_name)

  self.sc_logger:debug("[getCanopsisAPI]:Getting data from Canopsis route : ".. route)

  -- Handling the return code
  local retval = false
  local data = nil
  local params = self.sc_params.params
  local url = params.sending_protocol .. "://" .. params.canopsis_host .. ':' .. params.canopsis_port .. route

  self_metadata.headers = {
    "accept: application/json",
    "x-canopsis-authkey: " .. tostring(self.sc_params.params.canopsis_authkey)
  }

  self.sc_logger:log_curl_command(url, self_metadata, self.sc_params.params, data)

  -- write payload in the logfile for test purpose
  if self.sc_params.params.send_data_test == 1 then
    self.sc_logger:notice("[getCanopsisAPI]: ".. tostring(url) .. " | ".. tostring(type_name).. " | ".. tostring(reason_name))
    return false
  end

  self.sc_logger:info("[getCanopsisAPI]: Canopsis address is: " .. tostring(url))

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
    :setopt(curl.OPT_SSL_VERIFYHOST, self.sc_params.params.verify_certificate)
    :setopt(curl.OPT_HTTPHEADER, self_metadata.headers)
    :setopt(curl.OPT_CUSTOMREQUEST, "GET")

  -- set proxy address configuration
  if (self.sc_params.params.proxy_address ~= '') then
    if (self.sc_params.params.proxy_port ~= '') then
      http_request:setopt(curl.OPT_PROXY, self.sc_params.params.proxy_address .. ':' .. self.sc_params.params.proxy_port)
    else
      self.sc_logger:error("[getCanopsisAPI]: proxy_port parameter is not set but proxy_address is used")
    end
  end

  -- set proxy user configuration
  if (self.sc_params.params.proxy_username ~= '') then
    if (self.sc_params.params.proxy_password ~= '') then
      http_request:setopt(curl.OPT_PROXYUSERPWD, self.sc_params.params.proxy_username
        .. ':' .. self.sc_params.params.proxy_password)
    else
      self.sc_logger:error("[getCanopsisAPI]: proxy_password parameter is not set but proxy_username is used")
    end
  end

  -- performing the HTTP request
  http_request:perform()

  -- collecting results
  http_response_code = http_request:getinfo(curl.INFO_RESPONSE_CODE)

  http_request:close()

  if http_response_code == 200 then
    self.sc_logger:info("[getCanopsisAPI]: HTTP request successful: return code is "
      .. tostring(http_response_code))
    -- now handling response content which should be JSON
    local json_response_decoded, error = broker.json_decode(http_response_body)
    if error then
      self.sc_logger:error("[getCanopsisAPI]: couldn't decode json string: " .. tostring(http_response_body)
        .. ". Error is: " .. tostring(error))
      return retval
    end
    -- Handle Type
    if type_name ~= "" and reason_name == "" then
      for json_element, type_object in pairs(json_response_decoded["data"]) do
        if type_object["name"] == type_name then
          retval = type_object["_id"]
        end
      end
    -- Handle Reason
    elseif type_name == "" and reason_name ~= "" then
      for json_element, reason_object in pairs(json_response_decoded["data"]) do
        if reason_object["name"] == reason_name then
          retval = reason_object["_id"]
        end
      end
    -- No type_name and no reason_name had been given => getCanopsisAPI is used to check Canopsis version
    elseif type_name == "" and reason_name == "" then
      for json_element, json_object in pairs(json_response_decoded) do
        if json_element == "version" then
          retval = json_object
        end
      end
    end
  else
    self.sc_logger:error("[getCanopsisAPI]: HTTP request FAILED, return code is "
      .. tostring(http_response_code) .. ". Message is: " .. tostring(http_response_body))
  end

  return retval
end
