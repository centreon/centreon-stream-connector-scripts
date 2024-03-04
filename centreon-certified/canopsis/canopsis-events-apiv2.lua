#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker Canopsis Connector Events
--------------------------------------------------------------------------------


-- Libraries
local curl = require "cURL"
local http = require("socket.http")
local ltn12 = require("ltn12")
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

local EventQueue = {}
EventQueue.__index = EventQueue

--------------------------------------------------------------------------------
-- Send a Get Request to Canopsis API
--------------------------------------------------------------------------------
local function getCanopsisAPI(route, type_or_reason)
  local http_result_body = {}
  route = route

  url_to_use = params.sending_protocol .. "://" .. params.canopsis_user .. ":" .. params.canopsis_password .. "@" .. params.canopsis_host .. ":" .. params.canopsis_port .. route
  if(type_or_reason="type")
    url_to_use = url_to_use .. "?search=name%3D%22Default%20maintenance%22"
  end

  self.sc_logger:debug("Getting data from Canopsis route : ".. route)
  local hr_result, hr_code, hr_header, hr_s = http.request{
    url = url_to_use,
    method = "GET",
    -- sink is where the request result's body will go
    sink = ltn12.sink.table(http_result_body),
    headers = {}
  }

  -- handling the return code
  if hr_code == 200 then
    self.sc_logger:debug("HTTP GET request successful: return code is " .. hr_code)
    if (type_or_reason="type")
      -- now handling response content which should be JSON
      local json_response_string = table.concat(http_result_body)
      local json_response_decoded = json.decode(json_response_string)

      total_types = json_response_decoded["meta"]["total_count"]

      if total_types == 1 then
        return json_response_decoded["data"][1]["_id"]
      else
        self.sc_logger:debug("Default maintenance pbehavior type not found")
        return 1
      end
    else
      return 0
    end
  else
    fatal("HTTP GET FAILED: return code is " .. hr_code)
    for i, v in ipairs(http_result_body) do
      fatal("HTTP GET FAILED: message line " .. i .. ' is "' .. v .. '"')
    end
    return 1
  end
