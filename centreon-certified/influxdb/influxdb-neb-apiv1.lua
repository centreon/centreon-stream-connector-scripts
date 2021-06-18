#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker InfluxDB Connector
-- Tested with versions
-- 1.4.3, 1.7.4, 1.7.6
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
--          docker run -p 8086:8086 -p 8083:8083 -v $PWD:/var/lib/influxdb -d influxdb
-- You need to create a database
-- curl  http://<influxdb-server>:8086/query --data-urlencode "q=CREATE DATABASE mydb"
-- You can eventually create a retention policy
--
-- The Lua-socket and Lua-sec libraries are required by this script.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Access to the data:
-- curl -G 'http://<influxdb-server>:8086/query?pretty=true' --data-urlencode "db=mydb" 
--  --data-urlencode "q=SELECT * from Cpu"
--------------------------------------------------------------------------------

local http = require("socket.http")
local https = require("ssl.https")
local ltn12 = require("ltn12")
local mime = require("mime")

--------------------------------------------------------------------------------
-- EventQueue class
--------------------------------------------------------------------------------

local EventQueue = {}
EventQueue.__index = EventQueue

--------------------------------------------------------------------------------
-- flush() method
-- Called when the max number of events or the max age are reached
--------------------------------------------------------------------------------

function EventQueue:flush()
    broker_log:info(3, "EventQueue:flush: Concatenating all the events as one string")
    --  we concatenate all the events
    local http_post_data = ""
    local http_result_body = {}
    for _, raw_event in ipairs(self.events) do
        http_post_data = http_post_data .. raw_event
    end
    local url = self.http_server_protocol .. "://" .. self.http_server_address .. ":" .. self.http_server_port ..
        "/write?db=" .. self.influx_database .. "&rp=" .. self.influx_retention_policy
    broker_log:info(2, "EventQueue:flush: HTTP POST request \"" .. url .. "\"")
    broker_log:info(3, "EventQueue:flush: HTTP POST data are: '" .. http_post_data .. "'")
    http.TIMEOUT = self.http_timeout
    local req
    if self.http_server_protocol == "http" then
        req = http
    else
        req = https
    end
    local hr_result, hr_code, hr_header, hr_s = req.request{
        url = url,
        method = "POST",
        -- sink is where the request result's body will go
        sink = ltn12.sink.table(http_result_body),
        -- request body needs to be formatted as a LTN12 source
        source = ltn12.source.string(http_post_data),
        headers = {
            -- mandatory for POST request with body
            ["content-length"] = string.len(http_post_data),
            ["authorization"] = "Basic " .. (mime.b64(self.influx_username .. ":" .. self.influx_password))
        }
    }
    -- Handling the return code
    local retval = false
    if hr_code == 204 then
        broker_log:info(2, "EventQueue:flush: HTTP POST request successful: return code is " .. hr_code)
        -- now that the data has been sent, we empty the events array
        self.events = {}
        retval = true
    else
        broker_log:error(1, "EventQueue:flush: HTTP POST request FAILED: return code is " .. hr_code)
        for i, v in ipairs(http_result_body) do
            broker_log:error(1, "EventQueue:flush: HTTP POST request FAILED: message line " .. i ..
                " is \"" .. v .. "\"")
        end
    end
    -- and update the timestamp
    self.__internal_ts_last_flush = os.time()
    return retval
end

--------------------------------------------------------------------------------
-- EventQueue:add method
-- @param e An event
--------------------------------------------------------------------------------

local previous_event = ""

