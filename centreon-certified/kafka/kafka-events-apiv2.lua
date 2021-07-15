#!/usr/bin/lua

local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_event = require("centreon-stream-connectors-lib.sc_event")
local sc_params = require("centreon-stream-connectors-lib.sc_params")
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
  local log_level = params.log_level or 3
  
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
  
  self.sc_kafka_config:set_delivery_cb(function (payload, err) print("Delivery Callback '"..payload.."'") end)
  self.sc_kafka_config:set_stat_cb(function (payload) print("Stat Callback '"..payload.."'") end)
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

  -- return EventQueue object
  setmetatable(self, { __index = EventQueue })
  return self
end

--------------------------------------------------------------------------------
-- EventQueue:format_event, build your own table with the desired information
-- @return true (boolean)
--------------------------------------------------------------------------------
function EventQueue:format_event()
  local category = self.sc_event.event.category
  local element = self.sc_event.event.element

  if category == 1 and element == 14 then
    self.sc_event.event.formated_event = self:format_host_status()
  elseif category == 1 and element == 24 then
    self.sc_event.event.formated_event = self:format_service_status()
  elseif category == 1 and element == 5 then
    self.sc_event.event.formated_event = self:format_downtime()
  elseif category == 6 and element == 1 then
    self.sc_event.event.formated_event = self:format_ba_status()
  end

  self:add()

  return true
end

function EventQueue:format_host_status()
  local data = {
    ["alerte.alerte_emetteur"] = tostring(self.sc_params.params.centreon_name) 
      .. ";" .. self.sc_event.event.cache.host.name .. ";-",
    ["alerte.alerte_libelle"] = self.sc_event.event.cache.host.name,
    ["alerte.alerte_statut"] = self.sc_params.params.status_mapping[self.sc_event.event.category][self.sc_event.event.element][self.sc_event.event.state],
    ["alerte.alerte_message"] = self.sc_common:ifnil_or_empty(string.match(string.gsub(self.sc_event.event.output, '\\', "_"), "^(.*)\n"), "no output"),
    ["alerte.alerte_id"] = tostring(self.sc_params.params.centreon_name) 
      .. ";" .. self.sc_event.event.cache.host.name .. ";",
    ["alerte.alerte_criticite"] = self.sc_params.params.status_mapping[self.sc_event.event.category][self.sc_event.event.element][self.sc_event.event.state],
    ["alerte.custom_data.ticket_description"] = "",
    ["alerte.custom_data.ticket_note"] = ""
  }

  return data
end

function EventQueue:format_service_status()
  local data = {
    ["alerte.alerte_emetteur"] = tostring(self.sc_params.params.centreon_name) 
      .. ";" .. self.sc_event.event.cache.host.name .. ";" .. self.sc_event.event.cache.service.description,
    ["alerte.alerte_libelle"] = self.sc_event.event.cache.host.name .. "_" .. self.sc_event.event.cache.service.description,
    ["alerte.alerte_statut"] = self.sc_params.params.status_mapping[self.sc_event.event.category][self.sc_event.event.element][self.sc_event.event.state],
    ["alerte.alerte_message"] = self.sc_common:ifnil_or_empty(string.match(string.gsub(self.sc_event.event.output, '\\', "_"), "^(.*)\n"), "no output"),
    ["alerte.alerte_id"] =  tostring(self.sc_params.params.centreon_name) 
      .. ";" .. self.sc_event.event.cache.host.name .. ";" .. self.sc_event.event.cache.service.description,
    ["alerte.alerte_criticite"] = self.sc_params.params.status_mapping[self.sc_event.event.category][self.sc_event.event.element][self.sc_event.event.state],
    ["alerte.custom_data.ticket_description"] = "",
    ["alerte.custom_data.ticket_note"] = ""
  }

  return data
end

