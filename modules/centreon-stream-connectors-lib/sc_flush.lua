#!/usr/bin/lua

--- 
--- Module that handles data queue for stream connectors
--- @module sc_flush
--- @alias sc_flush sc_flush
local sc_flush = {}

local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_common = require("centreon-stream-connectors-lib.sc_common")

local ScFlush = {}

--- Creates a new instance of the `sc_flush` module.
--- This constructor initializes the logger, common utilities, and data queues for the stream connector.
--- It also links event queues to their respective categories and elements based on the provided parameters.
--- @param params table The parameters table of the stream connector, containing configuration details.
--- @param logger sc_logger Optional. A `sc_logger` object for logging. If not provided, a default logger is created.
--- @return table Returns a new instance of the `sc_flush` module.
function sc_flush.new(params, logger)
  local self = {}

  -- Create a default logger if it is not provided
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

  -- Link event queues to their respective categories and elements
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

--- Adds specific metadata to a queue.
--- This function updates the metadata of a queue associated with a given category and element.
--- If the category or element is not accepted, it logs a warning and does not modify the queue.
--- @param category_id number The ID of the BBDO category.
--- @param element_id number The ID of the BBDO element.
--- @param metadata table A table containing metadata as key-value pairs to be added to the queue.
function ScFlush:add_queue_metadata(category_id, element_id, metadata)
  -- Check if the category exists in the queues
  if not self.queues[category_id] then
    self.sc_logger:warning("[ScFlush:add_queue_metadata]: can't add queue metadata for category: " .. self.params.reverse_category_mapping[category_id]
      .. " (id: " .. category_id .. ") and element: " .. self.params.reverse_element_mapping[category_id][element_id] .. " (id: " .. element_id .. ")."
      .. ". metadata name: " .. tostring(metadata_name) .. ", metadata value: " .. tostring(metadata_value)
      .. ". You need to accept this category with the parameter 'accepted_categories'.")
    return
  end

  -- Check if the element exists in the category
  if not self.queues[category_id][element_id] then
    self.sc_logger:warning("[ScFlush:add_queue_metadata]: can't add queue metadata for category: " .. self.params.reverse_category_mapping[category_id]
      .. " (id: " .. category_id .. ") and element: " .. self.params.reverse_element_mapping[category_id][element_id] .. " (id: " .. element_id .. ")."
      .. ". metadata name: " .. tostring(metadata_name) .. ", metadata value: " .. tostring(metadata_value)
      .. ". You need to accept this element with the parameter 'accepted_elements'.")
    return
  end

  -- Add metadata to the queue
  for metadata_name, metadata_value in pairs(metadata) do
    self.queues[category_id][element_id].queue_metadata[metadata_name] = metadata_value
  end
end

--- Flushes all queues according to the accepted elements.
--- This function determines whether to flush mixed or homogeneous payloads based on the `send_mixed_events` parameter.
--- After flushing, it resets all queues to their initial state.
--- @param build_payload_method function The function used to concatenate events into the payload.
--- @param send_method function The function used to send the payload to the desired tool.
--- @return boolean Returns `true` if all queues are successfully flushed, or `false` if an error occurs during the process.
function ScFlush:flush_all_queues(build_payload_method, send_method)
  -- Check if mixed events should be sent
  if self.params.send_mixed_events == 1 then
    -- Flush mixed payloads
    if not self:flush_mixed_payload(build_payload_method, send_method) then
      return false
    end
  else
    -- Flush homogeneous payloads
    if not self:flush_homogeneous_payload(build_payload_method, send_method) then
      return false
    end
  end

  -- Reset all queues after flushing
  self:reset_all_queues()
  return true
end

--- Resets all queues to their initial state after flushing their events.
--- This function iterates through all accepted elements and clears the events stored in their respective queues.
--- Additionally, it updates the timestamp of the last global flush to the current time.
function ScFlush:reset_all_queues()
  for _, element_info in pairs(self.params.accepted_elements_info) do
    self.queues[element_info.category_id][element_info.element_id].events = {}
  end

  self.last_global_flush = os.time()
end

