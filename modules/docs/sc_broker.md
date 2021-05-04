# Documentation of the sc_broker module

- [Documentation of the sc_broker module](#documentation-of-the-sc_broker-module)
  - [Introduction](#introduction)
  - [Module initialization](#module-initialization)
    - [Module constructor](#module-constructor)
    - [constructor: Example](#constructor-example)
  - [get_host_all_infos method](#get_host_all_infos-method)
    - [get_host_all_infos: parameters](#get_host_all_infos-parameters)
    - [get_host_all_infos: returns](#get_host_all_infos-returns)
    - [get_host_all_infos: example](#get_host_all_infos-example)
  - [get_service_all_infos method](#get_service_all_infos-method)
    - [get_service_all_infos: parameters](#get_service_all_infos-parameters)
    - [get_service_all_infos: returns](#get_service_all_infos-returns)
    - [get_service_all_infos: example](#get_service_all_infos-example)
  - [get_host_infos method](#get_host_infos-method)
    - [get_host_infos: parameters](#get_host_infos-parameters)
    - [get_host_infos: returns](#get_host_infos-returns)
    - [get_host_infos: example](#get_host_infos-example)
  - [get_service_infos method](#get_service_infos-method)
    - [get_service_infos: parameters](#get_service_infos-parameters)
    - [get_service_infos: returns](#get_service_infos-returns)
    - [get_service_infos: example](#get_service_infos-example)
  - [get_hostgroups method](#get_hostgroups-method)
    - [get_hostgroups: parameters](#get_hostgroups-parameters)
    - [get_hostgroups: returns](#get_hostgroups-returns)
    - [get_hostgroups: example](#get_hostgroups-example)
  - [get_servicegroups method](#get_servicegroups-method)
    - [get_servicegroups: parameters](#get_servicegroups-parameters)
    - [get_servicegroups: returns](#get_servicegroups-returns)
    - [get_servicegroups: example](#get_servicegroups-example)
  - [get_severity method](#get_severity-method)
    - [get_severity: parameters](#get_severity-parameters)
    - [get_severity: returns](#get_severity-returns)
    - [get_severity: example](#get_severity-example)
  - [get_instance method](#get_instance-method)
    - [get_instance: parameters](#get_instance-parameters)
    - [get_instance: returns](#get_instance-returns)
    - [get_instance: example](#get_instance-example)
  - [get_ba_infos method](#get_ba_infos-method)
    - [get_ba_infos: parameters](#get_ba_infos-parameters)
    - [get_ba_infos: returns](#get_ba_infos-returns)
    - [get_ba_infos: example](#get_ba_infos-example)
  - [get_bvs_infos method](#get_bvs_infos-method)
    - [get_bvs_infos: parameters](#get_bvs_infos-parameters)
    - [get_bvs_infos: returns](#get_bvs_infos-returns)
    - [get_bvs_infos: example](#get_bvs_infos-example)

## Introduction

The sc_broker module provides wrapper methods for broker cache. It has been made in OOP (object oriented programming)

## Module initialization

Since this is OOP, it is required to initiate your module

### Module constructor

Constructor can be initialized with one parameter or it will use a default value.

- sc_logger. This is an instance of the sc_logger module

If you don't provider this parameter it will create a default sc_logger instance with default parameters ([sc_logger default params](./sc_logger.md#module-initialization))

### constructor: Example

```lua
-- load modules
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")

-- initiate "mandatory" informations for the logger module
local logfile = "/var/log/test_broker.log"
local severity = 1

-- create a new instance of the sc_logger module
local test_logger = sc_logger.new(logfile, severity)

-- create a new instance of the sc_common module
local test_broker = sc_broker.new(test_logger)
```

## get_host_all_infos method

The **get_host_all_infos** method returns all the broker cache information about a host using its ID

### get_host_all_infos: parameters

| parameter          | type   | optional | default value |
| ------------------ | ------ | -------- | ------------- |
| the ID of the host | number | no       |               |

### get_host_all_infos: returns

| return                                       | type    | always | condition                                   |
| -------------------------------------------- | ------- | ------ | ------------------------------------------- |
| a table with all cache information from host | table   | no     | host id must be found in broker cache       |
| false                                        | boolean | no     | if host id wasn't found in the broker cache |

### get_host_all_infos: example

```lua
local host_id = 2712

local result = test_broker:get_host_all_infos(host_id)

--[[
  --> result structure is: 
  {
    _type = 65548,
    acknowledged = false,
    acknowledgement_type = 0,
    action_url = "",
    active_checks = true,
    address = "10.30.2.85",
    alias = "NRPE",
    category = 1,
    check_attempt = 1,
    check_command = "base_host_alive",
    check_freshness = false,
    check_interval = 5,
    check_period = "24x7",
    check_type = 0,
    checked = true,
    default_active_checks = true,
    default_event_handler_enabled = true,
    default_flap_detection = true,
    default_notify = true,
    default_passive_checks = false,
    display_name = "NRPE",
    element = 12,
    enabled = true,
    event_handler = "",
    event_handler_enabled = true,
    execution_time = 0.002,
    first_notification_delay = 0,
    flap_detection = true,
    flap_detection_on_down = true,
    flap_detection_on_unreachable = true,
    flap_detection_on_up = true,
    flapping = false,
    freshness_threshold = 0,
    high_flap_threshold = 0,
    host_id = 2712,
    icon_image = "ppm/operatingsystems-linux-snmp-linux-128.png",
    icon_image_alt = "",
    instance_id = 1,
    last_check_value = 1619727378,
    last_hard_state = 0,
    last_hard_state_change = 1616086363,
    last_time_down = 1617692579,
    last_time_up = 1619727370,
    last_update = 1619727378,
    last_state_change = 1617692639,
    latency = 0.903,
    low_flap_threshold = 0, 
    max_check_attempts = 3,
    name = "NRPE",
    next_check = 1619727378,
    no_more_notification = false,
    notes = "",
    notes_url = "",
    notification_interval = 0,
    notification_number = 0,
    notification_period = "24x7",
    notify = true,
    notify_on_down = true,
    notify_on_downtime = true,
    notify_on_flapping = true,
    notify_on_recovery = true,
    notify_on_unreachable = true,
    passive_checks = false,
    percent_state_change = 0,
    perfdata = "rta=0,263ms;3000,000;5000,000;0; rtmax=0,263ms;;;; rtmin=0,263ms;;;; pl=0%;80;100;0;100",
    obsess_over_host = true,
    output = "OK - 10.30.2.85 rta 0,263ms lost 0%",
    retain_nonstatus_information = true,
    retain_status_information = true,
    retry_interval = 1,
    scheduled_downtime_depth = 0, 
    should_be_scheduled = true,
    stalk_on_down = false, 
    stalk_on_unreachable = false,
    stalk_on_up = false,
    state = 0,
    state_type = 1,
    statusmap_image = "",
    timezone = ""
  }

  --> result.output is "OK - 10.30.2.85 rta 0,263ms lost 0%"
--]]
```

## get_service_all_infos method

The **get_service_all_infos** method returns all the broker cache information about a service using its host and service ID

### get_service_all_infos: parameters

| parameter             | type   | optional | default value |
| --------------------- | ------ | -------- | ------------- |
| the ID of the host    | number | no       |               |
| the ID of the service | number | no       |               |

### get_service_all_infos: returns

| return                                          | type    | always | condition                                              |
| ----------------------------------------------- | ------- | ------ | ------------------------------------------------------ |
| a table with all cache information from service | table   | no     | host id and service id must be found in broker cache   |
| false                                           | boolean | no     | if host or service ID wasn't found in the broker cache |

### get_service_all_infos: example

```lua
local host_id = 2712
local service_id = 1991

local result = test_broker:get_service_all_infos(host_id, service_id)

--[[
  --> result structure is:
  {
    _type = 65559,
    action_url = "",
    acknowledged = false,
    acknowledgement_type = 0,
    active_checks = true,
    category = 1,
    check_attempt = 1,
    check_command = base_centreon_ping,
    check_freshness = false,
    check_interval = 5,
    check_period = 24x7,
    check_type = 0,
    checked = true,
    default_active_checks = true,
    default_event_handler_enabled = true,
    default_flap_detection = true,
    default_passive_checks = false,
    description = Ping,
    display_name = Ping,
    default_notify = true,
    element = 23,
    enabled = true,
    event_handler = "",
    event_handler_enabled = true,
    execution_time = 0.004,
    first_notification_delay = 0,
    flap_detection = true,
    flap_detection_on_critical = true,
    flap_detection_on_ok = true,
    flap_detection_on_unknown = true,
    flap_detection_on_warning = true,
    flapping = false,
    freshness_threshold = 0,
    high_flap_threshold = 0,
    host_id = 2712,
    icon_image = "",
    icon_image_alt = "",
    last_check = 1619730350,
    last_hard_state = 0,
    last_hard_state_change = 1609343081,
    last_state_change = 1609343081,
    last_time_critical = 1609342781,
    last_time_ok = 1619730350,
    last_update = 1619730437,
    latency = 0.76,
    low_flap_threshold = 0,
    max_check_attempts = 3,
    next_check = 1619730910,
    no_more_notifications = false,
    notes = "",
    notes_url = "",
    notification_interval = 0,
    notification_number = 0,
    notification_period = 24x7,
    notify = true,
    notify_on_critical = true,
    notify_on_downtime = true,
    notify_on_flapping = true,
    notify_on_recovery = true,
    notify_on_unknown = true,
    notify_on_warning = true,
    obsess_over_service = true,
    output = OK - 10.30.2.15 rta 0,110ms lost 0%
    passive_checks = false,
    percent_state_change = 0,
    perfdata = rta=0,110ms;200,000;400,000;0; rtmax=0,217ms;;;; rtmin=0,079ms;;;; pl=0%;20;50;0;100,
    retain_nonstatus_information = true,
    retain_status_information = true,
    retry_interval = 1,
    scheduled_downtime_depth = 0,
    service_id = 1991,
    should_be_scheduled = true,
    state_type = 1,
    stalk_on_critical = false,
    stalk_on_ok = false,
    stalk_on_unknown = false,
    stalk_on_warning = false,
    state = 0,
    volatile = false
  }

  --> result.output is: "OK - 10.30.2.15 rta 0,110ms lost 0%"
--]]
```

## get_host_infos method

The **get_host_infos** method returns asked information about a host from the broker cache using the host ID.

### get_host_infos: parameters

| parameter               | type            | optional | default value |
| ----------------------- | --------------- | -------- | ------------- |
| the ID of the host      | number          | no       |               |
| the desired information | string or table | no       |               |

### get_host_infos: returns

| return                                | type    | always | condition                  |
| ------------------------------------- | ------- | ------ | -------------------------- |
| a table with the desired informations | table   | no     | it must be a valid host id |
| false                                 | boolean | no     | if host ID is nil or empty |

### get_host_infos: example

```lua
local host_id = 2712
local desired_infos = {"retain_nonstatus_information", "obsess_over_host"}
-- if you want a single information you can also use = "retain_nonstatus_information" or {"retain_nonstatus_information"}

local result = test_broker:get_host_infos(host_id, desired_infos)

--[[
  --> result structure is: 
  {
    host_id = 2712,
    retain_nonstatus_information = false,
    obsess_over_host = true
  }

  --> result.obsess_over_host is: true
]]
```

## get_service_infos method

The **get_service_infos** method returns asked information about a service from the broker cache using the host and service ID.

### get_service_infos: parameters

| parameter               | type            | optional | default value |
| ----------------------- | --------------- | -------- | ------------- |
| the ID of the host      | number          | no       |               |
| the ID of the service   | number          | no       |               |
| the desired information | string or table | no       |               |

### get_service_infos: returns

| return                                | type    | always | condition                             |
| ------------------------------------- | ------- | ------ | ------------------------------------- |
| a table with the desired informations | table   | no     | it must be a valid host or service id |
| false                                 | boolean | no     | if host or service ID is nil or empty |

### get_service_infos: example

```lua
local host_id = 2712
local service_id = 1991
local desired_infos = {"description", "obsess_over_service"}
-- if you want a single information you can also use = "retain_nonstatus_information" or {"retain_nonstatus_information"}

local result = test_broker:get_host_infos(host_id, service_id, desired_infos)

--[[
  --> result structure is: 
  {
    host_id = 2712,
    service_id = 1991,
    description = "Ping",
    obsess_over_service = true
  }

  --> result.obsess_over_service is: true
]]
```

## get_hostgroups method

The **get_hostgroups** method retrieves hostgroups linked to a host from the broker cache using the host ID.

### get_hostgroups: parameters

| parameter          | type   | optional | default value |
| ------------------ | ------ | -------- | ------------- |
| the ID of the host | number | no       |               |

### get_hostgroups: returns

| return                                                     | type    | always | condition                                                        |
| ---------------------------------------------------------- | ------- | ------ | ---------------------------------------------------------------- |
| a table with all hostgroups information linked to the host | table   | no     | host id must have linked hostgroups found in broker cache        |
| false                                                      | boolean | no     | if host ID is invalid (empty or nil) or no hostgroups were found |

### get_hostgroups: example

***notice: to better understand the result, you need to know that, by convention, a table starts at index 1 in lua and not 0 like it is in most languages***

```lua
local host_id = 2712

local result = test_broker:get_hostgroups(host_id)

--[[
  --> result structure is:
  {
    [1] = {
      group_id = 2,
      group_name = "NetworkSecurity"
    },
    [2] = {
      group_id = 9,
      group_name = "Archimede_Sydney"
    }
  }

  --> result[2].group_name is: "Archimede_Sydney"
--]]
```

## get_servicegroups method

The **get_servicegroups** method retrieves servicegroups linked to a service from the broker cache using the host and service ID

### get_servicegroups: parameters

| parameter             | type   | optional | default value |
| --------------------- | ------ | -------- | ------------- |
| the ID of the host    | number | no       |               |
| the ID of the service | number | no       |               |

### get_servicegroups: returns

| return                                                           | type    | always | condition                                                                      |
| ---------------------------------------------------------------- | ------- | ------ | ------------------------------------------------------------------------------ |
| a table with all servicegroups information linked to the service | table   | no     | service must have linked servicegroups found in broker cache                   |
| false                                                            | boolean | no     | if host or service ID is invalid (empty or nil) or no servicegroups were found |

### get_servicegroups: example

***notice: to better understand the result, you need to know that, by convention, a table starts at index 1 in lua and not 0 like it is in most languages***

```lua
local host_id = 2712
local service_id = 1991

local result = test_broker:get_servicegroups(host_id, service_id)

--[[
  --> result structure is:
  {
    [1] = {
      group_id = 2,
      group_name = "Net_Services"
    },
    [2] = {
      group_id = 5,
      group_name = "Another_SG"
    }
  }

  --> result[2].group_name is: "Another_SG"
--]]
```

## get_severity method

The **get_severity** method retrieves the severity of a host or service from the broker cache using the ID of the service or host.

### get_severity: parameters

| parameter             | type   | optional | default value |
| --------------------- | ------ | -------- | ------------- |
| the ID of the host    | number | no       |               |
| the ID of the service | number | yes      |               |

### get_severity: returns

| return                                    | type    | always | condition                                                                |
| ----------------------------------------- | ------- | ------ | ------------------------------------------------------------------------ |
| the severity level of the host or service | number  | no     | service or host must have a severity found in broker cache               |
| false                                     | boolean | no     | if host or service ID is invalid (empty or nil) or no severity was found |

### get_severity: example

```lua
-- severity for a host
local host_id = 2712

local result = test_broker:get_severity(host_id)
--> result is: 2 

-- severity for a service
local service_id = 1991

result = test_broker:get_severity(host_id, service_id)
--> result is: 42
```

## get_instance method

The **get_instance** method returns the poller name using the instance ID.

### get_instance: parameters

| parameter              | type   | optional | default value |
| ---------------------- | ------ | -------- | ------------- |
| the ID of the instance | number | no       |               |

### get_instance: returns

| return          | type    | always | condition                                                                        |
| --------------- | ------- | ------ | -------------------------------------------------------------------------------- |
| the poller name | string  | no     | instance ID must be found in broker cache                                        |
| false           | boolean | no     | if instance ID is invalid (empty or nil) or ID was not found in the broker cache |

### get_instance: example

```lua
local instance_id = 2712

local result = test_broker:get_instance(instance_id)
--> result is: "awesome-poller"
```

## get_ba_infos method

The **get_ba_infos** method retrieves the name and description of a BA from the broker cache using its ID.

### get_ba_infos: parameters

| parameter        | type   | optional | default value |
| ---------------- | ------ | -------- | ------------- |
| the ID of the BA | number | no       |               |

### get_ba_infos: returns

| return                                          | type    | always | condition                                                                  |
| ----------------------------------------------- | ------- | ------ | -------------------------------------------------------------------------- |
| a table with the name and description of the BA | table   | no     | BA ID must be found in the broker cache                                    |
| false                                           | boolean | no     | if BA ID is invalid (empty or nil) or ID was not found in the broker cache |

### get_ba_infos: example

```lua
local ba_id = 2712

local result = test_broker:get_ba_infos(ba_id)
--[[
  --> result structure is: 
  {
    ba_id = 2712,
    ba_name = "awesome-BA",
    ba_description = "awesome-BA-description"
  }

  --> result.ba_name is: "awesome-BA"

--]]
```

## get_bvs_infos method

The **get_bvs_infos** method retrieves the name and description of all BVs linked to a BA from the broker cache.

### get_bvs_infos: parameters

| parameter        | type   | optional | default value |
| ---------------- | ------ | -------- | ------------- |
| the ID of the BA | number | no       |               |

### get_bvs_infos: returns

| return                                              | type    | always | condition                                                                   |
| --------------------------------------------------- | ------- | ------ | --------------------------------------------------------------------------- |
| a table with the name and description of all the BV | table   | no     | There must be BV found in the broker cache                                  |
| false                                               | boolean | no     | if BA ID is invalid (empty or nil) or no BVs were found in the broker cache |

### get_bvs_infos: example

***notice: to better understand the result, you need to know that, by convention, a table starts at index 1 in lua and not 0 like it is in most languages***

```lua
local ba_id = 2712

local result = test_broker:get_ba_infos(ba_id)
--[[
  --> result structure is: 
  {
    [1] = {
      bv_id = 9,
      bv_name = "awesome-BV",
      bv_description = "awesome-BV-description"
    },
    [2] = {
      bv_id = 33,
      bv_name = "another-BV",
      bv_description = "another-BV-description"
    }
  }
  
  --> result[2].bv_name is: "another-BV"
--]]
```
