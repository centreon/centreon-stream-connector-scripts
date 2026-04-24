-- broker_mock.lua
-- Mocks the Centreon Broker Lua API globals (broker_log, broker_cache, broker)
-- for running stream connectors outside of the broker process.

-- Stub cURL so connectors that require it at module level don't crash.
-- When send_data_test=1, connectors never call the cURL methods, so an
-- empty stub is enough. If a test ever needs real HTTP, replace this stub.
package.preload['cURL'] = function()
  local easy_mt = { __index = function(t, k)
    return function(self, ...) return self end
  end}
  return {
    easy = function() return setmetatable({}, easy_mt) end,
    OPT_TIMEOUT        = 0,
    OPT_SSL_VERIFYPEER = 0,
    OPT_HTTPHEADER     = 0,
    OPT_PROXY          = 0,
    OPT_PROXYUSERPWD   = 0,
    INFO_RESPONSE_CODE = 0,
  }
end

local json_ok, json = pcall(require, "cjson")
if not json_ok then
  error("lua-cjson is required. Install it with: apt-get install lua-cjson")
end

-- ============================================================
-- broker_log
-- All output goes to stdout so Robot Framework can capture it.
-- ============================================================
broker_log = {
  set_parameters = function(self, level, logfile) end,
  info    = function(self, level, msg) io.write("[INFO] "    .. tostring(msg) .. "\n") io.flush() end,
  warning = function(self, level, msg) io.write("[WARNING] " .. tostring(msg) .. "\n") io.flush() end,
  error   = function(self, level, msg) io.write("[ERROR] "   .. tostring(msg) .. "\n") io.flush() end,
  debug   = function(self, level, msg) io.write("[DEBUG] "   .. tostring(msg) .. "\n") io.flush() end,
  notice  = function(self, level, msg) io.write("[NOTICE] "  .. tostring(msg) .. "\n") io.flush() end,
}

-- ============================================================
-- broker
-- ============================================================

-- cjson on Lua 5.3 may decode JSON integers as floats (e.g. state=2 → 2.0).
-- tostring(2.0) = "2.0" ≠ "2", which breaks status comparisons in the library.
-- This function recursively converts float values that are exact integers back
-- to Lua integers, matching the behavior of the real Broker json_decode.
local function normalize_numbers(v)
  if type(v) == "number" then
    local i = math.tointeger(v)
    return i ~= nil and i or v
  elseif type(v) == "table" then
    local t = {}
    for k, val in pairs(v) do
      t[normalize_numbers(k)] = normalize_numbers(val)
    end
    return t
  end
  return v
end

broker = {
  json_encode = function(t)
    local ok, result = pcall(json.encode, t)
    return ok and result or "{}"
  end,
  json_decode = function(s)
    local ok, result = pcall(json.decode, s)
    return ok and normalize_numbers(result) or {}
  end,
  -- no broker.bbdo_version defined → sc_common defaults to BBDO v2
}

-- ============================================================
-- broker_cache
-- Data loaded from _MOCK_CACHE (set by sc_runner.lua from a fixture file).
-- Falls back to minimal valid defaults so connectors don't crash.
-- ============================================================
local _cache = _MOCK_CACHE or {}

broker_cache = {
  get_host = function(self, host_id)
    if _cache.hosts and _cache.hosts[tostring(host_id)] then
      return _cache.hosts[tostring(host_id)]
    end
    return {
      name = "mock-host-" .. tostring(host_id),
      alias = "mock-host-" .. tostring(host_id),
      address = "127.0.0.1",
      state = 0,
      state_type = 1,
      acknowledged = false,
      scheduled_downtime_depth = 0,
      instance_id = 1,
    }
  end,

  get_service = function(self, host_id, svc_id)
    local key = tostring(host_id) .. "_" .. tostring(svc_id)
    if _cache.services and _cache.services[key] then
      return _cache.services[key]
    end
    return {
      description = "mock-service-" .. tostring(svc_id),
      state = 0,
      state_type = 1,
      acknowledged = false,
      scheduled_downtime_depth = 0,
    }
  end,

  get_hostgroups = function(self, host_id)
    if _cache.hostgroups and _cache.hostgroups[tostring(host_id)] then
      return _cache.hostgroups[tostring(host_id)]
    end
    return {}
  end,

  get_servicegroups = function(self, host_id, svc_id)
    local key = tostring(host_id) .. "_" .. tostring(svc_id)
    if _cache.servicegroups and _cache.servicegroups[key] then
      return _cache.servicegroups[key]
    end
    return {}
  end,

  get_severity = function(self, host_id, svc_id)
    if svc_id then
      local key = tostring(host_id) .. "_" .. tostring(svc_id)
      return _cache.service_severities and _cache.service_severities[key] or nil
    end
    return _cache.host_severities and _cache.host_severities[tostring(host_id)] or nil
  end,

  get_instance = function(self, instance_id)
    if _cache.instances and _cache.instances[tostring(instance_id)] then
      return _cache.instances[tostring(instance_id)]
    end
    return { name = "mock-poller-" .. tostring(instance_id) }
  end,

  get_instance_name = function(self, instance_id)
    if _cache.instances and _cache.instances[tostring(instance_id)] then
      return _cache.instances[tostring(instance_id)].name
    end
    return "mock-poller-" .. tostring(instance_id)
  end,

  get_ba = function(self, ba_id)
    return _cache.bas and _cache.bas[tostring(ba_id)] or nil
  end,

  get_bv = function(self, bv_id)
    return _cache.bvs and _cache.bvs[tostring(bv_id)] or nil
  end,
}
