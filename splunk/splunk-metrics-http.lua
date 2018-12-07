#!/usr/bin/lua
local http = require("socket.http")
local ltn12 = require("ltn12")

--------------------------------------------------------------------------------
-- Classe event_queue
--------------------------------------------------------------------------------

local event_queue = {
        receiver_address    = "",
        receiver_port       = 8088,
        receiver_proto      = "http",
        splunk_sourcename   = "",
        splunk_sourcetype   = "",
        splunk_auth_var     = "",
        events              = {},
        buffer_size         = 50
}

-- Constructeur event_queue:new
function event_queue:new(o, conf)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    for i,v in pairs(conf) do
        broker_log:info(1, "event_queue:new: getting parameter " .. i .. " => " .. v)
        if self[i] and i ~= "events" then
            self[i] = v
        end
    end
    return o
end

-- Méthode event_queue:flush
function event_queue:flush()
    broker_log:info(2, "event_queue:flush: Concatenating all the events as one JSON string")
    --  we concatenate all the events as a serie of json objects separated by a whitespace
    local post_data = ""
    for i, json_event in ipairs(self.events) do
        post_data = post_data .. json_event
    end
    broker_log:info(2, "event_queue:flush: HTTP POST request \"" .. self.receiver_proto .. "://" .. self.receiver_address .. ":" .. self.receiver_port .. "/services/collector\"")
    broker_log:info(2, "event_queue:flush: HTTP POST data are: '" .. post_data .. "'")
    local hr_result, hr_code, hr_header, hr_s = http.request{
        url = self.receiver_proto .. "://" .. self.receiver_address .. ":" .. self.receiver_port .. "/services/collector",
        method = "POST",
        --sink = ltn12.sink.file("/dev/null"),                     -- sink is where the request result's body will go
        headers = { 
            ["Authorization"] = "Splunk " .. self.splunk_auth_var,      -- Splunk HTTP JSON API needs this header field to accept input
            ["content-length"] = string.len(post_data)                  -- mandatory for POST request with body
        },
        source = ltn12.source.string(post_data)                         -- request body needs to be formatted as a LTN12 source
    }
    if hr_code == 200 then
        broker_log:info(2, "event_queue:flush: HTTP POST request successful: return code is " .. hr_code)
    else
        broker_log:error(1, "event_queue:flush: HTTP POST request FAILED: return code is " .. hr_code)
    end

    -- now that the data has been sent, we flush the events array
    self.events = {}
end

-- Méthode event_queue:add
function event_queue:add(e)
    local splunk_event_data = {}
    local event_data = {
        metric                = e.name,
        value                 = e.value,
        ctime                 = e.ctime,
        host_name             = broker_cache:get_hostname(e.host_id),
        service_description   = broker_cache:get_service_description(e.host_id, e.service_id)
    }
    if not event_data.host_name then
        broker_log:warning(1, "event_queue:add: host_name for id " .. e.host_id .. " not found")
        event_data.host_name = e.host_id
    end
    if not event_data.service_description then
        broker_log:warning(1, "event_queue:add: service_description for id " .. e.host_id .. "." .. e.service_id .. " not found")
        event_data.service_description = e.service_id
    end
    splunk_event_data = {
        sourcetype      = self.splunk_sourcetype,
        source          = self.splunk_sourcename,
        time            = e.ctime,
        event           = event_data
    }
    local json_splunk_event_data = broker.json_encode(splunk_event_data)
    broker_log:info(3, "event_queue:add: Adding event #" .. #self.events)
    broker_log:info(3, "event_queue:add: event json: " .. json_splunk_event_data)
    self.events[#self.events + 1] = json_splunk_event_data

    if #self.events < self.buffer_size then
        return false
    else
        self:flush()
        return true
    end
end
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Fonctions requises pour Broker StreamConnector
--------------------------------------------------------------------------------

-- Fonction init()
function init(conf)
    broker_log:set_parameters(1, "/var/log/centreon-broker/stream-connector.log")
    broker_log:info(2, "init: Beginning init() function")
    queue = event_queue:new(nil, conf)
    broker_log:info(2, "init: Ending init() function, Event queue created")
end

-- Fonction write()
function write(e)
    broker_log:info(3, "write: Beginning write() function")
    queue:add(e)
    broker_log:info(3, "write: Ending write() function")
    return true
end

-- Fonction filter()
function filter(category, element)
    --broker_log:info(3, "category: ".. category .. " - element: " .. element)
    if category == 3 and element == 1 then 
        return true
    end
    return false
end
