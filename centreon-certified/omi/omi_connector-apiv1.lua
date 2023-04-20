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
-- To work you need to provide to this script a Broker stream connector output configuration
-- with the following informations:
--
-- source_ci (string): Name of the transmiter, usually Centreon server name
-- ipaddr (string): the ip address of the operation connector server
-- url (string): url of the operation connector endpoint
-- logfile (string): the log file to use
-- loglevel (number): th log level (0, 1, 2, 3) where 3 is the maximum level
-- port (number): the operation connector server port
-- max_size (number): how many events to store before sending them to the server.
-- max_age (number): flush the events when the specified time (in second) is reach (even if max_size is not reach).

local http = require("socket.http")
local ltn12 = require("ltn12")

--default values overwrite if set in the GUI (Broker stream connector output configuration)
local my_data = {
  source_ci = "Centreon",
  ipaddr = "192.168.56.15",
  url = "/bsmc/rest/events/opscx-sdk/v1/",
  logfile = "/var/log/centreon-broker/omi_connector.log",
  loglevel = 2, --set log level (0, 1, 2, 3) where 3 is the maximum level
  port = 30005,
  max_size = 5,
  max_age = 60,
  flush_time = os.time(),
  data = {}
}

--initialization of parameters if set in the GUI
function init(conf)
  if conf.logfile then
    my_data.logfile = conf.logfile
  end
  if conf.loglevel then
    my_data.loglevel = conf.loglevel
  end
  if conf.ipaddr then
    my_data.ipaddr = conf.ipaddr
  end
  if conf.url then
    my_data.url = conf.url
  end
  if conf.port then
    my_data.port = conf.port
  end
  if conf.max_size then
    my_data.max_size = conf.max_size
  end
  if conf.max_age then
    my_data.max_age = conf.max_age
  end
  broker_log:set_parameters(my_data.loglevel, my_data.logfile)
  broker_log:info(2, "init values :" ..
                     " logfile = " .. my_data.logfile .. 
                     " loglevel = " .. my_data.loglevel ..
                     " ipaddr = " .. my_data.ipaddr ..
                     " url = " .. my_data.url ..
                     " port = " .. my_data.port ..
                     " max_size = " .. my_data.max_size ..
                     " max_age = " .. my_data.max_age .. "\n")
end

--called when max_size or max_age is reached
local function flush()
  if #my_data.data == 0 then
    broker_log:info(2, "No data to flush")
    my_data.flush_time = os.time()
    return true
  end
  local buf = table.concat(my_data.data, "\n")
  local respbody = {}
  local  body, code, headers, status = http.request {
    method = "POST",
    url = "https://" .. my_data.ipaddr .. ":" .. my_data.port .. my_data.url,
    source = ltn12.source.string(buf),
    headers =
             {
               ["Content-Type"] = "Content-Type:text/xml",
               ["content-length"] = string.len(buf)
             },
    sink = ltn12.sink.table(respbody)
  }
  if code == 200 then
    my_data.data = {}
    broker_log:info(2, "API connexion ok : " .. tostring(code) .. "\t" .. tostring(status))
    my_data.flush_time = os.time()
    return true
  else
    broker_log:error(0, "Could not reach API : " .. tostring(code))
    return false
  end
end

function write(d)
  -- Service status
  if d.category == 1 and d.element == 24 then
    broker_log:info(3, "write: " .. broker.json_encode(d))
    if d.host_id and d.service_id then
      local hostname = broker_cache:get_hostname(d.host_id)
      local service_desc = broker_cache:get_service_description(d.host_id,d.service_id)
      if not hostname or not service_desc then
        broker_log:error(2, "Unknown host id : " .. d.host_id .. " Try to restart centengine")
        return true
      end
      if d.state_type == 1 then --we keep only events in hard state
        broker_log:info(3, "HARD STATE")
        if d.last_hard_state_change then
          if math.abs(d.last_check - d.last_hard_state_change) < 10 then --we keep only events with a state that changed from the previous check
            if d.state == d.last_hard_state then
            broker_log:info(3, "STATE CHANGE")
            local reqbody = "<event_data>\t" .. 
                "<title>" .. service_desc .. "</title>\t" .. 
                "<description>" .. d.output .. "</description>\t" .. 
                "<severity>" .. d.state .. "</severity>\t" .. 
                "<time_created>" .. d.last_update .. "</time_created>\t" .. 
                "<node>" .. hostname .. "</node>\t" .. 
                "<related_ci>" .. hostname .. "</related_ci>\t" .. 
                "<source_ci>" .. my_data.source_ci .. "</source_ci>\t" .. 
                "<source_event_id>" .. d.service_id .. "</source_event_id>\t" .. 
                "</event_data>"
            table.insert(my_data.data, reqbody)
            end
          end
        end
      end
    end
  end
  if #my_data.data >= my_data.max_size or os.time() - my_data.flush_time >= my_data.max_age then
      broker_log:info(2, "max size or flush time is reached, flushing data")
      return flush()
  end
  return true
end

