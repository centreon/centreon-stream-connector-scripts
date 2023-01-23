# Documentation of the sc_flush module

- [Documentation of the sc\_flush module](#documentation-of-the-sc_flush-module)
  - [Introduction](#introduction)
  - [Module initialization](#module-initialization)
    - [Module constructor](#module-constructor)
    - [constructor: Example](#constructor-example)
  - [add\_queue\_metadata method](#add_queue_metadata-method)
    - [add\_queue\_metadata: parameters](#add_queue_metadata-parameters)
    - [add\_queue\_metadata: example](#add_queue_metadata-example)
  - [flush\_all\_queues method](#flush_all_queues-method)
    - [flush\_all\_queues: parameters](#flush_all_queues-parameters)
    - [flush\_all\_queues: returns](#flush_all_queues-returns)
    - [flush\_all\_queues: example](#flush_all_queues-example)
  - [reset\_all\_queues method](#reset_all_queues-method)
    - [reset\_all\_queues: example](#reset_all_queues-example)
  - [get\_queues\_size method](#get_queues_size-method)
    - [get\_queues\_size: returns](#get_queues_size-returns)
    - [get\_queues\_size: example](#get_queues_size-example)
  - [flush\_mixed\_payload method](#flush_mixed_payload-method)
    - [flush\_mixed\_payload: parameters](#flush_mixed_payload-parameters)
    - [flush\_mixed\_payload: returns](#flush_mixed_payload-returns)
    - [flush\_mixed\_payload: example](#flush_mixed_payload-example)
  - [flush\_homogeneous\_payload method](#flush_homogeneous_payload-method)
    - [flush\_homogeneous\_payload: parameters](#flush_homogeneous_payload-parameters)
    - [flush\_homogeneous\_payload: returns](#flush_homogeneous_payload-returns)
    - [flush\_homogeneous\_payload: example](#flush_homogeneous_payload-example)
  - [flush\_payload method](#flush_payload-method)
    - [flush\_payload: parameters](#flush_payload-parameters)
    - [flush\_payload: returns](#flush_payload-returns)
    - [flush\_payload: example](#flush_payload-example)

## Introduction

The sc_flush module provides methods to help handling queues of events in stream connectors. It has been made in OOP (object oriented programming)

## Module initialization

Since this is OOP, it is required to initiate your module

### Module constructor

Constructor can be initialized with two parameter if the second one is not provided it will use a default value.

- params. This is the table of all stream connectors parameters
- sc_logger. This is an instance of the sc_logger module

If you don't provide this parameter it will create a default sc_logger instance with default parameters ([sc_logger default params](./sc_logger.md#module-initialization))

### constructor: Example

```lua
-- load modules
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_flush = require("centreon-stream-connectors-lib.sc_flush")

-- initiate "mandatory" informations for the logger module
local logfile = "/var/log/test_logger.log"
local severity = 1

-- create a new instance of the sc_logger module
local test_logger = sc_logger.new(logfile, severity)

local params = {
  param_A = "value A",
  param_B = "value B"
}

-- create a new instance of the sc_flush module
local test_flush = sc_flush.new(params, test_logger)
```

## add_queue_metadata method

The **add_queue_metadata** method adds a list of metadata to a given queue.

### add_queue_metadata: parameters

| parameter                                                                                      | type   | optional | default value |
| ---------------------------------------------------------------------------------------------- | ------ | -------- | ------------- |
| the category id of the queue                                                                   | number | no       |               |
| the element id of the queue                                                                    | number | no       |               |
| a table containing metadata where each key is the name of the metadata and the value its value | table  | no       |               |

### add_queue_metadata: example

```lua
-- if accepted_elements is set to "host_status,service_status"

local host_metadata = {
  endpoint = "/host",
  method = "POST"
}

local cateogry = 1
local element = 14

test_flush:add_queue_metadata(category, element, host_metadata) 
--> the host queue (category: 1, element: 14) now has metadata 
--[[
  test_flush.queues = {
    [1] = {
      [14] = {
        events = {},
        queue_metadata = {
          category_id = 1,
          element_id = 14,
          endpoint = "/host",
          method = "POST"
        }
      }
    }
  }
]]--
```

## flush_all_queues method

The **flush_all_queues** method tries to flush all the possible queues that can be created. It flushes queues according to the [**accepted_elements, max_buffer_size, max_buffer_age parameters and send_mixed_events**](sc_param.md#default_parameters)

head over the following chapters for more information

- [flush_mixed_payload](#flush_mixed_payload-method)
- [flush_homogeneous_payload](#flush_homogeneous_payload-method)
- [reset_all_queues](#reset_all_queues-method)

### flush_all_queues: parameters

| parameter                                                                                                                                                                                                                                                                                                                                           | type     | optional | default value |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | -------- | ------------- |
| the function that must be used to build the data payload. If the method is part of a lua module, you must use the dot syntax and not the colon syntax. Meaning it can be `self.build_payload` but not `self:build_payload` (do not put parenthesis otherwise it will pass the result of the function as a parameter instead of the function itself) | function | no       |               |
| the function that must be used to send data. If the method is part of a lua module, you must use the dot syntax and not the colon syntax. Meaning it can be `self.send_data` but not `self:send_data` (do not put parenthesis otherwise it will pass the result of the function as a parameter instead of the function itself)                      | function | no       |               |

### flush_all_queues: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### flush_all_queues: example

```lua
-- if accepted_elements is set to "host_status,service_status"

local function build_payload()
  -- build data payload
end 

local function send_data()
  -- send data somewhere
end

local result = test_flush:flush_all_queues(build_payload, send_data) 
--> result is true or false
--> host_status and service_status are flushed if it is possible
```

## reset_all_queues method

The **reset_all_queues** method removes all the entries from all the queue tables.

### reset_all_queues: example

```lua
test_flush.queues[1] = {
  [14] = {
    flush_date = os.time() - 30, -- simulate an old queue by setting its last flush date 30 seconds in the past
    events = {
      [1] = "first event",
      [2] = "second event"
    }
  },
  [24] = {
    flush_date = os.time() - 30, -- simulate an old queue by setting its last flush date 30 seconds in the past
    events = {
      [1] = "first event",
      [2] = "second event"
    }
  }
}

test_flush:reset_all_queues()
--> test_flush.queues are now reset
--[[
  test_flush.queues[1] = {
    [14] = {
      os.time() , -- the time at which the reset happened
      events = {}
    },
    [24] = {
      os.time() , -- the time at which the reset happened
      events = {}
    }
  }
]]--
```

## get_queues_size method

The **get_queues_size** method gets the number of events stored in all the queues.

### get_queues_size: returns

| return   | type   | always | condition |
| -------- | ------ | ------ | --------- |
| a number | number | yes    |           |

### get_queues_size: example

```lua
test_flush.queues[1] = {
  [14] = {
    flush_date = os.time(),
    events = {
      [1] = "first event",
      [2] = "second event"
    }
  },
  [24] = {
    flush_date = os.time(),
    events = {
      [1] = "first event",
      [2] = "second event"
    }
  }
}

local result = test_flush:get_queues_size() 
--> result is 4
```

## flush_mixed_payload method

The **flush_mixed_payload** method flushes a payload that contains various type of events (services mixed hosts for example) according to [**max_buffer_size and max_buffer_age parameters**](sc_param.md#default_parameters)

### flush_mixed_payload: parameters

| parameter                                                                                                                                                                                                                                                                                                                                           | type     | optional | default value |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | -------- | ------------- |
| the function that must be used to build the data payload. If the method is part of a lua module, you must use the dot syntax and not the colon syntax. Meaning it can be `self.build_payload` but not `self:build_payload` (do not put parenthesis otherwise it will pass the result of the function as a parameter instead of the function itself) | function | no       |               |
| the function that must be used to send data. If the method is part of a lua module, you must use the dot syntax and not the colon syntax. Meaning it can be `self.send_data` but not `self:send_data` (do not put parenthesis otherwise it will pass the result of the function as a parameter instead of the function itself)                      | function | no       |               |

### flush_mixed_payload: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### flush_mixed_payload: example

```lua
-- if accepted_elements is set to "host_status,service_status"

local function build_payload()
  -- build data payload
end 

local function send_data()
  -- send data somewhere
end

local result = test_flush:flush_all_queues(build_payload, send_data) 
--> result is true or false
--> host_status and service_status are flushed if it is possible
```

## flush_homogeneous_payload method

The **flush_mixed_payload** method flushes a payload that contains a single type of events (services with services only and hosts with hosts only for example) according to [**max_buffer_size and max_buffer_age parameters**](sc_param.md#default_parameters)

### flush_homogeneous_payload: parameters

| parameter                                                                                                                                                                                                                                                                                                                                           | type     | optional | default value |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | -------- | ------------- |
| the function that must be used to build the data payload. If the method is part of a lua module, you must use the dot syntax and not the colon syntax. Meaning it can be `self.build_payload` but not `self:build_payload` (do not put parenthesis otherwise it will pass the result of the function as a parameter instead of the function itself) | function | no       |               |
| the function that must be used to send data. If the method is part of a lua module, you must use the dot syntax and not the colon syntax. Meaning it can be `self.send_data` but not `self:send_data` (do not put parenthesis otherwise it will pass the result of the function as a parameter instead of the function itself)                      | function | no       |               |

### flush_homogeneous_payload: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### flush_homogeneous_payload: example

```lua
-- if accepted_elements is set to "host_status,service_status"

local function build_payload()
  -- build data payload
end 

local function send_data()
  -- send data somewhere
end

local result = test_flush:flush_homogeneous_payload(build_payload, send_data) 
--> result is true or false
--> host_status and service_status are flushed if it is possible
```

## flush_payload method

The **flush_payload** method sends a payload using the given method.

### flush_payload: parameters

| parameter                                                                                                                                                                                                                                                                                                                                           | type     | optional | default value |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | -------- | ------------- |
| the function that must be used to build the data payload. If the method is part of a lua module, you must use the dot syntax and not the colon syntax. Meaning it can be `self.build_payload` but not `self:build_payload` (do not put parenthesis otherwise it will pass the result of the function as a parameter instead of the function itself) | function | no       |               |
| a table containing the payload that must be sent                                                                                                                                                                                                                                                                                                    | table    | no       |               |
| a table containing metadata for the payload                                                                                                                                                                                                                                                                                                         | table    | no       | `{}`          |

### flush_payload: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### flush_payload: example

```lua
local payload = {
  host = "mont",
  state = "2",
  service = "marsan"
}

local metadata = {
  endpoint = "/api/event"
}

local function send_data()
  -- send data somewhere
end

result = test_flush:flush_payload(send_data, payload, metadata)
--> result is true or false
```
