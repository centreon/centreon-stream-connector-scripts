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
  
  -- link queue flush info to their respective categories and elements
  self.queue = {
    [categories.neb] = {
      [elements.acknowledgement] = {
        flush_date = os_time,
        events = {}
      },
      [elements.downtime] = {
        flush_date = os_time,
        events = {}
      },
      [elements.host_status] = {
        flush_date = os_time,
        events = {}
      }, 
      [elements.service_status] = {
        flush_date = os_time,
        events = {}
      }
    },
    [categories.bam] = {
      [elements.ba_status] = {
        flush_date = os_time,
        events = {}
      }
    }
  }

  -- link flush methods to their corresponding categories and elements
  self.flush = {
    [categories.neb] = {
      [elements.acknowledgement] = function (send_method) return self:flush_ack(send_method) end,
      [elements.downtime] = function (send_method) return self:flush_dt(send_method) end,
      [elements.host_status] = function (send_method) return self:flush_host(send_method) end,
      [elements.service_status] = function (send_method) return self:flush_service(send_method) end
    },
    [categories.bam] = {
      [elements.ba_status] = function (send_method) return self:flush_ba(send_method) end
    }
  }

  setmetatable(self, { __index = ScFlush })
  return self
end

--- flush_all_queues: tries to flush all kind of queues
-- @param send_method (function) the function from the stream connector that will send the data to the wanted tool
function ScFlush:flush_all_queues(send_method)
  self.sc_logger:debug("[sc_flush:flush_all_queues]: Starting to flush all queues")
  self:flush_ack(send_method)
  self:flush_dt(send_method)
  self:flush_host(send_method)
  self:flush_service(send_method)
  self:flush_ba(send_method)
  self.sc_logger:debug("[sc_flush:flush_all_queues]: All queues have been flushed")
end

--- flush_host: tries to flush the host queue
-- @param send_method (function) the function from the stream connector that will send the data to the wanted tool
function ScFlush:flush_host(send_method)
  local category = self.params.bbdo_info.host_status.category
  local element = self.params.bbdo_info.host_status.element

  -- flush the queue if possible
  if self.flush_queue(send_method, category, element) then
    self.reset_queue(category, element)
    return true
  else
    return false
  end
end

--- flush_host: tries to flush the service queue
-- @param send_method (function) the function from the stream connector that will send the data to the wanted tool
function ScFlush:flush_service(send_method)
  local category = self.params.bbdo_info.service_status.category
  local element = self.params.bbdo_info.service_status.element

  -- flush the queue if possible
  if self.flush_queue(send_method, category, element) then
    self.reset_queue(category, element)
    return true
  else
    return false
  end
end

--- flush_host: tries to flush the acknowledgement queue
-- @param send_method (function) the function from the stream connector that will send the data to the wanted tool
function ScFlush:flush_ack(send_method)
  local category = self.params.bbdo_info.acknowledgement.category
  local element = self.params.bbdo_info.acknowledgement.element

  -- flush the queue if possible
  if self.flush_queue(send_method, category, element) then
    self.reset_queue(category, element)
    return true
  else
    return false
  end
end

--- flush_host: tries to flush the downtime queue
-- @param send_method (function) the function from the stream connector that will send the data to the wanted tool
function ScFlush:flush_dt(send_method)
  local category = self.params.bbdo_info.downtime.category
  local element = self.params.bbdo_info.downtime.element

  -- flush the queue if possible
  if self.flush_queue(send_method, category, element) then
    self.reset_queue(category, element)
    return true
  else
    return false
  end
end

--- flush_host: tries to flush the BA queue
-- @param send_method (function) the function from the stream connector that will send the data to the wanted tool
function ScFlush:flush_ba(send_method)
  local category = self.params.bbdo_info.ba_status.category
  local element = self.params.bbdo_info.ba_status.element

  -- flush the queue if possible
  if self.flush_queue(send_method, category, element) then
    self.reset_queue(category, element)
    return true
  else
    return false
  end
end

--- flush_queue: flush a queue if requirements are met
-- @param send_method (function) the function from the stream connector that will send the data to the wanted tool
-- @param category (number) the category related to the queue
-- @param element (number) the element related to the queue
-- @return true|false (boolean) true if the queue is not flushed and true or false depending the send_method result 
function ScFlush:flush_queue(send_method, category, element)
  -- no events are stored in the queue
  if (#self.queue[category][element].events == 0) then
    self.sc_logger:debug("[sc_flush:flush_queue]: queue with category: " .. tostring(category) .. " and element: "
      .. tostring(element) .. " won't be flushed because there is no event stored in it.")
    return true
  end

  local rem = self.params.reverse_element_mapping;

  -- flush if events in the queue are too old or if the queue is full
  if (self.queue[category][element].flush_date > self.params.max_buffer_age)
    or (#self.queue[category][element].events > self.params.max_buffer_size) 
  then
    self.sc_logger:debug("sc_queue:flush_queue: flushing all the " .. rem[category][element] .. " events")
    local retval = send_method(self.queue[category][element].events, rem[category][element])
  else
    return true
  end

  return retval
end

--- reset_queue: put a queue back to its initial state after flushing its events
-- @param category (number) the category related to the queue
-- @param element (number) the element related to the queue
function ScFlush:reset_queue(category, element)
  self.queue[category][element].flush_date = os.time()
  self.queue[category][element].events = {}
end

return sc_flush