#!/usr/bin/lua

-- Centreon Broker Splunk Metrics Stream Connector 

-- Libraries
local curl = require "cURL"
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_metrics = require("centreon-stream-connectors-lib.sc_metrics")
local sc_flush = require("centreon-stream-connectors-lib.sc_flush")
local sc_params = require("centreon-stream-connectors-lib.sc_params")

-- event_queue class
local event_queue = {}
event_queue.__index = event_queue

--- Constructor
--- @param conf table given by the init() function and returned from the GUI
--- @return table the new event_queue
function event_queue.new(params)
  local self = {}

  local mandatory_parameters = {
    "http_server_url",
    "splunk_token"
  }

  self.fail = false

  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/splunk-metrics.log"
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
  self.sc_params.params.splunk_index                 = params.splunk_index or ""
  self.sc_params.params.splunk_source                = params.splunk_source or ""
  self.sc_params.params.splunk_sourcetype            = params.splunk_sourcetype or "_json"
  self.sc_params.params.splunk_host                  = params.splunk_host or "Central"
  self.sc_params.params.accepted_categories          = params.accepted_categories or "neb"
  self.sc_params.params.accepted_elements            = params.accepted_elements or "service_status"
  self.sc_params.params.max_buffer_size              = params.max_buffer_size or 30
  self.sc_params.params.hard_only                    = params.hard_only or 0
  self.sc_params.params.enable_host_status_dedup     = params.enable_host_status_dedup or 0
  self.sc_params.params.enable_service_status_dedup  = params.enable_service_status_dedup or 0
  self.sc_params.params.metric_name_regex            = params.metric_name_regex or "[^a-zA-Z0-9_]"
  self.sc_params.params.metric_replacement_character = params.metric_replacement_character or "_"
  self.sc_params.params.verify_certificate           = params.verify_certificate or true

  -- apply users params and check syntax of standard ones
  self.sc_params:param_override(params)
  self.sc_params:check_params()

  -- in order to have the proper use of that max_buffer_size param, we need to separate queues for hosts and services
  self.sc_params.params.send_mixed_events = 0

  -- only load the custom code file, not executed yet
  if self.sc_params.load_custom_code_file and not self.sc_params:load_custom_code_file(self.sc_params.params.custom_code_file) then
    self.sc_logger:error("[event_queue:new]: couldn't successfully load the custom code file: " .. tostring(self.sc_params.params.custom_code_file))
  end

  self.sc_params:build_accepted_elements_info()
  
  self.sc_flush = sc_flush.new(self.sc_params.params, self.sc_logger)

  local categories = self.sc_params.params.bbdo.categories
  local elements   = self.sc_params.params.bbdo.elements

  -- it is not possible to have a payload containing metrics from different hosts or services.
  -- therefore, we need to check if the metric that we are working on belongs to the same host/service than the previous metric
  -- that's why we initiate a structure to store this info
  self.previous_info = {
    [categories.neb.id] = {
      [elements.host_status.id] = {
        host_id = "",
        flush_success = false
      },
      [elements.service_status.id] = {
        host_id = "",
        service_id = "",
        flush_success = false
      }
    }
  }

  self.format_event = {
    [categories.neb.id] = {
      [elements.host_status.id]    = function () return self:format_event_host() end,
      [elements.service_status.id] = function () return self:format_event_service() end
    }
  }

  self.format_metric = {
    [categories.neb.id] = {
      [elements.host_status.id]    = function (metric) return self:format_metric_host(metric) end,
      [elements.service_status.id] = function (metric) return self:format_metric_service(metric) end
    }
  }

  self.send_data_method = {
    [1] = function (payload, queue_metadata) return self:send_data(payload, queue_metadata) end
  }

  self.build_payload_method = {
    [1] = function (payload, event) return self:build_payload(payload, event) end
  }

  -- those sleep counters will avoid log spam and connection spam
  self.send_data_sleep_counter = self.sc_common:create_sleep_counter_table({}, 0, 300, 10)
  self.init_fail_sleep_counter = self.sc_common:create_sleep_counter_table({}, 0, 300, 10)

  -- return event_queue object
  setmetatable(self, { __index = event_queue })
  return self
