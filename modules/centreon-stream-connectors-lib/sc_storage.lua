---
-- a wrapper to handle any storage system for stream connectors
-- @module sc_storage
-- @module sc_storage

local sc_storage = {}
local ScStorage = {}

local sc_common = require("centreon-stream-connectors-lib.sc_common")

--- sc_storage.new: sc_storage constructor
-- @param common (object) a sc_common instance 
-- @param logger (object) a sc_logger instance 
-- @param params (table) the params table of the stream connector
function sc_storage.new(common, logger, params)
  local self = {}

  self.sc_common = common
  self.sc_logger = logger
  self.params = params

  -- list of lua patterns used to check if an object is a valid one
  self.storage_objects = {
    "host_%d+",
    "service_%d+_%d+",
    "ba_%d+",
    "metric_.*"
  }

  -- make sure we are able to load the desired storage backend. If not, fall back to the one provided by broker
  if pcall(require, "centreon-stream-connectors-lib.storage_backends.sc_storage_" .. params.storage_backend) then
    local storage_backend = require("centreon-stream-connectors-lib.storage_backends.sc_storage_" .. params.storage_backend)
    self.storage_backend = storage_backend.new(self.sc_common, logger, params)
  else
    self.sc_logger:error("[sc_storage:new]: Couldn't load storage backend: " .. tostring(params.storage_backend)
      .. ". Make sure that the file sc_storage_" .. tostring(params.storage_backend) .. ".lua exists on your server."
      .. " The stream connector is going to use the broker storage backend.")
    self.storage_backend = require("centreon-stream-connectors-lib.storage_backends.sc_storage_broker")
  end

  setmetatable(self, { __index = ScStorage})
  return self
end

--- is_valid_storage_object: make sure that the object that needs an interraction with the storage is an object that can have storage
-- @param object_id (string) the object that must be checked
-- @return (boolean) true if valid, false otherwise
function ScStorage:is_valid_storage_object(object_id)
  for _, accepted_object_format in ipairs(self.storage_objects) do
    if string.match(object_id, accepted_object_format) then
      self.sc_logger:debug("[sc_storage:is_valid_storage_object]: object_id: "  .. tostring(object_id)
        .. " matched object format: " .. accepted_object_format) 
      return true
    end
  end

  self.sc_logger:error("[sc_storage:is_valid_storage_object]: object id: " .. tostring(object_id)
    .. " is not a valid object_id.")
  return false
end

--- set: set an object property in the storage
-- @param object_id (string) the object with the property that must be set
-- @param property (string) the name of the property
-- @param value (string|number|boolean) the value of the property
-- @return (boolean) true if value properly set in storage, false otherwise
function ScStorage:set(object_id, property, value)
  if not self:is_valid_storage_object(object_id) then
    self.sc_logger:error("[sc_storage:set]: Object is invalid")
    return false
  end

  return self.storage_backend:set(object_id, property, value)
end

--- set_multiple: set multiple object properties in the storage
-- @param object_id (string) the object with the property that must be set
-- @param properties (table) a table of properties and their values
-- @param value (string|number|boolean) the value of the property
-- @return (boolean) true if value properly set in storage, false otherwise
function ScStorage:set_multiple(object_id, properties)
  if not self:is_valid_storage_object(object_id) then
    self.sc_logger:error("[sc_storage:set_multiple]: Object is invalid")
    return false
  end

  if type(properties) ~= "table" then
    self.sc_logger:error("[sc_storage:set_multiple]: properties parameter is not a table"
      .. ". Received properties: " .. self.sc_common:dumper(properties))
    return false
  end

  return self.storage_backend:set_multiple(object_id, properties)
end

--- get: get an object property that is stored in the storage
-- @param object_id (string) the object with the property that must be retrieved
-- @param property (string) the name of the property
-- @return (boolean) true if value properly retrieved from storage, false otherwise
-- @return (string) empty string if status false, value otherwise
function ScStorage:get(object_id, property)
  if not self:is_valid_storage_object(object_id) then
    self.sc_logger:error("[sc_storage:get]: Object is invalid")
    return false
  end

  local status, value = self.storage_backend:get(object_id, property)
  
  if not status then
    self.sc_logger:error("[sc_storage:get]: couldn't get property in storage. Object id: " .. tostring(object_id)
      .. ", property name: " .. tostring(property))
  end

  return status, value
end

--- get_multiple: retrieve a list of properties for an object
-- @param object_id (string) the object with the property that must be retrieved
-- @param properties (table) a list of properties
-- @return (boolean) true if value properly retrieved from storage, false otherwise
-- @return (table) empty table if status false, table of properties and their value otherwise
function ScStorage:get_multiple(object_id, properties)
  if not self:is_valid_storage_object(object_id) then
    self.sc_logger:error("[sc_storage:get]: Object is invalid")
    return false
  end

  if type(properties) ~= "table" then
    self.sc_logger:error("[sc_storage:get_multiple]: properties parameter is not a table"
      .. ". Received properties: " .. self.sc_common:dumper(properties))
    return false
  end

  local status, value = self.storage_backend:get_multiple(object_id, properties)
  
  if not status then
    self.sc_logger:error("[sc_storage:get]: couldn't get property in storage. Object id: " .. tostring(object_id)
      .. ", property name: " .. self.sc_common:dumper(properties))
  end

  return status, value
end

--- delete: delete an object property in the storage
-- @param object_id (string) the object with the property that must be deleted
-- @param property (string) the name of the property
-- @return (boolean) true if value properly deleted in storage, false otherwise
function ScStorage:delete(object_id, property)
  if not self:is_valid_storage_object(object_id) then
    self.sc_logger:error("[sc_storage:delete]: Object is invalid")
    return false
  end

  return self.storage_backend:delete(object_id, property)
end

--- delete_multiple: delete an object properties in the storage
-- @param object_id (string) the object with the property that must be deleted
-- @param properties (table) a list of properties
-- @return (boolean) true if values properly deleted in storage, false otherwise
function ScStorage:delete_multiple(object_id, properties)
  if not self:is_valid_storage_object(object_id) then
    self.sc_logger:error("[sc_storage:delete]: Object is invalid")
    return false
  end

  if type(properties) ~= "table" then
    self.sc_logger:error("[sc_storage:delete_multiple]: properties parameter is not a table"
      .. ". Received properties: " .. self.sc_common:dumper(properties))
    return false
  end


  return self.storage_backend:delete_multiple(object_id, property)
end

--- show: show (in the log file) all stored properties of an object
-- @param object_id (string) the object with the property that must be shown
-- @return (boolean) true if object properties are retrieved, false otherwise
function ScStorage:show(object_id, property)
  if not self:is_valid_storage_object(object_id) then
    self.sc_logger:error("[sc_storage:show]: Object is invalid")
    return false
  end

  return self.storage_backend:show(object_id)
end

--- clear: delete all stored information in storage
-- @return (boolean) true if storage has been deleted, false otherwise
function ScStorage:clear()
  return self.storage_backend:clear()
end

--- TODO dump to extract the whole storage
return sc_storage