#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker Elastic Connector Events
--------------------------------------------------------------------------------

-- Libraries
local curl = require("cURL")
local ltn12 = require("ltn12")
local mime = require("mime")

-- Centreon lua core libraries
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_event = require("centreon-stream-connectors-lib.sc_event")
local sc_params = require("centreon-stream-connectors-lib.sc_params")
local sc_macros = require("centreon-stream-connectors-lib.sc_macros")
local sc_flush = require("centreon-stream-connectors-lib.sc_flush")

--------------------------------------------------------------------------------
-- event_queue class
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
        "elastic_url",
        "elastic_username",
        "elastic_password",
        "elastic_index_status"
    }

    self.fail = false

    -- set up log configuration
    local logfile = params.logfile or "/var/log/centreon-broker/elastic-events-apiv2.log"
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
    self.sc_params.params.accepted_elements = params.accepted_elements or "host_status,service_status"

    -- apply users params and check syntax of standard ones
    self.sc_params:param_override(params)
    self.sc_params:check_params()

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
      [categories.bam.id] = {}
    }

    self.send_data_method = {
      [1] = function (data, element) return self:send_data(data, element) end
    }

    -- return EventQueue object
    setmetatable(self, { __index = EventQueue })
    return self
  end

--------------------------------------------------------------------------------
---- EventQueue:format_event method
---------------------------------------------------------------------------------
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
        event_type = "host",
        timestamp = self.sc_event.event.last_check,
        host = self.sc_event.event.cache.host.name,
        output = string.gsub(self.sc_event.event.output, "\n", " "),
        status = self.sc_params.params.status_mapping[self.sc_event.event.category][self.sc_event.event.element][self.sc_event.event.state],
        state = self.sc_event.event.state,
        state_type = self.sc_event.event.state_type
    }
  end

  function EventQueue:format_event_service()
    self.sc_event.event.formated_event = {
      event_type = "service",
      timestamp = self.sc_event.event.last_check,
      host = self.sc_event.event.cache.host.name,
      service = self.sc_event.event.cache.service.description,
      status = self.sc_params.params.status_mapping[self.sc_event.event.category][self.sc_event.event.element][self.sc_event.event.state],
      state = self.sc_event.event.state,
      state_type = self.sc_event.event.state_type,
      output = string.gsub(self.sc_event.event.output, "\n", " "),
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

  function EventQueue:send_data(data, element)
    self.sc_logger:debug("[EventQueue:send_data]: Starting to send data")

    -- write payload in the logfile for test purpose
    if self.sc_params.params.send_data_test == 1 then
      self.sc_logger:info("[send_data]: " .. broker.json_encode(data))
      return true
    end

    local http_post_metadata = {
      ["index"] = {
        ["_index"] = tostring((self.sc_params.params.elastic_index_status))
      }
    }

    local http_post_data = broker.json_encode(http_post_metadata)
    for _, raw_event in ipairs(data) do
      http_post_data = http_post_data .. broker.json_encode(http_post_metadata) .. "\n" .. broker.json_encode(raw_event) .. "\n"
    end

    self.sc_logger:info("[EventQueue:send_data]: Going to send the following json " .. tostring(http_post_data))
    self.sc_logger:info("[EventQueue:send_data]: Elastic URL is: " .. tostring(self.sc_params.params.elastic_url) .. "/_bulk")

  local http_response_body = ""
  local http_request = curl.easy()
    :setopt_url(self.sc_params.params.elastic_url .. "/_bulk")
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
        "content-type: application/json;charset=UTF-8",
        "content-length: " .. string.len(http_post_data),
        "Authorization: Basic " .. (mime.b64(self.sc_params.params.elastic_username .. ":" .. self.sc_params.params.elastic_password))
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
        broker_log:error("[EventQueue:send_data]: proxy_password parameter is not set but proxy_username is used")
      end
    end

    -- adding the HTTP POST data
    http_request:setopt_postfields(http_post_data)

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

--------------------------------------------------------------------------------
-- Required functions for Broker StreamConnector
--------------------------------------------------------------------------------

local queue

-- Fonction init()
function init(conf)
  queue = EventQueue.new(conf)
end

-- Fonction write()
function write(event)
  -- First, flush all queues if needed (too old or size too big)
  queue.sc_flush:flush_all_queues(queue.send_data_method[1])

  -- skip event if a mandatory parameter is missing
  if queue.fail then
    queue.sc_logger:error("Skipping event because a mandatory parameter is not set")
    return true
  end

  -- initiate event object
  queue.sc_event = sc_event.new(event, queue.sc_params.params, queue.sc_common, queue.sc_logger, queue.sc_broker)

  -- drop event if wrong category
  if not queue.sc_event:is_valid_category() then
    queue.sc_logger:debug("dropping event because category is not valid. Event category is: "
      .. tostring(queue.sc_params.params.reverse_category_mapping[queue.sc_event.event.category]))
    return true
  end

  -- drop event if wrong element
  if not queue.sc_event:is_valid_element() then
    queue.sc_logger:debug("dropping event because element is not valid. Event element is: "
      .. tostring(queue.sc_params.params.reverse_element_mapping[queue.sc_event.event.category][queue.sc_event.event.element]))
    return true
  end

  -- drop event if it is not validated
  if queue.sc_event:is_valid_event() then
    queue:format_accepted_event()
  else
    return true
  end

  -- Since we've added an event to a specific queue, flush it if queue is full
  queue.sc_flush:flush_queue(queue.send_data_method[1], queue.sc_event.event.category, queue.sc_event.event.element)
  return true
end
