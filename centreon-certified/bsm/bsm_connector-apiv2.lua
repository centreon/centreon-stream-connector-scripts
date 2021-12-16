--
-- Copyright © 2021 Centreon
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the Licensself.sc_event.event.
-- You may obtain a copy of the License at
--
--     http://www.apachself.sc_event.event.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the Licensself.sc_event.event.
--
-- For more information : contact@centreon.com
--
-- To work you need to provide to this script a Broker stream connector output configuration
-- with the following informations:
--
-- source_ci (string): Name of the transmiter, usually Centreon server name
-- http_server_url (string): the full HTTP URL. Default: https://my.bsm.server:30005/bsmc/rest/events/ws-centreon/.
-- http_proxy_string (string): the full proxy URL if needed to reach the BSM server. Default: empty.
-- log_path (string): the log file to use
-- log_level (number): the log level (0, 1, 2, 3) where 3 is the maximum level. 0 logs almost nothing. 1 logs only the beginning of the script and errors. 2 logs a reasonable amount of verbosself.sc_event.event. 3 logs almost everything possible, to be used only for debug. Recommended value in production: 1.
-- max_buffer_size (number): how many events to store before sending them to the server.
-- max_buffer_age (number): flush the events when the specified time (in second) is reached (even if max_size is not reached).

-- Libraries
local curl = require "cURL"
require("LuaXML")

-- Centreon lua core libraries
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_event = require("centreon-stream-connectors-lib.sc_event")
local sc_params = require("centreon-stream-connectors-lib.sc_params")
local sc_macros = require("centreon-stream-connectors-lib.sc_macros")
local sc_flush = require("centreon-stream-connectors-lib.sc_flush")

-- workaround https://github.com/centreon/centreon-broker/issues/201
local previous_event = ""

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

function EventQueue.new(params)
  local self = {}
  self.fail = false

  local mandatory_parameters = {
      "http_server_url"
  }

  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/bsm_connector-apiv2.log"
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
  self.sc_params.params.source_ci = params.source_ci or "Centreon"
  self.sc_params.params.max_output_length = params.max_output_length or 1024

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

-- Format XML file with host infoamtion
function EventQueue:format_event_host()
  local xml_host_severity = "<host_severity>" .. self.sc_common:ifnil_or_empty(self.sc_broker:get_severity(self.sc_event.event.host_id) , '0') .. "</host_severity>"
  local xml_url = self.sc_common:ifnil_or_empty(self.sc_event.event.cache.service.action_url, 'no action url for this host')
  local xml_notes = "<host_notes>" .. self.sc_common:ifnil_or_empty(self.sc_event.event.cache.service.notes, 'OS not set') .. "</host_notes>"
  
  self.sc_event.event.formated_event = {
    "<event_data>"
      .. "<hostname>" .. hostname .. "</hostname>"
      .. xml_host_severity .. xml_notes
      .. "<url>" .. xml_url .. "</url>"
      .. "<source_ci>" .. ifnil_or_empty(self.source_ci, 'Centreon') .. "</source_ci>"
      .. "<source_host_id>" .. ifnil_or_empty(self.sc_event.event.host_id, '0') .. "</source_host_id>"
      .. "<scheduled_downtime_depth>" .. ifnil_or_empty(self.sc_event.event.scheduled_downtime_depth, '0') .. "</scheduled_downtime_depth>"
      .. "</event_data>"
  }
end

