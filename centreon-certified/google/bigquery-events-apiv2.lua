#!/usr/bin/lua

local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_event = require("centreon-stream-connectors-lib.sc_event")
local sc_params = require("centreon-stream-connectors-lib.sc_params")
local sc_macros = require("centreon-stream-connectors-lib.sc_macros")
local sc_flush = require("centreon-stream-connectors-lib.sc_flush")
local jwt_auth = require("centreon-stream-connectors-lib.auth.jwt.jwt")
local sc_bq = require("centreon-stream-connectors-lib.google.bigquery.bigquery")
local curl = require("cURL")

local EventQueue = {}

function EventQueue.new(params)
  local self = {}

  local mandatory_parameters = {
    [1] = "dataset",
    [2] = "key_file_path",
    [3] = "api_key",
    [4] = "scope_list"
  }

  self.fail = false

  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/bigquery-events.log"
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
  self.sc_params.params.accepted_categories = params.accepted_categories or "neb,bam"
  self.sc_params.params.accepted_elements = params.accepted_elements or "host_status,service_status,downtime,acknowledgement,ba_status"
  self.sc_params.params.google_bq_api_url = params.google_bq_api_url or "https://content-bigquery.googleapis.com/bigquery/v2"
  self.sc_params.params.dataset = params.dataset
  self.sc_params.params.key_file_path = params.key_file_path
  self.sc_params.params.api_key = params.api_key
  self.sc_params.params.scope_list = params.scope_list
  self.sc_params.params.host_table = params.host_table or "hosts"
  self.sc_params.params.service_table = params.service_table or "services"
  self.sc_params.params.ack_table = params.ack_table or "acknowledgements"
  self.sc_params.params.downtime_table = params.downtime_table or "downtimes"
  self.sc_params.params.ba_table = params.ba_table or "bas"  

  -- apply users params and check syntax of standard ones
  self.sc_params:param_override(params)
  self.sc_params:check_params()

  self.sc_params.params.send_mixed_events = 0

  self.jwt_auth = jwt_auth.new(self.sc_params.params, self.sc_common, self.sc_logger)

  self.sc_params:build_accepted_elements_info()
  self.sc_flush = sc_flush.new(self.sc_params.params, self.sc_logger)
  
  local categories = self.sc_params.params.bbdo.categories
  local elements = self.sc_params.params.bbdo.elements

  self.sc_flush:add_queue_metadata(categories.neb.id, elements.host_status.id, {table_name = self.sc_params.params.host_table})
  self.sc_flush:add_queue_metadata(categories.neb.id, elements.service_status.id, {table_name = self.sc_params.params.service_table})
  self.sc_flush:add_queue_metadata(categories.neb.id, elements.acknowledgement.id, {table_name = self.sc_params.params.ack_table})
  self.sc_flush:add_queue_metadata(categories.neb.id, elements.downtime.id, {table_name = self.sc_params.params.downtime_table})
  self.sc_flush:add_queue_metadata(categories.neb.id, elements.ba_status.id, {table_name = self.sc_params.params.ba_table})

  self.format_event = {
    [categories.neb.id] = {
      [elements.host_status.id] = function () return self:format_event_host() end,
      [elements.service_status.id] = function () return self:format_event_service() end,
      [elements.acknowledgement.id] = function () return self:format_event_acknowledgement() end,
      [elements.downtime.id] = function () return self:format_event_downtime() end
    },
    [categories.bam.id] = {
      [elements.ba_status.id] = function () return self:format_event_ba() end
    }
  }

  self.send_data_method = {
    [1] = function (payload, queue_metadata) return self:send_data(payload, queue_metadata) end
  }

  self.build_payload_method = {
    [1] = function (payload, event) return self:build_payload(payload, event) end
  }

  local success, key_table = self.sc_common:load_json_file(self.sc_params.params.key_file_path)

  if not success then
    self.fail = true
  else
    self.key_table = key_table
  end

  -- return EventQueue object
  setmetatable(self, { __index = EventQueue })

  if self.key_table then
    self:build_bigquery_jwt_claim()
  end

  return self
end

function EventQueue:build_bigquery_jwt_claim()
  if 
    not self.key_table.client_email or 
    not self.key_table.auth_uri or
    not self.key_table.token_uri or
    not self.key_table.private_key or
    not self.key_table.project_id
  then
    self.sc_logger:error("[EventQueue:build_bigquery_jwt_claim]: one of the following information wasn't found in the key_file:" 
      .. " client_email, auth_uri, token_uri, private_key or project_id. Make sure that "
      .. tostring(self.sc_params.params.key_file) .. " is a valid key file.")
    return false
  end

  -- jwt claim time to live
  local iat = os.time()
  local jwt_expiration_date = iat + 3600

  -- create jwt_claim table
  self.jwt_claim = {
    iss = self.key_table.client_email,
    aud = self.key_table.token_uri,
    scope = self.sc_params.params.scope,
    iat = iat,
    exp = jwt_expiration_date
  }

  for claim_name, claim_value in pairs(jwt_claim) do
    self.jwt_auth:add_claim(claim_name, claim_value)
  end
