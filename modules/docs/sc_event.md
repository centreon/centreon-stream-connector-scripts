# Documentation of the sc_param module

- [Documentation of the sc\_param module](#documentation-of-the-sc_param-module)
  - [Introduction](#introduction)
  - [Module initialization](#module-initialization)
    - [module constructor](#module-constructor)
    - [constructor: Example](#constructor-example)
  - [is\_valid\_category method](#is_valid_category-method)
    - [is\_valid\_category: returns](#is_valid_category-returns)
    - [is\_valid\_category: example](#is_valid_category-example)
  - [is\_valid\_element method](#is_valid_element-method)
    - [is\_valid\_element: returns](#is_valid_element-returns)
    - [is\_valid\_element: example](#is_valid_element-example)
  - [is\_valid\_event method](#is_valid_event-method)
    - [is\_valid\_event: returns](#is_valid_event-returns)
    - [is\_valid\_event: example](#is_valid_event-example)
  - [is\_valid\_neb\_event method](#is_valid_neb_event-method)
    - [is\_valid\_neb\_event: returns](#is_valid_neb_event-returns)
    - [is\_valid\_neb\_event: example](#is_valid_neb_event-example)
  - [is\_valid\_host\_status\_event method](#is_valid_host_status_event-method)
    - [is\_valid\_host\_status\_event: returns](#is_valid_host_status_event-returns)
    - [is\_valid\_host\_status\_event: example](#is_valid_host_status_event-example)
  - [is\_valid\_service\_status\_event method](#is_valid_service_status_event-method)
    - [is\_valid\_service\_status\_event: returns](#is_valid_service_status_event-returns)
    - [is\_valid\_service\_status\_event: example](#is_valid_service_status_event-example)
  - [is\_valid\_host method](#is_valid_host-method)
    - [is\_valid\_host: returns](#is_valid_host-returns)
    - [is\_valid\_host: example](#is_valid_host-example)
  - [is\_valid\_service method](#is_valid_service-method)
    - [is\_valid\_service: returns](#is_valid_service-returns)
    - [is\_valid\_service: example](#is_valid_service-example)
  - [is\_valid\_event\_states method](#is_valid_event_states-method)
    - [is\_valid\_event\_states: returns](#is_valid_event_states-returns)
    - [is\_valid\_event\_states: example](#is_valid_event_states-example)
  - [is\_valid\_event\_status method](#is_valid_event_status-method)
    - [is\_valid\_event\_status: parameters](#is_valid_event_status-parameters)
    - [is\_valid\_event\_status: returns](#is_valid_event_status-returns)
    - [is\_valid\_event\_status: example](#is_valid_event_status-example)
  - [is\_valid\_event\_state\_type method](#is_valid_event_state_type-method)
    - [is\_valid\_event\_state\_type: returns](#is_valid_event_state_type-returns)
    - [is\_valid\_event\_state\_type: example](#is_valid_event_state_type-example)
  - [is\_valid\_event\_acknowledge\_state method](#is_valid_event_acknowledge_state-method)
    - [is\_valid\_event\_acknowledge\_state: returns](#is_valid_event_acknowledge_state-returns)
    - [is\_valid\_event\_acknowledge\_state: example](#is_valid_event_acknowledge_state-example)
  - [is\_valid\_event\_downtime\_state method](#is_valid_event_downtime_state-method)
    - [is\_valid\_event\_downtime\_state: returns](#is_valid_event_downtime_state-returns)
    - [is\_valid\_event\_downtime\_state: example](#is_valid_event_downtime_state-example)
  - [is\_valid\_event\_flapping\_state method](#is_valid_event_flapping_state-method)
    - [is\_valid\_event\_flapping\_state: returns](#is_valid_event_flapping_state-returns)
    - [is\_valid\_event\_flapping\_state: example](#is_valid_event_flapping_state-example)
  - [is\_valid\_hostgroup method](#is_valid_hostgroup-method)
    - [is\_valid\_hostgroup: returns](#is_valid_hostgroup-returns)
    - [is\_valid\_hostgroup: example](#is_valid_hostgroup-example)
  - [is\_valid\_servicegroup method](#is_valid_servicegroup-method)
    - [is\_valid\_servicegroup: returns](#is_valid_servicegroup-returns)
    - [is\_valid\_servicegroup: example](#is_valid_servicegroup-example)
  - [is\_valid\_bam\_event method](#is_valid_bam_event-method)
    - [is\_valid\_bam\_event: returns](#is_valid_bam_event-returns)
    - [is\_valid\_bam\_event: example](#is_valid_bam_event-example)
  - [is\_valid\_ba method](#is_valid_ba-method)
    - [is\_valid\_ba: returns](#is_valid_ba-returns)
    - [is\_valid\_ba: example](#is_valid_ba-example)
  - [is\_valid\_ba\_status\_event method](#is_valid_ba_status_event-method)
    - [is\_valid\_ba\_status\_event: returns](#is_valid_ba_status_event-returns)
    - [is\_valid\_ba\_status\_event: example](#is_valid_ba_status_event-example)
  - [is\_valid\_ba\_downtime\_state method](#is_valid_ba_downtime_state-method)
    - [is\_valid\_ba\_downtime\_state: returns](#is_valid_ba_downtime_state-returns)
    - [is\_valid\_ba\_downtime\_state: example](#is_valid_ba_downtime_state-example)
  - [is\_valid\_ba\_acknowledge\_state method](#is_valid_ba_acknowledge_state-method)
    - [is\_valid\_ba\_acknowledge\_state: returns](#is_valid_ba_acknowledge_state-returns)
    - [is\_valid\_ba\_acknowledge\_state: example](#is_valid_ba_acknowledge_state-example)
  - [is\_valid\_bv method](#is_valid_bv-method)
    - [is\_valid\_bv: returns](#is_valid_bv-returns)
    - [is\_valid\_bv: example](#is_valid_bv-example)
  - [find\_hostgroup\_in\_list method](#find_hostgroup_in_list-method)
    - [find\_hostgroup\_in\_list: returns](#find_hostgroup_in_list-returns)
    - [find\_hostgroup\_in\_list: example](#find_hostgroup_in_list-example)
  - [find\_servicegroup\_in\_list method](#find_servicegroup_in_list-method)
    - [find\_servicegroup\_in\_list: returns](#find_servicegroup_in_list-returns)
    - [find\_servicegroup\_in\_list: example](#find_servicegroup_in_list-example)
  - [find\_bv\_in\_list method](#find_bv_in_list-method)
    - [find\_bv\_in\_list: returns](#find_bv_in_list-returns)
    - [find\_bv\_in\_list: example](#find_bv_in_list-example)
  - [is\_valid\_poller method](#is_valid_poller-method)
    - [is\_valid\_poller: returns](#is_valid_poller-returns)
    - [is\_valid\_poller: example](#is_valid_poller-example)
  - [find\_poller\_in\_list method](#find_poller_in_list-method)
    - [find\_poller\_in\_list: returns](#find_poller_in_list-returns)
    - [find\_poller\_in\_list: example](#find_poller_in_list-example)
  - [is\_valid\_host\_severity method](#is_valid_host_severity-method)
    - [is\_valid\_host\_severity: returns](#is_valid_host_severity-returns)
    - [is\_valid\_host\_severity: example](#is_valid_host_severity-example)
  - [is\_valid\_service\_severity method](#is_valid_service_severity-method)
    - [is\_valid\_service\_severity: returns](#is_valid_service_severity-returns)
    - [is\_valid\_service\_severity: example](#is_valid_service_severity-example)
  - [is\_valid\_acknowledgement\_event method](#is_valid_acknowledgement_event-method)
    - [is\_valid\_acknowledgement\_event: returns](#is_valid_acknowledgement_event-returns)
    - [is\_valid\_acknowledgement\_event: example](#is_valid_acknowledgement_event-example)
  - [is\_host\_status\_event\_duplicated method](#is_host_status_event_duplicated-method)
    - [is\_host\_status\_event\_duplicated: returns](#is_host_status_event_duplicated-returns)
    - [is\_host\_status\_event\_duplicated: example](#is_host_status_event_duplicated-example)
  - [is\_service\_status\_event\_duplicated method](#is_service_status_event_duplicated-method)
    - [is\_service\_status\_event\_duplicated: returns](#is_service_status_event_duplicated-returns)
    - [is\_service\_status\_event\_duplicated: example](#is_service_status_event_duplicated-example)
  - [is\_valid\_downtime\_event method](#is_valid_downtime_event-method)
    - [is\_valid\_downtime\_event: returns](#is_valid_downtime_event-returns)
    - [is\_valid\_downtime\_event: example](#is_valid_downtime_event-example)
  - [get\_downtime\_host\_status method](#get_downtime_host_status-method)
    - [get\_downtime\_host\_status: returns](#get_downtime_host_status-returns)
    - [get\_downtime\_host\_status: example](#get_downtime_host_status-example)
  - [get\_downtime\_service\_status method](#get_downtime_service_status-method)
    - [get\_downtime\_service\_status: returns](#get_downtime_service_status-returns)
    - [get\_downtime\_service\_status: example](#get_downtime_service_status-example)
  - [is\_valid\_author method](#is_valid_author-method)
    - [is\_valid\_author: returns](#is_valid_author-returns)
    - [is\_valid\_author: example](#is_valid_author-example)
  - [is\_downtime\_event\_useless method](#is_downtime_event_useless-method)
    - [is\_downtime\_event\_useless: returns](#is_downtime_event_useless-returns)
    - [is\_downtime\_event\_useless: example](#is_downtime_event_useless-example)
  - [is\_valid\_downtime\_event\_start method](#is_valid_downtime_event_start-method)
    - [is\_valid\_downtime\_event\_start: returns](#is_valid_downtime_event_start-returns)
    - [is\_valid\_downtime\_event\_start: example](#is_valid_downtime_event_start-example)
  - [is\_valid\_downtime\_event\_end method](#is_valid_downtime_event_end-method)
    - [is\_valid\_downtime\_event\_end: returns](#is_valid_downtime_event_end-returns)
    - [is\_valid\_downtime\_event\_end: example](#is_valid_downtime_event_end-example)
  - [build\_outputs method](#build_outputs-method)
    - [build\_outputs: example](#build_outputs-example)
  - [is\_valid\_storage\_event method](#is_valid_storage_event-method)

## Introduction

The sc_event module provides methods to help you handle events for your stream connectors. It has been made in OOP (object oriented programming)

## Module initialization

Since this is OOP, it is required to initiate your module.

### module constructor

Constructor must be initialized with 5 parameters

- an event table
- a params table
- a sc_common instance
- a sc_logger instance (will create a new one with default parameters if not provided)
- a sc_broker instance

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
local test_event = sc_event.new(event, test_param.params, test_common, test_logger, test_broker)
```

## is_valid_category method

The **is_valid_category** method checks if the event category is part of [**accepted_categories**](sc_param.md#default-parameters)

### is_valid_category: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_category: example

```lua
local result = test_event:is_valid_category()
--> result is true or false 
```

## is_valid_element method

The **is_valid_element** method checks if the event element is part of [**accepted_elements**](sc_param.md#default-parameters)

### is_valid_element: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_element: example

```lua
local result = test_event:is_valid_element()
--> result is true or false 
```

## is_valid_event method

The **is_valid_event** method checks if the event is valid based on [**default parameters**](sc_param.md#default-parameters)

head over the following chapters for more information

- [is_valid_neb_event](#is_valid_neb_event-method)
- [is_valid_bam_event](#is_valid_bam_event-method)
- [is_valid_storage_event](#is_valid_storage_event-method)

### is_valid_event: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_event: example

```lua
local result = test_event:is_valid_event()
--> result is true or false 
```

## is_valid_neb_event method

The **is_valid_neb_event** method checks if the event is a valid **neb** event based on [**default parameters**](sc_param.md#default-parameters) in the **neb** scope

head over the following chapters for more information

- [is_valid_host_status_event](#is_valid_host_status_event-method)
- [is_valid_service_status_event](#is_valid_service_status_event-method)
- [is_valid_acknowledgement_event](#is_valid_acknowledgement_event-method)

### is_valid_neb_event: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_neb_event: example

```lua
local result = test_event:is_valid_neb_event()
--> result is true or false
```

## is_valid_host_status_event method

The **is_valid_host_status_event** method checks if the host status event is valid based on [**default parameters**](sc_param.md#default-parameters) in the **host_status** scope

head over the following chapters for more information

- [is_valid_host](#is_valid_host-method)
- [is_valid_event_status](#is_valid_event_status-method)
- [is_valid_event_states](#is_valid_event_states-method)
- [is_valid_poller](#is_valid_poller-method)
- [is_valid_host_severity](#is_valid_host_severity-method)
- [is_valid_hostgroup](#is_valid_hostgroup-method)
- [is_host_status_event_duplicated](#is_host_status_event_duplicated-method)

### is_valid_host_status_event: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_host_status_event: example

```lua
local result = test_event:is_valid_host_status_event()
--> result is true or false
```

## is_valid_service_status_event method

The **is_valid_service_status_event** method checks if the service status event is valid based on [**default parameters**](sc_param.md#default-parameters) in the **service_status** scope

head over the following chapters for more information

- [is_valid_host](#is_valid_host-method)
- [is_valid_service](#is_valid_service-method)
- [is_valid_event_status](#is_valid_event_status-method)
- [is_valid_event_states](#is_valid_event_states-method)
- [is_valid_poller](#is_valid_poller-method)
- [is_valid_host_severity](#is_valid_host_severity-method)
- [is_valid_service_severity](#is_valid_service_severity-method)
- [is_valid_hostgroup](#is_valid_hostgroup-method)
- [is_valid_servicegroup](#is_valid_servicegroup-method)

### is_valid_service_status_event: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_service_status_event: example

```lua
local result = test_event:is_valid_service_status_event()
--> result is true or false
```

## is_valid_host method

The **is_valid_host** method checks if the host is valid based on [**skip_nil_id and skip_anon_events**](sc_param.md#default-parameters)

If the host is valid, all broker cache information regarding this host will be added to the event in a cache.host table. More details about this cache table [**here**](sc_broker.md#get_host_all_infos-example)

### is_valid_host: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_host: example

```lua
local result = test_event:is_valid_host()
--> result is true or false
--[[
  --> test_event.event structure is:
  {
    --- event data ---
    cache = {
      host = {
        --- cache data ---
      }
      --- other cache data type ---
    }
  }
]]
```

## is_valid_service method

The **is_valid_service** method checks if the service is valid based on [**skip_nil_id and skip_anon_events**](sc_param.md#default-parameters) in the **service_status** scope

If the service is valid, all broker cache information regarding this service will be added to the event in a cache.service table. More details about this cache table [**here**](sc_broker.md#get_service_all_infos-example)

### is_valid_service: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_service: example

```lua
local result = test_event:is_valid_service()
--> result is true or false
--[[
  --> test_event.event structure is:
  {
    --- event data ---
    cache = {
      service = {
        --- cache data ---
      }
      --- other cache data type ---
    }
  }
]]
```

## is_valid_event_states method

The **is_valid_event_states** method checks if the event states (downtime, hard/soft, acknowledgement, flapping) are valid based on[**hard_only, in_downtime, acknowledged and flapping parameters**](sc_param.md#default-parameters) in the **host_status or service_status** scope

head over the following chapters for more information

- [is_valid_event_state_type](#is_valid_event_state_type-method)
- [is_valid_event_acknowledge_state](#is_valid_event_acknowledge_state-method)
- [is_valid_event_downtime_state](#is_valid_event_downtime_state-method)
- [is_valid_event_flapping_state](#is_valid_event_flapping_state-method)

### is_valid_event_states: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_event_states: example

```lua
local result = test_event:is_valid_event_states(test_param.params.host_status)
--> result is true or false 
```

## is_valid_event_status method

The **is_valid_event_states** method checks if the event status is valid based on [**host_status, service_status or ba_status parameters**](sc_param.md#default-parameters) in the **host_status, service_status or ba_status** scope

### is_valid_event_status: parameters

| parameter                                        | type   | optional | default value |
| ------------------------------------------------ | ------ | -------- | ------------- |
| the list of accepted status code from parameters | string | no       |               |

### is_valid_event_status: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_event_status: example

```lua
local result = test_event:is_valid_event_status()
--> result is true or false
```

## is_valid_event_state_type method

The **is_valid_event_state_type** method checks if the event state (HARD/SOFT) is valid based on the [**hard_only parameter**](sc_param.md#default-parameters) in the **host_status, service_status** scope

### is_valid_event_state_type: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_event_state_type: example

```lua
local result = test_event:is_valid_event_state_type()
--> result is true or false
```

## is_valid_event_acknowledge_state method

The **is_valid_event_acknowledge_state** method checks if the event is in valid acknowledgement state based on the [**acknowledged parameter**](sc_param.md#default-parameters) in the **host_status, service_status** scope

### is_valid_event_acknowledge_state: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_event_acknowledge_state: example

```lua
local result = test_event:is_valid_event_acknowledge_state()
--> result is true or false
```

## is_valid_event_downtime_state method

The **is_valid_event_downtime_state** method checks if the event is in a valid downtime state based on the [**in_downtime parameter**](sc_param.md#default-parameters) in the **host_status, service_status** scope

### is_valid_event_downtime_state: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_event_downtime_state: example

```lua
local result = test_event:is_valid_event_downtime_state()
--> result is true or false
```

## is_valid_event_flapping_state method

The **is_valid_event_flapping_state** method checks if the event is in valid flapping state based on the [**flapping parameter**](sc_param.md#default-parameters) in the **host_status, service_status** scope

### is_valid_event_flapping_state: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_event_flapping_state: example

```lua
local result = test_event:is_valid_event_flapping_state()
--> result is true or false
```

## is_valid_hostgroup method

The **is_valid_hostgroup** method checks if the event is in a valid hostgroup based on [**accepted_hostgroups**](sc_param.md#default-parameters) in the **host_status or service_status** scope

If the **accepted_hostgroup** is configured, all broker cache information regarding the hostgroups linked to a host will be added to the event in a cache.hostgroups table. More details about this cache table [**here**](sc_broker.md#get_hostgroups-example)

### is_valid_hostgroup: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_hostgroup: example

```lua
local result = test_event:is_valid_hostgroup()
--> result is true or false
--[[
  --> test_event.event structure is:
  {
    --- event data ---
    cache = {
      hostgroups = {
        --- cache data ---
      }
      --- other cache data type ---
    }
  }
]]
```

## is_valid_servicegroup method

The **is_valid_servicegroup** method checks if the event is in a valid servicegroup based on [**accepted_servicegroups**](sc_param.md#default-parameters) in the **service_status** scope

If the **accepted_servicegroup** is configured, all broker cache information regarding the servicegroups linked to a service will be added to the event in a cache.servicegroups table. More details about this cache table [**here**](sc_broker.md#get_servicegroups-example)

### is_valid_servicegroup: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_servicegroup: example

```lua
local result = test_event:is_valid_servicegroup()
--> result is true or false
--[[
  --> test_event.event structure is:
  {
    --- event data ---
    cache = {
      servicegroups = {
        --- cache data ---
      }
      --- other cache data type ---
    }
  }
]]
```

## is_valid_bam_event method

The **is_valid_bam_event** method checks if the bam status event is valid based on [**default parameters**](sc_param.md#default-parameters) in the **bam** scope

head over the following chapters for more information

- [is_valid_ba](#is_valid_ba-method)
- [is_valid_ba_status_event](#is_valid_ba_status_event-method)
- [is_valid_ba_downtime_state](#is_valid_ba_downtime_state-method)
- [is_valid_ba_acknowledge_state](#is_valid_ba_acknowledge_state-method)
- [is_valid_bv](#is_valid_bv-method)

### is_valid_bam_event: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_bam_event: example

```lua
local result = test_event:is_valid_bam_event()
--> result is true or false
```

## is_valid_ba method

The **is_valid_ba** method checks if the BA is valid based on [**skip_nil_id and skip_anon_events**](sc_param.md#default-parameters)

If the BA is valid, all broker cache information regarding this BA will be added to the event in a cache.ba table. More details about this cache table [**here**](sc_broker.md#get_ba_infos-example)

### is_valid_ba: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_ba: example

```lua
local result = test_event:is_valid_ba()
--> result is true or false
--[[
  --> test_event.event structure is:
  {
    --- event data ---
    cache = {
      ba = {
        --- cache data ---
      }
      --- other cache data type ---
    }
  }
]]
```

## is_valid_ba_status_event method

The **is_valid_ba_status_event** method checks if the BA status is valid based on [**ba_status**](sc_param.md#default-parameters) in the **ba_status** scope

head over the following chapters for more information

- [is_valid_event_status](#is_valid_event_status-method)

### is_valid_ba_status_event: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_ba_status_event: example

```lua
local result = test_event:is_valid_ba_status_event()
--> result is true or false
```

## is_valid_ba_downtime_state method

The **is_valid_ba_downtime_state** method checks if the BA is in a valid downtime state based on [**in_downtime**](sc_param.md#default-parameters) in the **ba_status** scope

### is_valid_ba_downtime_state: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_ba_downtime_state: example

```lua
local result = test_event:is_valid_ba_downtime_state()
--> result is true or false
```

## is_valid_ba_acknowledge_state method

**DOES NOTHING** The **is_valid_ba_acknowledge_state** method checks if the event is in a valid acknowledgement state based on [**acknowledged**](sc_param.md#default-parameters) in the **ba_status** scope

### is_valid_ba_acknowledge_state: returns

| return | type    | always | condition |
| ------ | ------- | ------ | --------- |
| true   | boolean | yes    |           |

### is_valid_ba_acknowledge_state: example

```lua
local result = test_event:is_valid_ba_acknowledge_state()
--> result is true
```

## is_valid_bv method

The **is_valid_bv** method checks if the event is linked to a valid BV based on [**accepted_bvs**](sc_param.md#default-parameters) in the **ba_status** scope

If the **accepted_bvs** is configured, all broker cache information regarding the BVs linked to a service will be added to the event in a cache.bvs table. More details about this cache table [**here**](sc_broker.md#get_bvs_infos-example)

### is_valid_bv: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_bv: example

```lua
local result = test_event:is_valid_bv()
--> result is true or false
--[[
  --> test_event.event structure is:
  {
    --- event data ---
    cache = {
      bvs = {
        --- cache data ---
      }
      --- other cache data type ---
    }
  }
]]
```

## find_hostgroup_in_list method

The **find_hostgroup_in_list** method checks if one of the hostgroup in [**accepted_hostgroups**](sc_param.md#default-parameters) is linked to the host.

### find_hostgroup_in_list: returns

| return                                        | type    | always | condition               |
| --------------------------------------------- | ------- | ------ | ----------------------- |
| the name of the first hostgroup that is found | string  | no     | a hostgroup must  match |
| false                                         | boolean | no     | if no hostgroup matched |

### find_hostgroup_in_list: example

```lua
-- accepted_hostgroups are my_hostgroup_1 and my_hostgroup_2
-- host from event is linked to my_hostgroup_2

local result = test_event:find_hostgroup_in_list()
--> result is: "my_hostgroup_2"

-- accepted_hostgroups are my_hostgroup_1 and my_hostgroup_2
-- host from is linked to my_hostgroup_2712

result = test_event:find_hostgroup_in_list()
--> result is: false
```

## find_servicegroup_in_list method

The **find_servicegroup_in_list** method checks if one of the servicegroup in [**accepted_servicegroups**](sc_param.md#default-parameters) is linked to the service.

### find_servicegroup_in_list: returns

| return                                           | type    | always | condition                  |
| ------------------------------------------------ | ------- | ------ | -------------------------- |
| the name of the first servicegroup that is found | string  | no     | a servicegroup must  match |
| false                                            | boolean | no     | if no servicegroup matched |

### find_servicegroup_in_list: example

```lua
-- accepted_servicegroups are my_servicegroup_1 and my_servicegroup_2
-- service from event is linked to my_servicegroup_2

local result = test_event:find_servicegroup_in_list()
--> result is: "my_servicegroup_2"

-- accepted_servicegroups are my_servicegroup_1 and my_servicegroup_2
-- service from is linked to my_servicegroup_2712

result = test_event:find_servicegroup_in_list()
--> result is: false
```

## find_bv_in_list method

The **find_bv_in_list** method checks if one of the BV in [**accepted_bvs**](sc_param.md#default-parameters) is linked to the BA.

### find_bv_in_list: returns

| return                                 | type    | always | condition        |
| -------------------------------------- | ------- | ------ | ---------------- |
| the name of the first BV that is found | string  | no     | a BV must match  |
| false                                  | boolean | no     | if no BV matched |

### find_bv_in_list: example

```lua
-- accepted_bvs are my_bv_1 and my_bv_2
-- BA from event is linked to my_bv_2

local result = test_event:find_bv_in_list()
--> result is: "my_bv_2"

-- accepted_bvs are my_bv_1 and my_bv_2
-- BA from is linked to my_bv_2712

result = test_event:find_bv_in_list()
--> result is: false
```

## is_valid_poller method

The **is_valid_poller** method checks if the event is monitored from an accepted poller based on [**accepted_pollers**](sc_param.md#default-parameters) in the **host_status or service_status** scope

If the **accepted_pollers** is configured, all broker cache information regarding the poller linked to a host will be added to the event in a cache.poller index. More details about this cache index [**here**](sc_broker.md#get_instance-example)

### is_valid_poller: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_poller: example

```lua
local result = test_event:is_valid_poller()
--> result is true or false
--[[
  --> test_event.event structure is:
  {
    --- event data ---
    cache = {
      hostgroups = "my_poller_name"
      --- other cache data type ---
    }
  }
]]
```

## find_poller_in_list method

The **find_poller_in_list** method checks if one of the pollers in [**accepted_pollers**](sc_param.md#default-parameters) is monitoring the host.

### find_poller_in_list: returns

| return                                     | type    | always | condition            |
| ------------------------------------------ | ------- | ------ | -------------------- |
| the name of the first poller that is found | string  | no     | a poller must  match |
| false                                      | boolean | no     | if no poller matched |

### find_poller_in_list: example

```lua
-- accepted_pollers are my_poller_1 and my_poller_2
-- host from event is monitored from my_poller_2

local result = test_event:find_poller_in_list()
--> result is: "my_poller_2"

-- accepted_pollers are my_poller_1 and my_poller_2
-- host from event is monitored from my_poller_2712

result = test_event:find_poller_in_list()
--> result is: false
```

## is_valid_host_severity method

The **is_valid_host_severity** method checks if the event has an accepted host severity based on [**host_severity_threshold and host_severity_operator**](sc_param.md#default-parameters) in the **host_status or service_status** scope

If the **host_severity_threshold** is configured, all broker cache information regarding the severity linked to a host will be added to the event in a cache.host_severity index. More details about this cache index [**here**](sc_broker.md#get_severity-example)

### is_valid_host_severity: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_host_severity: example

```lua
local result = test_event:is_valid_host_severity()
--> result is true or false
--[[
  --> test_event.event structure is:
  {
    --- event data ---
    cache = {
      severity = {
        host = 2712
      }
      --- other cache data type ---
    }
  }
]]
```

## is_valid_service_severity method

The **is_valid_service_severity** method checks if the event has an accepted service severity based on [**service_severity_threshold and service_severity_operator**](sc_param.md#default-parameters) in the **service_status** scope

If the **service_severity_threshold** is configured, all broker cache information regarding the severity linked to a service will be added to the event in a cache.service_severity index. More details about this cache index [**here**](sc_broker.md#get_severity-example)

### is_valid_service_severity: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_service_severity: example

```lua
local result = test_event:is_valid_service_severity()
--> result is true or false
--[[
  --> test_event.event structure is:
  {
    --- event data ---
    cache = {
      severity = {
        service = 2712
      }
      --- other cache data type ---
    }
  }
]]
```

## is_valid_acknowledgement_event method

The **is_valid_acknowledgement_event** method checks if the acknowledgement event is accepted based on [**default_parameters**](sc_param.md#default-parameters) in the **acknowledgement** scope

head over the following chapters for more information

- [is_valid_host](#is_valid_host-method)
- [is_valid_author](#is_valid_author-method)
- [is_valid_poller](#is_valid_poller-method)
- [is_valid_host_severity](#is_valid_host_severity-method)
- [is_valid_event_status](#is_valid_event_status-method)
- [is_valid_service](#is_valid_service-method)
- [is_valid_service_severity](#is_valid_service_severity-method)
- [is_valid_servicegroup](#is_valid_servicegroup-method)
- [is_valid_hostgroup](#is_valid_hostgroup-method)

### is_valid_acknowledgement_event: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_acknowledgement_event: example

```lua
local result = test_event:is_valid_acknowledgement_event()
--> result is true or false 
```

## is_host_status_event_duplicated method

The **is_host_status_event_duplicated** method checks if the event is a duplicated one. for example, if host down event has already been received, it will consider the next down host event as a duplicated one. To enable this feature you must set the [**enable_host_status_dedup option to 1**](sc_param.md#default-parameters)

### is_host_status_event_duplicated: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_host_status_event_duplicated: example

```lua
local result = test_event:is_host_status_event_duplicated()
--> result is true or false
```

## is_service_status_event_duplicated method

The **is_service_status_event_duplicated** method checks if the event is a duplicated one. for example, if service critical event has already been received, it will consider the next critical service event as a duplicated one. To enable this feature you must set the [**enable_service_status_dedup option to 1**](sc_param.md#default-parameters)

### is_service_status_event_duplicated: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_service_status_event_duplicated: example

```lua
local result = test_event:is_service_status_event_duplicated()
--> result is true or false
```

## is_valid_downtime_event method

The **is_valid_downtime_event** method checks if the downtime event is valid based on [**default_parameters**](sc_param.md#default-parameters) in the **downtime** scope

head over the following chapters for more information

- [is_valid_host](#is_valid_host-method)
- [is_valid_author](#is_valid_author-method)
- [is_valid_poller](#is_valid_poller-method)
- [is_valid_host_severity](#is_valid_host_severity-method)
- [is_valid_event_status](#is_valid_event_status-method)
- [is_valid_service](#is_valid_service-method)
- [is_valid_service_severity](#is_valid_service_severity-method)
- [is_valid_servicegroup](#is_valid_servicegroup-method)
- [is_valid_hostgroup](#is_valid_hostgroup-method)
- [get_downtime_host_status](#get_downtime_host_status-method)
- [get_downtime_service_status](#get_downtime_service_status-method)

### is_valid_downtime_event: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_downtime_event: example

```lua
local result = test_event:is_valid_downtime_event()
--> result is true or false 
```

## get_downtime_host_status method

The **get_downtime_host_status** method retrieve the status of the host in a host downtime event

### get_downtime_host_status: returns

| return            | type   | always | condition |
| ----------------- | ------ | ------ | --------- |
| event status code | number | yes    |           |

### get_downtime_host_status: example

```lua
  local result = test_event:get_downtime_host_status()
  --> result is 0 or 1 (UP or DOWN)
```

## get_downtime_service_status method

The **get_downtime_service_status** method retrieve the status of the host in a host downtime event

### get_downtime_service_status: returns

| return            | type   | always | condition |
| ----------------- | ------ | ------ | --------- |
| event status code | number | yes    |           |

### get_downtime_service_status: example

```lua
  local result = test_event:get_downtime_service_status()
  --> result is 0 or 1 or 2 or 3 (OK, WARNING, CRITICAL, UNKNOWN)
```

## is_valid_author method

The **is_valid_author** method checks if the author of a comment is valid according to the [**accepted_authors parameter**](sc_param.md#default-parameters).

### is_valid_author: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_author: example

```lua
local result = test_event:is_valid_author()
--> result is true or false
```

## is_downtime_event_useless method

The **is_downtime_event_useless** method checks if the downtime event is a true start or end of a downtime.

head over the following chapters for more information

- [is_valid_downtime_event_start](#is_valid_downtime_event_start-method)
- [is_valid_downtime_event_end](#is_valid_downtime_event_end-method)

### is_downtime_event_useless: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_downtime_event_useless: example

```lua
local result = test_event:is_downtime_event_useless()
--> result is true or false
```

## is_valid_downtime_event_start method

The **is_valid_downtime_event_start** method checks if the downtime event is a true start of downtime event. It checks if there is no `actual_end_time` information in the downtime and that the `actual_start_time` is set. Otherwise it is not a true start of downtime event.

### is_valid_downtime_event_start: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_downtime_event_start: example

```lua
local result = test_event:is_valid_downtime_event_start()
--> result is true or false
```

## is_valid_downtime_event_end method

The **is_valid_downtime_event_end** method checks if the downtime event is a true end of downtime event. It checks if there the `deletion_time` is set. Otherwise it is not a true end of downtime event.

### is_valid_downtime_event_end: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_downtime_event_end: example

```lua
local result = test_event:is_valid_downtime_event_end()
--> result is true or false
```

## build_outputs method

The **build_outputs** method adds short_output and long_output entries in the event table. output entry will be equal to one or another depending on the [**use_long_output parameter](sc_param.md#default-parameters).

### build_outputs: example

```lua
local result = test_event:build_outputs()
```

## is_valid_storage_event method

**DEPRECATED** does nothing