function EventQueue:format_ba_status()
  local data = {
    ["alerte.alerte_emetteur"] =  tostring(self.sc_params.params.centreon_name) .. ";Business Activity" .. self.sc_event.event.cache.ba.ba_name,
    ["alerte.alerte_libelle"] = "Business_Activity_" .. self.sc_event.event.cache.ba.ba_name,
    ["alerte.alerte_statut"] = self.sc_params.params.status_mapping[self.sc_event.event.category][self.sc_event.event.element][self.sc_event.event.state],
    ["alerte.alerte_message"] = self.sc_params.params.status_mapping[self.sc_event.event.category][self.sc_event.event.element][self.sc_event.event.state],
    ["alerte.alerte_id"] = self.sc_params.params.status_mapping[self.sc_event.event.category][self.sc_event.event.element][self.sc_event.event.state],
    ["alerte.alerte_criticite"] = self.sc_params.params.status_mapping[self.sc_event.event.category][self.sc_event.event.element][self.sc_event.event.state],
    ["alerte.custom_data.ticket_description"] = "",
    ["alerte.custom_data.ticket_note"] = ""
  }

  return data
end

--------------------------------------------------------------------------------
-- EventQueue:add, add an event to the sending queue
--------------------------------------------------------------------------------
function EventQueue:add ()
  -- store event in self.events list
  self.events[#self.events + 1] = self.sc_event.event.formated_event
end

--------------------------------------------------------------------------------
-- EventQueue:flush, flush stored events
-- Called when the max number of events or the max age are reached
-- @return (boolean)
--------------------------------------------------------------------------------
function EventQueue:flush ()
  self.sc_logger:debug("EventQueue:flush: Concatenating all the events as one string")

  -- send stored events
  retval = self:send_data()

  -- reset stored events list
  self.events = {}
  
  -- and update the timestamp
  self.sc_params.params.__internal_ts_last_flush = os.time()

  return retval
end

--------------------------------------------------------------------------------
-- EventQueue:send_data, send data to external tool
-- @return (boolean)
--------------------------------------------------------------------------------
function EventQueue:send_data ()
  local data = ""
  local counter = 0

  -- concatenate all stored event in the data variable
  for _, formated_event in ipairs(self.events) do
    if counter == 0 then
      data = broker.json_encode(formated_event) 
      counter = counter + 1
    else
      data = data .. "," .. broker.json_encode(formated_event)
    end
  end

  self.sc_logger:debug("EventQueue:send_data:  creating json: " .. tostring(data))

  -- output data to the tool we want
  if self:call(data) then
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

function write(event)
  -- skip event if a mandatory parameter is missing
  if queue.fail then
    queue.sc_logger:error("Skipping event because a mandatory parameter is not set")
    return true
  end
  
  -- initiate event object
  queue.sc_event = sc_event.new(event, queue.sc_params.params, queue.sc_common, queue.sc_logger, queue.sc_broker)

  -- drop event if wrong category
  if not queue.sc_event:is_valid_category() then
    return true
  end

  -- drop event if wrong element
  if not queue.sc_event:is_valid_element() then
    return true
  end

  -- First, are there some old events waiting in the flush queue ?
  if (#queue.events > 0 and os.time() - queue.sc_params.params.__internal_ts_last_flush > queue.sc_params.params.max_buffer_age) then
    queue.sc_logger:debug("write: Queue max age (" .. os.time() - queue.sc_params.params.__internal_ts_last_flush .. "/" .. queue.sc_params.params.max_buffer_age .. ") is reached, flushing data")
    queue:flush()
  end

  -- Then we check that the event queue is not already full
  if (#queue.events >= queue.sc_params.params.max_buffer_size) then
    queue.sc_logger:debug("write: Queue max size (" .. #queue.events .. "/" .. queue.sc_params.params.max_buffer_size .. ") is reached BEFORE APPENDING AN EVENT, trying to flush data before appending more events.")
    queue:flush()
  end

  -- drop event if it is not validated
  if queue.sc_event:is_valid_event() then
    queue:format_event()
  else
    return true
  end

  -- Then we check whether it is time to send the events to the receiver and flush
  if (#queue.events >= queue.sc_params.params.max_buffer_size) then
    queue.sc_logger:debug("write: Queue max size (" .. #queue.events .. "/" .. queue.sc_params.params.max_buffer_size .. ") is reached, flushing data")
    queue:flush()
  end

  return true
end