function EventQueue:add(e)
    -- workaround https://github.com/centreon/centreon-broker/issues/201
    current_event = broker.json_encode(e)
    if current_event == previous_event then
        broker_log:info(3, "EventQueue:add: Duplicate event ignored.")
        return false
    end
    previous_event = current_event
    broker_log:info(3, "EventQueue:add: " .. current_event)
    -- let's get and verify we have perfdata
    local perfdata, perfdata_err = broker.parse_perfdata(e.perfdata)
    if perfdata_err then
        broker_log:info(3, "EventQueue:add: No metric: " .. perfdata_err)
        perfdata = {}
    end
    -- retrieve and store state for further processing
    if self.skip_events_state == 0 then
        perfdata["centreon.state"] = e.state
        perfdata["centreon.state_type"] = e.state_type
    elseif perfdata_err then
        return false
    end
    -- retrieve objects names instead of IDs
    local host_name = broker_cache:get_hostname(e.host_id)
    local service_description
    if e.service_id then
        service_description = broker_cache:get_service_description(e.host_id, e.service_id)
    else
        service_description = "host-latency"
    end
    -- what if we could not get them from cache
    if not host_name then
        broker_log:warning(1, "EventQueue:add: host_name for id " .. e.host_id ..
            " not found. Restarting centengine should fix this.")
        if self.skip_anon_events == 1 then
            return false
        end
        host_name = e.host_id
    end
    if not service_description then
        broker_log:warning(1, "EventQueue:add: service_description for id " .. e.host_id .. "." .. e.service_id ..
            " not found. Restarting centengine should fix this.")
        if self.skip_anon_events == 1 then
            return false
        end
        service_description = e.service_id
    end
    -- message format : <measurement>[,<tag-key>=<tag-value>...]
    --  <field-key>=<field-value>[,<field2-key>=<field2-value>...] [unix-nano-timestamp]
    -- some characters [ ,=] must be escaped, let's replace them by the replacement_character for better handling
    -- backslash at the end of a tag value is not supported, let's also replace it
    -- consider last space in service_description as a separator for an item tag
    local item = ""
    if string.find(service_description, " [^ ]+$") then
        item = string.gsub(service_description, ".* ", "", 1)
        item = ",item=" .. string.gsub(string.gsub(item, "[ ,=]", self.replacement_character), "\\$", self.replacement_character)
        service_description = string.gsub(service_description, " +[^ ]+$", "", 1)
    end
    service_description = string.gsub(string.gsub(service_description, "[ ,=]", self.replacement_character), "\\$", self.replacement_character)
    -- define messages from perfata, transforming instance names to inst tags, which leads to one message per instance
    -- consider new perfdata (dot-separated metric names) only (of course except for host-latency)
    local instances = {}
    local perfdate = e.last_check
    for m,v in pairs(perfdata) do
        local inst, metric = string.match(m, "(.+)#(.+)")
        if not inst then
            inst = ""
            metric = m
        else
            inst = ",inst=" .. string.gsub(string.gsub(inst, "[ ,=]", self.replacement_character), "\\$", self.replacement_character)
        end
        if (not e.service_id and metric ~= "time") or string.match(metric, ".+[.].+") then
            if not instances[inst] then
                instances[inst] = self.measurement .. service_description .. ",host=" .. host_name .. item .. inst .. " "
            end
            instances[inst] = instances[inst] .. metric .. "=" .. v .. ","
        elseif metric == "perfdate" then
            perfdate = v
        end
    end
    -- compute final messages to push
    for _,v in pairs(instances) do
        self.events[#self.events + 1] = v:sub(1, -2) .. " " .. perfdate .. "000000000" .. "\n"
        broker_log:info(3, "EventQueue:add: adding " .. self.events[#self.events]:sub(1, -2))
    end
    -- then we check whether it is time to send the events to the receiver and flush
    if #self.events >= self.max_buffer_size then
        broker_log:info(2, "EventQueue:add: flushing because buffer size reached " .. self.max_buffer_size ..
            " elements.")
        local retval = self:flush()
        return retval
    elseif os.time() - self.__internal_ts_last_flush >= self.max_buffer_age then
        broker_log:info(2, "EventQueue:add: flushing " .. #self.events .. " elements because buffer age reached " ..
            (os.time() - self.__internal_ts_last_flush) .. "s and max age is " .. self.max_buffer_age .. "s.")
        local retval = self:flush()
        return retval
    else
        return false
    end
end

--------------------------------------------------------------------------------
-- Constructor
-- @param conf The table given by the init() function and returned from the GUI
-- @return the new EventQueue
--------------------------------------------------------------------------------

function EventQueue.new(conf)
    local retval = {
        measurement                 = "",
        http_server_address         = "",
        http_server_port            = 8086,
        http_server_protocol        = "https",
        http_timeout                = 5,
        influx_database             = "mydb",
        influx_retention_policy     = "",
        influx_username             = "",
        influx_password             = "",
        max_buffer_size             = 5000,
        max_buffer_age              = 30,
        skip_anon_events            = 1,
        skip_events_state           = 0,
        replacement_character       = "_",
        log_level                   = 0, -- already proceeded in init function
        log_path                    = "" -- already proceeded in init function
    }
    for i,v in pairs(conf) do
        if retval[i] then
            retval[i] = v
            if i == "influx_password" then
                v = string.gsub(v, ".", "*")
            end
            broker_log:info(1, "EventQueue.new: getting parameter " .. i .. " => " .. v)
            if i == "measurement" then
                retval[i] = retval[i] .. ",service="
            end
        else
            broker_log:warning(1, "EventQueue.new: ignoring parameter " .. i .. " => " .. v)
        end
    end
    retval.__internal_ts_last_flush = os.time()
    retval.events = {},
    setmetatable(retval, EventQueue)
    -- Internal data initialization
    broker_log:info(2, "EventQueue.new: setting the internal timestamp to " .. retval.__internal_ts_last_flush)
    return retval
end

--------------------------------------------------------------------------------
-- Required functions for Broker StreamConnector
--------------------------------------------------------------------------------

local queue

-- Fonction init()
function init(conf)
    local log_level = 3
    local log_path = "/var/log/centreon-broker/stream-connector-influxdb-neb.log"
    for i,v in pairs(conf) do
        if i == "log_level" then
            log_level = v
        end
        if i == "log_path" then
            log_path = v
        end
    end
    broker_log:set_parameters(log_level, log_path)
    broker_log:info(2, "init: Beginning init() function")
    queue = EventQueue.new(conf)
    broker_log:info(2, "init: Ending init() function, Event queue created")
end

-- Fonction write()
function write(e)
    broker_log:info(3, "write: Beginning write() function")
    local retval = queue:add(e)
    broker_log:info(3, "write: Ending write() function, returning " .. tostring(retval))
    -- return true to ask broker to clear its cache, false otherwise
    return retval
end

-- Fonction filter()
-- return true if you want to handle this type of event (category, element) ; here category NEB and element
--  Host or Service
-- return false otherwise
function filter(category, element)
    return category == 1 and (element == 14 or element == 24)
end
