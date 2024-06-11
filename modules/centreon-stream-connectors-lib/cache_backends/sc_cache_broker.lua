---
-- a cache module that is using centreon broker
-- @module sc_cache_broker
-- @module sc_cache_broker

--[[

      THIS IS A CACHE MODULE SKELETON/PLACEHOLDER
      IT WILL LATER ON BE A REAL CACHE MECANISM.
      IT IS JUST HERE TO HAVE A FALLBACK FAKE CACHE SYSTEM WHILE THIS FEATURE IS DEPLOYED

]]--

local sc_cache_broker = {}
local ScCacheBroker = {}

function sc_cache_broker.new(common, logger, params)
  local self = {}

  self.sc_common = common
  self.sc_logger = logger
  self.params = params

  setmetatable(self, { __index = ScCacheBroker})
  return self
end


function ScCacheBroker:set(object_id, property, value)
  return true
end

function ScCacheBroker:set_multiple(object_id, properties)
  return true
end

function ScCacheBroker:get(object_id, property)
  return true, ""
end

function ScCacheBroker:get_multiple(object_id, properties)
  return true, {}
end

function ScCacheBroker:delete(object_id, property)
  return true
end

function ScCacheBroker:show(object_id)
  return true
end

function ScCacheBroker:clear()
  return true
end

return sc_cache_broker