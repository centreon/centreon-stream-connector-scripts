# Documentation of the sc_flush module

- [Documentation of the sc_flush module](#documentation-of-the-sc_flush-module)
  - [Introduction](#introduction)
  - [Module initialization](#module-initialization)
    - [Module constructor](#module-constructor)
    - [constructor: Example](#constructor-example)
  - [flush_all_queues method](#flush_all_queues-method)
    - [flush_all_queues: parameters](#flush_all_queues-parameters)
    - [flush_all_queues: example](#flush_all_queues-example)
  - [flush_queue method](#flush_queue-method)
    - [flush_queue: parameters](#flush_queue-parameters)
    - [flush_queue: returns](#flush_queue-returns)
    - [flush_queue: example](#flush_queue-example)
  - [reset_queue method](#reset_queue-method)
    - [reset_queue: parameters](#reset_queue-parameters)
    - [reset_queue: example](#reset_queue-example)

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

-- create a new instance of the sc_common module
local test_flush = sc_flush.new(params, test_logger)
```

## flush_all_queues method

The **flush_all_queues** method tries to flush all the possible queues that can be created. It flushes queues according to the [**accepted_elements, max_buffer_size and max_buffer_age parameters**](sc_param.md#default_parameters)

head over the following chapters for more information

- [flush_queue](#flush_queue-method)

### flush_all_queues: parameters

| parameter                                                                                                                                                                                                                                                                                                                      | type     | optional | default value |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | -------- | ------------- |
| the function that must be used to send data. If the method is part of a lua module, you must use the dot syntax and not the colon syntax. Meaning it can be `self.send_data` but not `self:send_data` (do not put parenthesis otherwise it will pass the result of the function as a parameter instead of the function itself) | function | no       |               |

### flush_all_queues: example

```lua
-- if accepted_elements is set to "host_status,service_status"

local function send_data()
  -- send data somewhere
end

test_flush:flush_all_queues(send_data) 
--> host_status and service_status are flushed if it is possible
```

## flush_queue method

The **flush_queue** method tries to flush a specific queue. It flushes a  queue according to the [**max_buffer_size and max_buffer_age parameters**](sc_param.md#default_parameters)

head over the following chapters for more information

- [reset_queue](#reset_queue-method)

### flush_queue: parameters

| parameter                                                                                                                                                                                                                                                                                                                      | type     | optional | default value |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | -------- | ------------- |
| the function that must be used to send data. If the method is part of a lua module, you must use the dot syntax and not the colon syntax. Meaning it can be `self.send_data` but not `self:send_data` (do not put parenthesis otherwise it will pass the result of the function as a parameter instead of the function itself) | function | no       |               |
| the category of the queue that we need to flush | number | no | |
| the element of the queue that we need to flush | number | no | |

### flush_queue: returns

| return        | type    | always | condition |
| ------------- | ------- | ------ | --------- |
| true or false | boolean | yes    |           |

### flush_queue: example

```lua

local function send_data()
  -- send data somewhere
end

-- fill a host_status queue with 2 events for the example
test_flush.queues[1][14].events = {
  [1] = "first event",
  [2] = "second event"
}

local result = test_flush:flush_queue(send_data, 1, 14) 
--> result is true

-- initiate a empty queue for service_status events
test_.queues[1][24].events = {}

result = test_flush:flush_queue(send_data, 1, 24)
--> result is false because buffer size is 0
```

## reset_queue method

The **reset_queue** reset a queue after it has been flushed

### reset_queue: parameters

| parameter                                                                                                                                                                                                                                                                                                                      | type     | optional | default value |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | -------- | ------------- |
| the category of the queue that we need to reset | number | no | |
| the element of the queue that we need to reset| number | no | |

### reset_queue: example

```lua

local function send_data()
  -- send data somewhere
end

-- fill a host_status queue with 2 events for the example
test_flush.queues[1][14] = {
  flush_date = os.time() - 30, -- simulate an old queue by setting its last flush date 30 seconds in the past
  events = {
    [1] = "first event",
    [2] = "second event"
  }
}

test_flush:reset_queue(1, 14) 
--> test_flush.queues[1][14] is now reset like below
--[[
  test_flush.queues[1][14] = {
    flush_date = os.time() , -- the time at which the reset happened
    events = {}
  }
]]
```
