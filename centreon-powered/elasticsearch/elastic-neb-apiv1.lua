#!/usr/bin/lua
--------------------------------------------------------------------------------
-- Centreon Broker Elasticsearch Connector
-- Tested with versions
-- 7.1.1
--
-- References: 
-- https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-bulk.html
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Prerequisites:
-- You need an elasticsearch server
--      You can install one with docker:
--          docker pull elasticsearch
--          docker run -p 9200:9200 -p 9300:9300 -v $PWD:/var/lib/elasticsearch -d elasticsearch
-- You need to create two indices:
--      curl -X PUT "http://elasticsearch/centreon_metric" -H 'Content-Type: application/json'
--          -d '{"mappings":{"properties":{"host":{"type":"keyword"},"service":{"type":"keyword"},
--          "instance":{"type":"keyword"},"metric":{"type":"keyword"},"value":{"type":"double"},
--          "min":{"type":"double"},"max":{"type":"double"},"uom":{"type":"text"},
--          "type":{"type":"keyword"},"timestamp":{"type":"date","format":"epoch_second"}}}}'
--      curl -X PUT "http://elasticsearch/centreon_status" -H 'Content-Type: application/json'
--          -d '{"mappings":{"properties":{"host":{"type":"keyword"},"service":{"type":"keyword"},
--          "output":{"type":"text"},"status":{"type":"keyword"},"state":{"type":"keyword"},
--          "type":{"type":"keyword"},"timestamp":{"type":"date","format":"epoch_second"}}}}''
--
-- The Lua-socket and Lua-sec libraries are required by this script.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Access to the data:
--   curl "http://elasticsearch/centreon_status/_search?pretty"
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
-- EventQueue:flush method
-- Called when the max number of events or the max age are reached
--------------------------------------------------------------------------------

function EventQueue:flush()
    broker_log:info(3, "EventQueue:flush: Concatenating all the events as one string")
    local http_result_body = {}
    local url = self.http_server_protocol .. "://" .. self.http_server_address .. ":" .. self.http_server_port ..
        "/_bulk"
    local http_post_data = ""    
    for _, raw_event in ipairs(self.events) do
        if raw_event.status then
            http_post_data = http_post_data .. '{"index":{"_index":"' .. self.elastic_index_status .. '"}}\n' ..
                broker.json_encode(raw_event) .. '\n'
        end
        if raw_event.metric then
            http_post_data = http_post_data .. '{"index":{"_index":"' .. self.elastic_index_metric .. '"}}\n' ..
                broker.json_encode(raw_event) .. '\n'
        end
    end
    broker_log:info(2, "EventQueue:flush: HTTP POST url: \"" .. url .. "\"")
    for s in http_post_data:gmatch("[^\r\n]+") do
        broker_log:info(3, "EventQueue:flush: HTTP POST data:   " .. s .. "")
    end
    
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
            ["content-type"] = "application/x-ndjson",
            ["content-length"] = string.len(http_post_data),
            ["authorization"] = "Basic " .. (mime.b64(self.elastic_username .. ":" .. self.elastic_password))
        }
    }

    -- Handling the return code
    local retval = false
    if hr_code == 200 then
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

local function get_hostname(host_id)
    local hostname = broker_cache:get_hostname(host_id)
    if not hostname then
        broker_log:warning(1, "get_hostname: hostname for id " .. host_id ..
            " not found. Restarting centengine should fix this.")
        hostname = host_id
    end
    return hostname
end

local function get_service_description(host_id, service_id)
    local service = broker_cache:get_service_description(host_id, service_id)
    if not service then
        broker_log:warning(1, "get_service_description: service_description for id " .. host_id .. "." .. service_id ..
            " not found. Restarting centengine should fix this.")
        service = service_id
    end
    return service
end

