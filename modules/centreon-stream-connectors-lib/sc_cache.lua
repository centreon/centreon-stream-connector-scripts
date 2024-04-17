---
-- a wrapper to handle any cache system for stream connectors
-- @module sc_cache
-- @module sc_cache

local sc_cache = {}
local ScCache = {}

function sc_cache.new(logger, params)
  local self = {}

  self.sc_logger = logger
  self.params = params
  self.cache_objects = {
    "host_%d+",
    "service_%d+_%d+",
    "ba_%d+",
    "metric_.*"
  }

  if pcall(require, "centreon-stream-connectors-lib.cache_backends.sc_cache_" .. params.cache_backend) then
    local cache_backend = require("centreon-stream-connectors-lib.cache_backends.sc_cache_" .. params.cache_backend)
    self.cache_backend = cache_backend.new(logger, params)
  else
    self.sc_logger:error("[sc_cache:new]: Couldn't load cache backend: " .. tostring(params.cache_backend)
      .. ". Make sure that the file sc_cache_" .. tostring(params.cache_backend) .. ".lua exists on your server."
      .. " The stream connector is going to use the broker cache backend.")
    self.cache_backend = require("centreon-stream-connectors-lib.cache_backends.sc_cache_broker")
  end

  setmetatable(self, { __index = ScCache})
  return self
end

--- is_valid_cache_object: make sure that the object that needs an interraction with the cache is an object that can have cache
-- @param object_id (string) the object that must be checked
-- @return (boolean) true if valid, false otherwise
function is_valid_cache_object(object_id)
  for _, accepted_object_format in ipairs(self.cache_objects) do
    if string.match(object_id, accepted_object_format) then
      self.sc_logger:debug("[sc_cache:is_valid_cache_object]: object_id: "  .. tostring(object_id)
        .. " matched object format: " .. accepted_object_format) 
      return true
    end
  end

  self.sc_logger:error("[sc_cache:is_valid_cache_object]: object id: " .. tostring(object_id)
    .. " is not a valid object_id.")
  return false
end

--- set: set an object property in the cache
-- @param object_id (string) the object with the property that must be set
-- @param property (string) the name of the property
-- @param value (string|number|boolean) the value of the property
-- @return (boolean) true if value properly set in cache, false otherwise
function ScCache:set(object_id, property, value)
  if not is_valid_cache_object(object_id) then
    self.sc_logger:error("[sc_cache:set]: Object is invalid")
    return false
  end

  return self.cache_backend:set(object_id, property, value)
end

--- get: get an object property that is stored in the cache
-- @param object_id (string) the object with the property that must be retrieved
-- @param property (string) the name of the property
-- @return (boolean) true if value properly retrieved from cache, false otherwise
function ScCache:get(object_id, property)
  if not is_valid_cache_object(object_id) then
    self.sc_logger:error("[sc_cache:get]: Object is invalid")
    return false
  end

  return self.cache_backend:get(object_id, property)
end

--- delete: delete an object property in the cache
-- @param object_id (string) the object with the property that must be deleted
-- @param property (string) the name of the property
-- @return (boolean) true if value properly deleted in cache, false otherwise
function ScCache:delete(object_id, property)
  if not is_valid_cache_object(object_id) then
    self.sc_logger:error("[sc_cache:delete]: Object is invalid")
    return false
  end

  return self.cache_backend:delete(object_id, property)
end

--- show: show (in the log file) all stored properties of an object
-- @param object_id (string) the object with the property that must be shown
-- @return (boolean) true if object properties are retrieved, false otherwise
function ScCache:show(object_id, property)
  if not is_valid_cache_object(object_id) then
    self.sc_logger:error("[sc_cache:show]: Object is invalid")
    return false
  end

  return self.cache_backend:show(object_id)
end

--- clear: delete all stored information in cache
-- @return (boolean) true if cache has been deleted, false otherwise
function ScCache:clear()
  return self.cache_backend:clear()
end

--- TODO dump to extract the whole cache
return sc_cache