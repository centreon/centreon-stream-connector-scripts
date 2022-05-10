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

  -- create a default logger if it is not provided
  self.sc_logger = logger
  if not self.sc_logger then 
    self.sc_logger = sc_logger.new()
  end
  
  self.sc_common = common
  self.params = params
  self.sc_broker = broker

  local categories = self.params.bbdo.categories
  local elements = self.params.bbdo.elements

  -- store metric validation functions inside a table linked to category/element
  self.metric_validation = {
    [categories.neb.id] = {
      [elements.host.id] = function () return self:is_valid_host_metric_event() end,
      [elements.host_status.id] = function() return self:is_valid_host_metric_event() end,
      [elements.service.id] = function () return self:is_valid_service_metric_event() end,
      [elements.service_status.id] = function () return self:is_valid_service_metric_event() end
    },
    [categories.bam.id] = {
      [elements.kpi_event.id] = function () return self:is_valid_kpi_metric_event() end
    }
  }

-- open metric (prometheus) : metric name = [a-zA-Z0-9_:], labels [a-zA-Z0-9_] https://github.com/OpenObservability/OpenMetrics/blob/main/specification/OpenMetrics.md#protocol-negotiation
-- datadog : metric_name = [a-zA-Z0-9_.] https://docs.datadoghq.com/fr/metrics/custom_metrics/#naming-custom-metrics
-- dynatrace matric name [a-zA-Z0-9-_.] https://dynatrace.com/support/help/how-to-use-dynatrace/metrics/metric-ingestion/metric-ingestion-protocol#metric-key
-- metric 2.0 (carbon/grafite/grafana) [a-zA-Z0-9-_./]  http://metrics20.org/spec/ (see Data Model section)
-- splunk [^a-zA-Z0-9_]

  if self.params.metrics_name_custom_regex and self.params.metrics_name_custom_regex ~= "" then
    self.metrics_name_operations.custom.regex = self.params.metrics_custom_regex
  end

  if self.params.metrics_name_custom_replacement_character then
    self.metrics_name_operations.custom.replacement_character = self.params.metrics_name_custom_replacement_character
  end

  -- initiate metrics table 
  self.metrics = {}
  -- initiate sc_event object
  self.sc_event = sc_event.new(event, self.params, self.sc_common, self.sc_logger, self.sc_broker)

  setmetatable(self, { __index = ScMetrics })
  return self
end

--- is_valid_bbdo_element: checks if the event category and element are valid according to parameters and bbdo protocol
-- @return  true|false (boolean) depending on the validity of the event category and element
function ScMetrics:is_valid_bbdo_element()
  -- initiate variables with shorter name
  local categories = self.params.bbdo.categories
  local elements = self.params.bbdo.elements
  local event_category = self.sc_event.event.category
  local event_element = self.sc_event.event.element
  -- self.sc_logger:debug("[sc_metrics:is_valid_bbdo_element]: event cat: " .. tostring(event_category) .. ". Event element: " .. tostring(event_element))

  -- drop event if event category is not accepted
  if not self.sc_event:find_in_mapping(self.params.category_mapping, self.params.accepted_categories, event_category) then
    self.sc_logger:debug("[sc_metrics:is_valid_bbdo_element] event with category: " ..  tostring(event_category) .. " is not an accepted category")
    return false
  else
    -- drop event if accepted category is not supposed to be used for a metric stream connector
    if event_category ~= categories.neb.id and event_category ~= categories.bam.id then
      self.sc_logger:warning("[sc_metrics:is_valid_bbdo_element] Configuration error. accepted categories from paramters are: "
        .. tostring(self.params.accepted_categories) .. ". Only bam and neb can be used for metrics")
      return false
    else
      -- drop event if element is not accepted
      if not self.sc_event:find_in_mapping(self.params.element_mapping[event_category], self.params.accepted_elements, event_element) then
        self.sc_logger:debug("[sc_metrics:is_valid_bbdo_element] event with element: " ..  tostring(event_element) .. " is not an accepted element")
        return false
      else
        -- drop event if element is not an element that carries perfdata
        if event_element ~= elements.host_status.id
          and event_element ~= elements.service_status.id
          and event_element ~= elements.kpi_event.id
        then
          self.sc_logger:warning("[sc_metrics:is_valid_bbdo_element] Configuration error. accepted elements from paramters are: "
            .. tostring(self.params.accepted_elements) .. ". Only host_status, service_status and kpi_event can be used for metrics")
          return false
        end
      end
    end

    return true
  end