end

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

  -- overriding default parameters for this stream connector if the default values doesn't suit the basic needs
  self.sc_params.params.canopsis_authkey = params.canopsis_authkey
  self.sc_params.params.connector = params.connector or "centreon-stream"
  self.sc_params.params.connector_name_type =  params.connector_name_type or "poller"
  self.sc_params.params.connector_name = params.connector_name or "centreon-stream-central"
  self.sc_params.params.canopsis_event_route = params.canopsis_event_route or "/api/v4/event"
  self.sc_params.params.canopsis_host = params.canopsis_host
  self.sc_params.params.canopsis_port = params.canopsis_port or 8082
  self.sc_params.params.sending_method = params.sending_method or "api"
  self.sc_params.params.sending_protocol = params.sending_protocol or "http"
  self.sc_params.params.timezone = params.timezone or "Europe/Paris"
  self.sc_params.params.accepted_categories = params.accepted_categories or "neb"
  self.sc_params.params.accepted_elements = params.accepted_elements or "host_status,service_status,acknowledgement"
  self.sc_params.params.use_severity_as_state = params.use_severity_as_state or 0
  self.sc_params.params.canopsis_downtime_route = params.canopsis_downtime_route or "/api/v4/bulk/pbehavior"
  self.sc_params.params.canopsis_downtime_reason_route = params.canopsis_downtime_reason_route or "/api/v4/pbehavior-reasons"
  self.sc_params.params.canopsis_downtime_type_route = params.canopsis_downtime_type_route or "/api/v4/pbehavior-types"
  self.sc_params.params.canopsis_downtime_reason_name =  params.canopsis_downtime_reason_name or "Downtime_Centreon"
  self.sc_params.params.canopsis_downtime_type_id = params.canopsis_downtime_type_id or "Maintenance"
  self.sc_params.params.canopsis_downtime_send_pbh = params.canopsis_downtime_send_pbh or 1
  self.sc_params.params.canopsis_user = params.canopsis_user or ""
  self.sc_params.params.canopsis_password = params.canopsis_password or ""

  -- apply users params and check syntax of standard ones
  self.sc_params:param_override(params)
  self.sc_params:check_params()
  self.sc_params.params.send_mixed_events = 0

  -- If Canopsis credentials are set and pbh send is set to 1 :
  -- check for reason and type check if Canopsis API already have them otherwise post them.
  if self.sc_params.params.canopsis_user ~= "" and self.sc_params.params.canopsis_password ~= "" self.sc_params.and params.canopsis_downtime_send_pbh ~= 0
    centreon_reason_id = "centreon_reason"
    -- 1. Reason : Ensure reason "centreon_reason" exists, if not create it and post it
    getCanopsisAPI(self.sc_params.params.canopsis_downtime_reason_route .. "/" .. centreon_reason_id, "") ~= 0 then
      self.sc_logger:debug("Reason for Centreon downtimes doesn't exist in Canopsis API: Creating pbehavior-reason 'centreon_reason")
      reason = {
          _id = centreon_reason_id,
          name = self.sc_params.params.canopsis_downtime_reason_name,
          description = "Activation Maintenance Centreon",
      }
      self:send_data(reason, self.sc_params.params.canopsis_downtime_reason_route)
    end

    -- 2. Type : Dynamically get pbehavior type id for "Default maintenance"
    pbh_maintenance_type_id = getCanopsisMaintenanceTypeId(self.sc_params.params.canopsis_downtime_type_route, "type")
    -- If the type id is reachable with downtime_type_route
    if pbh_maintenance_type_id ~= 1 then
      self.sc_params.params.canopsis_downtime_type_id = pbh_maintenance_type_id
    else
      -- if unable to get type id, disable pbehavior management
      self.sc_params.params.canopsis_downtime_send_pbh = 0
    end
  end

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

  return servicegroups
end

function EventQueue:list_hostgroups()
  local hostgroups =  {}

  for _, hg in pairs(self.sc_event.event.cache.hostgroups) do
    table.insert(hostgroups, hg.group_name)
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
  self.sc_logger:notice("DUMPER: EVENT-HOST - self:list_hostgroups(): " .. self.sc_common:dumper(self:list_hostgroups()))
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
  self.sc_logger:notice("DUMPER: EVENT-SERVICE - self:list_hostgroups(): " .. self.sc_common:dumper(self:list_hostgroups()))
end

function EventQueue:format_event_acknowledgement()
  local event = self.sc_event.event
  local elements = self.sc_params.params.bbdo.elements

  self.sc_logger:notice("DUMPER: EVENT-ACKNOWLEDGEMENT - Formating an acknowledgement in host: " .. self.sc_common:dumper(tostring(event.cache.host.name)))

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
  if event.deletion_time then
    self.sc_event.event.formated_event['event_type'] = "ackremove"
    -- only with v2 api ?
    -- self.sc_event.event.formated_event['crecord_type'] = "ackremove"
    -- self.sc_event.event.formated_event['timestamp'] = event.deletion_time
  end
end

