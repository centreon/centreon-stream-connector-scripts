---
-- a wrapper to handle any cache system for stream connectors
-- @module sc_cache
-- @module sc_cache

local sc_cache = {}
local ScCache = {}

local sc_common = require("centreon-stream-connectors-lib.sc_common")

--- sc_cache.new: sc_cache constructor
-- @param common (object) a sc_common instance 
-- @param logger (object) a sc_logger instance 
-- @param params (table) the params table of the stream connector
function sc_cache.new(common, logger, params)
  local self = {}

  self.sc_common = common
  self.sc_logger = logger
  self.params = params

  -- list of lua patterns used to check if an object is a valid one
  self.cache_objects = {
    "host_%d+",
    "service_%d+_%d+",
    "ba_%d+",
    "metric_.*"
  }

  -- make sure we are able to load the desired cache backend. If not, fall back to the one provided by broker
  if pcall(require, "centreon-stream-connectors-lib.cache_backends.sc_cache_" .. params.cache_backend) then
    local cache_backend = require("centreon-stream-connectors-lib.cache_backends.sc_cache_" .. params.cache_backend)
    self.cache_backend = cache_backend.new(self.sc_common, logger, params)
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
function ScCache:is_valid_cache_object(object_id)
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
  if not self:is_valid_cache_object(object_id) then
    self.sc_logger:error("[sc_cache:set]: Object is invalid")
    return false
  end

  return self.cache_backend:set(object_id, property, value)
end

--- set_multiple: set multiple object properties in the cache
-- @param object_id (string) the object with the property that must be set
-- @param properties (table) a table of properties and their values
-- @param value (string|number|boolean) the value of the property
-- @return (boolean) true if value properly set in cache, false otherwise
function ScCache:set_multiple(object_id, properties)
  if not self:is_valid_cache_object(object_id) then
    self.sc_logger:error("[sc_cache:set_multiple]: Object is invalid")
    return false
  end

  if type(properties) ~= "table" then
    self.sc_logger:error("[sc_cache:set_multiple]: properties parameter is not a table"
      .. ". Received properties: " .. self.sc_common:dumper(properties))
    return false
  end

  return self.cache_backend:set_multiple(object_id, properties)
end

--- get: get an object property that is stored in the cache
-- @param object_id (string) the object with the property that must be retrieved
-- @param property (string) the name of the property
-- @return (boolean) true if value properly retrieved from cache, false otherwise
-- @return (string) empty string if status false, value otherwise
function ScCache:get(object_id, property)
  if not self:is_valid_cache_object(object_id) then
    self.sc_logger:error("[sc_cache:get]: Object is invalid")
    return false
  end

  local status, value = self.cache_backend:get(object_id, property)
  
  if not status then
    self.sc_logger:error("[sc_cache:get]: couldn't get property in cache. Object id: " .. tostring(object_id)
      .. ", property name: " .. tostring(property))
  end

  return status, value
end

--- get_multiple: retrieve a list of properties for an object
-- @param object_id (string) the object with the property that must be retrieved
-- @param properties (table) a list of properties
-- @return (boolean) true if value properly retrieved from cache, false otherwise
-- @return (table) empty table if status false, table of properties and their value otherwise
function ScCache:get_multiple(object_id, properties)
  if not self:is_valid_cache_object(object_id) then
    self.sc_logger:error("[sc_cache:get]: Object is invalid")
    return false
  end

  if type(properties) ~= "table" then
    self.sc_logger:error("[sc_cache:get_multiple]: properties parameter is not a table"
      .. ". Received properties: " .. self.sc_common:dumper(properties))
    return false
  end

  local status, value = self.cache_backend:get(object_id, properties)
  
  if not status then
    self.sc_logger:error("[sc_cache:get]: couldn't get property in cache. Object id: " .. tostring(object_id)
      .. ", property name: " .. self.sc_common:dumper(properties))
  end

  return status, value
end

--- delete: delete an object property in the cache
-- @param object_id (string) the object with the property that must be deleted
-- @param property (string) the name of the property
-- @return (boolean) true if value properly deleted in cache, false otherwise
function ScCache:delete(object_id, property)
  if not self:is_valid_cache_object(object_id) then
    self.sc_logger:error("[sc_cache:delete]: Object is invalid")
    return false
  end

  return self.cache_backend:delete(object_id, property)
end

--- show: show (in the log file) all stored properties of an object
-- @param object_id (string) the object with the property that must be shown
-- @return (boolean) true if object properties are retrieved, false otherwise
function ScCache:show(object_id, property)
  if not self:is_valid_cache_object(object_id) then
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