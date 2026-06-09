#!/bin/lua

local getopt = require("centreon-stream-connectors-lib.sc_getopt")
local json = require("centreon-stream-connectors-lib.sc_json")
local sc_webserver = require("centreon-stream-connectors-lib.sc_webserver")

local debug = false
local log_file = "/var/log/standalone_stream_connector.log"
local running_mode = "standalone"
local logger_backend = 'file'
local params

local append = false
local nonoptions = {}
local infile = io.input()
local sc_file

local usage = arg[-1] .. " " .. arg[0] .. [[
  You are using the stream connector standalone mode. This mode allow you to use stream connectors outside of the standard centreon-broker environment.
  Options :
   -s) the path to the stream connector that must be run (e.g: /usr/share/centreon-broker/lua/splunk-events-apiv2.lua)
   -l) [optional] the log file that is going to be used by the stream connector (default: /var/log/standalone_stream_connector.log)
   -d) [optional] when set, enable debug for the standalone script
   -m) [optional] execution mode, can be "standalone" or "standard", default is "standalone" (you should probably not use the standard mode when running this tool)
   -b) [optional] the logger backend that must be used (default: file)
   -p) [optional] They option can be optional but usually each stream connector has its set of mandatory params. If there is at least one mandatory params then you must use this option. json encoded list of params for the stream connector e.g: -p '{"http_server_url":"https://mysplunk.test.loal","splunk_token":"abcdef","send_data_test":1}'
]] .. arg[-1] .. " " .. arg[0] .. " -s /usr/share/centreon-broker/lua/splunk-events-apiv2.lua [-l /var/log/standalone_stream_connector.log] [-d] [-m standalone]"


for opt, arg in getopt(arg, 's:l:m:b:p:d', nonoptions) do
  if opt == 's' then
    sc_file = arg
  elseif opt == 'l' then
    log_file = arg
  elseif opt == 'd' then
    debug = true
  elseif opt == 'm' then
    running_mode = arg
  elseif opt == 'b' then
    logger_backend = arg
  elseif opt == 'p' then
    params = arg
  elseif opt == '?' then
    print('[ERROR]: unknown option: ' .. tostring(arg) .. ".\n " .. usage)
    os.exit(1)
  elseif opt == ':' then
    print('[ERROR]: missing argument: ' .. tostring(arg) .. ".\n " .. usage)
    os.exit(1)
  else
    print('[ERROR]: unknown error: ' .. tostring(arg) .. ".\n " .. usage)
    os.exit(1)
  end
end

-- useless ??
if #nonoptions == 1 then
  infile = io.open(nonoptions[1], 'r')
elseif #nonoptions > 1 then
  print('[ERROR]: wrong number of arguments: ' .. tostring(arg) .. ".\n " .. usage)
  os.exit(1)
end

if not sc_file then
  print('[ERROR]: no stream connector to load received. \n' .. usage)
  os.exit(1)
end

local stream_connector_init_params = {
  logfile = log_file,
  logger_backend = logger_backend,
  running_mode = running_mode
}

local stream_connector = assert(loadfile(sc_file))

if type(stream_connector) ~= "function" then
  print(tostring(stream_connector))
  os.exit(1)
end

stream_connector()

sc_params = json:decode(params)
for param_name, param_value in pairs(sc_params) do
  stream_connector_init_params[param_name] = param_value
end

-- create a global broker variable that we will use to override some very basic function normally provided by centreon-broker
broker = {
  bbdo_version = function () return '3.0.0' end,
  json_encode = function (t) return json:encode(t) end,
  json_decode = function (s) return json:decode(s) end
}

-- needs to be global otherwise you'll get this kind of error "attempt to index a nil value (upvalue 'queue')"
queue = EventQueue.new(stream_connector_init_params)

webserver = sc_webserver.new(queue.sc_params.params, queue.sc_logger, queue.sc_common)
local result, err = webserver:start()

queue.ws_counter = {
  counter = 1,
  counter_func = function ()
    queue.ws_counter.counter = queue.ws_counter.counter + 1
    return {
      status = 200, 
      status_text = "success", 
      body = '{"counter":' .. queue.ws_counter.counter .. '}', 
      content_type = "application/json"
    }
  end
}

queue.endpoint_callbacks = {
  events = function (http_data)
    queue.sc_logger:debug("[sc_standalone:endpoint_callback]: http data: " .. queue.sc_common:dumper(http_data))
    local success, data = pcall(json.decode, json, http_data.body) 
    
    -- list of events is not a valid json
    if not success then
      return {
        status = 400,
        status_text = "Bad Request",
        body = '{"error":"' .. tostring(data) .. '"}',
        content_type = "application/json"
      }
    end
    
    for index, event in ipairs(data) do
      success, data = pcall(write, event)

      if not success then
        return {
          status = 500,
          status_text = "Internal server error",
          body = '{"error":"' .. tostring(data) .. '"}',
          content_type = "application/json"
        }
      end
    end

    return {
      status = 200,
      status_text = "OK",
      body = '{"error":"","events":"' .. http_data.body .. '"}',
      content_type = "application/json"
    }
  end
}

webserver:add_post_route("/events", queue.endpoint_callbacks.events)

if not result then
  queue.sc_logger:error(err)
  os.exit(1)
end

-- webserver:stop()

while true do
  webserver:process()
end