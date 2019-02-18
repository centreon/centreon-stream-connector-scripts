--
-- Copyright 2018 Centreon
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- For more information : contact@centreon.com
--
-- To work this script to provide a Broker stream connector output configuration
-- with the following informations:
-- ipaddr (string): the ip address of the Warp10 server
-- logfile (string): the log file
-- port (number): the Warp10 server port
-- token (string): the Warp10 write token
-- max_size (number): how many queries to store before sending them to the server.
--
local curl = require "cURL"

local my_data = {
  ipaddr = "172.17.0.1",
  logfile = "/tmp/test-warp10.log",
  port = 8080,
  token = "",
  max_size = 10,
  data = {}
}

function init(conf)
  if conf.logfile then
    my_data.logfile = conf.logfile
  end
  broker_log:set_parameters(3, my_data.logfile)
  if conf.ipaddr then
    my_data.ipaddr = conf.ipaddr
  end
  if conf.port then
    my_data.port = conf.port
  end
  if not conf.token then
    broker_log:error(0, "You must provide a token to write into Warp10")
  end
  my_data.token = conf.token
  if conf.max_size then
    my_data.max_size = conf.max_size
  end
end

local function flush()
  local buf = table.concat(my_data.data, "\n")
  local c = curl.easy{
    url = "http://" .. my_data.ipaddr .. ":" .. my_data.port .. "/api/v0/update",
    post = true,
    httpheader = {
      "Transfer-Encoding:chunked",
      "X-Warp10-Token:" .. my_data.token,
    },
    postfields = buf }

  c:perform()
  my_data.data = {}
  return true
end

function write(d)
  -- Service status
  if d.category == 1 and d.element == 24 then
    local pd = broker.parse_perfdata(d.perfdata)
    local host = broker_cache:get_hostname(d.host_id)
    local service = broker_cache:get_service_description(d.host_id, d.service_id)
    if not host or not service then
      broker_log:error(0, "You should restart engine to fill the cache")
      return true
    end
    for metric,v in pairs(pd) do
      local line = tostring(d.last_update) .. "000000// "
                     .. metric
                     .. "{" .. "host=" .. host
                             .. ",service=" .. service
                             .. "} "
                     .. tostring(v)
      table.insert(my_data.data, line)
      broker_log:info(0, "New line added to data: '" .. line .. "'")
    end
    if #my_data.data > my_data.max_size then
      broker_log:info(0, "Flushing data")
      return flush()
    end
  end
  return false
end
