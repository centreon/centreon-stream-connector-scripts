#!/usr/bin/lua

local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_event = require("centreon-stream-connectors-lib.sc_event")
local sc_params = require("centreon-stream-connectors-lib.sc_params")
local sc_macros = require("centreon-stream-connectors-lib.sc_macros")
local sc_flush = require("centreon-stream-connectors-lib.sc_flush")
local kafka_config = require("centreon-stream-connectors-lib.rdkafka.config")
local kafka_producer = require("centreon-stream-connectors-lib.rdkafka.producer")
local kafka_topic_config = require("centreon-stream-connectors-lib.rdkafka.topic_config")
local kafka_topic = require("centreon-stream-connectors-lib.rdkafka.topic")

local EventQueue = {}

function EventQueue.new(params)
  local self = {}

  -- listing madantory parameters
  local mandatory_parameters = {
    [1] = "topic",
    [2] = "brokers"
  }

  -- initiate EventQueue variables
  self.events = {}
  self.fail = false

  -- set up log configuration
  local logfile = params.logfile or "/var/log/centreon-broker/kafka-stream-connector.log"
  local log_level = params.log_level or 1
  
  -- initiate mandatory objects
  self.sc_logger = sc_logger.new(logfile, log_level)
  self.sc_common = sc_common.new(self.sc_logger)
  self.sc_broker = sc_broker.new(self.sc_logger)
  self.sc_params = sc_params.new(self.sc_common, self.sc_logger)
  self.sc_kafka_config = kafka_config.new()
  self.sc_kafka_topic_config = kafka_topic_config.new()

  -- initiate parameters dedicated to this stream connector
  self.sc_params.params.kafka_partition_ua = -1
  self.sc_params.params.topic = params.topic
  self.sc_params.params.brokers = params.brokers
  self.sc_params.params.centreon_name = params.centreon_name
  
  -- overriding default parameters for this stream connector
  
  -- checking mandatory parameters and setting a fail flag
  if not self.sc_params:is_mandatory_config_set(mandatory_parameters, params) then
    self.fail = true
  end

  -- handle kafka params
  self.sc_params:get_kafka_params(self.sc_kafka_config, params)
  
  -- apply users params and check syntax of standard ones
  self.sc_params:param_override(params)
  self.sc_params:check_params()
  
  -- SEGFAULT ON EL8 (only usefull for debugging)
  -- self.sc_kafka_config:set_delivery_cb(function (payload, err) print("Delivery Callback '"..payload.."'") end)
  -- self.sc_kafka_config:set_stat_cb(function (payload) print("Stat Callback '"..payload.."'") end)
  
  -- initiate a kafka producer
  self.sc_kafka_producer = kafka_producer.new(self.sc_kafka_config)

  -- add kafka brokers to the producer
  local kafka_brokers = self.sc_common:split(self.sc_params.params.brokers, ',')
  for index, broker in ipairs(kafka_brokers) do
    self.sc_kafka_producer:brokers_add(broker)
  end

  -- add kafka topic config
  self.sc_kafka_topic_config["auto.commit.enable"] = "true"
  self.sc_kafka_topic = kafka_topic.new(self.sc_kafka_producer, self.sc_params.params.topic, self.sc_kafka_topic_config)

  self.sc_macros = sc_macros.new(self.sc_params.params, self.sc_logger)
  self.format_template = self.sc_params:load_event_format_file()
  self.sc_params:build_accepted_elements_info()
  self.sc_flush = sc_flush.new(self.sc_params.params, self.sc_logger)
  
  local categories = self.sc_params.params.bbdo.categories
  local elements = self.sc_params.params.bbdo.elements

  self.format_event = {
    [categories.neb.id] = {
      [elements.host_status.id] = function () return self:format_host_status() end,
      [elements.service_status.id] = function () return self:format_service_status() end
    },
    [categories.bam.id] = function () return self:format_ba_status() end
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

  return true
end

function EventQueue:format_host_status()
  self.sc_event.event.formated_event = {
    host = tostring(self.sc_event.event.cache.host.name),
    state = self.sc_params.params.status_mapping[self.sc_event.event.category][self.sc_event.event.element][self.sc_event.event.state],
    output = self.sc_common:ifnil_or_empty(string.gsub(self.sc_event.event.output, '\\', "_"), "no output"),
  }
end

function EventQueue:format_service_status()
  self.sc_event.event.formated_event = {
    host = tostring(self.sc_event.event.cache.host.name),
    service = tostring(self.sc_event.event.cache.service.description),
    state = self.sc_params.params.status_mapping[self.sc_event.event.category][self.sc_event.event.element][self.sc_event.event.state],
    output = self.sc_common:ifnil_or_empty(string.gsub(self.sc_event.event.output, '\\', "_"), "no output")
  }
end

function EventQueue:format_ba_status()
  self.sc_event.event.formated_event = {
    ba = tostring(self.sc_event.event.cache.ba.ba_name),
    state = self.sc_params.params.status_mapping[self.sc_event.event.category][self.sc_event.event.element][self.sc_event.event.state]
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
    payload = payload .. ',' .. broker.json_encode(event)
  end
  
  return payload
end

--------------------------------------------------------------------------------
-- EventQueue:send_data, send data to external tool
-- @return (boolean)
--------------------------------------------------------------------------------
function EventQueue:send_data (payload)

  -- write payload in the logfile for test purpose
  if self.sc_params.params.send_data_test == 1 then
    self.sc_logger:notice("[send_data]: " .. tostring(payload))
    return true
  end

  self.sc_logger:info("EventQueue:send_data:  creating json: " .. tostring(payload))

  -- output data to the tool we want
  if self:call(payload) then
    return true
  end

  return false
end

--------------------------------------------------------------------------------
-- EventQueue:call send the data where we want it to be
-- @param data (string) the data we want to send
-- @return true (boolean)
--------------------------------------------------------------------------------
function EventQueue:call (data)
  self.sc_kafka_producer:produce(self.sc_kafka_topic, self.sc_params.params.kafka_partition_ua, data)

  return true
end

local queue

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
