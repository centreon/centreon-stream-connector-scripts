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

  local os_time = os.time()
  local categories = self.params.bbdo.categories
  local elements = self.params.bbdo.elements

  self.queues = {
    [categories.neb.id] = {},
    [categories.storage.id] = {},
    [categories.bam.id] = {}
  }
  
  -- link queue flush info to their respective categories and elements
  for element_name, element_info in pairs(self.params.accepted_elements_info) do
    self.queues[element_info.category_id][element_info.element_id] = {
      flush_date = os_time,
      events = {}
    }
  end

  setmetatable(self, { __index = ScFlush })
  return self
end

--- flush_all_queues: tries to flush all queues according to accepted elements
-- @param send_method (function) the function from the stream connector that will send the data to the wanted tool
function ScFlush:flush_all_queues(send_method)
  self.sc_logger:debug("[sc_flush:flush_all_queues]: Starting to flush all queues")
  
  -- flush and reset queues of accepted elements
  for element_name, element_info in pairs(self.params.accepted_elements_info) do
    self:flush_queue(send_method, element_info.category_id, element_info.element_id)
  end
  
  self.sc_logger:debug("[sc_flush:flush_all_queues]: All queues have been flushed")
end


--- flush_queue: flush a queue if requirements are met
-- @param send_method (function) the function from the stream connector that will send the data to the wanted tool
-- @param category (number) the category related to the queue
-- @param element (number) the element related to the queue
-- @return true|false (boolean) true if the queue is not flushed and true or false depending the send_method result 
function ScFlush:flush_queue(send_method, category, element)
  -- no events are stored in the queue
  if (#self.queues[category][element].events == 0) then
    self.sc_logger:debug("[sc_flush:flush_queue]: queue with category: " .. tostring(category) .. " and element: "
      .. tostring(element) .. " won't be flushed because there is no event stored in it.")
    return true
  end

  local rem = self.params.reverse_element_mapping;

  -- flush if events in the queue are too old or if the queue is full
  if (os.time() > self.queues[category][element].flush_date + self.params.max_buffer_age)
    or (#self.queues[category][element].events > self.params.max_buffer_size) 
  then
    self.sc_logger:debug("[sc_flush:flush_queue]: flushing all the " .. rem[category][element] .. " events. Last flush date was: "
      .. tostring(self.queues[category][element].flush_date) .. ". Buffer size is: " .. tostring(#self.queues[category][element].events))
    local retval = send_method(self.queues[category][element].events, rem[category][element])

    if retval then
      self:reset_queue(category, element)
    end
  else
    return true
  end

  return retval
end

--- reset_queue: put a queue back to its initial state after flushing its events
-- @param category (number) the category related to the queue
-- @param element (number) the element related to the queue
function ScFlush:reset_queue(category, element)
  self.queues[category][element].flush_date = os.time()
  self.queues[category][element].events = {}
end

return sc_flush