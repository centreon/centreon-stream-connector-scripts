# Documentation of the sc_macros module

- [Documentation of the sc_macros module](#documentation-of-the-sc_macros-module)
  - [Introduction](#introduction)
  - [Stream connectors macro explanation](#stream-connectors-macro-explanation)
    - [Event macros](#event-macros)
    - [Cache macros](#cache-macros)
    - [Group macros](#group-macros)
      - [group type](#group-type)
      - [output format](#output-format)
      - [regex filter](#regex-filter)
      - [examples](#examples)
    - [Transformation flags](#transformation-flags)
  - [Module initialization](#module-initialization)
    - [Module constructor](#module-constructor)
    - [constructor: Example](#constructor-example)
  - [replace_sc_macro method](#replace_sc_macro-method)
    - [replace_sc_macro: parameters](#replace_sc_macro-parameters)
    - [replace_sc_macroreplace_sc_macro: returns](#replace_sc_macroreplace_sc_macro-returns)
    - [replace_sc_macro: example](#replace_sc_macro-example)
  - [get_cache_macro method](#get_cache_macro-method)
    - [get_cache_macro: parameters](#get_cache_macro-parameters)
    - [get_cache_macro: returns](#get_cache_macro-returns)
    - [get_cache_macro: example](#get_cache_macro-example)
  - [get_event_macro method](#get_event_macro-method)
    - [get_event_macro: parameters](#get_event_macro-parameters)
    - [get_event_macro: returns](#get_event_macro-returns)
    - [get_event_macro: example](#get_event_macro-example)
  - [get_group_macro method](#get_group_macro-method)
    - [get_group_macro: parameters](#get_group_macro-parameters)
    - [get_group_macro: returns](#get_group_macro-returns)
    - [get_group_macro: example](#get_group_macro-example)
  - [convert_centreon_macro method](#convert_centreon_macro-method)
    - [convert_centreon_macro: parameters](#convert_centreon_macro-parameters)
    - [convert_centreon_macro: returns](#convert_centreon_macro-returns)
    - [convert_centreon_macro: example](#convert_centreon_macro-example)
  - [get_centreon_macro method](#get_centreon_macro-method)
    - [get_centreon_macro: parameters](#get_centreon_macro-parameters)
    - [get_centreon_macro: returns](#get_centreon_macro-returns)
    - [get_centreon_macro: example](#get_centreon_macro-example)
  - [get_transform_flag method](#get_transform_flag-method)
    - [get_transform_flag: parameters](#get_transform_flag-parameters)
    - [get_transform_flag: returns](#get_transform_flag-returns)
    - [get_transform_flag: example](#get_transform_flag-example)
  - [transform_date method](#transform_date-method)
    - [transform_date: parameters](#transform_date-parameters)
    - [transform_date: returns](#transform_date-returns)
    - [transform_date: example](#transform_date-example)
  - [transform_short method](#transform_short-method)
    - [transform_short: parameters](#transform_short-parameters)
    - [transform_short: returns](#transform_short-returns)
    - [transform_short: example](#transform_short-example)
  - [transform_type method](#transform_type-method)
    - [transform_type: parameters](#transform_type-parameters)
    - [transform_type: returns](#transform_type-returns)
    - [transform_type: example](#transform_type-example)
  - [transform_state method](#transform_state-method)
    - [transform_state: parameters](#transform_state-parameters)
    - [transform_state: returns](#transform_state-returns)
    - [transform_state: example](#transform_state-example)
  - [transform_number method](#transform_number-method)
    - [transform_number: parameters](#transform_number-parameters)
    - [transform_number: returns](#transform_number-returns)
    - [transform_number: example](#transform_number-example)
  - [transform_string method](#transform_string-method)
    - [transform_string: parameters](#transform_string-parameters)
    - [transform_string: returns](#transform_string-returns)
    - [transform_string: example](#transform_string-example)
  - [get_hg_macro method](#get_hg_macro-method)
    - [get_hg_macro: parameters](#get_hg_macro-parameters)
    - [get_hg_macro: returns](#get_hg_macro-returns)
    - [get_hg_macro: example](#get_hg_macro-example)
  - [get_sg_macro method](#get_sg_macro-method)
    - [get_sg_macro: parameters](#get_sg_macro-parameters)
    - [get_sg_macro: returns](#get_sg_macro-returns)
    - [get_sg_macro: example](#get_sg_macro-example)
  - [get_bv_macro method](#get_bv_macro-method)
    - [get_bv_macro: parameters](#get_bv_macro-parameters)
    - [get_bv_macro: returns](#get_bv_macro-returns)
    - [get_bv_macro: example](#get_bv_macro-example)
  - [build_group_macro_value method](#build_group_macro_value-method)
    - [build_group_macro_value: parameters](#build_group_macro_value-parameters)
    - [build_group_macro_value: returns](#build_group_macro_value-returns)
    - [build_group_macro_value: example](#build_group_macro_value-example)
  - [group_macro_format_table method](#group_macro_format_table-method)
    - [group_macro_format_table: parameters](#group_macro_format_table-parameters)
    - [group_macro_format_table: returns](#group_macro_format_table-returns)
    - [group_macro_format_table: example](#group_macro_format_table-example)
  - [group_macro_format_inline method](#group_macro_format_inline-method)
    - [group_macro_format_inline: parameters](#group_macro_format_inline-parameters)
    - [group_macro_format_inline: returns](#group_macro_format_inline-returns)
    - [group_macro_format_inline: example](#group_macro_format_inline-example)
  - [build_converted_string_for_cache_and_event_macro method](#build_converted_string_for_cache_and_event_macro-method)
    - [build_converted_string_for_cache_and_event_macro: parameters](#build_converted_string_for_cache_and_event_macro-parameters)
    - [build_converted_string_for_cache_and_event_macro: returns](#build_converted_string_for_cache_and_event_macro-returns)
    - [build_converted_string_for_cache_and_event_macro: example](#build_converted_string_for_cache_and_event_macro-example)

## Introduction

The sc_macros module provides methods to handle a stream connector oriented macro system such as {cache.host.name} and Centreon standard macro such as $HOSTALIAS$. It has been made in OOP (object oriented programming)

## Stream connectors macro explanation

There are three kind of stream connectors macro:

- **event macros**
- **cache macros**
- **group macros**

The first type refers to data that are accessible right from the event. The second type refers to data that needs to be retrieved from the broker cache. And the last type refers to three kind of group object in Centreon (hostgroups, servicegroups and Business views)

### Event macros

This one is quite easy to understand. The macro syntaxt is `{macro_name}` where *macro_name* is a property of an event. For example, for a service_status neb event all macro names are available [there](broker_data_structure.md#Service_status).

This means that it is possible to use the following macros

```lua
"{service_id}" -- will be replaced by the service_id
"{output}" -- will be replaced by the service output
"{last_check}" -- will be replaced by the last_check timestamp
"{state_type}" -- will be replaced by the state type value (0 or 1 for SOFT or HARD)
"{state}" -- will be replaced by the state of the service (0, 1, 2, 3 for OK, WARNING, CRITICAL, UNKNOWN)
```

### Cache macros

This one is a bit more complicated. The purpose is to retrieve information from the event cache using a macro. If you rely on the centreon-stream-connectors-lib to fill the cache, here is what you need to know.

There are 5 kind of cache

- host cache (for any event that is linked to a host, which means any event but BA events)
- service cache (for any event that is linked to a service)
- poller cache (for any event that is linked to a poller, which means any event but BA events)
- severity cache  (for any event that is linked to a host, which means any event but BA events)
- ba cache (only for a ba_status event)

For example, if we want to retrieve the description of a service in the cache (because the description is not provided in the event data). We will use `{cache.service.description}`.

For example, for a service_status neb event, all cache macros are available [there](sc_broker.md#get_service_all_infos-example)

This means that it is possible to use the following macros

```lua
"{cache.service.description}" -- will be replaced by the service description
"{cache.service.notes}" -- will be replaced by the service notes
"{cache.service.last_time_critical}" -- will be replaced by the service last_time_critical timestamp
```

cache values for hosts: [list](sc_broker.md#get_host_all_infos-example)
cache values for services: [list](sc_broker.md#get_services_all_infos-example)
cache values for BAs: [list](sc_broker.md#get_ba_infos-example)
cache values for pollers:
  
- {cache.instance.name}
- {cache.instance.id}

cache values for severities:

- {cache.severity.service}
- {cache.severity.host}

### Group macros

Group macros are a very special kind of macros that allows you to retrieve the hostgroups, services groups or BVs that are linked to your host/service/BA. The syntax goes as follow: `{groups(<group_type>,<output_format>,<regex_filter>)}`

It means that when using a group macro, you need to specify which kind of group you want, its output format and the filter you are going to use.

#### group type

When using a group macro, you need to set a group type. You have three possibilities

- hg (to retrieve hostgroups)
- sg (to retrieve servicegroups)
- bv (to retrives business views)

#### output format

When using a group, you need to set an output format. You have two possibilities

- table (each found group is going to be stored in a table structure)
- inline (each found group is going to be stored in a string and each value will be separated using a `,`)

#### regex filter

When using a group, you need to set a regex filter. You accept everything using `.*` or you can accept groups that will only have alpha numerical characters in their name with `^%w+$`.

[More information about regex in lua](https://www.lua.org/pil/20.2.html)

#### examples

for a service linked to:

| hostgroups | servicegroups  |
| ---------- | -------------- |
| HG_1       | FOO_the-first  |
| HG_2       | FOO_the-second |
| HG_3       | another_sg     |

get all hostgroups in a table format:

| macro                   | result                     |
| ----------------------- | -------------------------- |
| `{groups(hg,table,.*)}` | `["HG_1", "HG_2", "HG_3"]` |

get all servicegroups that start with "FOO" in an inline format: `{groups}

| macro                        | result                           |
| ---------------------------- | -------------------------------- |
| `{groups(sg,inline,^FOO.*)}` | `"FOO_the-first,FOO_the-second"` |

### Transformation flags

You can use transformation flags on stream connectors macros. Those flags purpose is to convert the given value to something more appropriate. For example, you can convert a timestamp to a human readable date.

Here is the list of all available flags

| flag name | purpose                                                                                                                     | without flag                                 | with flag              |
| --------- | --------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- | ---------------------- |
| _scdate   | convert a timestamp to a date                                                                                               | 1623691758                                   | 2021-06-14 19:29:18    |
| _sctype   | convert a state type number to its human value                                                                              | 0                                            | SOFT                   |
| _scstate  | convert a state to its human value                                                                                          | 2                                            | WARNING (for a servie) |
| _scshort  | only retrieve the first line of a string (mostly use to get the output instead of the long output of a service for exemple) | "my output\n this is part of the longoutput" | "my output"            |
| _scnumber | convert a string to a number                                                                                                | "1"                                          | 1                      |
| _scstring | convert anything to a string                                                                                                | false                                        | "false"                |

The **_scdate** is a bit specific because you can change the date format using the [**timestamp_conversion_format parameter**](sc_param.md#default-parameters)

With all that information in mind, we can use the following macros

```lua
"{cache.service.last_time_critical}" -- will be replaced by the service last_time_critical timestamp
"{cache.service.last_time_critical_scdate}" -- will be replaced by the service last_time_critical converted in a human readable date format
"{state_type_sctype}" -- will be replaced by the service state_type in a human readable format (SOFT or HARD)
"{state_scstate}" -- will be replaced by the servie state in a human readable format (OK, WARNING, CRITICAL or UNKNOWN)
"{output_scshort}" -- will be replaced by the first line of the service output
"{cache.severity.service_scnumber}" -- will be replaced by 1 instead of "1"
"{acknowledged_scstring}" -- will be replaced by "false" instead of false 
```

## Module initialization

Since this is OOP, it is required to initiate your module

### Module constructor

Constructor can be initialized with two parameters, if the second one is not provided it will use a default value

- params. This is a table of all the stream connectors parameters
- sc_logger. This is an instance of the sc_logger module

If you don't provide the sc_logger parameter it will create a default sc_logger instance with default parameters ([sc_logger default params](./sc_logger.md#module-initialization))

### constructor: Example

```lua
-- load modules
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_macros = require("centreon-stream-connecotrs-lib.sc_macros")

-- initiate "mandatory" informations for the logger module
local logfile = "/var/log/test_logger.log"
local severity = 1

-- create a new instance of the sc_logger module
local test_logger = sc_logger.new(logfile, severity)
-- some stream connector params

local params = {
  my_param = "my_value"
}

-- create a new instance of the sc_macros module
local test_macros = sc_macros.new(params, test_logger)
```

## replace_sc_macro method

The **replace_sc_macro** method replaces all stream connector macro in a string with its value.

head over the following chapters for more information

- [Stream connectors macro explanation](#stream-connectors-macro-explanation)
- [get_cache_macro](#get_cache_macro-method)
- [get_event_macro](#get_event_macro-method)

### replace_sc_macro: parameters

| parameter              | type   | optional | default value |
| ---------------------- | ------ | -------- | ------------- |
| the string with macros | string | no       |               |
| the event              | table  | no       |               |

### replace_sc_macroreplace_sc_macro: returns

| return           | type   | always | condition |
| ---------------- | ------ | ------ | --------- |
| converted_string | string | yes    |           |

### replace_sc_macro: example

```lua
local string = "my host id is {host_id}, name is {cache.host.name}, its status is {state_scstate} and its state type is {state_type_scstate}"
local event = {
  host_id = 2712,
  state_type = 1,
  state = 0
  cache = {
    host = {
      name = "Tatooine"
    }
  }
}

local result = test_macros:replace_sc_macro(string, event)
--> result is "my host id is 2712, name is Tatooine, its status is UP and its state type is HARD"
```

## get_cache_macro method

The **get_cache_macro** method replaces a stream connector cache macro by its value.

head over the following chapters for more information

- [Transformation flags](#transformation-flags)
- [Cache macros](#cache-macros)
- [get_transform_flag](#get_transform_flag-method)

### get_cache_macro: parameters

| parameter      | type   | optional | default value |
| -------------- | ------ | -------- | ------------- |
| the macro name | string | no       |               |
| the event      | table  | no       |               |

### get_cache_macro: returns

| return             | type                        | always | condition                                                         |
| ------------------ | --------------------------- | ------ | ----------------------------------------------------------------- |
| false              | boolean                     | no     | if the macro is not a cache macro or value can't be find in cache |
| value of the macro | boolean or string or number | no     | the value that has been found in the cache                        |

### get_cache_macro: example

```lua
local macro = "{cache.host.name}"
local event = {
  host_id = 2712,
  state_type = 1,
  state = 0
  cache = {
    host = {
      name = "Tatooine"
    }
  }
}

local result = test_macros:get_cache_macro(macro, event)
--> result is "Tatooine"

macro = "{host_id}"
result = test_macros:get_cache_macro(macro, event)
--> result is false, host_id is in the event table, not in a table inside the cache table of the event
```

## get_event_macro method

The **get_event_macro** method replaces a stream connector event macro by its value.

head over the following chapters for more information

- [Transformation flags](#transformation-flags)
- [Event macros](#event-macros)
- [get_transform_flag](#get_transform_flag-method)

### get_event_macro: parameters

| parameter      | type   | optional | default value |
| -------------- | ------ | -------- | ------------- |
| the macro name | string | no       |               |
| the event      | table  | no       |               |

### get_event_macro: returns

| return             | type                        | always | condition                                  |
| ------------------ | --------------------------- | ------ | ------------------------------------------ |
| false              | boolean                     | no     | if the macro is not an event macro         |
| value of the macro | boolean or string or number | no     | the value that has been found in the event |

### get_event_macro: example

```lua
local macro = "{host_id}"
local event = {
  host_id = 2712,
  state_type = 1,
  state = 0
  cache = {
    host = {
      name = "Tatooine"
    }
  }
}

local result = test_macros:get_event_macro(macro, event)
--> result is "2712"

macro = "{cache.host.name}"
result = test_macros:get_event_macro(macro, event)
--> result is false, cache.host.name is in the cache table, not directly in the event table
```

## get_group_macro method

The **get_group_macro** method replaces a stream connector group macro by its value.

head over the following chapters for more information

- [Group macros](#group-macros)

### get_group_macro: parameters

| parameter      | type   | optional | default value |
| -------------- | ------ | -------- | ------------- |
| the macro name | string | no       |               |
| the event      | table  | no       |               |

### get_group_macro: returns

| return             | type                        | always | condition                                  |
| ------------------ | --------------------------- | ------ | ------------------------------------------ |
| false              | boolean                     | no     | if the macro is not a group macro          |
| value of the macro | boolean or string or number | no     | the value that has been found in the event |

### get_group_macro: example

```lua
local macro = "{groups(hg,table,^%w+$)}"
local event = {
  host_id = 2712,
  state_type = 1,
  state = 0
  cache = {
    hostgroups = {
      [1] = {
        group_id = 27,
        group_name = "hg_1"
      },
      [2] = {
        group_id = 12,
        group_name = "hg2"
      },
      [3] = {
        group_id = 1991
        group_name = "hg3"
      }
    }
  }
}

local result = test_macros:get_group_macro(macro, event)
--> result is
--[[
  {
    [1] = "hg2",
    [2] = "hg3"
  }
]] 

macro = "{groups(foo,bar,.*)}"
result = test_macros:get_group_macro(macro, event)
--> result is false, foo is not a valid group type and bar is not a valid format type
```

## convert_centreon_macro method

The **convert_centreon_macro** method replaces all centreon macro in a string (such as $HOSTALIAS$) by its value. It will first convert it to its stream connector macro counterpart and then convert the stream connector macro to its value.

### convert_centreon_macro: parameters

| parameter              | type   | optional | default value |
| ---------------------- | ------ | -------- | ------------- |
| the string with macros | string | no       |               |
| the event              | table  | no       |               |

### convert_centreon_macro: returns

| return           | type   | always | condition                                  |
| ---------------- | ------ | ------ | ------------------------------------------ |
| converted string | string | yes    | the value that has been found in the event |

### convert_centreon_macro: example

```lua
local string = "We should go to $HOSTNAME$ but address $HOSTADDRESS$ is not on open street map and by the way there is $HOSTALIAS$"
local event = {
  host_id = 2712,
  state_type = 1,
  state = 0
  cache = {
    host = {
      name = "Tatooine",
      address = "27.12.19.91"
      alias = "Too much sand"
    }
  }
}

local result = test_macros:convert_centreon_macro(macro, event)
--> result is "We should go to Tatooine but address 27.12.19.91 is not on open street map and by the way there is Too much sand"
```

## get_centreon_macro method

The **get_centreon_macro** method retrieves the given macro in a Centreon macro list set up in the sc_macros module constructor and returns its associated stream connector macro.

### get_centreon_macro: parameters

| parameter             | type   | optional | default value |
| --------------------- | ------ | -------- | ------------- |
| the name of the macro | string | no       |               |

### get_centreon_macro: returns

| return                                 | type    | always | condition                                              |
| -------------------------------------- | ------- | ------ | ------------------------------------------------------ |
| false                                  | boolean | no     | if the macro is not found in the predefined macro list |
| the appropriate stream connector macro | string  | no     | the value that has been found in the event             |

### get_centreon_macro: example

```lua
local macro = "$HOSTALIAS$"

local result = test_macros:get_centreon_macro(macro)
--> result is "{cache.host.alias}"

macro = "$ENDOR$"

result = test_macros:get_centreon_macro(macro)
--> result is false
```

## get_transform_flag method

The **get_transform_flag** method gets the flag from a macro if there is one

head over the following chapters for more information

- [Transformation flags](#transformation-flags)

### get_transform_flag: parameters

| parameter             | type   | optional | default value |
| --------------------- | ------ | -------- | ------------- |
| the name of the macro | string | no       |               |

### get_transform_flag: returns

| return | type          | always | condition                                     |
| ------ | ------------- | ------ | --------------------------------------------- |
| macro  | string        | yes    | the name of the macro                         |
| flag   | string or nil | yes    | the macro transformation flag if there is one |

### get_transform_flag: example

```lua
local macro = "{state_scstate}"

local result, flag = test_macros:get_transform_flag(macro)
--> result is "state" flag is "state" (_sc prefix is removed)

macro = "{last_check}"

result, flag = test_macros:get_transform_flag(macro)
--> result is "last_check" flag is nil
```

## transform_date method

The **transform_date** method converts a timestamp into a human readable date. It is possible to chose the date format using the [**timestamp_conversion_format parameter**](sc_param.md#default-parameters) and get help from the [**lua documentation**](https://www.lua.org/pil/22.1.html) for the option syntax.

### transform_date: parameters

| parameter         | type   | optional | default value |
| ----------------- | ------ | -------- | ------------- |
| a timestamp value | number | no       |               |

### transform_date: returns

| return | type   | always | condition                   |
| ------ | ------ | ------ | --------------------------- |
| date   | string | yes    | timestamp converted to date |

### transform_date: example

```lua
local timestamp = 1623691758

local result = test_macros:transform_date(timestamp)
--> result is "2021-06-14 19:29:18"
```

## transform_short method

The **transform_short** method keeps the first line of a string.

### transform_short: parameters

| parameter | type   | optional | default value |
| --------- | ------ | -------- | ------------- |
| a string  | string | no       |               |

### transform_short: returns

| return                     | type   | always | condition |
| -------------------------- | ------ | ------ | --------- |
| the first line of a string | string | yes    |           |

### transform_short: example

```lua
local string = "Paris is a nice city\n Mont de Marsan is way better"

local result, flag = test_macros:transform_short(string)
--> result is "Paris is a nice city"
```

## transform_type method

The **transform_type** method transforms a 0 or 1 value into SOFT or HARD

### transform_type: parameters

| parameter | type   | optional | default value |
| --------- | ------ | -------- | ------------- |
| 0 or 1    | number | no       |               |

### transform_type: returns

| return       | type   | always | condition |
| ------------ | ------ | ------ | --------- |
| SOFT or HARD | string | yes    |           |

### transform_type: example

```lua
local state_type = 0

local result = test_macros:transform_type(state_type)
--> result is "SOFT"
```

## transform_state method

The **transform_state** method transforms a status code into its human readable status (e.g: UP, DOWN, WARNING, CRITICAL...)

### transform_state: parameters

| parameter    | type   | optional | default value |
| ------------ | ------ | -------- | ------------- |
| 0, 1, 2 or 3 | number | no       |               |
| the event    | table  | no       |               |

### transform_state: returns

| return            | type   | always | condition |
| ----------------- | ------ | ------ | --------- |
| the status string | string | yes    |           |

### transform_state: example

```lua
local event = {
  service_id = 2712,
  element = 24,
  category = 1,
  host_id = 1991
}

local state = 1

local result = test_macros:transform_state(state, event)
--> result is "WARNING" because it is a service (category 1 = neb, element 24 = service_status event)


event = {
  element = 14,
  category = 1,
  host_id = 1991
}

result = test_macros:transform_state(state, event)
--> result is "DOWN" because it is a service (category 1 = neb, element 14 = host_status event)
```

## transform_number method

The **transform_number** method transforms a string value into a number

### transform_number: parameters

| parameter | type   | optional | default value |
| --------- | ------ | -------- | ------------- |
| a string  | string | no       |               |

### transform_number: returns

| return   | type   | always | condition |
| -------- | ------ | ------ | --------- |
| a number | number | yes    |           |

### transform_number: example

```lua
local string_number = "0"

local result = test_macros:transform_number(string_number)
--> result is 0
```

## transform_string method

The **transform_string** method transforms any value into a string

### transform_string: parameters

| parameter | type | optional | default value |
| --------- | ---- | -------- | ------------- |
| anything  | any  | no       |               |

### transform_string: returns

| return   | type   | always | condition |
| -------- | ------ | ------ | --------- |
| a string | string | yes    |           |

### transform_string: example

```lua
local boolean = false

local result = test_macros:transform_string(boolean)
--> result is "false"
```

## get_hg_macro method

The **get_hg_macro** method retrieves hostgroup information and make it available as a macro

### get_hg_macro: parameters

| parameter | type  | optional | default value |
| --------- | ----- | -------- | ------------- |
| the event | table | no       |               |

### get_hg_macro: returns

| return                                                  | type   | always | condition |
| ------------------------------------------------------- | ------ | ------ | --------- |
| all hostgroups                                          | table  | yes    |           |
| the name of the index that is linked to hostgroups name | string | yes    |           |

### get_hg_macro: example

```lua
local event = {
  host_id = 2712,
  state_type = 1,
  state = 0
  cache = {
    hostgroups = {
      [1] = {
        group_id = 27,
        group_name = "hg_1"
      },
      [2] = {
        group_id = 12,
        group_name = "hg2"
      },
      [3] = {
        group_id = 1991
        group_name = "hg3"
      }
    }
  }
}

local hostgroups, index_name = test_macros:get_hg_macro(event)
--> hostgroups is:
--[[
  hostgroups = {
      [1] = {
        group_id = 27,
        group_name = "hg_1"
      },
      [2] = {
        group_id = 12,
        group_name = "hg2"
      },
      [3] = {
        group_id = 1991
        group_name = "hg3"
      }
    }
]] 
--> index_name is: group_name
```

## get_sg_macro method

The **get_sg_macro** method retrieves servicegroup information and make it available as a macro

### get_sg_macro: parameters

| parameter | type  | optional | default value |
| --------- | ----- | -------- | ------------- |
| the event | table | no       |               |

### get_sg_macro: returns

| return                                                     | type   | always | condition |
| ---------------------------------------------------------- | ------ | ------ | --------- |
| all servicegroups                                          | table  | yes    |           |
| the name of the index that is linked to servicegroups name | string | yes    |           |

### get_sg_macro: example

```lua
local event = {
  host_id = 2712,
  state_type = 1,
  state = 0
  cache = {
    hostgroups = {
      [1] = {
        group_id = 27,
        group_name = "sg_1"
      },
      [2] = {
        group_id = 12,
        group_name = "sg2"
      },
      [3] = {
        group_id = 1991
        group_name = "sg3"
      }
    }
  }
}

local servicegroups, index_name = test_macros:get_sg_macro(event)
--> servicegroups is:
--[[
  servicegroups = {
      [1] = {
        group_id = 27,
        group_name = "sg_1"
      },
      [2] = {
        group_id = 12,
        group_name = "sg2"
      },
      [3] = {
        group_id = 1991
        group_name = "sg3"
      }
    }
]] 
--> index_name is: group_name
```

## get_bv_macro method

The **get_bv_macro** method retrieves business views information and make it available as a macro

### get_bv_macro: parameters

| parameter | type  | optional | default value |
| --------- | ----- | -------- | ------------- |
| the event | table | no       |               |

### get_bv_macro: returns

| return                                                      | type   | always | condition |
| ----------------------------------------------------------- | ------ | ------ | --------- |
| all business views                                          | table  | yes    |           |
| the name of the index that is linked to business views name | string | yes    |           |

### get_bv_macro: example

```lua
local event = {
  ba_id = 2712,
  state = 0
  cache = {
    bvs = {
      [1] = {
        bv_id = 27,
        bv_name = "bv_1"
      },
      [2] = {
        bv_id = 12,
        bv_name = "bv2"
      },
      [3] = {
        bv_id = 1991
        bv_name = "bv3"
      }
    }
  }
}

local bvs, index_name = test_macros:get_bv_macro(event)
--> bvs is:
--[[
  bvs = {
      [1] = {
        bv_id = 27,
        bv_name = "bv_1"
      },
      [2] = {
        bv_id = 12,
        bv_name = "bv2"
      },
      [3] = {
        bv_id = 1991
        bv_name = "bv3"
      }
    }
]] 
--> index_name is: bv_name
```

## build_group_macro_value method

The **build_group_macro_value** method builds the value that must replace the macro (it will also put it in the desired format)

### build_group_macro_value: parameters

| parameter                                                | type   | optional | default value |
| -------------------------------------------------------- | ------ | -------- | ------------- |
| the group data                                           | table  | no       |               |
| the name of the index where the group name will be found | string | no       |               |
| the format in which the result will be built             | string | no       |               |
| the regex that will filter found groups                  | string | no       |               |

### build_group_macro_value: returns

| return                              | type            | always | condition                           |
| ----------------------------------- | --------------- | ------ | ----------------------------------- |
| boolean                             | boolean         | yes    |                                     |
| the macro value in the right format | string or table | no     | only if the desired format is valid |

### build_group_macro_value: example

```lua
local group_data = {
      [1] = {
        bv_id = 27,
        bv_name = "bv_1"
      },
      [2] = {
        bv_id = 12,
        bv_name = "bv2"
      },
      [3] = {
        bv_id = 1991
        bv_name = "bv3"
      }
    }
local index_name = "bv_name"
local format = "inline"
local regex = "^%w+$"

local code, result = test_macros:build_group_macro_value(group_data, index_name, format, regex)
--> code is: true
--> result is: "bv2,bv3"

format = "bad_format"
code, result = test_macros:build_group_macro_value(group_data, index_name, format, regex)
--> code is: false
--> result is: nil
```

## group_macro_format_table method

The **group_macro_format_table** method transforms the given macro value into a table (does nothing as is)

### group_macro_format_table: parameters

| parameter       | type  | optional | default value |
| --------------- | ----- | -------- | ------------- |
| the macro value | table | no       |               |

### group_macro_format_table: returns

| return                     | type  | always | condition |
| -------------------------- | ----- | ------ | --------- |
| the macro value as a table | table | yes    |           |

### group_macro_format_table: example

```lua
local macro_value = {
  [1] = "bv2",
  [2] = "bv3"
}

local result = test_macros:group_macro_format_table(macro_value)
--> result is: 
--[[
  result = {
    [1] = "bv2",
    [2] = "bv3"
  }
]]--
```

## group_macro_format_inline method

The **group_macro_format_inline** method transforms the give macro value into a string with values separated using comas

### group_macro_format_inline: parameters

| parameter       | type  | optional | default value |
| --------------- | ----- | -------- | ------------- |
| the macro value | table | no       |               |

### group_macro_format_inline: returns

| return                      | type   | always | condition |
| --------------------------- | ------ | ------ | --------- |
| the macro value as a string | string | yes    |           |

### group_macro_format_inline: example

```lua
local macro_value = {
  [1] = "bv2",
  [2] = "bv3"
}

local result = test_macros:group_macro_format_inline(macro_value)
--> result is: "bv2,bv3"
```

## build_converted_string_for_cache_and_event_macro method

The **build_converted_string_for_cache_and_event_macro** method replace a cache or event macro in a string that may contain those macros

### build_converted_string_for_cache_and_event_macro: parameters

| parameter                          | type   | optional | default value |
| ---------------------------------- | ------ | -------- | ------------- |
| the macro value                    | any    | no       |               |
| the macro name                     | string | no       |               |
| the string that may contain macros | string | no       |               |

### build_converted_string_for_cache_and_event_macro: returns

| return                              | type   | always | condition |
| ----------------------------------- | ------ | ------ | --------- |
| the string with the macro converted | string | yes    |           |

### build_converted_string_for_cache_and_event_macro: example

```lua
local string_with_macros = "my cache macro {cache.host.name}
local macro_name = "{cache.host.name}"
local macro_value = "Arcadia"

local result = test_macros:build_converted_string_for_cache_and_event_macro(macro_value, macro_name, string_with_macros)
--> result is: "my cache macro Arcadia"
```
