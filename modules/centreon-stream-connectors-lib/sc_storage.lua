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
    "metric_.*",
    "downtime_host_%d+",
    "downtime_service_%d+_%d+"
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
  self:init_memory()
  return self
end

--- init_memory: create and populate the self.memory table that is able to interact with the persistent storage when updated
function ScStorage:init_memory()

  self:create_memory()

  -- load host properties in memory table
  self:set_memory("host", self.params.load_host_properties_from_storage)

  -- load service properties in memory table
  self:set_memory("service", self.params.load_service_properties_from_storage)

  -- load BA properties in memory table
  self:set_memory("ba", self.params.load_ba_properties_from_storage)

  -- load metric properties in memory table
  self:set_memory("metric", self.params.load_metric_properties_from_storage)
end

--- create_memory: create the self.memory table and add meta tables to it
function ScStorage:create_memory()
  -- prepare the "magic table". It is a table to store data in memory. 
  -- But when you set/delete values from it, it will also set/delete from the persistent storage
  -- when you get values, if it is not found in the memory table, it will search it in the persistent storage 
  self.memory = {} -- this is a proxy table, the one that will be used by users, it will not store data. This is needed to be able to updates values
  self.internal_memory = {} -- this is the table that will store all the data

  -- the meta table for your storage_objects that are going to be subtables of the memory table: 
  local object_meta = {
    -- this meta table function gets data from the persistent storage when not found in memory 
    __index = function (object_memory_table, property)
        -- try to find value in the real memory
      if self.internal_memory[object_memory_table._internal_object_id][property] then
        return self.internal_memory[object_memory_table._internal_object_id][property]
      end

      -- else try to find it in the persistent storage
      local status, value = self:get(object_memory_table._internal_object_id, property)
      return value
    end,
    -- this meta table function will delete/set the data in the persistent storage while also setting/deleting from the memory table
    __newindex = function (object_memory_table, property, value)
      if value == nil then
        self.internal_memory[object_memory_table._internal_object_id][property] = value --delete in real memory
        self:delete(object_memory_table._internal_object_id, property) -- delete in persistent
        return
      end

      self.internal_memory[object_memory_table._internal_object_id][property] = value --set in real memory
      self:set(object_memory_table._internal_object_id, property, value) -- set in persistent
    end
  }

  -- the meta table for the memory table. It is here to dynamically create storage_objects subtables and to link them with the object_meta meta table
  local memory_meta = {
    __newindex = function (memory_table, key, value)
      -- you can store whatever you want in the self.memory table. 
      -- but if the index is a valid storage_object it will assume that you want to create the magic between memory and persistent storage
      if self:is_valid_storage_object(key) then
        -- we need to create the storage_object subtable and link it to the appropriate meta table
        if not self.memory[key] then
          rawset(self.memory, key, {})
          setmetatable(self.memory[key], object_meta)
        end

        -- condition is either triggered on first storage_object memory creation or some weird code that someone is doing.
        if type(value) == "table" then
          -- need to add an internal property to the storage_object subtable that contains the storage_object ID otherwise we will never be able to get this information and communicate with the persistent storage backend
          rawset(self.memory[key], "_internal_object_id", key)
          self.internal_memory[key] = {} -- add object_id table to internal memory table
          
          -- at the moment, I can't find a way to make use of "multiple()" functions. So we can't bulk things. Therefore we loop through everything and it will do a set() action for each property
          for property, property_value in pairs(value) do
            self.memory[key][property] = property_value
          end
        end
      end
    end
  }
  setmetatable(self.memory, memory_meta)
end

--- set_memory: populate the self.memory table with data from the persistent storage.
-- @param object_type (string) the object_type from which properties are going to be retrieved. Object types can be host, service, ba, metric
-- @param properties_list (string) a coma-separated list of properties that must be retrieved from a given object
function ScStorage:set_memory(object_type, properties_list)
  local success, result
  local rawset = rawset -- we may have to use it a million time so let's try to improve perfs even if it is in the init phase

  if properties_list ~= "" then
    self.sc_logger:notice("[sc_storage:set_memory] init memory: start getting properties: " .. tostring(properties_list) .. " for object type: " .. tostring(object_type))
    success, result = self:get_properties_for_object_type(object_type, self.sc_common:split(properties_list))

    if success then
      for object_id, data in pairs(result) do
        if not self.memory[object_id] then
          self.memory[object_id] = {}
        end

        for property, value in pairs(data) do
          self.memory[object_id][property] = value
        end
      end
    end

    self.sc_logger:notice("[sc_storage:set_memory] init memory: finished getting properties for object type: " .. tostring(object_type))
  end
end

--- get_properties_for_object_type: retrieve every given properties for a given object type
-- @param object_type (string) the object type from which propertes are going to be retrieved. Object type can be host, service, ba, metric
-- @param object_properties (table) a list of properties that you want to retrieve from the given object type
-- @return (boolean) true if it worked, false otherwise
-- @return result (table) table with all results, an empty table if it failed (or if no object/properties were found)
function ScStorage:get_properties_for_object_type(object_type, object_properties)
  return self.storage_backend:get_properties_for_object_type(object_type, object_properties)
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
function ScStorage:show(object_id)
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