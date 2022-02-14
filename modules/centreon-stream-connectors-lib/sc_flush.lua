#!/usr/bin/lua

--- 
-- Module that handles data queue for stream connectors
-- @module sc_flush
-- @alias sc_flush
local sc_flush = {}

local sc_logger = require("centreon-stream-connectors-lib.sc_logger")

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

  self.params = params
  self.last_global_flush = os.time()

  local categories = self.params.bbdo.categories
  local elements = self.params.bbdo.elements

  self.queues = {
    [categories.neb.id] = {},
    [categories.storage.id] = {},
    [categories.bam.id] = {}
  }
  
  -- link events queues to their respective categories and elements
  for element_name, element_info in pairs(self.params.accepted_elements_info) do
    self.queues[element_info.category_id][element_info.element_id] = {
      events = {}
    }
  end

  setmetatable(self, { __index = ScFlush })
  return self
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
        if not self:flush_payload(send_method, payload) then
          return false
        end

        -- reset payload and counter because events have been sent
        payload = nil
        counter = 0
      end
    end
  end

  -- we need to empty all queues to not mess with broker retention
  if not self:flush_payload(send_method, payload) then
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
        if not self:flush_payload(send_method, payload) then
          return false
        end
        
        -- reset payload and counter because events have been sent
        counter = 0
        payload = nil
      end
    end

    -- make sure there are no events left inside a specific queue
    if not self:flush_payload(send_method, payload) then
      return false
    end

    -- reset payload to not mix events from different queues
    payload = nil
  end

  return true
end

--- flush_payload: flush a payload that contains a single type of events (services with services only and hosts with hosts only for example)
-- @return boolean (boolean) true or false depending on the success of the operation
function ScFlush:flush_payload(send_method, payload)
  if payload then
    if not send_method(payload) then
      return false
    end
  end

  return true
end

return sc_flush