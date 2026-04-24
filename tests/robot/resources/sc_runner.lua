-- sc_runner.lua
-- Generic driver to run a stream connector outside of Centreon Broker.
--
-- Usage:
--   lua sc_runner.lua <connector.lua> <event.json> [key=value ...]
--
-- Special keys:
--   cache_file=<path>   JSON file with broker_cache fixture data
--
-- The connector always runs with send_data_test=1 (no real network call).
-- The payload logged by the connector appears on stdout as:
--   [NOTICE] [send_data]: <payload>

local script_dir = arg[0]:match("^(.*[/\\])") or "./"

-- load broker mock globals before anything else
dofile(script_dir .. "broker_mock.lua")

local connector_path = arg[1]
local event_file     = arg[2]

if not connector_path or not event_file then
  io.stderr:write("Usage: lua sc_runner.lua <connector.lua> <event.json> [key=value ...]\n")
  os.exit(1)
end

-- default config: test mode on, output to stdout.
-- max_buffer_size=0 forces flush() to trigger immediately (flush condition is
-- queues_size > max_buffer_size, so any non-empty queue will flush).
local conf = {
  send_data_test  = 1,
  log_level       = 1,
  logfile         = "/dev/stdout",
  max_buffer_size = 0,
}

-- parse key=value overrides from remaining args
for i = 3, #arg do
  local k, v = arg[i]:match("^(.-)=(.+)$")
  if k then
    conf[k] = tonumber(v) or v
  end
end

-- load broker_cache fixture if provided
if conf.cache_file then
  local f = io.open(conf.cache_file, "r")
  if f then
    _MOCK_CACHE = broker.json_decode(f:read("*a"))
    f:close()
    -- reload broker_mock so broker_cache picks up the new _MOCK_CACHE
    dofile(script_dir .. "broker_mock.lua")
  else
    io.stderr:write("[sc_runner] WARNING: cache_file not found: " .. conf.cache_file .. "\n")
  end
  conf.cache_file = nil
end

-- add the local modules path for running without the installed package
local repo_root = script_dir .. "../../../"
package.path = package.path
  .. ";" .. repo_root .. "modules/?.lua"
  .. ";" .. repo_root .. "modules/?/init.lua"

-- load event
local f = io.open(event_file, "r")
if not f then
  io.stderr:write("[sc_runner] ERROR: cannot open event file: " .. event_file .. "\n")
  os.exit(1)
end
local event = broker.json_decode(f:read("*a"))
f:close()

-- load and run the connector
dofile(connector_path)
init(conf)
write(event)
flush()
