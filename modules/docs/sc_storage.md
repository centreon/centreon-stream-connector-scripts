# Documentation of the sc_storage module

- [Documentation of the sc\_storage module](#documentation-of-the-sc_storage-module)
  - [Introduction](#introduction)
  - [What can you store](#what-can-you-store)
  - [Memory table A.K.A magic table](#memory-table-aka-magic-table)
    - [Use case](#use-case)
    - [How does it work](#how-does-it-work)
      - [First time adding data in the memory table](#first-time-adding-data-in-the-memory-table)
      - [Get data from the memory table](#get-data-from-the-memory-table)
      - [Set a single property in the memory table](#set-a-single-property-in-the-memory-table)
      - [delete a value](#delete-a-value)
      - [use multiple functions (set, get, delete)](#use-multiple-functions-set-get-delete)
      - [what if I want to set or get in the memory table but not interact with the persistent storage](#what-if-i-want-to-set-or-get-in-the-memory-table-but-not-interact-with-the-persistent-storage)
  - [Module initialization](#module-initialization)
    - [Module constructor](#module-constructor)
    - [constructor: Example](#constructor-example)
  - [is\_valid\_storage\_object method](#is_valid_storage_object-method)
    - [is\_valid\_storage\_object: parameters](#is_valid_storage_object-parameters)
    - [is\_valid\_storage\_object: returns](#is_valid_storage_object-returns)
    - [is\_valid\_storage\_object: example](#is_valid_storage_object-example)
  - [set method](#set-method)
    - [set: parameters](#set-parameters)
    - [set: returns](#set-returns)
    - [set: example](#set-example)
  - [set\_multiple method](#set_multiple-method)
    - [set\_multiple: parameters](#set_multiple-parameters)
    - [set\_multiple: returns](#set_multiple-returns)
    - [set\_multiple: example](#set_multiple-example)
  - [get method](#get-method)
    - [get: parameters](#get-parameters)
    - [get: returns](#get-returns)
    - [get: example](#get-example)
  - [get\_multiple method](#get_multiple-method)
    - [get\_multiple: parameters](#get_multiple-parameters)
    - [get\_multiple: returns](#get_multiple-returns)
    - [get\_multiple: example](#get_multiple-example)
  - [delete method](#delete-method)
    - [delete: parameters](#delete-parameters)
    - [delete: returns](#delete-returns)
    - [delete: example](#delete-example)
  - [delete\_multiple method](#delete_multiple-method)
    - [delete\_multiple: parameters](#delete_multiple-parameters)
    - [delete\_multiple: returns](#delete_multiple-returns)
    - [delete\_multiple: example](#delete_multiple-example)
  - [show method](#show-method)
    - [show: parameters](#show-parameters)
    - [show: returns](#show-returns)
    - [show: example](#show-example)
  - [clear method](#clear-method)
    - [clear: returns](#clear-returns)
    - [clear: example](#clear-example)

## Introduction

The sc_storage module provides methods to help communicate with storage backends. It has been made in OOP (object oriented programming)

## What can you store

The storage mechanism will only allow to store valid objects. Valid objects are referred as **"storage_objects"** in the code and are defined within the code. They must match one of the following Lua pattern:

- "host_%d+",
- "service_%d+_%d+",
- "ba_%d+",
- "metric_.*"

The above pattern is then called an object_id (host_2712 is a storage object id)
This rule is here to enforce a readable storage and easily understand which data belongs to what.

## Memory table A.K.A magic table

This feature is a kind of abstraction layer for the storage mechanism.
When used, it will usually do something in memory but also do something with the persistent storage. (I rarely write sentences that meaningless but I will explain)

### Use case

Usually when you want to store a value in memory, you just put it in a table.
If you want some persistent storage you also need to use the appropriate function from the sc_storage module.

The memory table is designed to avoid this double work.
When you set a value inside the memory table, it is automatically going to also set it in the persistent storage.

### How does it work

#### First time adding data in the memory table

First, you have access to a memory table after having initiated the sc_storage module

```lua
local test_storage = sc_storage.new(test_common, test_logger, params)

-- test_storage.memory is the memory table
```

Then you can store data inside it, let's do it for the first time

```lua
local object_id = "host_2712"
local object_properties = {
  town = "bordeaux",
  zip_code = 33000
}

test_storage.memory[object_id] = object_properties
--> test_storage.memory has now the following structure: 
--[[
  test_storage.memory = {
    host_2712 = {
      _internal_object_id = "host_2712",
      town = "bordeaux",
      zip_code = 33000
    }
  }
]]
```

As you can see, upon creation, a `_internal_object_id` index has been added in the memory table. This is because it is required by the mechanims in order to know how to store data in the persistent storage. Because while the memory table has been populated with some values, so does the persistent storage.

#### Get data from the memory table

This one is quite simple

```lua
local best_town = test_storage.memory.host_2712.town
--> best_town is bordeaux
```

While it looks like you just get the value of an index from a table, it does in fact another action. If it can't get the value from memory (meaning from the memory table) it will look into the persistent storage for the value.

This is to avoid having to write the below code:

```lua
local best_town = my_memory.host_2712.town

if not best_town then
  best_town = test_storage:get("host_2712", "town")
end
```

#### Set a single property in the memory table

As simple as to get one value

```lua
test_storage.memory.host_2712.country = "france"
```

Once again, not only does it put the value in the memory table, it also put it in the persistent storage. This is to avoid the below code:

```lua
my_memory.host_2712.country = france
test_storage:set("host_2712", "country", "france")
```

#### delete a value

To remove an index from a Lua table, just set it to nil. Therefore it is done like below:

```lua
test_storage.memory.host_2712.country = nil
```

Once again, it will remove the data from the memory table but also from the persistent storage. This is to avoid the below code:

```lua
my_memory.host_2712.country = nil
test_storage:delete("host_2712", "country")
```

#### use multiple functions (set, get, delete)

You can't set nor get nor delete properties in bulk with the memory table.

#### what if I want to set or get in the memory table but not interact with the persistent storage

For some reason, you may want to use the memory table but for one specific property of an object you don't want it to trigger a communication with the persistent storage backend.
You could totally store this data in another table but this will create confusion if sometime a property of an object is in the memory table and sometime not.
In such situations, you can use `rawset` and `rawget` this will allow you to interact with the memory table without triggering the meta table functions that are linked to it.

```lua
-- set/delete a property
test_storage.memory.host_2712.country = "france" --> will set the country property in memory and in persistent storage
rawset(test_storage.memory.host_2712, "country", "france") --> will only the country property in the memory table but not in the persistent storage

-- get a property
local country = test_storage.memory.host_2712.country --> will try to find the country property in the memory table and if not found will look into the persistent storage
local country = rawget(test_storage.memory.host_2712, "country") --> will only try to find the country property in the memory table
```

## Module initialization

Since this is OOP, it is required to initiate your module

### Module constructor

Constructor must be initialized with thres parameters 

- sc_common. This is an instance of the sc_common module
- sc_logger. This is an instance of the sc_logger module
- a params table

### constructor: Example

```lua
-- load modules
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_storage = require("centreon-stream-connectors-lib.sc_storage")

-- initiate "mandatory" informations for the logger module
local logfile = "/var/log/test_logger.log"
local severity = 1

-- create a new instance of the sc_logger and sc_common module
local test_logger = sc_logger.new(logfile, severity)
local test_common = sc_common.new(test_logger)

-- create the required table of parameters

local params = {
  storage_backend = "broker"
}

-- create a new instance of the sc_common module
local test_storage = sc_storage.new(test_common, test_logger, params)
```

## is_valid_storage_object method

The **is_valid_storage_object** method makes sure that the object that needs an interraction with the storage is an object that can have storage.

### is_valid_storage_object: parameters

| parameter                       | type   | optional | default value |
| ------------------------------- | ------ | -------- | ------------- |
| the object that must be checked | string | no       |               |

### is_valid_storage_object: returns

| return        | type    | always | condition                      |
| ------------- | ------- | ------ | ------------------------------ |
| true or false | boolean | yes    | true if valid, false otherwise |

### is_valid_storage_object: example

```lua
local object_id = "host_2712"

local result = test_storage:is_valid_storage_object(object_id) 
--> result is true

object_id = "vive_les_landes"
result = test_storage:is_valid_storage_object(object_id)
--> result is false
```

## set method

The **set** method sets an object property in the storage

### set: parameters

| parameter                                     | type                    | optional | default value |
| --------------------------------------------- | ----------------------- | -------- | ------------- |
| the object with the property that must be set | string                  | no       |               |
| the name of the property                      | string                  | no       |               |
| the value of the property                     | string, number, boolean, table | no       |               |

### set: returns

| return        | type    | always | condition                                            |
| ------------- | ------- | ------ | ---------------------------------------------------- |
| true or false | boolean | yes    | true if value properly set in storage, false otherwise |

### set: example

```lua
local object_id = "host_2712"
local property = "city"
local value = "Bordeaux"

local result = test_storage:set(object_id, property, value) 
--> result is true
```

## set_multiple method

The **set_multiple** method sets multiple object properties in the storage

### set_multiple: parameters

| parameter                                     | type   | optional | default value |
| --------------------------------------------- | ------ | -------- | ------------- |
| the object with the property that must be set | string | no       |               |
| a table of properties and their values        | table  | no       |               |

### set_multiple: returns

| return        | type    | always | condition                                            |
| ------------- | ------- | ------ | ---------------------------------------------------- |
| true or false | boolean | yes    | true if value properly set in storage, false otherwise |

### set_multiple: example

```lua
local object_id = "host_2712"
local properties = {
  city = "Bordeaux",
  country = "France"
}

local result = test_storage:set_multiple(object_id, properties) 
--> result is true
```

## get method

The **get** method gets an object property in the storage

### get: parameters

| parameter                                           | type   | optional | default value |
| --------------------------------------------------- | ------ | -------- | ------------- |
| the object with the property that must be retrieved | string | no       |               |
| the name of the property                            | string | no       |               |

### get: returns

| return               | type                           | always | condition                                                    |
| -------------------- | ------------------------------ | ------ | ------------------------------------------------------------ |
| true or false        | boolean                        | yes    | true if value properly retrieved from storage, false otherwise |
| value from the storage | string, boolean, number, table | yes    | empty string if first return is false, value otherwise       |

### get: example

```lua
local object_id = "host_2712"
local property = "city"

local status, value = test_storage:get(object_id, property) 
--> status is true, value is "Bordeaux"

property = "a_random_property_not_in_the_storage"
status, value = test_storage:get(object_id, property)
--> status is true, value is ""
```

## get_multiple method

The **get_multiple** method retrieves a list of properties for an object

### get_multiple: parameters

| parameter                                           | type   | optional | default value |
| --------------------------------------------------- | ------ | -------- | ------------- |
| the object with the property that must be retrieved | string | no       |               |
| a list of properties                                | table  | no       |               |

### get_multiple: returns

| return                | type    | always | condition                                                                           |
| --------------------- | ------- | ------ | ----------------------------------------------------------------------------------- |
| true or false         | boolean | yes    | true if value properly retrieved from storage, false otherwise                        |
| values from the storage | table   | yes    | empty table if first return is false, table of properties and their value otherwise |

### get_multiple: example

```lua
local object_id = "host_2712"
local properties = {"city", "country"}

local status, values = test_storage:get_multiple(object_id, properties) 
--> status is true
--[[
  values structure is:
  {
    {
      city = "Bordeaux",
      country = "France"
    }
  }
]]
```

## delete method

The **delete** method deletes an object property in the storage

### delete: parameters

| parameter                                         | type   | optional | default value |
| ------------------------------------------------- | ------ | -------- | ------------- |
| the object with the property that must be deleted | string | no       |               |
| the name of the property                          | string | no       |               |

### delete: returns

| return        | type    | always | condition                                                |
| ------------- | ------- | ------ | -------------------------------------------------------- |
| true or false | boolean | yes    | true if value properly deleted in storage, false otherwise |

### delete: example

```lua
local object_id = "host_2712"
local property = "city"

local status = test_storage:delete(object_id, property) 
--> status is true
```

## delete_multiple method

The **delete_multiple** method deletes an object properties in the storage

### delete_multiple: parameters

| parameter                                         | type   | optional | default value |
| ------------------------------------------------- | ------ | -------- | ------------- |
| the object with the property that must be deleted | string | no       |               |
| a list of properties                              | table  | no       |               |

### delete_multiple: returns

| return        | type    | always | condition                                                 |
| ------------- | ------- | ------ | --------------------------------------------------------- |
| true or false | boolean | yes    | true if values properly deleted in storage, false otherwise |

### delete_multiple: example

```lua
local object_id = "host_2712"
local properties = {"city", "country"}

local status = test_storage:delete_multiple(object_id, properties) 
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

local status = test_storage:show(object_id) 
--> status is true
```

## clear method

The **clear** method deletes all stored information in storage

### clear: returns

| return        | type    | always | condition                                       |
| ------------- | ------- | ------ | ----------------------------------------------- |
| true or false | boolean | yes    | true if storage has been deleted, false otherwise |

### clear: example

```lua
local object_id = "host_2712"

local status = test_storage:clear() 
--> status is true
```
