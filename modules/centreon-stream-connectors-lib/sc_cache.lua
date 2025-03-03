---
-- a module to handle object cached data (such as host configuration)
-- @module sc_cache
-- @module sc_cache

local sc_cache = {}
local ScCache = {}

function sc_cache.new(params, sc_common, sc_logger)
  local self = {}

  self.sc_logger = sc_logger
  self.sc_common = sc_common
  self.params = params

  if pcall(require, "centreon-stream-connectors-lib.cache_sources.sc_cache_" .. self.params.cache_source) then
    local cache_source = require("centreon-stream-connectors-lib.cache_sources.sc_cache_" .. self.params.cache_source)
    self.cache_backend = cache_source.new(self.params, self.sc_common, self.sc_logger)
  else
    self.sc_logger:error("[sc_cache.new]: Couldn't load cache source: " .. tostring(self.params.cache_source)
      .. ". Make sure that the file sc_cache_" .. tostring(self.params.cache_source) .. ".lua exists on your server."
      .. " The stream connector is going to use the broker cache source.")
    local cache_source = require("centreon-stream-connectors-lib.cache_sources.sc_cache_broker")
    self.cache_backend = cache_source.new(self.params, self.sc_common, self.sc_logger)
  end

  setmetatable(self, { __index = ScCache})
  return self
end

--- get_hostgroups: retrieve hostgroups from host_id
-- @param host_id (number)
-- @return false (boolean) if host id is invalid or no hostgroup found
-- @return hostgroups (table) a table of all hostgroups for the host 
-- function ScScache:get_hostgroups(host_id)
--   return self.cache_source:get_hostgroups(host_id)
  -- return false if host id is invalid
  -- if host_id == nil or host_id == "" then 
  --   self.sc_logger:warning("[sc_broker:get_hostgroup]: host id is nil or empty")
  --   return false
  -- end

  -- -- get hostgroups
  -- local hostgroups = broker_cache:get_hostgroups(host_id)

  -- -- return false if no hostgroups were found
  -- if not hostgroups then
  --   return false
  -- end
  
  -- return hostgroups
-- end


return sc_cache