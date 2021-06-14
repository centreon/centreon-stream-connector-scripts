#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker InfluxDB Connector
-- Tested with versions
-- 1.4.3
--
-- References: 
-- https://docs.influxdata.com/influxdb/v1.4/write_protocols/line_protocol_tutorial/
-- https://docs.influxdata.com/influxdb/v1.4/guides/writing_data/
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Prerequisites:
-- You need an influxdb server
--      You can install one with docker and these commands:
--          docker pull influxdb
--          docker run -p 8086:8086 -p 8083:8083 -v $PWD:/var/lib/influxdb -d  influxdb 
-- You need to create a database
-- curl  http://<influxdb-server>:8086/query --data-urlencode "q=CREATE DATABASE mydb"
--
-- The Lua-socket library is required by this script.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Access to the data:
-- curl -G 'http://<influxdb-server>:8086/query?pretty=true' --data-urlencode "db=mydb" --data-urlencode "q=SELECT * from Cpu"
--------------------------------------------------------------------------------


local http = require("socket.http")
local ltn12 = require("ltn12")

--------------------------------------------------------------------------------
-- event_queue class
--------------------------------------------------------------------------------

local event_queue = {
    __internal_ts_last_flush    = nil,
    http_server_address         = "",
    http_server_port            = 8086,
    http_server_protocol        = "http",
    events                      = {},
    influx_database             = "mydb",
    max_buffer_size             = 5000,
    max_buffer_age              = 5
}

-- Constructor: event_queue:new
function event_queue:new(o, conf)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    for i,v in pairs(conf) do
        if self[i] and i ~= "events" and string.sub(i, 1, 11) ~= "__internal_" then
            broker_log:info(1, "event_queue:new: getting parameter " .. i .. " => " .. v)
            self[i] = v
        else
            broker_log:warning(1, "event_queue:new: ignoring parameter " .. i .. " => " .. v)
        end
    end
    self.__internal_ts_last_flush = os.time()
    broker_log:info(2, "event_queue:new: setting the internal timestamp to " .. self.__internal_ts_last_flush)
    return o
end

-- Method: event_queue:flush
-- Called when the max number of events or when the max age of buffer is reached 
function event_queue:flush()
    broker_log:info(2, "event_queue:flush: Concatenating all the events as one string")
    --  we concatenate all the events
    local http_post_data = ""
    local http_result_body = {}
    for i, raw_event in ipairs(self.events) do
        http_post_data = http_post_data .. raw_event
    end
    broker_log:info(2, "event_queue:flush: HTTP POST request \"" .. self.http_server_protocol .. "://" .. self.http_server_address .. ":" .. self.http_server_port .. "/write?db=" .. self.influx_database .. "\"")
    broker_log:info(3, "event_queue:flush: HTTP POST data are: '" .. http_post_data .. "'")
    local hr_result, hr_code, hr_header, hr_s = http.request{
        url = self.http_server_protocol.."://"..self.http_server_address..":"..self.http_server_port.."/write?db="..self.influx_database,
        method = "POST",
        -- sink is where the request result's body will go
        sink = ltn12.sink.table(http_result_body),
        -- request body needs to be formatted as a LTN12 source
        source = ltn12.source.string(http_post_data),
        headers = { 
            -- mandatory for POST request with body
            ["content-length"] = string.len(http_post_data)
        }
    }
    -- Handling the return code
    if hr_code == 204 then
        broker_log:info(2, "event_queue:flush: HTTP POST request successful: return code is " .. hr_code)
    else
        broker_log:error(1, "event_queue:flush: HTTP POST request FAILED: return code is " .. hr_code)
        for i, v in ipairs(http_result_body) do
            broker_log:error(1, "event_queue:flush: HTTP POST request FAILED: message line " .. i ..  " is \"" .. v .. "\"")
        end
    end

    -- now that the data has been sent, we empty the events array
    self.events = {}
    -- and update the timestamp
    self.__internal_ts_last_flush = os.time()
end

-- Méthode event_queue:add
function event_queue:add(e)
    local metric = e.name
    -- time is a reserved word in influxDB so I rename it 
    if metric == "time" then
        metric = "_"..metric
    end
    -- retrieve objects names instead of IDs
    local host_name = broker_cache:get_hostname(e.host_id)
    local service_description = broker_cache:get_service_description(e.host_id, e.service_id)
    -- what if we could not get them from cache
    if not host_name then
        broker_log:warning(1, "event_queue:add: host_name for id " .. e.host_id .. " not found. Restarting centengine should fix this.")
        host_name = e.host_id
    end
    if not service_description then
        broker_log:warning(1, "event_queue:add: service_description for id " .. e.host_id .. "." .. e.service_id .. " not found. Restarting centengine should fix this.")
        service_description = e.service_id
    end
    -- we finally append the event to the events table
    broker_log:info(3, "event_queue:add: adding \"" .. service_description..",host="..host_name.." "..metric.."="..e.value.." "..e.ctime.."000000000\" to event list.")
    self.events[#self.events + 1] = service_description..",host="..host_name.." "..metric.."="..e.value.." "..e.ctime.."000000000\n"

    -- then we check whether it is time to send the events to the receiver and flush
    if #self.events >= self.max_buffer_size then
        broker_log:info(2, "event_queue:add: flushing because buffer size reached " .. self.max_buffer_size .. " elements.")
        self:flush()
        return true
    elseif os.time() - self.__internal_ts_last_flush >= self.max_buffer_age then
        broker_log:info(2, "event_queue:add: flushing " .. #self.events .. " elements because buffer age reached " .. (os.time() - self.__internal_ts_last_flush) .. "s and max age is " .. self.max_buffer_age .. "s.")
        self:flush()
        return true
    else
        return false
    end
end
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Required functions for Broker StreamConnector
--------------------------------------------------------------------------------

-- Fonction init()
function init(conf)
    broker_log:set_parameters(1, "/var/log/centreon-broker/stream-connector-influxdb.log")
    broker_log:info(2, "init: Beginning init() function")
    queue = event_queue:new(nil, conf)
    broker_log:info(2, "init: Ending init() function, Event queue created")
end

-- Fonction write()
function write(e)
    broker_log:info(3, "write: Beginning write() function")
    queue:add(e)
    broker_log:info(3, "write: Ending write() function\n")
    return true
end

-- Fonction filter()
-- return true if you want to handle this type of event (category, element)
-- return false if you want to ignore them
function filter(category, element)
    if category == 3 and element == 1 then 
        return true
    end
    return false
end
