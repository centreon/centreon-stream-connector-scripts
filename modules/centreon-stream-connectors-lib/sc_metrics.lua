#!/usr/bin/lua

--- 
-- Module that handles event metrics for stream connectors
-- @module sc_metrics
-- @alias sc_metrics
local sc_metrics = {}

local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_event = require("centreon-stream-connectors-lib.sc_event")
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_params = require("centreon-stream-connectors-lib.sc_params")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")

local ScMetrics = {}

--- sc_metrics.new: sc_metrics constructor
-- @param event (table) the current event
-- @param params (table) the params table of the stream connector
-- @param common (object) a sc_common instance
-- @param broker (object) a sc_broker instance
-- @param [opt] sc_logger (object) a sc_logger instance 
function sc_metrics.new(event, params, common, broker, logger)
  self = {}

  self.sc_logger = logger
  if not self.sc_logger then 
    self.sc_logger = sc_logger.new()
  end
  
  self.sc_common = common
  self.params = params
  self.sc_broker = broker

  local categories = self.params.bbdo.categories
  local elements = self.params.bbdo.elements

  self.metric_validation = {
    [categories.neb] = {
      [elements.host.element] = function () return self:is_valid_host_metric_event() end,
      [elements.host_status.element] = function() return self:is_valid_host_metric_event() end,
      [elements.service.element] = function () return self:is_valid_service_metric_event() end,
      [elements.service_status.element] = function () return self:is_valid_service_metric_event() end
    },
    [categories.bam] = {
      [elements.kpi_event.element] = function () return self:is_valid_kpi_metric_event() end
    }
  }

  self.metrics = {}

  self.sc_event = sc_event.new(event, self.params, self.sc_common, self.sc_logger, self.sc_broker)

  setmetatable(self, { __index = ScMetrics })
  return self
end

