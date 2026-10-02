# Documentation of the sc_trigger module

- [Documentation of the sc\_trigger module](#documentation-of-the-sc_trigger-module)
  - [Introduction](#introduction)
  - [Module initialization](#module-initialization)
    - [Module constructor](#module-constructor)
    - [constructor: Example](#constructor-example)
  - [build\_valid\_trigger\_categories method](#build_valid_trigger_categories-method)
    - [build\_valid\_trigger\_categories: returns](#build_valid_trigger_categories-returns)
    - [build\_valid\_trigger\_categories: example](#build_valid_trigger_categories-example)
  - [build\_valid\_trigger\_event\_types method](#build_valid_trigger_event_types-method)
    - [build\_valid\_trigger\_event\_types: returns](#build_valid_trigger_event_types-returns)
    - [build\_valid\_trigger\_event\_types: example](#build_valid_trigger_event_types-example)
  - [execute\_trigger\_file method](#execute_trigger_file-method)
    - [execute\_trigger\_file: returns](#execute_trigger_file-returns)
    - [execute\_trigger\_file: example](#execute_trigger_file-example)
  - [register\_trigger method](#register_trigger-method)
    - [register\_trigger: parameters](#register_trigger-parameters)
    - [register\_trigger: returns](#register_trigger-returns)
    - [register\_trigger: example](#register_trigger-example)
  - [run\_trigger method](#run_trigger-method)
    - [run\_trigger: parameters](#run_trigger-parameters)
    - [run\_trigger: returns](#run_trigger-returns)
    - [run\_trigger: example](#run_trigger-example)

## Introduction

The sc_trigger module provides a hook mechanism for stream connectors. It has been made in OOP (object oriented programming)

Its purpose is to let end users run their own Lua code at specific points of a stream connector (or library) lifecycle **without editing the stream connector or the library code**. Since customizations live in a separate file, they are not overwritten each time the stream connector or the centreon-stream-connectors-lib module is updated.

There are two sides to this mechanism:

- library/stream connector code calls the [**run_trigger**](#run_trigger-method) method at a point it wants to expose as a customization point (see [how_to_use_triggers.md](how_to_use_triggers.md) for the full list of points that already do this)
- the end user provides a **trigger file** (loaded through the [**trigger_file** parameter](sc_param.md#default-parameters) and compiled by [sc_params:load_trigger_file](sc_param.md#load_trigger_file-method)) that calls the [**register_trigger**](#register_trigger-method) method to attach their own function to one of those points. [how_to_use_triggers.md](how_to_use_triggers.md) is the practical guide for writing this file.

## Module initialization

Since this is OOP, it is required to initiate your module.

### Module constructor

Constructor must be initialized with 3 parameters

- params. This is the table of all stream connectors parameters (it must have been processed by the sc_params module so that the **trigger_code** parameter is set if a **trigger_file** parameter has been configured, see [sc_params:load_trigger_file](sc_param.md#load_trigger_file-method))
- sc_common. This is an instance of the sc_common module
- sc_logger. This is an instance of the sc_logger module

Unlike other modules, sc_trigger does not create a default sc_logger instance if none is provided, you must provide one.

The constructor automatically chains [build\_valid\_trigger\_categories](#build_valid_trigger_categories-method), [build\_valid\_trigger\_event\_types](#build_valid_trigger_event_types-method) and [execute\_trigger\_file](#execute_trigger_file-method), in that order, before returning.

### constructor: Example

```lua
-- load modules
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_param = require("centreon-stream-connectors-lib.sc_param")
local sc_trigger = require("centreon-stream-connectors-lib.sc_trigger")

-- initiate "mandatory" informations for the logger module
local logfile = "/var/log/test_logger.log"
local severity = 1

-- create a new instance of the sc_logger module
local test_logger = sc_logger.new(logfile, severity)

-- create a new instance of the sc_common module
local test_common = sc_common.new(test_logger)

-- create a new instance of the sc_param module
local test_param = sc_param.new(test_common, test_logger)

-- tell the stream connector where to find the trigger file
-- this parameter is automatically compiled into test_param.params.trigger_code by sc_params:check_params()
test_param.params.trigger_file = "/etc/centreon-broker/my-trigger-file.lua"
test_param:check_params()

-- create a new instance of the sc_trigger module
local test_trigger = sc_trigger.new(test_param.params, test_common, test_logger)
```

## build_valid_trigger_categories method

The **build_valid_trigger_categories** method builds the list of valid trigger categories (the keys of `self.triggers`) and stores it in `self.valid_categories`. It is called once, automatically, by the [constructor](#module-constructor), right before [build_valid_trigger_event_types](#build_valid_trigger_event_types-method).

**This is an internal method, you should never need to call it yourself.** It is documented here for maintainers of the sc_trigger module.

### build_valid_trigger_categories: returns

| return | type | always | condition |
| - | - | - | - |
| self | table | yes | always returns itself, this allows to chain calls |

### build_valid_trigger_categories: example

```lua
-- called automatically by sc_trigger.new(), you don't need to call it yourself
self:build_valid_trigger_categories()

--> self.valid_categories is now a plain table, for example:
--> { "EventQueue:new", "EventQueue:add", "sc_flush:flush_payload", ... }
```

## build_valid_trigger_event_types method

The **build_valid_trigger_event_types** method builds, for each valid category, the comma separated list of its valid event types and stores it in `self.valid_event_types[category]`. It also converts `self.valid_categories` into a single comma separated string (up to that point it was a plain table of category names). It is called once, automatically, by the [constructor](#module-constructor), right after [build_valid_trigger_categories](#build_valid_trigger_categories-method) and right before [execute_trigger_file](#execute_trigger_file-method).

**This is an internal method, you should never need to call it yourself.** It is documented here for maintainers of the sc_trigger module. It relies on `self.valid_categories` already being a table of category names, which is what [build_valid_trigger_categories](#build_valid_trigger_categories-method) provides.

### build_valid_trigger_event_types: returns

| return | type | always | condition |
| - | - | - | - |
| self | table | yes | always returns itself, this allows to chain calls |

### build_valid_trigger_event_types: example

```lua
-- called automatically by sc_trigger.new(), you don't need to call it yourself
self:build_valid_trigger_categories():build_valid_trigger_event_types()

--> self.valid_categories is now a string, for example: "EventQueue:new, EventQueue:add, sc_flush:flush_payload"
--> self.valid_event_types is now a table, for example:
--> {
-->   ["EventQueue:new"] = "on-init",
-->   ["sc_flush:flush_payload"] = "on-success, on-fail"
--> }
```

## execute_trigger_file method

The **execute_trigger_file** method runs the compiled trigger file (`self.params.trigger_code`, produced by [sc_params:load_trigger_file](sc_param.md#load_trigger_file-method) from the [**trigger_file** parameter](sc_param.md#default-parameters)), giving it `self` (the sc_trigger instance) as its only argument. This is what lets the [trigger file](how_to_use_triggers.md) call [register_trigger](#register_trigger-method) on it. It is called once, automatically, by the [constructor](#module-constructor), right after [build_valid_trigger_event_types](#build_valid_trigger_event_types-method).

**This is an internal method, you should never need to call it yourself.** It is documented here for maintainers of the sc_trigger module.

If `self.params.trigger_code` is not set (no **trigger_file** parameter has been configured), this method does nothing. If running the trigger file raises an error, it is caught and logged, it will not crash the stream connector.

### execute_trigger_file: returns

| return | type | always | condition |
| - | - | - | - |
| self | table | yes | always returns itself, this allows to chain calls, even if the trigger file failed to run |

### execute_trigger_file: example

```lua
-- called automatically by sc_trigger.new(), you don't need to call it yourself
self:build_valid_trigger_categories():build_valid_trigger_event_types():execute_trigger_file()
--> self.params.trigger_code (if set) has now been executed once, with self given as its argument
```

## register_trigger method

The **register_trigger** method attaches a function to a category/event_type. It is meant to be called from a [trigger file](how_to_use_triggers.md).

If the category or the event_type does not exist, or if the provided trigger is not a Lua function, the registration is refused and an error is logged (with the list of valid categories/event types for that category).

### register_trigger: parameters

| parameter | type | optional | default value |
| - | - | - | - |
| category | string | no | |
| event_type | string | no | |
| trigger_function | function | no | |

### register_trigger: returns

| return | type | always | condition |
| - | - | - | - |
| true | boolean | no | the trigger has been registered |
| false | boolean | no | category or event_type is invalid, or trigger_function is not a function |

### register_trigger: example

```lua
local result = test_trigger:register_trigger("EventQueue:new", "on-init", function(data)
  test_logger:notice("stream connector has been initialized")
end)
--> result is true or false
```

## run_trigger method

The **run_trigger** method runs the function that has been registered (with [register_trigger](#register_trigger-method)) for a given category/event_type. It is meant to be called from the stream connector or the library code, at the exact point that should be exposed as a customization point.

If no function has been registered for the category/event_type, or if it raises an error, the documented default value for that category/event_type is returned instead (see [how_to_use_triggers.md](how_to_use_triggers.md)).

### run_trigger: parameters

| parameter | type | optional | default value |
| - | - | - | - |
| category | string | no | |
| event_type | string | no | |
| data | table | no | |

### run_trigger: returns

| return | type | always | condition |
| - | - | - | - |
| the result of the registered trigger function | any | no | a trigger has been registered for the category/event_type and it succeeded |
| the default value documented for the category/event_type | any | no | no trigger has been registered, or it raised an error, or category/event_type is invalid |

### run_trigger: example

```lua
local result = test_trigger:run_trigger("EventQueue:new", "on-init", {params = test_param.params})
```
