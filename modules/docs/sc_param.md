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
  - [get_kafka_parameters method](#get_kafka_parameters-method)
    - [get_kafka_params: parameters](#get_kafka_params-parameters)
    - [get_kafka_params: example](#get_kafka_params-example)
  - [is_mandatory_config_set method](#is_mandatory_config_set-method)
    - [is_mandatory_config_set: parameters](#is_mandatory_config_set-parameters)
    - [is_mandatory_config_set: returns](#is_mandatory_config_set-returns)
    - [is_mandatory_config_set: example](#is_mandatory_config_set-example)
  - [load_event_format_file method](#load_event_format_file-method)
    - [load_event_format_file: returns](#load_event_format_file-returns)
    - [load_event_format_file: example](#load_event_format_file-example)
  - [build_accepted_elements_info method](#build_accepted_elements_info-method)
    - [build_accepted_elements_info: example](#build_accepted_elements_info-example)

## Introduction

The sc_param module provides methods to help you handle parameters for your stream connectors. It also provides a list of default parameters that are available for every stream connectors (the complete list is below) and a set of mappings to convert ID to human readable text or the other way around. Head over [**the mappings documentation**](mappings.md) for more information. It has been made in OOP (object oriented programming)

### Default parameters

| Parameter name              | type   | default value                                                                 | description                                                                                                                                                    | default scope                                                                                                                                                                 | additionnal information                                                                                                                                                                                                                                                                       |
| --------------------------- | ------ | ----------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| accepted_categories         | string | neb,bam                                                                       | each event is linked to a broker category that we can use to filter events                                                                                     |                                                                                                                                                                               | it is a coma separated list, can use "neb", "bam", "storage". Storage is deprecated, use "neb" to get metrics data [more information](https://docs.centreon.com/current/en/developer/developer-broker-bbdo.html#event-categories)                                                             |
| accepted_elements           | string | host_status,service_status,ba_status                                          |                                                                                                                                                                | each event is linked to a broker element that we can use to filter events                                                                                                     | it is a coma separated list, can use any type in the "neb", "bam" and "storage" tables [described here](https://docs.centreon.com/current/en/developer/developer-broker-bbdo.html#neb) (you must use lower case and replace blank space with underscore. "Host status" becomes "host_status") |
| host_status                 | string | 0,1,2                                                                         | coma separated list of accepted host status (0 = UP, 1 = DOWN, 2 = UNREACHABLE)                                                                                |                                                                                                                                                                               |                                                                                                                                                                                                                                                                                               |
| service_status              | string | 0,1,2,3                                                                       | coma separated list of accepted services status (0 = OK, 1 = WARNING, 2 = CRITICAL, 3 = UNKNOWN)                                                               |                                                                                                                                                                               |                                                                                                                                                                                                                                                                                               |
| ba_status                   | string | 0,1,2                                                                         | coma separated list of accepted BA status (0 = OK, 1 = WARNING, 2 = CRITICAL)                                                                                  |                                                                                                                                                                               |                                                                                                                                                                                                                                                                                               |
| hard_only                   | number | 1                                                                             | accept only events that are in a HARD state (use 0 to accept SOFT state too)                                                                                   | host_status(neb), service_status(neb)                                                                                                                                         |                                                                                                                                                                                                                                                                                               |
| acknowledged                | number | 0                                                                             | accept only events that aren't acknowledged (use 1 to accept acknowledged events too)                                                                          | host_status(neb), service_status(neb)                                                                                                                                         |                                                                                                                                                                                                                                                                                               |
| in_downtime                 | number | 0                                                                             | accept only events that aren't in downtime (use 1 to accept events that are in downtime too)                                                                   | host_status(neb), service_status(neb), ba_status(bam)                                                                                                                         |                                                                                                                                                                                                                                                                                               |
| accepted_hostgroups         | string |                                                                               | coma separated list of hostgroups that are accepted (for example: my_hostgroup_1,my_hostgroup_2)                                                               | host_status(neb), service_status(neb), acknowledgement(neb)                                                                                                                   |                                                                                                                                                                                                                                                                                               |
| accepted_servicegroups      | string |                                                                               | coma separated list of servicegroups that are accepted (for example: my_servicegroup_1,my_servicegroup_2)                                                      | service_status(neb), acknowledgement(neb)                                                                                                                                     |                                                                                                                                                                                                                                                                                               |
| accepted_bvs                | string |                                                                               | coma separated list of BVs that are accepted (for example: my_bv_1,my_bv_2)                                                                                    | ba_status(bam)                                                                                                                                                                |                                                                                                                                                                                                                                                                                               |
| accepted_pollers            | string |                                                                               | coma separated list of pollers that are accepted (for example: my_poller_1,my_poller_2)                                                                        | host_status(neb), service_status(neb),acknowledgement(neb)                                                                                                                    |                                                                                                                                                                                                                                                                                               |
| skip_anon_events            | number | 1                                                                             | filter out events if their name can't be found in the broker cache (use 0 to accept them)                                                                      | host_status(neb), service_status(neb), ba_status(bam), acknowledgement(neb)                                                                                                   |                                                                                                                                                                                                                                                                                               |
| skip_nil_id                 | number | 1                                                                             | filter out events if their ID is nil (use 0 to accept them. YOU SHOULDN'T DO THAT)                                                                             | host_status(neb), service_status(neb), ba_status(bam), acknowledgement(neb)                                                                                                   |                                                                                                                                                                                                                                                                                               |
| max_buffer_size             | number | 1                                                                             | this is the number of events the stream connector is going to store before sending them. (bulk send is made using a value above 1).                            |                                                                                                                                                                               |                                                                                                                                                                                                                                                                                               |
| max_buffer_age              | number | 5                                                                             | if no new event has been stored in the buffer in the past 5 seconds, all stored events are going to be sent even if the max_buffer_size hasn't been reached    |                                                                                                                                                                               |                                                                                                                                                                                                                                                                                               |
| service_severity_threshold  | number | nil                                                                           | the threshold that will be used to filter severity for services. it must be used with service_severity_operator option                                         | service_status(neb), acknowledgement(neb)                                                                                                                                     |                                                                                                                                                                                                                                                                                               |
| service_severity_operator   | string | >=                                                                            | the mathematical operator used to compare the accepted service severity threshold and the service severity (operation order is: threshold >= service severity) | service_status(neb), acknowledgement(neb)                                                                                                                                     |                                                                                                                                                                                                                                                                                               |
| host_severity_threshold     | number | nil                                                                           | the threshold that will be used to filter severity for hosts. it must be used with host_severity_operator option                                               | host_status(neb), service_status(neb) , acknowledgement(neb)                                                                                                                  |                                                                                                                                                                                                                                                                                               |
| host_severity_operator      | string | >=                                                                            | the mathematical operator used to compare the accepted host severity threshold and the host severity (operation order is: threshold >= host severity)          | host_status(neb), service_status(neb), acknowledgement(neb)                                                                                                                   |                                                                                                                                                                                                                                                                                               |
| ack_host_status             | string |                                                                               |                                                                                                                                                                | coma separated list of accepted host status for an acknowledgement event. It uses the host_status parameter by default (0 = UP, 1 = DOWN, 2 = UNREACHABLE)                    | acknowledgement(neb)                                                                                                                                                                                                                                                                          |                                                              |
| ack_service_status          | string |                                                                               |                                                                                                                                                                | coma separated list of accepted service status for an acknowledgement event. It uses the service_status parameter by default (0 = OK, 1 = WARNING, 2 = CRITICAL, 3 = UNKNOWN) | acknowledgement(neb)                                                                                                                                                                                                                                                                          |                                                              |
| dt_host_status              | string |                                                                               |                                                                                                                                                                | coma separated list of accepted host status for a downtime event. It uses the host_status parameter by default (0 = UP, 1 = DOWN, 2 = UNREACHABLE)                            | downtime(neb)                                                                                                                                                                                                                                                                                 |                                                              |
| dt_service_status           | string |                                                                               |                                                                                                                                                                | coma separated list of accepted service status for a downtime event. It uses the service_status parameter by default (0 = OK, 1 = WARNING, 2 = CRITICAL, 3 = UNKNOWN)         | downtime(neb)                                                                                                                                                                                                                                                                                 |                                                              |
| enable_host_status_dedup    | number | 1                                                                             |                                                                                                                                                                | enable the deduplication of host status event when set to 1                                                                                                                   | host_status(neb)                                                                                                                                                                                                                                                                              |                                                              |
| enable_service_status_dedup | number | 1                                                                             |                                                                                                                                                                | enable the deduplication of service status event when set to 1                                                                                                                | service_status(neb)                                                                                                                                                                                                                                                                           |                                                              |
| accepted_authors            | string |                                                                               |                                                                                                                                                                | coma separated list of accepted authors for a comment. It uses the alias (login) of the Centreon contacts                                                                     | downtime(neb), acknowledgement(neb)                                                                                                                                                                                                                                                           |                                                              |
| local_time_diff_from_utc    | number | default value is the time difference the centreon central server has from UTC |                                                                                                                                                                | the time difference from UTC in seconds                                                                                                                                       | all                                                                                                                                                                                                                                                                                           |                                                              |
| timestamp_conversion_format | string | %Y-%m-%d %X                                                                   |                                                                                                                                                                | the date format used to convert timestamps. Default value will print dates like this: 2021-06-11 10:43:38                                                                     | all                                                                                                                                                                                                                                                                                           | (date format information)[https://www.lua.org/pil/22.1.html] |
| send_data_test              | number | 0                                                                             |                                                                                                                                                                | When set to 1, send data in the logfile of the stream connector instead of sending it where the stream connector was designed to                                              | all                                                                                                                                                                                                                                                                                           |                                                              |
| format_file                 | string |                                                                               |                                                                                                                                                                | Path to a file that will be used as a template to format events instead of using default format                                                                               | only usable for events stream connectors (\*-events-apiv2.lua) and not metrics stream connectors (\*-metrics-apiv2.lua) you should put the file in /etc/centreon-broker to keep your broker configuration in a single place. [**See documentation for more information**](templating.md)      |

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

## get_kafka_parameters method

The **get_kafka_parameters** method find the configuration parameters that are related to a stream connector that sends data to **Kafka**.
To achieve this, parameters must match the following regular expression `^_sc_kafka_`. It will then exclude the `_sc_kafka_` prefix from the parameter name and add the parameter to the kafka_config object.

A list of Kafka parameters is available [**here**](https://github.com/edenhill/librdkafka/blob/master/CONFIGURATION.md). You must put **_sc_kafka_** as a prefix to use them.
For example the parameter `security.protocol` becomes `_sc_kafka_security.protocol`

### get_kafka_params: parameters

| parameter    | type   | optional | default value |
| ------------ | ------ | -------- | ------------- |
| kafka_config | object | no       |               |
| params       | table  | no       |               |

### get_kafka_params: example

```lua
-- create the kafka_config object
local test_kafka_config = kafka_config.create()

-- set up a parameter list
local params = {
  broker = "localhost:9093",
  ["_sc_kafka_sasl.username"] = "john",
  topic = "pasta",
  ["_sc_kafka_sasl.password"] = "doe"
}

test_param:get_kafka_params(test_kafka_config, params)

--> test_kafka_config["sasl.username"] is "john"
--> test_kafka_config["sasl.password"] is "doe"
--> test_kafka_config["topic"] is nil
```

## is_mandatory_config_set method

The **is_mandatory_config_set** method checks if all mandatory parameters for a stream connector are set up. If one is missing, it will print an error and return false. Each mandatory parameter that is found is going to be stored in the standard parameters list.

### is_mandatory_config_set: parameters

| parameter        | type  | optional | default value |
| ---------------- | ----- | -------- | ------------- |
| mandatory_params | table | no       |               |
| params           | table | no       |               |

### is_mandatory_config_set: returns

| return        | type    | always | condition                                                |
| ------------- | ------- | ------ | -------------------------------------------------------- |
| true or false | boolean | yes    | if a mandatory configuration parameter is missing or not |

### is_mandatory_config_set: example

```lua
-- create a list of mandatory parameters
local mandatory_parameters = {
  [1] = "username",
  [2] = "password"
}

-- list of parameters configured by the user
local params = {
  username = "John",
  address = "localhost",
}

local result = test_param:is_mandatory_config_set(mandatory_params, params)

--> result is false because the "password" parameter is not in the list of parameters
--[[
  since username index (1) is lower than password index (2), the username property will still be available in the test_param.param table
  --> test_param.param.username is "John"
]]

params.password = "hello"

result = test_param:is_mandatory_config_set(mandatory_params, params)
--> result is true because password and username are in the params table
--> test_param.param.username is "John"
--> test_param.param.password is "hello"
```

## load_event_format_file method

The **load_event_format_file** load a json file which purpose is to serve as a template to format events. It will use the [**format_file parameter**](#default-parameters) in order to know which file to load. If a file has been successfully loaded, a template table will be created in the self.params table.

### load_event_format_file: returns

| return        | type    | always | condition                                                |
| ------------- | ------- | ------ | -------------------------------------------------------- |
| true or false | boolean | yes    | if the template file has been successfully loaded or not |

### load_event_format_file: example

```lua
test_param.params.format_file = "/etc/centreon-broker/sc_template.json"


local result = test_param:load_event_format_file()

--> result is true 
--> test_param.params.format_template is now created

test_param.params.format_file = 3

result = test_param:load_event_format_file(mandatory_params, params)
--> result is false
```

## build_accepted_elements_info method

The **build_accepted_elements_info** creates a table with information related to the accepted elements. It will use the [**accepted_elements parameter**](#default-parameters) in order to create this table.

### build_accepted_elements_info: example

```lua
test_param.params.accepted_elements = "host_status,service_status,ba_status"

test_param:build_accepted_elements_info()

--> a test_param.params.accepted_elements_info table is now created and here is its content
--[[
  test_param.params.accepted_elements_info = {
    host_status = {
      category_id = 1,
      category_name = "neb",
      id = 14,
      name = "host_status"
    },
    service_status = {
      category_id = 1,
      category_name = "neb",
      id = 24,
      name = "service_status"
    },
    ba_status = {
      category_id = 6,
      category_name = "bam",
      id = 1,
      name = "ba_status
    }
  }
]]--
```
