---
-- module to create and serve centreon cache for objetcs such as host configuration
-- @module sc_cache_engine
-- @module sc_cache_engine

local sc_cache_engine = {}
local ScCacheEngine = {}

function sc_cache_engine.new(params, sc_common, sc_logger)
  local self = {}

  self.params = params
  self.sc_logger = sc_logger
  self.sc_common = sc_common

  self.cache_type = {
    instance = { config = self.params.broker_module_json },
    host = { config = self.params.engine_host_cfg }
    -- service = { config = self.params.engine_service_cfg }

    -- "poller",
    -- "hostgroup",
    -- "servicegroup",
    -- "bv"
  }

  self.cache = {
    host = {},
    instance = {}
  }

  self.build_cache = {
    host = function (config_file) return self:build_host_cache(config_file) end,
    service = function (config_file) return self:build_service_cache(config_file) end,
    instance = function (config_file) return self:build_poller_cache(config_file) end
  }

  self.object_parsers = {
    host = {
      parse = function(host_info) self:parse_host(host_info) end
    }
  }

  setmetatable(self, { __index = ScCacheEngine})

  if not self:create_cache() then
    return false
  end

  self.sc_logger:notice(self.sc_common:dumper(self.cache))
  return self
end

function ScCacheEngine:parse_config_file(config_file, config_updater)
  local temp_table
  local object_type
  local file = io.open(config_file, "r")

  for line in file:lines() do
    if not line:match("^#") and line ~= '' then
      if line:match("^define") then
        object_type = line:match("define (%w+) {")
        temp_table = {}
      elseif line:match("^}") then
        if config_updater then
          for _, updater_function in ipairs(config_updater) do
            updater_function(temp_table)
          end
        end

        self.object_parsers[object_type].parse(temp_table)
      else
        local attribute_name, attribute_value= line:match("^%s+([%w_]+)%s+(.*)%s$")
        temp_table[attribute_name] = attribute_value
      end
    end
  end

  return temp_table
end


function ScCacheEngine:create_cache()
  for cache_type, info in pairs(self.cache_type) do
    if not self.build_cache[cache_type](info.config) then
      return false
    end
  end

  return true
end

function ScCacheEngine:build_host_cache(config_file) 

  local config_updater = {
    [1] = function (host) 
        host.host_id = host._HOST_ID
        host.instance_id = self.instance_id
        host.name = host.host_name
      end
  }

  self:parse_config_file(config_file, config_updater)

  return true
end

function ScCacheEngine:build_poller_cache(config_file) 
  local success, decoded_json = self.sc_common:load_json_file(config_file)
  
  if not success then
    self.sc_logger:error("[sc_cache_engine:build_poller_cache]: couldn't decode json file: " .. tostringc(config_file))
    return false
  end

  self.cache.instance[decoded_json.centreonBroker.poller_id] = {
    instance_id = decoded_json.centreonBroker.poller_id,
    instance_name = decoded_json.centreonBroker.poller_name
  }

  self.instance_id = decoded_json.centreonBroker.poller_id

  return true
end

function ScCacheEngine:parse_host(host_info)
  if host_info._HOST_ID then
    self.cache.host[host_info._HOST_ID] = host_info
  end
end




return sc_cache_engine