end

--- is_valid_metric_event: makes sure that the event is a valid event for metric usage
-- @return true|false (boolean) depending on the validity of the metric event
function ScMetrics:is_valid_metric_event()
  category = self.sc_event.event.category
  element = self.sc_event.event.element
  
  self.sc_logger:debug("[sc_metrics:is_valid_metric_event]: starting validation for event with category: "
    .. tostring(category) .. ". And element: " .. tostring(element))
  return self.metric_validation[category][element]()
end

--- is_valid_host_metric_event: makes sure that the metric and the event from the host are valid according to the stream connector parameters
-- @return true|false (boolean) depening on the validity of the event
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

  -- return false if there is no perfdata or it can't be parsed
  if not self:is_valid_perfdata(self.sc_event.event.perfdata) then
    self.sc_logger:warning("[sc_metrics:is_vaild_host_metric_event]: host_id: "
      .. tostring(self.sc_event.event.host_id) .. " is not sending valid perfdata. Received perfdata: " .. tostring(self.sc_event.event.perf_data))
    return false
  end

  return true
end

--- is_valid_host_metric_event: makes sure that the metric and the event from the service are valid according to the stream connector parameters
-- @return true|false (boolean) depening on the validity of the event
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

  -- return false if there is no perfdata or they it can't be parsed
  if not self:is_valid_perfdata(self.sc_event.event.perfdata) then
    self.sc_logger:warning("[sc_metrics:is_valid_service_metric_event]: service_id: "
      .. tostring(self.sc_event.event.service_id) .. " is not sending valid perfdata. Received perfdata: " .. tostring(self.sc_event.event.perfdata))
    return false
  end

  return true
end

--- is_valid_host_metric_event: makes sure that the metric and the event from the KPI are valid according to the stream connector parameters
-- @return true|false (boolean) depening on the validity of the event
function ScMetrics:is_valid_kpi_metric_event()
  if not self:is_valid_perfdata(self.sc_event.event.perfdata) then
    self.sc_logger:warning("[sc_metrics:is_vaild_kpi_metric_event]: kpi_id: "
      .. tostring(self.sc_event.event.kpi_id) .. " is not sending valid perfdata. Received perfdata: " .. tostring(self.sc_event.event.perf_data))
    return false
  end

  return true
end

--- is_valid_perfdata: makes sure that the perfdata string is a valid one
-- @param perfdata (string) a string that contains perfdata
-- @return true|false (boolean) depending on the validity of the perfdata
function ScMetrics:is_valid_perfdata(perfdata)
  -- drop event if perfdata is nil or empty
  if not perfdata or perfdata == "" then
    return false
  end

  -- parse perfdata
  local metrics_info, error = broker.parse_perfdata(perfdata, true)

  -- drop event if parsing failed
  if not metrics_info then
    self.sc_logger:error("[sc_metrics:is_valid_perfdata]: couldn't parse perfdata. Error is: "
      .. tostring(error) .. ". Perfdata string is: " .. tostring(perfdata))
    return false
  end

  -- store data from parsed perfdata inside a metrics table
  self.metrics_info = metrics_info

  return true
end

-- to name a few : 
-- open metric (prometheus) : metric name = [a-zA-Z0-9_:], labels [a-zA-Z0-9_] https://github.com/OpenObservability/OpenMetrics/blob/main/specification/OpenMetrics.md#protocol-negotiation
-- datadog : metric_name = [a-zA-Z0-9_.] https://docs.datadoghq.com/fr/metrics/custom_metrics/#naming-custom-metrics
-- dynatrace matric name [a-zA-Z0-9-_.] https://dynatrace.com/support/help/how-to-use-dynatrace/metrics/metric-ingestion/metric-ingestion-protocol#metric-key
-- metric 2.0 (carbon/grafite/grafana) [a-zA-Z0-9-_./]  http://metrics20.org/spec/ (see Data Model section)

--- build_metric: use the stream connector format method to parse every metric in the event
-- @param format_metric (function) the format method from the stream connector
function ScMetrics:build_metric(format_metric)
  local metrics_info = self.metrics_info
  self.sc_logger:debug("perfdata: " .. self.sc_common:dumper(metrics_info))

  for metric, metric_data in pairs(self.metrics_info) do
    metrics_info[metric].metric_name = string.gsub(metric_data.metric_name, self.params.metric_name_regex, self.params.metric_replacement_character)
    -- use stream connector method to format the metric event
    format_metric(metrics_info[metric])
  end
end

return sc_metrics