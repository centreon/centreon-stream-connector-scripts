# Documentation of the sc_param module

- [Documentation of the sc_param module](#documentation-of-the-sc_param-module)
  - [Introduction](#introduction)
    - [Default parameters](#default-parameters)
  - [Module initialization](#module-initialization)
    - [module constructor](#module-constructor)
    - [constructor: Example](#constructor-example)
  - [param_override method](#param_override-method)
    - [param_override: parameters](#param_override-parameters)
    - [param_override: example](#param_override-example)
  - [check_params method](#check_params-method)
    - [check_params: example](#check_params-example)

## Introduction

The sc_param module provides methods to help you handle parameters for your stream connectors. It also provides a list of default parameters that are available for every stream connectors (the complete list is below). It has been made in OOP (object oriented programming)

### Default parameters

| Parameter name             | type   | default value                        | description                                                                                                                                                    | default scope                                                             | additionnal information                                                                                                                                                                                                                                                                      |
| -------------------------- | ------ | ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| accepted_categories        | string | neb,bam                              | each event is linked to a broker category that we can use to filter events                                                                                     |                                                                           | it is a coma separated list, can use "neb", "bam", "storage". Storage is deprecated, use "neb" to get metrics data [more information](https://docs.centreon.com/current/en/developer/developer-broker-bbdo.html#event-categories)                                                            |
| accepted_elements          | string | host_status,service_status,ba_status |                                                                                                                                                                | each event is linked to a broker element that we can use to filter events | it is a coma separated list, can use any type in the "neb", "bam" and "storage" tables [described here](https://docs.centreon.com/current/en/developer/developer-broker-bbdo.html#neb) (you must use lower case and replace blank space with underscore. "Host status" becomes "host_status") |
| host_status                | string | 0,1,2                                | coma separated list of accepted host status (0 = UP, 1 = DOWN, 2 = UNREACHABLE)                                                                                |                                                                           |                                                                                                                                                                                                                                                                                               |
| service_status             | string | 0,1,2,3                              | coma separated list of accepted services status (0 = OK, 1 = WARNING, 2 = CRITICAL, 3 = UNKNOWN)                                                               |                                                                           |                                                                                                                                                                                                                                                                                               |
| ba_status                  | string | 0,1,2                                | coma separated list of accepted BA status (0 = OK, 1 = WARNING, 2 = CRITICAL)                                                                                  |                                                                           |                                                                                                                                                                                                                                                                                               |
| hard_only                  | number | 1                                    | accept only events that are in a HARD state (use 0 to accept SOFT state too)                                                                                   | host_status(neb), service_status(neb)                                     |                                                                                                                                                                                                                                                                                               |
| acknowledged               | number | 0                                    | accept only events that aren't acknowledged (use 1 to accept acknowledged events too)                                                                          | host_status(neb), service_status(neb)                                     |                                                                                                                                                                                                                                                                                               |
| in_downtime                | number | 0                                    | accept only events that aren't in downtime (use 1 to accept events that are in downtime too)                                                                   | host_status(neb), service_status(neb), ba_status(bam)                     |                                                                                                                                                                                                                                                                                               |
| accepted_hostgroups        | string |                                      | coma separated list of hostgroups that are accepted (for example: my_hostgroup_1,my_hostgroup_2)                                                               | host_status(neb), service_status(neb)                                     |                                                                                                                                                                                                                                                                                               |
| accepted_servicegroups     | string |                                      | coma separated list of servicegroups that are accepted (for example: my_servicegroup_1,my_servicegroup_2)                                                      | service_status(neb)                                                       |                                                                                                                                                                                                                                                                                               |
| accepted_bvs               | string |                                      | coma separated list of BVs that are accepted (for example: my_bv_1,my_bv_2)                                                                                    | ba_status(bam)                                                            |                                                                                                                                                                                                                                                                                               |
| accepted_pollers           | string |                                      | coma separated list of pollers that are accepted (for example: my_poller_1,my_poller_2)                                                                        | host_status(neb), service_status(neb)                                     |                                                                                                                                                                                                                                                                                               |
| skip_anon_events           | number | 1                                    | filter out events if their name can't be found in the broker cache (use 0 to accept them)                                                                      | host_status(neb), service_status(neb), ba_status(bam)                     |                                                                                                                                                                                                                                                                                               |
| skip_nil_id                | number | 1                                    | filter out events if their ID is nil (use 0 to accept them. YOU SHOULDN'T DO THAT)                                                                             | host_status(neb), service_status(neb), ba_status(bam)                     |                                                                                                                                                                                                                                                                                               |
| max_buffer_size            | number | 1                                    | this is the number of events the stream connector is going to store before sending them. (bulk send is made using a value above 1).                            |                                                                           |                                                                                                                                                                                                                                                                                               |
| max_buffer_age             | number | 5                                    | if no new event has been stored in the buffer in the past 5 seconds, all stored events are going to be sent even if the max_buffer_size hasn't been reached    |                                                                           |                                                                                                                                                                                                                                                                                               |
| service_severity_threshold | number | nil                                  | the threshold that will be used to filter severity for services. it must be used with service_severity_operator option                                         | service_status(neb)                                                       |                                                                                                                                                                                                                                                                                               |
| service_severity_operator  | string | >=                                   | the mathematical operator used to compare the accepted service severity threshold and the service severity (operation order is: threshold >= service severity) | service_status(neb)                                                       |                                                                                                                                                                                                                                                                                               |
| host_severity_threshold    | number | nil                                  | the threshold that will be used to filter severity for hosts. it must be used with host_severity_operator option                                               | host_status(neb), service_status(neb)                                     |                                                                                                                                                                                                                                                                                               |
| host_severity_operator     | string | >=                                   | the mathematical operator used to compare the accepted host severity threshold and the host severity (operation order is: threshold >= host severity)          | host_status(neb), service_status(neb)                                     |                                                                                                                                                                                                                                                                                               |

## Module initialization

Since this is OOP, it is required to initiate your module.

### module constructor

Constructor must be initialized with two parameters

- a sc_common instance
- a sc_logger instance (will create a new one with default parameters if not provided)

### constructor: Example

```lua
-- load module
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")

-- initiate "mandatory" information for the logger module
local logfile = "/var/log/test_param.log"
local severity = 1

-- create a new instance of the sc_logger module
local test_logger = sc_logger.new(logfile, severity)

-- create a new instance of the sc_common module
local test_common = sc_common.new(test_logger)

-- create a new instance of the sc_param module
local test_param = sc_param.new(test_common, test_logger)
```

## param_override method

The **param_override** method checks if a standard parameter from [**Default parameters**](#default-parameters) has been overriden by the user. If so, it replace the default value with the one provided by the user

### param_override: parameters

| parameter                              | type  | optional | default value |
| -------------------------------------- | ----- | -------- | ------------- |
| the list of parameters and their value | table | no       |               |

### param_override: example

```lua
--> test_param.param.accepted_elements is: "host_status,service_status,ba_status"
--> test_param.param.in_downtime is: 0

-- change the value of the default parameter called accepted_elements and in_downtime (normally they come from the web configuration, we just simulate this behavior in this example)
local params = {
  accepted_elements = "ba_status",
  in_downtime = 1
}

-- use the param override method to override the default values for in_downtime and accepted_elements 
test_param:param_override(params)
--> test_param.param.accepted_elements is: "ba_status"
--> test_param.param.in_downtime is: 1
```

## check_params method

The **check_params** method applies various conformity checks on the default parameters. If the conformity check fails on a parameter, it is reverted to a the [**default value**](#default-parameters)

### check_params: example

```lua
--> test_param.param.accepted_elements is: "host_status,service_status,ba_status"
--> test_param.param.in_downtime is: 0

-- change the value of the default parameter called accepted_elements and in_downtime (normally they come from the web configuration, we just simulate this behavior in this example)
local params = {
  accepted_elements = "ba_status",
  in_downtime = 12 -- this must be 0 or 1 
}

-- use the param override method to override the default values for in_downtime and accepted_elements 
test_param:param_override(params)
--> test_param.param.accepted_elements is: "ba_status"
--> test_param.param.in_downtime is: 12

-- checks default param validity
test_param:check_params()
--> test_param.param.accepted_elements is: "ba_status"
--> test_param.param.in_downtime is: 0 (12 is not a valid value, it goes back to the default one)
```