end

--- Calls the adequate format_event_* function and then
--- calls add() functions
--- @return void
function event_queue:format_accepted_event()
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element
  self.sc_logger:debug("[event_queue:format_event]: starting format event")

  -- can't format event if stream connector is not handling this kind of event
  if not self.format_event[category][element] then
    self.sc_logger:error("[format_event]: You are trying to format an event with category: "
      .. tostring(self.sc_params.params.reverse_category_mapping[category]) .. " and element: "
      .. tostring(self.sc_params.params.reverse_element_mapping[category][element])
      .. ". If it is a not a misconfiguration, you can open an issue at https://github.com/centreon/centreon-stream-connector-scripts/issues")
  else
    self.sc_logger:debug("[event_queue:format_event]: going to format it")
    self.format_event[category][element]()
  end

  -- Add hostgroup
  if self.sc_event.event.cache.host.groups then
    self.sc_event.event.formated_event["hostgroups:"] = self.sc_event.event.cache.host.groups
  end

  -- Add ACK & Downtime
  self.sc_event.event.formated_event["acknowledge"] = self.sc_event.event.acknowledged
  self.sc_event.event.formated_event["downtime"] = self.sc_event.event.scheduled_downtime_depth

  self.sc_logger:debug("[event_queue:format_event]: event formatting is finished")
end

--- Formats host events by calling the format_metric() function defined for host status events
--- @return void
function event_queue:format_event_host()
  self.sc_logger:debug("[event_queue:format_event_host]: starting format event host.")
  local event = self.sc_event.event
  self.sc_logger:debug("[event_queue:format_event_host]: call build_metric ")
  self.sc_metrics:build_metric(self.format_metric[event.category][event.element])
end

--- Formats service events by calling the format_metric() function defined for service status events
--- @return void
function event_queue:format_event_service()
  self.sc_logger:debug("[event_queue:format_event_service]: starting format event service.")
  local event = self.sc_event.event
  self.sc_metrics:build_metric(self.format_metric[event.category][event.element])
  self.sc_logger:debug("[event_queue:format_event_service]: format metric service is finished ")
end

--- Prepare a formatted metric event based on a service status event
--- @param metric table A single metric's data
--- @return void
function event_queue:format_metric_host(metric)
  self.sc_logger:debug("[event_queue:format_metric_host]: call format metric ")
  local event = self.sc_event.event

  self.sc_event.event.formated_event = {
    event_type = "host",
    state = event.state,
    state_type = event.state_type,
    hostname = event.cache.host.name,
    hostaddress = event.cache.host.address,
    lastchange = event.last_hard_state_change,
    ctime = event.last_check
  }

  self:format_metric_event(metric)
  self.sc_logger:debug("[event_queue:format_metric_host]: Finishing")
end

--- Prepare a formatted metric event based on a service status event
--- @param metric table a single metric's data
--- @return void
function event_queue:format_metric_service(metric)
  self.sc_logger:debug("[event_queue:format_metric_service]: Beginning to format metric ")
  local event = self.sc_event.event

  self.sc_event.event.formated_event = {
    event_type = "service",
    state = event.state,
    state_type = event.state_type,
    hostname = event.cache.host.name,
    hostaddress = event.cache.host.address,
    service_description = event.cache.service.description,
    lastchange = event.last_hard_state_change,
    ctime = event.last_check
  }

  self:format_metric_event(metric)
  self.sc_logger:debug("[event_queue:format_metric_service]: Finishing")
end