--- Calculates the total number of events stored across all queues.
--- This function iterates through all accepted elements and sums up the number of events in their respective queues.
--- Additionally, it logs the size of each queue for debugging purposes.
--- @return number The total number of events stored in all queues.
function ScFlush:get_queues_size()
  local queues_size = 0

  -- Iterate through all accepted elements and sum up the number of events in their queues
  for _, element_info in pairs(self.params.accepted_elements_info) do
    queues_size = queues_size + #self.queues[element_info.category_id][element_info.element_id].events

    -- Log the size of each queue for debugging purposes
    self.sc_logger:debug("[sc_flush:get_queues_size]: size of queue for category " .. tostring(element_info.category_name)
      .. " and element: " .. tostring(element_info.element_name)
      .. " is: " .. tostring(#self.queues[element_info.category_id][element_info.element_id].events))
  end

  return queues_size
end

--- Flushes a payload containing various types of events (e.g., services mixed with hosts).
--- This function iterates through all queues, builds a payload for each event, and sends it using the provided methods.
--- If the maximum buffer size is reached, the payload is sent and reset before continuing.
--- Ensures that all queues are emptied to avoid broker retention issues.
--- @param build_payload_method function The function used to build the payload from events.
--- @param send_method function The function used to send the payload to the desired tool.
--- @return boolean Returns `true` if all events are successfully flushed, or `false` if an error occurs during the process.
function ScFlush:flush_mixed_payload(build_payload_method, send_method)
  local payload = nil
  local counter = 0

  -- Iterate through all queues
  for _, element_info in pairs(self.params.accepted_elements_info) do
    -- Retrieve events from queues
    for _, event in ipairs(self.queues[element_info.category_id][element_info.element_id].events) do
      -- Add event to the payload
      payload = build_payload_method(payload, event)
      counter = counter + 1

      -- Send events if the maximum buffer size is reached
      if counter >= self.params.max_buffer_size then
        if not self:flush_payload(send_method, payload, self.queues.global_queues_metadata) then
          return false
        end

        -- Reset payload and counter after sending events
        payload = nil
        counter = 0
      end
    end
  end

  -- Ensure all queues are emptied to avoid broker retention issues
  if not self:flush_payload(send_method, payload, self.queues.global_queues_metadata) then
    return false
  end

  -- All events have been sent successfully
  return true
end

--- Flushes a payload containing a single type of events (e.g., services only or hosts only).
--- This function iterates through all queues, builds a payload for each event, and sends it using the provided methods.
--- If the maximum buffer size is reached, the payload is sent and reset before continuing.
--- Ensures that no events are left in the queues after processing.
--- @param build_payload_method function The function used to build the payload from events.
--- @param send_method function The function used to send the payload to the desired tool.
--- @return boolean Returns `true` if all events are successfully flushed, or `false` if an error occurs during the process.
function ScFlush:flush_homogeneous_payload(build_payload_method, send_method)
  local counter = 0
  local payload = nil

  -- Iterate through all queues
  for _, element_info in pairs(self.params.accepted_elements_info) do
    -- Retrieve events from queues
    for _, event in ipairs(self.queues[element_info.category_id][element_info.element_id].events) do
      -- Add event to the payload
      payload = build_payload_method(payload, event)
      counter = counter + 1

      -- Send events if the maximum buffer size is reached
      if counter >= self.params.max_buffer_size then
        if not self:flush_payload(
          send_method,
          payload,
          self.queues[element_info.category_id][element_info.element_id].queue_metadata
        ) then
          return false
        end

        -- Reset payload and counter after sending events
        counter = 0
        payload = nil
      end
    end

    -- Ensure no events are left in the current queue
    if not self:flush_payload(
      send_method,
      payload,
      self.queues[element_info.category_id][element_info.element_id].queue_metadata
    ) then
      return false
    end

    -- Reset payload to avoid mixing events from different queues
    payload = nil
  end

  return true
end

--- Sends a given payload using the provided send function.
--- This function attempts to send the payload and its associated metadata using the `send_method`.
--- If the payload is empty or `nil`, it returns `true` to indicate no issues on the stream connector side.
--- Logs debug information about the sending attempt and errors if the operation fails.
--- @param send_method function The function used to send the payload.
--- @param payload any The data to be sent. Can be of any type.
--- @param metadata table Metadata associated with the payload.
--- @return boolean Returns `true` if the payload is successfully sent or if the payload is empty.
--- Returns `false` if an error occurs during the sending process.
function ScFlush:flush_payload(send_method, payload, metadata)
  -- When the payload doesn't exist or is empty, we just tell broker that everything is fine on the stream connector side
  if not payload or payload == "" then
    return true
  end

  -- Attempt to send the payload using the provided send method, protected by pcall
  local pcall_status, result = pcall(send_method, payload, metadata)

  -- Log debug information about the sending attempt
  self.sc_logger:debug("[sc_flush:flush_payload]: tried to send payload protected by pcall. Status: " .. tostring(pcall_status) .. ", Message: " .. tostring(result))

  -- Log an error and return false if the sending operation fails
  if not pcall_status then
    self.sc_logger:error("[sc_flush:flush_payload]: could not send payload because of an internal error. pcall status: " .. tostring(pcall_status) .. ", error message: " .. tostring(result))
    return false
  end

  -- Return the result of the sending operation
  return result
end
return sc_flush