end

function EventQueue:get_access_token()
  -- check if it is really needed to generate a new access_token 
  if not self.access_token or os.time() > self.jwt_expiration_date - 60 then
    self.sc_logger:info("[google.auth.jwt:get_access_token]: no jwt_token found or jwt token expiration date has been reached."
      .. " Generating a new  JWT token") 
    
    -- generate a new jwt token before asking for an access token
    if not self:create_jwt_token() then
      self.sc_logger:error("[google.auth.jwt:get_access_token]: couldn't generate a new JWT token.")
      return false
    end
  else 
    -- an already valid access_token exist, give this one instead of a new one
    return self.access_token
  end
end

--------------------------------------------------------------------------------
-- EventQueue:format_event, build your own table with the desired information
-- @return true (boolean)
--------------------------------------------------------------------------------
function EventQueue:format_accepted_event()
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element
  local template = self.sc_params.params.format_template[category][element]
  self.sc_logger:debug("[EventQueue:format_event]: starting format event")
  self.sc_event.event.formated_event = {}

  if self.format_template and template ~= nil and template ~= "" then
    for index, value in pairs(template) do
      self.sc_event.event.formated_event[index] = self.sc_macros:replace_sc_macro(value, self.sc_event.event)
    end
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

  self.sc_event.event.formated_event = {
    host_id = event.host_id,
    host_name = event.cache.host.name,
    status = event.state,
    last_check = event.last_check,
    output = event.output,
    instance_id = event.instance_id
  }
end

function EventQueue:format_event_service()
  local event = self.sc_event.event

  self.sc_event.event.formated_event = {
    host_id = event.host_id,
    host_name = event.cache.host.name,
    service_id = event.service_id,
    service_description = event.cache.service.description,
    status = event.state,
    last_check = event.last_check,
    output = event.output,
    instance_id = event.cache.host.instance_id
  }
end

function EventQueue:format_event_acknowledgement()
  local event = self.sc_event.event

  self.sc_event.event.formated_event = {
    author = event.author,
    host_id = event.host_id,
    host_name = event.cache.host.name,
    service_id = event.service_id,
    service_description = tostring(event.cache.service.description),
    status = event.state,
    output = event.output,
    instance_id = event.cache.host.instance_id,
    entry_time = event.entry_time
  }
end

function EventQueue:format_event_downtime()
  local event = self.sc_event.event

  self.sc_event.event.formated_event = {
    author = event.author,
    host_id = event.host_id,
    host_name = event.cache.host.name,
    service_id = event.service_id,
    service_description = tostring(event.cache.service.description),
    status = event.state,
    output = event.output,
    instance_id = event.cache.host.instance_id,
    actual_start_time = tonumber(event.actual_start_time),
    actual_end_time = tonumber(event.actual_end_time)
  }
end

function EventQueue:format_event_ba()
  local event = self.sc_event.event

  self.sc_event.event.formated_event = {
    ba_id = event.ba_id,
    ba_name = event.cache.ba.ba_name,
    status = event.state
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

function EventQueue:build_payload(payload, event)
  if not payload then
    payload = {
      rows = { event }
    }
  else
    table.insert(payload.rows, event)
  end

  return payload
end

function EventQueue:send_data(payload, queue_metadata)
  local params = self.sc_params.params
  self.sc_logger:debug("[EventQueue:send_data]: Starting to send data")

  local url = params.google_bq_api_url .. "/projects/" .. self.sc_oauth.key_table.project_id .. "/datasets/"
    .. params.dataset .. "/tables/" .. queue_metadata.table_name .. "/insertAll?alt=json&key=" .. params.api_key 
  queue_metadata.headers = {
    "Authorization: Bearer " .. self.sc_oauth:get_access_token(),
    "Content-Type: application/json"
  }

  self.sc_logger:log_curl_command(url, queue_metadata, params, payload)
  -- write payload in the logfile for test purpose
  if params.send_data_test == 1 then
    self.sc_logger:notice("[send_data]: " .. tostring(payload))
    return true
  end

  self.sc_logger:info("[EventQueue:send_data]: Going to send the following json " .. tostring(payload))
  self.sc_logger:info("[EventQueue:send_data]: bigquery endpoint address is: " .. tostring(url))

  local http_response_body = ""
  local http_request = curl.easy()
    :setopt_url(url)
    :setopt_writefunction(
      function (response)
        http_response_body = http_response_body .. tostring(response)
      end
    )
    :setopt(curl.OPT_TIMEOUT, params.connection_timeout)
    :setopt(curl.OPT_SSL_VERIFYPEER, params.verify_certificate)
    :setopt(curl.OPT_HTTPHEADER, queue_metadata.headers)

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
  if payload then
    http_request:setopt_postfields(payload)
  end

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

    if payload then
      self.sc_logger:error("[EventQueue:send_data]: sent payload was: " .. tostring(payload))
    end
  end

  return retval
end

function init(params)
  queue = EventQueue.new(params)
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