--- Completes the formatting of a metric event and calls add() to adds it to the events list
--- @param metric table a single metric's data
--- @return void
function event_queue:format_metric_event(metric)
  self.sc_logger:debug("[event_queue:format_metric]: start real format metric ")
  self.sc_event.event.formated_event["metric_name:" .. tostring(metric.metric_name)] = metric.value
  
  -- add metric instance in tags
  if metric.instance ~= "" then
    self.sc_event.event.formated_event["instance"] = metric.instance
  end
  
  if metric.subinstance[1] then
    self.sc_event.event.formated_event["subinstances"] = metric.subinstance
  end
  
  self:add()
  self.sc_logger:debug("[event_queue:format_metric]: end real format metric ")
end

--- Adds an event to the sending queue
--- @return void
function event_queue:add()
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element

  self.sc_logger:debug("[event_queue:add]: add event in queue category: " .. tostring(self.sc_params.params.reverse_category_mapping[category])
    .. " element: " .. tostring(self.sc_params.params.reverse_element_mapping[category][element]))

  self.sc_logger:debug("[event_queue:add]: queue size before adding event: " .. tostring(#self.sc_flush.queues[category][element].events))

  self.sc_flush.queues[category][element].events[#self.sc_flush.queues[category][element].events + 1] = self.sc_event.event.formated_event

  self.sc_logger:info("[event_queue:add]: queue size is now: " .. tostring(#self.sc_flush.queues[category][element].events) 
    .. ", max is: " .. tostring(self.sc_params.params.max_buffer_size))
end

--- Concatenates data so it is ready to be sent
--- @param payload string json encoded string
--- @param event table the event that is going to be added to the payload
--- @return string json encoded string
function event_queue:build_payload(payload, event)
  self.sc_logger:debug("[event_queue:build_payload]: Starting to build payload")

  if not payload then
    payload = { event }
  else
    table.insert(payload, event)
  end

  self.sc_logger:debug("[event_queue:build_payload]: Finishing to build payload")
  return payload
end

--- Attempts to send the data
--- @param payload table Object to send
--- @param queue_metadata table metadata to use for sending data
--- @return boolean json encoded string
function event_queue:send_data(payload, queue_metadata)
  self.sc_logger:debug("[event_queue:send_data]: Starting to send data")

  -- until this line, the payload variable contains an array of objects
  payload = broker.json_encode(
    {
      sourcetype = self.sc_params.params.splunk_sourcetype,
      source     = self.sc_params.params.splunk_source,
      index      = self.sc_params.params.splunk_index,
      host       = self.sc_params.params.splunk_host,
      time       = self.sc_event.event.last_check,
      event      = payload
    }
  )
  -- now it is a JSON string with the former table encoded under the event attribute

  queue_metadata.headers = {
    "content-type: application/json",
    "content-length:" .. string.len(payload),
    "authorization: Splunk " .. self.sc_params.params.splunk_token
  }
  local url = self.sc_params.params.http_server_url

  -- write payload in the logfile for test purpose
  if self.sc_params.params.send_data_test == 1 then
    self.sc_logger:notice("[send_data]: " .. tostring(payload))
    return true
  end

  self.sc_logger:debug("[event_queue:send_data]: Going to send the following json " .. tostring(payload))
  self.sc_logger:debug("[event_queue:send_data]: Splunk address is: " .. tostring(url))

  local http_response_body = ""
  local http_request = curl.easy()
    :setopt_url(url)
    :setopt_writefunction(
      function (response)
        http_response_body = http_response_body .. tostring(response)
      end
    )
    :setopt(curl.OPT_SSL_VERIFYPEER, self.sc_params.params.verify_certificate)
    :setopt(curl.OPT_SSL_VERIFYHOST, self.sc_params.params.verify_certificate)
    :setopt(curl.OPT_TIMEOUT, self.sc_params.params.connection_timeout)
    :setopt(curl.OPT_HTTPHEADER, queue_metadata.headers)

  -- set proxy address configuration
  if (self.sc_params.params.proxy_address ~= '') then
    if (self.sc_params.params.proxy_port ~= '') then
      http_request:setopt(curl.OPT_PROXY, self.sc_params.params.proxy_address .. ':' .. self.sc_params.params.proxy_port)
    else 
      self.sc_logger:error("[event_queue:send_data]: proxy_port parameter is not set but proxy_address is used")
    end
  end

  -- set proxy user configuration
  if (self.sc_params.params.proxy_username ~= '') then
    if (self.sc_params.params.proxy_password ~= '') then
      http_request:setopt(curl.OPT_PROXYUSERPWD, self.sc_params.params.proxy_username .. ':' .. self.sc_params.params.proxy_password)
    else
      self.sc_logger:error("[event_queue:send_data]: proxy_password parameter is not set but proxy_username is used")
    end
  end

  -- adding the HTTP POST data
  http_request:setopt_postfields(payload)

  -- for troubleshooting purpose
  self.sc_logger:log_curl_command(url, queue_metadata, self.sc_params.params, payload)

  -- performing the HTTP request
  self.sc_logger:debug("[event_queue:send_data]: performing request")
  http_request:perform()
  self.sc_logger:debug("[event_queue:send_data]: request performed")

  -- collecting results
  http_response_code = http_request:getinfo(curl.INFO_RESPONSE_CODE) 

  http_request:close()
  
  -- Handling the return code
  local retval = false
  if http_response_code == 200 then
    self.sc_logger:info("[event_queue:send_data]: HTTP POST request successful: return code is " .. tostring(http_response_code))
    retval = true
  else
    self.sc_logger:error("[event_queue:send_data]: HTTP POST request FAILED, return code is " .. tostring(http_response_code) .. ". Message is: " .. tostring(http_response_body))

    if payload then
      self.sc_logger:error("[event_queue:send_data]: sent payload was: " .. tostring(payload))
    end
  end
  
  return retval
end

local queue

--- Required function for Broker Stream Connector
--- @param conf table Parameters of the stream connector
--- @return void
function init(conf)
  queue = event_queue.new(conf)
end

--- Required function for Broker Stream Connector
--- @param event table the event from broker
--- @return boolean true if everything went well, false otherwise
function write (event)
  -- skip event if a mandatory parameter is missing
  if queue.fail then
    queue.init_fail_sleep_counter:sleep()
    queue.sc_logger:error("Skipping event because a mandatory parameter is not set")
    
    return false
  end

  queue.init_fail_sleep_counter:reset()

  -- initiate event object
  queue.sc_metrics = sc_metrics.new(event, queue.sc_params.params, queue.sc_common, queue.sc_broker, queue.sc_logger)
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
  queue.sc_logger:debug("[write]: Calling flush() function ")
  return flush()
end

-- flush method is called by broker every now and then (more often when broker has nothing else to do)
function flush()
  queue.sc_logger:debug("[flush]: Function starting")
  local queues_size = queue.sc_flush:get_queues_size()
  
  -- nothing to flush
  if queues_size == 0 then
    queue.sc_logger:debug("[flush]: Function finishing without flushing (queue empty)")
    return true
  end

  -- flush all queues because last global flush is too old
  if queue.sc_flush.last_global_flush < os.time() - queue.sc_params.params.max_all_queues_age then
    queue.sc_logger:debug("[flush]: Time to flush: max age reached")
    if not queue.sc_flush:flush_all_queues(queue.build_payload_method[1], queue.send_data_method[1]) then
      return false
    end

    return true
  end

  -- flush queues because too many events are stored in them
  if queues_size > queue.sc_params.params.max_buffer_size then
    queue.sc_logger:debug("[flush]: Time to flush: max size reached")
    if not queue.sc_flush:flush_all_queues(queue.build_payload_method[1], queue.send_data_method[1]) then
      return false
    end

    return true
  end
  queue.sc_logger:debug("[flush]: Function finishing without flushing")
  -- there are events in the queue but they were not ready to be send
  return false
end