function ScMetrics:is_valid_bbdo_element()
-- drop event if wrong category
  local categories = self.params.bbdo.categories
  local elements = self.params.bbdo.elements

  local event_category = self.sc_event.event.category
  local event_element = self.sc_event.event.element

  -- drop event if event category is not accepted
  if not self.sc_event:find_in_mapping(categories, self.params.accepted_categories, event_category) then
    return false
  else
    -- drop event if accepted category is not supposed to be used for a metric stream connector
    if event_category ~= categories.neb and event_category ~= categories.bam then
      return false
    else
      -- drop event if element is not accepted
      if not self.sc_event:find_in_mapping(self.params.element_mapping[event_category], self.params.accepted_elements, event_element) then
        return false
      else
        -- drop event if element is not an element that carries perfdata
        if event_element ~= elements.host.element
          and event_element ~= elements.host_status.element
          and event_element ~= elements.service.element
          and event_element ~= elements.service_status.element
          and event_element ~= elements.kpi_event.element
        then
          return false
        end
      end
    end
  end

  function ScMetrics:is_valid_metric_event()
    category = self.sc_event.event.category
    element = self.sc_event.event.element
    
    return self.metric_validation[category][element]()
  end

  function ScMetrics:is_valid_host_metric_event()
    -- return false if we can't get hostname or host id is nil
    if not self.sc_event:is_valid_host() then
      self.sc_logger:warning("[sc_metrics:is_valid_host_metric_event]: host_id: " .. tostring(self.sc_event.event.host_id) .. " hasn't been validated")
      return false
    end

    -- return false if host is not monitored from an accepted poller
    if not self.sc_event:is_valid_poller() then
      self.sc_logger:warning("[sc_metrics:is_valid_host_metric_event]: host_id: " .. tostring(self.sc_event.event.host_id) .. " is not monitored from an accepted poller")
      return false
    end

    -- return false if host has not an accepted severity
    if not self.sc_event:is_valid_host_severity() then
      self.sc_logger:warning("[sc_metrics:is_valid_host_metric_event]: host_id: " .. tostring(self.sc_event.event.host_id) .. " has not an accepted severity")
      return false
    end

    -- return false if host is not in an accepted hostgroup
    if not self.sc_event:is_valid_hostgroup() then
      self.sc_logger:warning("[sc_metrics:is_valid_host_metric_event]: host_id: " .. tostring(self.sc_event.event.host_id) .. " is not in an accepted hostgroup")
      return false
    end

    if not self:is_valid_perfdata(self.sc_event.event.perf_data) then
      self.sc_logger:warning("[sc_metrics:is_vaild_host_metric_event]: host_id: "
        .. tostring(self.sc_event.event.host_id) .. " is not sending valid perfdata. Received perfdata: " .. tostring(self.sc_event.event.perf_data))
      return false
    end
  end

  function ScMetrics:is_valid_service_metric_event()
    -- return false if we can't get hostname or host id is nil
    if not self.sc_event:is_valid_host() then
      self.sc_logger:warning("[sc_metrics:is_valid_service_metric_event]: host_id: " .. tostring(self.sc_event.event.host_id) .. " hasn't been validated")
      return false
    end

    -- return false if we can't get service description of service id is nil
    if not self.sc_event:is_valid_service() then
      self.sc_logger:warning("[sc_metrics:is_valid_service_metric_event]: service with id: " .. tostring(self.sc_event.event.service_id) .. " hasn't been validated")
      return false
    end

    -- return false if host is not monitored from an accepted poller
    if not self.sc_event:is_valid_poller() then
      self.sc_logger:warning("[sc_metrics:is_valid_service_metric_event]: service id: " .. tostring(self.sc_event.event.service_id) 
        .. ". host_id: " .. tostring(self.sc_event.event.host_id) .. " is not monitored from an accepted poller")
      return false
    end

    -- return false if host has not an accepted severity
    if not self.sc_event:is_valid_host_severity() then
      self.sc_logger:warning("[sc_metrics:is_valid_service_metric_event]: service id: " .. tostring(self.sc_event.event.service_id) 
        .. ". host_id: " .. tostring(self.sc_event.event.host_id) .. ". Host has not an accepted severity")
      return false
    end

    -- return false if service has not an accepted severity
    if not self.sc_event:is_valid_service_severity() then
      self.sc_logger:warning("[sc_metrics:is_valid_service_metric_event]: service id: " .. tostring(self.sc_event.event.service_id) 
        .. ". host_id: " .. tostring(self.sc_event.event.host_id) .. ". Service has not an accepted severity")
      return false
    end

    -- return false if host is not in an accepted hostgroup
    if not self.sc_event:is_valid_hostgroup() then
      self.sc_logger:warning("[sc_metrics:is_valid_service_metric_event]: service_id: " .. tostring(self.sc_event.event.service_id) 
        .. " is not in an accepted hostgroup. Host ID is: " .. tostring(self.sc_event.event.host_id))
      return false
    end

    -- return false if service is not in an accepted servicegroup 
    if not self.sc_event:is_valid_servicegroup() then
      self.sc_logger:warning("[sc_metrics:is_valid_service_metric_event]: service_id: " .. tostring(self.sc_event.event.service_id) .. " is not in an accepted servicegroup")
      return false
    end

    if not self:is_valid_perfdata(self.sc_event.event.perf_data) then
      self.sc_logger:warning("[sc_metrics:is_vaild_service_metric_event]: service_id: "
        .. tostring(self.sc_event.event.service_id) .. " is not sending valid perfdata. Received perfdata: " .. tostring(self.sc_event.event.perf_data))
      return false
    end

    return true
  end

  function ScMetrics:is_valid_kpi_metric_event()
    if not self:is_valid_perfdata(self.sc_event.event.perfdata) then
      self.sc_logger:warning("[sc_metrics:is_vaild_kpi_metric_event]: kpi_id: "
        .. tostring(self.sc_event.event.kpi_id) .. " is not sending valid perfdata. Received perfdata: " .. tostring(self.sc_event.event.perf_data))
      return false
    end

    return true
  end

  function ScMetrics:is_valid_perfdata(perfdata)
    if not perfdata then
      return false
    end

    local metrics_info, error = broker.parse_perfdata(perfdata, true)

    if not metrics_info then
      self.sc_logger:error("[sc_metrics:is_valid_perfdata]: couldn't parse perfdata. Error is: "
        .. tostring(error) .. ". Perfdata string is: " .. tostring(perfdata))
      return false
    end

    for metric_name, metric_data in pairs(metrics_info) do
      self.metrics[metric_name] = metric_data
      self.metrics[metric_name].name = metric_name
    end

    return true
  end

  return true
end

return sc_metrics