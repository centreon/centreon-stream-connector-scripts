#!/usr/bin/lua

--------------------------------------------------------------------------------
-- Centreon Broker Service Now connector
-- documentation: https://docs.centreon.com/current/en/integrations/stream-connectors/servicenow.html
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
    [1] = "instance",
    [2] = "client_id",
    [3] = "client_secret",
    [4] = "username",
    [5] = "password"
  }

  self.tokens = {}
  self.tokens.authToken = nil
  self.tokens.refreshToken = nil
  

  self.events = {}
  self.fail = false

  local logfile = params.logfile or "/var/log/centreon-broker/servicenow-em-stream-connector.log"
  local log_level = params.log_level or 1

  -- initiate mandatory objects
  self.sc_logger = sc_logger.new(logfile, log_level)
  self.sc_common = sc_common.new(self.sc_logger)
  self.sc_broker = sc_broker.new(self.sc_logger)
  self.sc_params = sc_params.new(self.sc_common, self.sc_logger)

  self.sc_params.params.instance = params.instance
  self.sc_params.params.client_id = params.client_id
  self.sc_params.params.client_secret = params.client_secret
  self.sc_params.params.username = params.username
  self.sc_params.params.password = params.password

  self.sc_params.params.accepted_categories = params.accepted_categories or "neb"
  self.sc_params.params.accepted_elements = params.accepted_elements or "host_status,service_status"

  -- checking mandatory parameters and setting a fail flag
  if not self.sc_params:is_mandatory_config_set(mandatory_parameters, params) then
    self.fail = true
  end

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

  setmetatable(self, { __index = EventQueue })

  return self
end

--------------------------------------------------------------------------------
-- getAuthToken: obtain a auth token
-- @return {string} self.tokens.authToken.token, the auth token
--------------------------------------------------------------------------------
function EventQueue:getAuthToken ()
  if not self:refreshTokenIsValid() then
    self:authToken()
  end

  if not self:accessTokenIsValid() then
    self:refreshToken(self.tokens.refreshToken.token)
  end

  return self.tokens.authToken.token
end

--------------------------------------------------------------------------------
-- authToken: obtain auth token
--------------------------------------------------------------------------------
function EventQueue:authToken ()
  local data = "grant_type=password&client_id=" .. self.sc_params.params.client_id .. "&client_secret=" .. self.sc_params.params.client_secret .. "&username=" .. self.sc_params.params.username .. "&password=" .. self.sc_params.params.password

  local res = self:call(
    "oauth_token.do",
    "POST",
    data
  )

  if not res.access_token then
    broker_log:error(1, "EventQueue:authToken: Authentication failed, couldn't get tokens")
    return false
  end

  self.tokens.authToken = {
    token = res.access_token,
    expTime = os.time(os.date("!*t")) + 1700
  }

  self.tokens.refreshToken = {
    token = res.refresh_token,
    expTime = os.time(os.date("!*t")) + 360000
  }
end

--------------------------------------------------------------------------------
-- refreshToken: refresh auth token
--------------------------------------------------------------------------------
function EventQueue:refreshToken (token)
  local data = "grant_type=refresh_token&client_id=" .. self.sc_params.params.client_id .. "&client_secret=" .. self.sc_params.params.client_secret .. "&username=" .. self.sc_params.params.username .. "&password=" .. self.sc_params.params.password .. "&refresh_token=" .. token
  
  local res = self:call(
    "oauth_token.do",
    "POST",
    data
  )

  if not res.access_token then
    broker_log:error(1, 'EventQueue:refreshToken Bad access token')
    return false
  end

  self.tokens.authToken = {
    token = res.access_token,
    expTime = os.time(os.date("!*t")) + 1700
  }
end

--------------------------------------------------------------------------------
-- refreshTokenIsValid: obtain auth token
--------------------------------------------------------------------------------
function EventQueue:refreshTokenIsValid ()
  if not self.tokens.refreshToken then
    return false
  end

  if os.time(os.date("!*t")) > self.tokens.refreshToken.expTime then
    self.tokens.refreshToken = nil
    return false
  end

  return true
end

--------------------------------------------------------------------------------
-- accessTokenIsValid: obtain auth token
--------------------------------------------------------------------------------
function EventQueue:accessTokenIsValid ()
  if not self.tokens.authToken then
    return false
  end

  if os.time(os.date("!*t")) > self.tokens.authToken.expTime then
    self.tokens.authToken = nil
    return false
  end

  return true
end

