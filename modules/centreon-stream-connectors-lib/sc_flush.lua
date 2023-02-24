#!/usr/bin/lua

--- 
-- Module that handles data queue for stream connectors
-- @module sc_flush
-- @alias sc_flush
local sc_flush = {}

local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_common = require("centreon-stream-connectors-lib.sc_common")

local ScFlush = {}

--- sc_flush.new: sc_flush constructor
-- @param params (table) the params table of the stream connector
-- @param [opt] sc_logger (object) a sc_logger object 
function sc_flush.new(params, logger)
  local self = {}
  
  -- create a default logger if it is not provided
  self.sc_logger = logger
  if not self.sc_logger then 
    self.sc_logger = sc_logger.new()
  end

  self.sc_common = sc_common.new(self.sc_logger)

  self.params = params
  self.last_global_flush = os.time()

  local categories = self.params.bbdo.categories
  local elements = self.params.bbdo.elements

  self.queues = {
    [categories.neb.id] = {},
    [categories.storage.id] = {},
    [categories.bam.id] = {},
    global_queues_metadata = {}
  }
  
  -- link events queues to their respective categories and elements
  for element_name, element_info in pairs(self.params.accepted_elements_info) do
    self.queues[element_info.category_id][element_info.element_id] = {
      events = {},
      queue_metadata = {
        category_id = element_info.category_id,
        element_id = element_info.element_id
      }
    }
  end

  setmetatable(self, { __index = ScFlush })
  return self
end

--- add_queue_metadata: add specific metadata to a queue
-- @param category_id (number) the id of the bbdo category
-- @param element_id (number) the id of the bbdo element
-- @param metadata (table) a table with keys that are the name of the metadata and values the metadata values
function ScFlush:add_queue_metadata(category_id, element_id, metadata)
  if not self.queues[category_id] then
    self.sc_logger:warning("[ScFlush:add_queue_metadata]: can't add queue metadata for category: " .. self.params.reverse_category_mapping[category_id]
      .. " (id: " .. category_id .. ") and element: " .. self.params.reverse_element_mapping[category_id][element_id] .. " (id: " .. element_id .. ")."
      .. ". metadata name: " .. tostring(metadata_name) .. ", metadata value: " .. tostring(metadata_value)
      .. ". You need to accept this category with the parameter 'accepted_categories'.") 
    return
  end

  if not self.queues[category_id][element_id] then
    self.sc_logger:warning("[ScFlush:add_queue_metadata]: can't add queue metadata for category: " .. self.params.reverse_category_mapping[category_id]
      .. " (id: " .. category_id .. ") and element: " .. self.params.reverse_element_mapping[category_id][element_id] .. " (id: " .. element_id .. ")."
      .. ". metadata name: " .. tostring(metadata_name) .. ", metadata value: " .. tostring(metadata_value)
      .. ". You need to accept this element with the parameter 'accepted_elements'.")
    return
  end

  for metadata_name, metadata_value in pairs(metadata) do
    self.queues[category_id][element_id].queue_metadata[metadata_name] = metadata_value
  end
end

--- flush_all_queues: tries to flush all queues according to accepted elements
-- @param build_payload_method (function) the function from the stream connector that will concatenate events in the payload
-- @param send_method (function) the function from the stream connector that will send the data to the wanted tool
-- @return boolean (boolean) if flush failed or not
function ScFlush:flush_all_queues(build_payload_method, send_method)
  if self.params.send_mixed_events == 1 then
    if not self:flush_mixed_payload(build_payload_method, send_method) then
      return false
    end
  else
    if not self:flush_homogeneous_payload(build_payload_method, send_method) then
      return false
    end
  end

  self:reset_all_queues()
  return true
end

--- reset_all_queues: put all queues back to their initial state after flushing their events
function ScFlush:reset_all_queues()
  for _, element_info in pairs(self.params.accepted_elements_info) do
    self.queues[element_info.category_id][element_info.element_id].events = {}
  end

  self.last_global_flush = os.time()
end

--- get_queues_size: get the number of events stored in all the queues
-- @return queues_size (number) the number of events stored in all queues
function ScFlush:get_queues_size()
  local queues_size = 0

  for _, element_info in pairs(self.params.accepted_elements_info) do
    queues_size = queues_size + #self.queues[element_info.category_id][element_info.element_id].events
    self.sc_logger:debug("[sc_flush:get_queues_size]: size of queue for category " .. tostring(element_info.category_name)
      .. " and element: " .. tostring(element_info.element_name)
      .. " is: " .. tostring(#self.queues[element_info.category_id][element_info.element_id].events))
  end

  return queues_size
end

--- flush_mixed_payload: flush a payload that contains various type of events (services mixed hosts for example)
-- @return boolean (boolean) true or false depending on the success of the operation
function ScFlush:flush_mixed_payload(build_payload_method, send_method)
  local payload = nil
  local counter = 0

  -- get all queues
  for _, element_info in pairs(self.params.accepted_elements_info) do
    -- get events from queues
    for _, event in ipairs(self.queues[element_info.category_id][element_info.element_id].events) do
      -- add event to the payload
      payload = build_payload_method(payload, event)
      counter = counter + 1

      -- send events if max buffer size is reached
      if counter >= self.params.max_buffer_size then
        if not self:flush_payload(send_method, payload, self.queues.global_queues_metadata) then
          return false
        end

        -- reset payload and counter because events have been sent
        payload = nil
        counter = 0
      end
    end
  end

  -- we need to empty all queues to not mess with broker retention
  if not self:flush_payload(send_method, payload, self.queues.global_queues_metadata) then
    return false
  end

  -- all events have been sent
  return true
end 

--- flush_homogeneous_payload: flush a payload that contains a single type of events (services with services only and hosts with hosts only for example)
-- @return boolean (boolean) true or false depending on the success of the operation
function ScFlush:flush_homogeneous_payload(build_payload_method, send_method)
  local counter = 0
  local payload = nil
  
  -- get all queues
  for _, element_info in pairs(self.params.accepted_elements_info) do
    -- get events from queues
    for _, event in ipairs(self.queues[element_info.category_id][element_info.element_id].events) do
      -- add event to the payload
      payload = build_payload_method(payload, event)
      counter = counter + 1
      
      -- send events if max buffer size is reached
      if counter >= self.params.max_buffer_size then
        if not self:flush_payload(
          send_method, 
          payload, 
          self.queues[element_info.category_id][element_info.element_id].queue_metadata
        ) then
          return false
        end
        
        -- reset payload and counter because events have been sent
        counter = 0
        payload = nil
      end
    end

    -- make sure there are no events left inside a specific queue
    if not self:flush_payload(
      send_method, 
      payload, 
      self.queues[element_info.category_id][element_info.element_id].queue_metadata
    ) then
      return false
    end

    -- reset payload to not mix events from different queues
    payload = nil
  end

  return true
end

--- flush_payload: flush a given payload by sending it using the given send function
-- @param send_method (function) the function that will be used to send the payload
-- @param payload (any) the data that needs to be sent
-- @param metadata (table) all metadata for the payload
-- @return boolean (boolean) true or false depending on the success of the operation
function ScFlush:flush_payload(send_method, payload, metadata)
  if payload then
    if not send_method(payload, metadata) then
      return false
    end
  end

  return true
end

return sc_flush