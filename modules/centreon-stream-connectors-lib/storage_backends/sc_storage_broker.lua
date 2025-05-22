---
-- a storage module that is using centreon broker
-- @module sc_storage_broker
-- @module sc_storage_broker

--[[

      THIS IS A STORAGE MODULE SKELETON/PLACEHOLDER
      IT WILL LATER ON BE A REAL STORAGE MECANISM.
      IT IS JUST HERE TO HAVE A FALLBACK FAKE STORAGE SYSTEM WHILE THIS FEATURE IS DEPLOYED

]]--

local sc_storage_broker = {}
local ScStorageBroker = {}

function sc_storage_broker.new(common, logger, params)
  local self = {}

  self.sc_common = common
  self.sc_logger = logger
  self.params = params

  setmetatable(self, { __index = ScStorageBroker})
  return self
end


function ScStorageBroker:set(object_id, property, value)
  return true
end

function ScStorageBroker:set_multiple(object_id, properties)
  return true
end

function ScStorageBroker:get(object_id, property)
  return true, ""
end

function ScStorageBroker:get_multiple(object_id, properties)
  return true, {}
end

function ScStorageBroker:delete(object_id, property)
  return true
end

function ScStorageBroker:delete_multiple(object_id, properties)
  return true
end

function ScStorageBroker:show(object_id)
  return true
end

function ScStorageBroker:clear()
  return true
end

function ScStorageBroker:get_all_values_from_property(property)
  return true, {}
end

return sc_storage_broker