-- Format XML file with service infoamtion
function EventQueue:format_event_service()
  local xml_url = self.sc_common:ifnil_or_empty(self.sc_event.event.cache.service.notes_url, 'no notes url for this service')
  local xml_service_severity = "<service_severity>" .. self.sc_common:ifnil_or_empty(self.sc_broker:get_severity(self.sc_event.event.host_id, self.sc_event.event.service_id) , '0') .. "</service_severity>"
    
  self.sc_event.event.formated_event = {
      "<event_data>"
        .. "<hostname>" .. hostname .. "</hostname>"
        .. "<svc_desc>" .. service_description .. "</svc_desc>"
        .. "<state>" ..self.sc_event.event.state .. "</state>"
        .. "<last_update>" ..self.sc_event.event.last_update .. "</last_update>"
        .. "<output>" .. string.match(e.output, "^(.*)\n") .. "</output>"
        .. xml_service_severity
        .. "<url>" .. xml_url .. "</url>"
        .. "<source_host_id>" .. ifnil_or_empty(self.sc_event.event.host_id, '0') .. "</source_host_id>"
        .."<source_svc_id>" .. ifnil_or_empty(self.sc_event.event.service_id, '0') .. "</source_svc_id>"
        .. "<scheduled_downtime_depth>" .. ifnil_or_empty(self.sc_event.event.scheduled_downtime_depth, '0') .. "</scheduled_downtime_depth>"
        .."</event_data>"
    }  
end

--------------------------------------------------------------------------------
-- EventQueue:add method
-- @param e An event
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
    for _, xml_str in ipairs(data) do
      http_post_data = http_post_data .. tostring(xml.eval(xml_str))
    end

    self.sc_logger:info(http_post_data)
    return true
  end
  
  local http_post_data = ""

  for _, xml_str in ipairs(data) do
    http_post_data = http_post_data .. tostring(xml.eval(xml_str))
  end

  self.sc_logger:info("[EventQueue:send_data]: Going to send the following json " .. tostring(http_post_data))
  self.sc_logger:info("[EventQueue:send_data]: BSM Http Server URL is: \"" .. tostring(self.sc_params.params.http_server_url .. "\""))

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
      "Content-Type: text/xml",
      "content-length: " .. string.len(http_post_data)
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
  http_request:setopt_postfields(http_post_data)
  -- performing the HTTP request
  http_request:perform()
  -- collecting results
  http_response_code = http_request:getinfo(curl.INFO_RESPONSE_CODE)
  http_request:close()

  -- Handling the return code
  local retval = false
  if http_response_code == 202 or http_response_code == 200 then
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
  queue = EventQueue.sc_event.event.new(conf)
end

-- Fonction write()
function write(event)
  -- First, flush all queues if needed (too old or size too big)
  Queue.sc_event.event.sc_flush:flush_all_queues(Queue.sc_event.event.send_data_method[1])

  -- skip event if a mandatory parameter is missing
  if Queue.sc_event.event.fail then
    Queue.sc_event.event.sc_logger:error("Skipping event because a mandatory parameter is not set")
    return true
  end

  -- initiate event object
  Queue.sc_event.event.sc_event = sc_event.new(event, Queue.sc_event.event.sc_params.params, Queue.sc_event.event.sc_common, Queue.sc_event.event.sc_logger, Queue.sc_event.event.sc_broker)

  -- drop event if wrong category
  if not Queue.sc_event.event.sc_event:is_valid_category() then
    Queue.sc_event.event.sc_logger:debug("dropping event because category is not valid. Event category is: "
      .. tostring(Queue.sc_event.event.sc_params.params.reverse_category_mapping[Queue.sc_event.event.sc_event.event.category]))
    return true
  end

  -- drop event if wrong element
  if not Queue.sc_event.event.sc_event:is_valid_element() then
    Queue.sc_event.event.sc_logger:debug("dropping event because element is not valid. Event element is: "
      .. tostring(Queue.sc_event.event.sc_params.params.reverse_element_mapping[Queue.sc_event.event.sc_event.event.category][Queue.sc_event.event.sc_event.event.element]))
    return true
  end

  -- drop event if it is not validated
  if Queue.sc_event.event.sc_event:is_valid_event() then
    queue:format_accepted_event()
  else
    return true
  end

  -- Since we've added an event to a specific queue, flush it if queue is full
  Queue.sc_event.event.sc_flush:flush_queue(Queue.sc_event.event.send_data_method[1], Queue.sc_event.event.sc_event.event.category, Queue.sc_event.event.sc_event.event.element)
  return true
end
