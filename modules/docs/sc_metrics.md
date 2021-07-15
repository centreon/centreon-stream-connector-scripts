# Documentation of the sc_flush module

- [Documentation of the sc_flush module](#documentation-of-the-sc_flush-module)
  - [Introduction](#introduction)
  - [Module initialization](#module-initialization)
    - [module constructor](#module-constructor)
    - [constructor: Example](#constructor-example)
  - [is_valid_bbdo_element method](#is_valid_bbdo_element-method)
    - [is_valid_bbdo_element: returns](#is_valid_bbdo_element-returns)
    - [is_valid_bbdo_element: example](#is_valid_bbdo_element-example)
  - [is_valid_metric_event method](#is_valid_metric_event-method)
    - [is_valid_metric_event: returns](#is_valid_metric_event-returns)
    - [is_valid_metric_event: example](#is_valid_metric_event-example)
  - [is_valid_host_metric_event method](#is_valid_host_metric_event-method)
    - [is_valid_host_metric_event: returns](#is_valid_host_metric_event-returns)
    - [is_valid_host_metric_event: example](#is_valid_host_metric_event-example)
  - [is_valid_service_metric_event method](#is_valid_service_metric_event-method)
    - [is_valid_service_metric_event: returns](#is_valid_service_metric_event-returns)
    - [is_valid_service_metric_event: example](#is_valid_service_metric_event-example)
  - [is_valid_kpi_metric_event method](#is_valid_kpi_metric_event-method)
    - [is_valid_kpi_metric_event: returns](#is_valid_kpi_metric_event-returns)
    - [is_valid_kpi_metric_event: example](#is_valid_kpi_metric_event-example)
  - [is_valid_perfdata method](#is_valid_perfdata-method)
    - [is_valid_perfdata parameters](#is_valid_perfdata-parameters)
    - [is_valid_perfdata: returns](#is_valid_perfdata-returns)
    - [is_valid_perfdata: example](#is_valid_perfdata-example)

## Introduction

The sc_metrics module provides methods to help you handle metrics for your stream connectors. It has been made in OOP (object oriented programming)

## Module initialization

Since this is OOP, it is required to initiate your module.

### module constructor

Constructor must be initialized with 5 parameters

- an event table
- a params table
- a sc_common instance
- a sc_broker instance
- a sc_logger instance (will create a new one with default parameters if not provided)

### constructor: Example

```lua
local event = {
  --- event data ---
}

  -- load module
local sc_param = require("centreon-stream-connectors-lib.sc_param")
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local sc_metrics = require("centreon-stream-connectors-lib.sc_metrics")

-- initiate "mandatory" information for the logger module
local logfile = "/var/log/test_param.log"
local severity = 1

-- create a new instance of the sc_logger module
local test_logger = sc_logger.new(logfile, severity)

-- create a new instance of the sc_common module
local test_common = sc_common.new(test_logger)

-- create a new instance of the sc_param module
local test_param = sc_param.new(test_common, test_logger)

-- create a new instance of the sc_broker module
local test_broker = sc_broker.new(test_logger)

-- create a new instance of the sc_event module
local test_metrics = sc_metrics.new(event, test_param.params, test_common, test_broker, test_logger)
```

## is_valid_bbdo_element method

The **is_valid_bbdo_element** method checks if the event is in an accepted category and is an appropriate element. It uses the [**accepted_elements and accepted_categories parameters**](sc_param.md#default_parameters) to validate an event. It also checks if the element is one that provides performance data (current list is: *host, service, host_status, service_status, kpi_event*)

head over the following chapters for more information

- [flush_queue](#flush_queue-method)

### is_valid_bbdo_element: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_bbdo_element: example

```lua
local result = test_metrics:is_valid_bbdo_element() 
--> result is true or false
```

## is_valid_metric_event method

The **is_valid_metric_event** method makes sure that the metric event is valid if it is a **host, service, service_status or kpi_event** event.

head over the following chapters for more information

- [is_valid_host_metric_event](#is_valid_host_metric_event-method)
- [is_valid_service_metric_event](#is_valid_service_metric_event-method)
- [is_valid_kpi_metric_event](#is_valid_kpi_metric_event-method)

### is_valid_metric_event: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_metric_event: example

```lua
local result = test_metrics:is_valid_metric_event()
--> result is true or false
```

## is_valid_host_metric_event method

The **is_valid_host_metric_event** method makes sure that the metric event is valid host metric event.

head over the following chapters for more information

- [is_valid_host](sc_event.md#is_valid_host-method)
- [is_valid_poller](sc_event.md#is_valid_poller-method)
- [is_valid_host_severity](sc_event.md#is_valid_host_severity-method)
- [is_valid_hostgroup](sc_event.md#is_valid_hostgroup-method)
- [is_valid_perfdata](#is_valid_perfdata-method)

### is_valid_host_metric_event: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_host_metric_event: example

```lua
local result = test_metrics:is_valid_host_metric_event()
--> result is true or false
```

## is_valid_service_metric_event method

The **is_valid_service_metric_event** method makes sure that the metric event is valid service metric event.

head over the following chapters for more information

- [is_valid_host](sc_event.md#is_valid_host-method)
- [is_valid_poller](sc_event.md#is_valid_poller-method)
- [is_valid_host_severity](sc_event.md#is_valid_host_severity-method)
- [is_valid_hostgroup](sc_event.md#is_valid_hostgroup-method)
- [is_valid_service](sc_event.md#is_valid_service-method)
- [is_valid_service_severity](sc_event.md#is_valid_service_severity-method)
- [is_valid_servicegroup](sc_event.md#is_valid_servicegroup-method)
- [is_valid_perfdata](#is_valid_perfdata-method)

### is_valid_service_metric_event: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_service_metric_event: example

```lua
local result = test_metrics:is_valid_service_metric_event()
--> result is true or false
```

## is_valid_kpi_metric_event method

The **is_valid_kpi_metric_event** method makes sure that the metric event is valid kpi metric event.

head over the following chapters for more information

- [is_valid_perfdata](#is_valid_perfdata-method)

### is_valid_kpi_metric_event: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_kpi_metric_event: example

```lua
local result = test_metrics:is_valid_kpi_metric_event()
--> result is true or false
```

## is_valid_perfdata method

The **is_valid_perfdata** method makes sure that the performance data is valid. Meaning that it is not empty and that it can be parsed. If the performance data is valid, it will store its information in a new table

### is_valid_perfdata parameters

| parameter                                     | type   | optional | default value |
| --------------------------------------------- | ------ | -------- | ------------- |
| the performance data that needs to be checked | string | no       |               |

### is_valid_perfdata: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_perfdata: example

```lua
local perfdata = "pl=45%;40;80;0;100"
local result = test_metrics:is_valid_perfdata()
--> result is true or false
--> test_metrics.metrics is now 
--[[
  test_metrics.metrics = {
    pl = {
      value = 45,
      uom = "%",
      min = 0,
      max = 100,
      warning_low = 0,
      warning_high = 40,
      warning_mode = false,
      critical_low = 0,
      critical_high = 80,
      critical_mode = false,
      name = "pl"
    }
  }
]]--
```