function EventQueue:add(e)
    -- workaround https://github.com/centreon/centreon-broker/issues/201
    current_event = broker.json_encode(e)
    if current_event == previous_event then
        broker_log:info(3, "EventQueue:add: Duplicate event ignored.")
        return false
    end
    previous_event = current_event
    
    broker_log:info(3, "EventQueue:add: " .. current_event)
    
    local type = "host"
    local hostname = get_hostname(e.host_id)
    if hostname == e.host_id then
        if self.skip_anon_events == 1 then return false end
    end

    local service_description = ""
    if e.service_id then
        type = "service"
        service_description = get_service_description(e.host_id, e.service_id)
        if service_description == e.service_id then
            if self.skip_anon_events == 1 then return false end
        end
    end
    
    if string.match(self.filter_type, "status") then
        self.events[#self.events + 1] = {
            timestamp = e.last_check,
            host = hostname,
            service = service_description,
            output = string.match(e.output, "^(.*)\n"),
            status = e.state,
            state = e.state_type,
            type = type
        }
        broker_log:info(3, "EventQueue:add: entry #" .. #self.events .. " [type: status]: timestamp = " ..
            self.events[#self.events].timestamp)
        broker_log:info(3, "EventQueue:add: entry #" .. #self.events .. " [type: status]:      host = " ..
            self.events[#self.events].host)
        broker_log:info(3, "EventQueue:add: entry #" .. #self.events .. " [type: status]:   service = " ..
            self.events[#self.events].service)
        broker_log:info(3, "EventQueue:add: entry #" .. #self.events .. " [type: status]:    output = " ..
            self.events[#self.events].output)
        broker_log:info(3, "EventQueue:add: entry #" .. #self.events .. " [type: status]:    status = " ..
            self.events[#self.events].status)
        broker_log:info(3, "EventQueue:add: entry #" .. #self.events .. " [type: status]:     state = " ..
            self.events[#self.events].state)
    end
    if string.match(self.filter_type, "metric") then
        local perfdata, perfdata_err = broker.parse_perfdata(e.perfdata, true)
        if perfdata_err then
            broker_log:info(3, "EventQueue:add: No metric: " .. perfdata_err)
            return false
        end
        
        for m,v in pairs(perfdata) do
            local instance = string.match(m, "(.*)#.*")
            if not instance then
                instance = ""
            end

            local perfval = {
                value = "",
                min = "",
                max = "",
                uom = ""
            }
            for i,d in pairs(perfdata[m]) do
                perfval[i] = d
            end
            self.events[#self.events + 1] = {
                timestamp = e.last_check,
                host = hostname,
                service = service_description,
                instance = instance,
                metric = string.gsub(m, ".*#", ""),
                value = perfval.value,
                min = perfval.min,
                max = perfval.max,
                uom = perfval.uom,
                type = type
            }
            broker_log:info(3, "EventQueue:add: entry #" .. #self.events .. " [type: metric]: timestamp = " ..
                self.events[#self.events].timestamp)
            broker_log:info(3, "EventQueue:add: entry #" .. #self.events .. " [type: metric]:      host = " ..
                self.events[#self.events].host)
            broker_log:info(3, "EventQueue:add: entry #" .. #self.events .. " [type: metric]:   service = " ..
                self.events[#self.events].service)
            broker_log:info(3, "EventQueue:add: entry #" .. #self.events .. " [type: metric]:  instance = " ..
                self.events[#self.events].instance)
            broker_log:info(3, "EventQueue:add: entry #" .. #self.events .. " [type: metric]:    metric = " ..
                self.events[#self.events].metric)
            broker_log:info(3, "EventQueue:add: entry #" .. #self.events .. " [type: metric]:     value = " ..
                self.events[#self.events].value)
            broker_log:info(3, "EventQueue:add: entry #" .. #self.events .. " [type: metric]:       min = " ..
                self.events[#self.events].min)
            broker_log:info(3, "EventQueue:add: entry #" .. #self.events .. " [type: metric]:       max = " ..
                self.events[#self.events].max)
            broker_log:info(3, "EventQueue:add: entry #" .. #self.events .. " [type: metric]:       uom = " ..
                self.events[#self.events].uom)
        end
    end

    -- then we check whether it is time to send the events to the receiver and flush
    if #self.events >= self.max_buffer_size then
        broker_log:info(2, "EventQueue:add: flushing because buffer size reached " .. self.max_buffer_size ..
            " elements.")
        local retval = self:flush()
        return retval
    elseif os.time() - self.__internal_ts_last_flush >= self.max_buffer_age then
        if #self.events > 0 then
            broker_log:info(2, "EventQueue:add: flushing " .. #self.events .. " elements because buffer age reached " ..
                (os.time() - self.__internal_ts_last_flush) .. "s and max age is " .. self.max_buffer_age .. "s.")
            local retval = self:flush()
            return retval
        end
        return false
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
        http_server_address     = "",
        http_server_port        = 9200,
        http_server_protocol    = "http",
        http_timeout            = 5,
        elastic_username        = "",
        elastic_password        = "",
        elastic_index_metric    = "centreon_metric",
        elastic_index_status    = "centreon_status",
        filter_type             = "metric,status",
        max_buffer_size         = 5000,
        max_buffer_age          = 30,
        log_level               = 0, -- already proceeded in init function
        log_path                = "", -- already proceeded in init function
        skip_anon_events        = 1
    }
    for i,v in pairs(conf) do
        if retval[i] then
            retval[i] = v
            if i == "elastic_password" then
                v = string.gsub(v, ".", "*")
            end
            broker_log:info(1, "EventQueue.new: getting parameter " .. i .. " => " .. v)
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
    local log_path = "/var/log/centreon-broker/stream-connector-elastic-neb.log"
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
-- return true if category NEB and elements Host or Service
-- return false otherwise
function filter(category, element)
    return category == 1 and (element == 14 or element == 24)
end
