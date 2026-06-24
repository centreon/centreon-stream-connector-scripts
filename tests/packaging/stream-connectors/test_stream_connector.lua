dofile("tests/packaging/mocks.lua")

local install_dir = "/usr/share/centreon-broker/lua"
local ok = true

local skipped = {
    -- LuaXML uses the Lua 5.1 API (luaL_register), not exported by lua5.3
    ["bsm_connector-apiv1.lua"] = "LuaXML incompatible with Lua 5.3+ (luaL_register undefined symbol)",
    -- init() calls getCanopsisAPI which concatenates canopsis_host without nil check
    ["canopsis2x-events-apiv2.lua"] = "requires canopsis_host config to initialize",
    -- requires C broker internal module 'ndo', not loadable outside centreon-broker
    ["ndo-output-apiv1.lua"] = "module 'ndo' is a C broker internal module",
    -- broker module, not a stream connector (no init/write)
    ["ndo-module-apiv1.lua"] = "broker module, not a stream connector",
    -- init() validates elastic-address as mandatory config
    ["elastic-metrics-apiv1.lua"] = "requires elastic-address config to initialize",
    -- init() concatenates http_server_url without nil check
    ["elastic-metrics-apiv2.lua"] = "requires http_server_url config to initialize",
    -- write() makes HTTP calls to nil URL (no config provided)
    ["elastic-neb-apiv1.lua"] = "write() requires real elasticsearch URL config",
    -- write() calls broker.parse_perfdata then makes HTTP calls to nil URL
    ["influxdb-neb-apiv1.lua"] = "write() requires real influxdb URL config",
    -- write() makes HTTP calls to nil URL (no config provided)
    ["influxdb-metrics-apiv1.lua"] = "write() requires real influxdb URL config",
    -- write() makes HTTP calls to nil URL (no config provided)
    ["splunk-states-http-apiv1.lua"] = "write() requires real splunk URL config",
    -- write() makes HTTP calls to nil URL (no config provided)
    ["prometheus-gateway-apiv1.lua"] = "write() requires real prometheus URL config",
    -- requires lua-crypto (needs libssl-dev to compile, not available in test env)
    ["bigquery-events-apiv2.lua"] = "module 'lua-crypto' requires libssl-dev to compile via luarocks",
}

local needs_install = {}

local handle = io.popen("find " .. install_dir .. " -maxdepth 1 -name '*.lua' -type f 2>/dev/null")
if not handle then
  print("Cannot list files in " .. install_dir)
  os.exit(1)
end

local files = {}
for filepath in handle:lines() do
  files[#files + 1] = filepath
end
handle:close()

if #files == 0 then
  print("No Lua files found in " .. install_dir)
  os.exit(1)
end

for _, filepath in ipairs(files) do
  local script = filepath:match("([^/]+)$")
  print("Testing " .. script .. " stream connector")
  if skipped[script] then
    print("⚠ " .. script .. ": skipped (" .. skipped[script] .. ")")
    goto continue
  end
  if needs_install[script] then
    local pkg = needs_install[script]
    local installed = os.execute("luarocks install " .. pkg .. " > /dev/null 2>&1")
    if not installed then
      print("⚠ " .. script .. ": could not install '" .. pkg .. "' via luarocks, skipping")
      ok = false
      goto continue
    end
  end
  -- Reset globals before each dofile to prevent cross-connector pollution
  init = nil
  write = nil
  local loaded, load_err = pcall(dofile, filepath)
  if not loaded then
    print("✗ " .. script .. ": load error: " .. tostring(load_err))
    ok = false
  elseif type(init) ~= "function" then
    print("✗ " .. script .. ": does not export a global 'init' function (got " .. type(init) .. ")")
    ok = false
  elseif type(write) ~= "function" then
    print("✗ " .. script .. ": does not export a global 'write' function (got " .. type(write) .. ")")
    ok = false
  else
    local inited, init_err = pcall(init, {logfile = "/tmp/test-packaging.log"})
    if not inited then
      print("✗ " .. script .. ": init() error: " .. tostring(init_err))
      ok = false
    else
      local wrote, write_err = pcall(write, {})
      if not wrote then
        print("✗ " .. script .. ": write() error: " .. tostring(write_err))
        ok = false
      else
        print("✓ " .. script)
      end
    end
  end
  ::continue::
end

if not ok then
  os.exit(1)
end
print("\nAll tests passed!")