--------------------------------------------------------------------------------
-- EventQueue:call run api call
-- @param {string} url, the service now instance url
-- @param {string} method, the HTTP method that is used
-- @param {string} data, the data we want to send to service now
-- @param {string} authToken, the api auth token
-- @return {array} decoded output
-- @throw exception if http call fails or response is empty
--------------------------------------------------------------------------------
function EventQueue:call(url, method, data, authToken)
  method = method or "GET"
  data = data or nil
  authToken = authToken or nil

  local endpoint = "https://" .. tostring(self.sc_params.params.instance) .. ".service-now.com/" .. tostring(url)
  self.sc_logger:debug("EventQueue:call: Prepare url " .. endpoint)

  -- write payload in the logfile for test purpose
  if self.sc_params.params.send_data_test == 1 then
    self.sc_logger:notice("[send_data]: " .. tostring(data) .. " to endpoint: " .. tostring(endpoint))
    return true
  end

  local res = ""
  local request = curl.easy()
    :setopt_url(endpoint)
    :setopt_writefunction(function (response)
      res = res .. tostring(response)
    end)
    :setopt(curl.OPT_TIMEOUT, self.sc_params.params.connection_timeout)

  self.sc_logger:debug("EventQueue:call: Request initialize")

  -- set proxy address configuration
  if (self.sc_params.params.proxy_address ~= '') then
    if (self.sc_params.params.proxy_port ~= '') then
      request:setopt(curl.OPT_PROXY, self.sc_params.params.proxy_address .. ':' .. self.sc_params.params.proxy_port)
    else 
      self.sc_logger:error("EventQueue:call: proxy_port parameter is not set but proxy_address is used")
    end
  end

  -- set proxy user configuration
  if (self.sc_params.params.proxy_username ~= '') then
    if (self.sc_params.params.proxy_password ~= '') then
      request:setopt(curl.OPT_PROXYUSERPWD, self.proxy_username .. ':' .. self.sc_params.params.proxy_password)
    else
      self.sc_logger:error("EventQueue:call: proxy_password parameter is not set but proxy_username is used")
    end
  end

  if not authToken then
    if method ~= "GET" then
      self.sc_logger:debug("EventQueue:call: Add form header")
      request:setopt(curl.OPT_HTTPHEADER, { "Content-Type: application/x-www-form-urlencoded" })
    end
  else
    broker_log:info(3, "Add JSON header")
    request:setopt(
      curl.OPT_HTTPHEADER,
      {
        "Accept: application/json",
        "Content-Type: application/json",
        "Authorization: Bearer " .. authToken
      }
    )
  end

  if method ~= "GET" then
    self.sc_logger:debug("EventQueue:call: Add post data")
    request:setopt_postfields(data)
  end

  self.sc_logger:debug("EventQueue:call: request body " .. tostring(data))
  self.sc_logger:debug("EventQueue:call: request header " .. tostring(authToken))
  self.sc_logger:warning("EventQueue:call: Call url " .. endpoint)
  request:perform()

  respCode = request:getinfo(curl.INFO_RESPONSE_CODE)
  self.sc_logger:debug("EventQueue:call: HTTP Code : " .. respCode)
  self.sc_logger:debug("EventQueue:call: Response body : " .. tostring(res))

  request:close()

  if respCode >= 300 then
    self.sc_logger:error("EventQueue:call: HTTP Code : " .. respCode)
    self.sc_logger:error("EventQueue:call: HTTP Error : " .. res)
    return false
  end

  if res == "" then
    self.sc_logger:warning("EventQueue:call: HTTP Error : " .. res)
    return false
  end

  return broker.json_decode(res)
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
  self.sc_event.event.formated_event = {
    source = "centreon",
    event_class = "centreon",
    node = tostring(self.sc_event.event.cache.host.name),
    time_of_event = os.date("!%Y-%m-%d %H:%M:%S", self.sc_event.event.last_check),
    description = self.sc_event.event.output,
    resource = tostring(self.sc_event.event.cache.host.name),
    severity = self.sc_event.event.state
  }
end

function EventQueue:format_event_service()
  self.sc_event.event.formated_event = {
    source = "centreon",
    event_class = "centreon",
    node = tostring(self.sc_event.event.cache.host.name),
    time_of_event = os.date("!%Y-%m-%d %H:%M:%S", self.sc_event.event.last_check),
    description = self.sc_event.event.output,
    resource = tostring(self.sc_event.event.cache.service.description),
    severity = 5
  }

  if self.sc_event.event.state == 0 then
    self.sc_event.event.formated_event.severity = 0
  elseif self.sc_event.event.state == 1 then
      self.sc_event.event.formated_event.severity = 3
  elseif self.sc_event.event.state == 2 then 
      self.sc_event.event.formated_event.severity = 1
  elseif self.sc_event.event.state == 3 then 
      self.sc_event.event.formated_event.severity = 4
  end
end

local queue

-- Fonction init()
function init(conf)
  queue = EventQueue.new(conf)
end

--------------------------------------------------------------------------------
-- init, initiate stream connector with parameters from the configuration file
-- @param {table} parameters, the table with all the configuration parameters
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
    payload = payload .. ',' .. broker.json_encode(event)
  end
  
  return payload
end

--------------------------------------------------------------------------------
-- EventQueue:send_data, send data to external tool
-- @return {boolean}
--------------------------------------------------------------------------------
function EventQueue:send_data(payload, queue_metadata)
  local authToken
  local counter = 0

  -- generate a fake token for test purpose or use a real one if not testing
  if self.sc_params.params.send_data_test == 1 then
    authToken = "fake_token"
  else
    authToken = self:getAuthToken()
  end

  local http_post_data = '{"records":[' .. payload .. ']}'
  self.sc_logger:info('EventQueue:send_data:  creating json: ' .. http_post_data)

  if self:call(
      "api/global/em/jsonv2",
      "POST",
      http_post_data,
      authToken
    ) then
    return true
  end

  return false
end

--------------------------------------------------------------------------------
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