function EventQueue:format_event_downtime()

  self.sc_logger:notice("DUMPER: format_event_downtime")

  local event = self.sc_event.event
  local elements = self.sc_params.params.bbdo.elements
  local downtime_name = "centreon-downtime-" .. event.internal_id .. "-" .. event.entry_time
  self.sc_logger:notice("DUMPER: downtime_name: " .. self.sc_common:dumper(downtime_name))

  --
  if event.cancelled == true or (self.bbdo_version == 2 and event.deletion_time == 1) or (self.bbdo_version > 2 and event.deletion_time ~= -1) then
    self.sc_logger:notice("DUMPER: DELETE event :" .. self.sc_common:dumper(downtime_name))
    local metadata = {
      method = "DELETE",
      event_route = "/api/v4/pbehaviors"
    }
    self:send_data({name = downtime_name}, metadata)
  else
    self.sc_logger:notice("DUMPER: SET DOWNTIME :" .. self.sc_common:dumper(downtime_name))
    self.sc_event.event.formated_event = {
      -- _id = canopsis_downtime_id,
      author = event.author,
      name = downtime_name,
      tstart = event.start_time,
      tstop = event.end_time,
      type = self.sc_params.params.canopsis_downtime_type_id,
      reason = self.sc_params.params.canopsis_downtime_reason_name,
      timezone = self.sc_params.params.timezone,
      comments = {
        {
          ['author'] = event.author,
          ['message'] = event.comment_data
        }
      },
      entity_pattern = {
        {
          {
            field = "name",
            cond = {
              type = "eq"
            }
          }
        }
      },
      exdates = {}
    }
    self.sc_logger:notice("DUMPER: event.formated_event['comments'] :" .. self.sc_common:dumper(event.formated_event["comments"]))
    self.sc_logger:notice("DUMPER: event.formated_event['type'] :" .. self.sc_common:dumper(event.formated_event["type"]))
    self.sc_logger:notice("DUMPER: event.formated_event['reason'] :" .. self.sc_common:dumper(event.formated_event["reason"]))

    if event.service_id then
      self.sc_event.event.formated_event["entity_pattern"][1][1]["cond"]["value"] = tostring(event.cache.service.description)
        .. "/" .. tostring(event.cache.host.name)
    else
      self.sc_event.event.formated_event["entity_pattern"][1][1]["cond"]["value"] = tostring(event.cache.host.name)
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
  local url = params.sending_protocol .. "://" .. params.canopsis_host .. ':' .. params.canopsis_port .. queue_metadata.event_route
  payload = broker.json_encode(payload)
  queue_metadata.headers = {
    "content-length: " .. string.len(payload),
    "content-type: application/json",
    "x-canopsis-authkey: " .. tostring(self.sc_params.params.canopsis_authkey)
  }

  self.sc_logger:log_curl_command(url, queue_metadata, self.sc_params.params, payload)

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
    :setopt(curl.OPT_SSL_VERIFYPEER, self.sc_params.params.allow_insecure_connection)
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
      http_request:setopt(curl.OPT_PROXYUSERPWD, self.sc_params.params.proxy_username 
        .. ':' .. self.sc_params.params.proxy_password)
    else
      self.sc_logger:error("[EventQueue:send_data]: proxy_password parameter is not set but proxy_username is used")
    end
  end

  -- adding the HTTP POST data
  if queue_metadata.method and queue_metadata.method == "DELETE" then
    http_request:setopt(curl.OPT_CUSTOMREQUEST, queue_metadata.method)
  end

  http_request:setopt_postfields(payload)

  -- performing the HTTP request
  http_request:perform()

  -- collecting results
  http_response_code = http_request:getinfo(curl.INFO_RESPONSE_CODE)

  http_request:close()

  -- Handling the return code
  local retval = false

  if http_response_code == 200 then
    self.sc_logger:info("[EventQueue:send_data]: HTTP POST request successful: return code is "
      .. tostring(http_response_code))
    retval = true
  elseif http_response_code == 400 and string.match(http_response_body, "Trying to insert PBehavior with already existing _id") then
    self.sc_logger:notice("[EventQueue:send_data]: Ignoring downtime with id: " .. tostring(payload._id)
      .. ". Canopsis result: " .. tostring(http_response_body))
    self.sc_logger:info("[EventQueue:send_data]: duplicated downtime event: " .. tostring(data))
    retval = true
  else
    self.sc_logger:error("[EventQueue:send_data]: HTTP POST request FAILED, return code is " 
      .. tostring(http_response_code) .. ". Message is: " .. tostring(http_response_body))
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

