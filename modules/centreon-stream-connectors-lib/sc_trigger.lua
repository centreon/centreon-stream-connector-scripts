---
-- Centreon stream connector Lua module to handle triggers
-- @module sc_trigger

local sc_trigger = {}
local ScTrigger = {}

function sc_trigger.new(params, sc_common, sc_logger)
  local self = {}

  self.params = params
  self.sc_common = sc_common
  self.sc_logger = sc_logger

  self.triggers = {
    ["sc_flush:flush_payload"] = {
      ["on-success"] = {
        trigger_function = false,
        _internal = {
          expected_return_type = "boolean",
          default_value = true
        }
      },
      ["on-fail"] = {
        trigger_function = false,
        _internal = {
          expected_return_type = "boolean",
          default_value = false
        }
      }
    }
  }

  setmetatable(self, { __index = ScTrigger})
  self:build_valid_trigger_categories()
    :build_valid_trigger_event_types()
    :execute_trigger_file()
  return self
end

function ScTrigger:execute_trigger_file()
  if not self.params.trigger_code then
    return self
  end

  local pcall_status, message = pcall(self.params.trigger_code, self)

  if not pcall_status then
    self.sc_logger:error("[sc_trigger:execute_trigger_file]: couldn't run trigger file Lua code. Error: " .. tostring(message))
  end

  self.sc_logger:notice("[sc_trigger:execute_trigger_file]: successfully executed trigger file Lua code")
  return self
end

--- build_valid_trigger_categories: create a table of all trigger categories that are set in the self.triggers table
-- @return self
function ScTrigger:build_valid_trigger_categories()
  local valid_categories = {}

  for category_name, category_data in pairs(self.triggers) do
    table.insert(valid_categories, category_name)
  end

  self.valid_categories = table.concat(valid_categories, ", ")

  return self
end

--- build_valid_trigger_event_types: create a table of all trigger event_type for each categories that are set in the self.triggers table
-- @return self
function ScTrigger:build_valid_trigger_event_types()
  local valid_event_types = {}

  for _, category_name in ipairs(self.valid_categories) do
    self.valid_event_types[category_name] = {}
    for event_type_name, event_type_data in pairs(self.triggers[category_name]) do
      table.insert(self.valid_event_types[category_name], event_type_name)
    end
  end

  self.valid_event_types = table.concat(valid_event_types, ", ")
  return self
end

--- register_trigger: register a trigger for later use
-- @param category (string) the trigger category
-- @param event_type (string) the trigger event type from the category
-- @param trigger_function (function) the function that is going to be fired
function ScTrigger:register_trigger(category, event_type, trigger_function)
  self.sc_logger:debug("[sc_trigger:register_trigger]: register trigger for category: " .. tostring(category) .. " and event type: " .. tostring(event_type))
  
  if not self.triggers[category] then
    self.sc_logger:error("[sc_trigger:register_trigger]: invalid trigger category: " .. tostring(category) .. ". Valid categories are: " .. self.valid_categories)
    return false
  end

  if not self.triggers[category][event_type] then
    self.sc_logger:error("[sc_trigger:register_trigger]: ivalid trigger event type: " .. tostring(event_type) 
      .. ". List of valid event type for category " .. tostring(category) .. ": " .. self.valid_event_types)
    return false
  end

  if type(trigger_function) ~= "function" then
    self.sc_logger:error("[sc_trigger:register_trigger]: provided trigger is not a Lua function")
    return false
  end

  self.triggers[category][event_type].trigger_function = trigger_function
  self.sc_logger:notice("[sc_trigger:register_trigger]: successfully registered a trigger for category: " .. tostring(category) .. " and event type: " .. tostring(event_type))
  return true
end

function ScTrigger:run_trigger(category, event_type, data)
  self.sc_logger:debug("[sc_trigger:run_trigger]: try to run trigger for category: " .. tostring(category) .. " and event type: " .. tostring(event_type))

  if not self.triggers[category] then
    self.sc_logger:error("[sc_trigger:run_trigger]: invalid trigger category: " .. tostring(category) .. ". Valid categories are: " .. self.valid_categories)
    return false
  end

  if not self.triggers[category][event_type] then
    self.sc_logger:error("[sc_trigger:run_trigger]: ivalid trigger event type: " .. tostring(event_type) 
      .. ". List of valid event type for category " .. tostring(category) .. ": " .. self.valid_event_types)
    return false
  end

  -- at that point, we know that there is an existing entry in the trigger table. Check if the is a default return value that we can use if something fails from now on
  local default_return_value = false
  if self.triggers[category][event_type].default_value ~= nil then
    default_return_value = self.triggers[category][event_type].default_value
  end

  if not self.triggers[category][event_type].trigger_function then
    self.sc_logger:debug("[sc_trigger:run_trigger]: no trigger registered for category: " .. tostring(category) .. " and event_type: " .. tostring(event_type))
    return default_return_value
  end

  local pcall_status, result = pcall(self.triggers[category][event_type].trigger_function, data)

  if not pcall_status then
    self.sc_logger:error("[sc_trigger:run_trigger]: error while running trigger " .. tostring(event_type) .. " from category: " .. tostring(category) .. ". Error message: " .. tostring(result))
    return default_return_value
  else
    return result
  end
end

return sc_trigger