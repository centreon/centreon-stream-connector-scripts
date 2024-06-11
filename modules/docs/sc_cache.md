# Documentation of the sc_cache module

- [Documentation of the sc\_cache module](#documentation-of-the-sc_cache-module)
  - [Introduction](#introduction)
  - [Module initialization](#module-initialization)
    - [Module constructor](#module-constructor)
    - [constructor: Example](#constructor-example)
  - [is\_valid\_cache\_object method](#is_valid_cache_object-method)
    - [is\_valid\_cache\_object: parameters](#is_valid_cache_object-parameters)
    - [is\_valid\_cache\_object: returns](#is_valid_cache_object-returns)
    - [is\_valid\_cache\_object: example](#is_valid_cache_object-example)
  - [set method](#set-method)
    - [set: parameters](#set-parameters)
    - [set: returns](#set-returns)
    - [set: example](#set-example)
  - [get method](#get-method)
    - [get: parameters](#get-parameters)
    - [get: returns](#get-returns)
    - [get: example](#get-example)
  - [delete method](#delete-method)
    - [delete: parameters](#delete-parameters)
    - [delete: returns](#delete-returns)
    - [delete: example](#delete-example)
  - [show method](#show-method)
    - [show: parameters](#show-parameters)
    - [show: returns](#show-returns)
    - [show: example](#show-example)
  - [clear method](#clear-method)
    - [clear: returns](#clear-returns)
    - [clear: example](#clear-example)

## Introduction

The sc_cache module provides methods to help communicate with cache backends. It has been made in OOP (object oriented programming)

## Module initialization

Since this is OOP, it is required to initiate your module

### Module constructor

Constructor can be initialized with one parameter or it will use a default value.

- sc_logger. This is an instance of the sc_logger module
- a params table

### constructor: Example

```lua
-- load modules
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_cache = require("centreon-stream-connectors-lib.sc_cache")

-- initiate "mandatory" informations for the logger module
local logfile = "/var/log/test_logger.log"
local severity = 1

-- create a new instance of the sc_logger module
local test_logger = sc_logger.new(logfile, severity)

-- create the required table of parameters

local params = {
  cache_backend = "broker"
}

-- create a new instance of the sc_common module
local test_cache = sc_cache.new(test_logger, params)
```

## is_valid_cache_object method

The **is_valid_cache_object** method makes sure that the object that needs an interraction with the cache is an object that can have cache.

### is_valid_cache_object: parameters

| parameter                       | type   | optional | default value |
| ------------------------------- | ------ | -------- | ------------- |
| the object that must be checked | string | no       |               |

### is_valid_cache_object: returns

| return        | type    | always | condition                      |
| ------------- | ------- | ------ | ------------------------------ |
| true or false | boolean | yes    | true if valid, false otherwise |

### is_valid_cache_object: example

```lua
local object_id = "host_2712"

local result = test_cache:is_valid_cache_object(object_id) 
--> result is true

object_id = "vive_les_landes"
result = test_cache:is_valid_cache_object(object_id)
--> result is false
```

## set method

The **set** method sets an object property in the cache

### set: parameters

| parameter                                     | type                    | optional | default value |
| --------------------------------------------- | ----------------------- | -------- | ------------- |
| the object with the property that must be set | string                  | no       |               |
| the name of the property                      | string                  | no       |               |
| the value of the property                     | string, number, boolean | no       |               |

### set: returns

| return        | type    | always | condition                                            |
| ------------- | ------- | ------ | ---------------------------------------------------- |
| true or false | boolean | yes    | true if value properly set in cache, false otherwise |

### set: example

```lua
local object_id = "host_2712"
local property = "city"
local value = "Bordeaux"

local result = test_cache:set(object_id, property, value) 
--> result is true
```

## get method

The **get** method gets an object property in the cache

### get: parameters

| parameter                                           | type   | optional | default value |
| --------------------------------------------------- | ------ | -------- | ------------- |
| the object with the property that must be retrieved | string | no       |               |
| the name of the property                            | string | no       |               |

### get: returns

| return               | type                           | always | condition                                                    |
| -------------------- | ------------------------------ | ------ | ------------------------------------------------------------ |
| true or false        | boolean                        | yes    | true if value properly retrieved from cache, false otherwise |
| value from the cache | string, boolean, number, table | yes    | empty string if status false, value otherwise                |

### get: example

```lua
local object_id = "host_2712"
local property = "city"

local status, value = test_cache:get(object_id, property) 
--> status is true, value is "Bordeaux"

property = "a_random_property_not_in_the_cache"
status, value = test_cache:get(object_id, property)
--> status is true, value is ""
```

## delete method

The **delete** method deletes an object property in the cache

### delete: parameters

| parameter                                         | type   | optional | default value |
| ------------------------------------------------- | ------ | -------- | ------------- |
| the object with the property that must be deleted | string | no       |               |
| the name of the property                          | string | no       |               |

### delete: returns

| return        | type    | always | condition                                                |
| ------------- | ------- | ------ | -------------------------------------------------------- |
| true or false | boolean | yes    | true if value properly deleted in cache, false otherwise |

### delete: example

```lua
local object_id = "host_2712"
local property = "city"

local status, value = test_cache:delete(object_id, property) 
--> status is true
```

## show method

The **show** method shows (in the log file) all stored properties of an object

### show: parameters

| parameter                                         | type   | optional | default value |
| ------------------------------------------------- | ------ | -------- | ------------- |
| the object with the property that must be deleted | string | no       |               |

### show: returns

| return        | type    | always | condition                                                |
| ------------- | ------- | ------ | -------------------------------------------------------- |
| true or false | boolean | yes    | true if object properties are retrieved, false otherwise |

### show: example

```lua
local object_id = "host_2712"

local status = test_cache:show(object_id) 
--> status is true
```

## clear method

The **clear** method deletes all stored information in cache

### clear: returns

| return        | type    | always | condition                                       |
| ------------- | ------- | ------ | ----------------------------------------------- |
| true or false | boolean | yes    | true if cache has been deleted, false otherwise |

### clear: example

```lua
local object_id = "host_2712"

local status = test_cache:clear() 
--> status is true
```
