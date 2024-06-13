# Documentation of the sc_cache_sqlite module

- [Documentation of the sc\_cache\_sqlite module](#documentation-of-the-sc_cache_sqlite-module)
  - [Introduction](#introduction)
  - [Prerequisites](#prerequisites)
  - [Module initialization](#module-initialization)
    - [Module constructor](#module-constructor)
    - [constructor: Example](#constructor-example)
  - [get\_query\_result method](#get_query_result-method)
    - [get\_query\_result: parameters](#get_query_result-parameters)
    - [get\_query\_result: returns](#get_query_result-returns)
    - [get\_query\_result: example](#get_query_result-example)
  - [check\_cache\_table method](#check_cache_table-method)
    - [check\_cache\_table: example](#check_cache_table-example)
  - [create\_cache\_table method](#create_cache_table-method)
    - [create\_cache\_table: example](#create_cache_table-example)
  - [run\_query method](#run_query-method)
    - [run\_query: parameters](#run_query-parameters)
    - [run\_query: returns](#run_query-returns)
    - [run\_query: example](#run_query-example)
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

The sc_cache_sqlite module provides methods to use sqlite as a cache backend. It has been made in OOP (object oriented programming)

## Prerequisites

To be able to use this backend, you need to install luasqlite. Since this backend is not the standard one, the installation part will not explain every step nor cover every operating system.

Example for enterprise linux

```bash
dnf install lua-devel make gcc sqlite-devel epel-release
dnf install luarocks
luarocks install lsqlite3
```

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
local sc_cache_sqlite = require("centreon-stream-connectors-lib.sc_cache_sqlite")

-- initiate "mandatory" informations for the logger module
local logfile = "/var/log/test_logger.log"
local severity = 1

-- create a new instance of the sc_logger module
local test_logger = sc_logger.new(logfile, severity)

-- create the required table of parameters

local params = {
  cache_backend = "broker",
  ["sc_cache.sqlite.db_file"] = "/var/lib/centreon-broker/test-db.sdb"
}

-- create a new instance of the sc_common module
local test_cache_sqlite_sqlite = sc_cache_sqlite.new(test_logger, params)
```

## get_query_result method

The **get_query_result** method is a callback function. It is called for each row found by a sql query.

> This functions fills the `self.last_query_result` with the result from the query

### get_query_result: parameters

| parameter                                                                                                                                    | type   | optional | default value |
| -------------------------------------------------------------------------------------------------------------------------------------------- | ------ | -------- | ------------- |
| "udata", I'm sorry, I have no explanation apart from [this documentation](http://lua.sqlite.org/index.cgi/doc/tip/doc/lsqlite3.wiki#db_exec) | string | no       |               |
| the number of columns from the sql query                                                                                                     | number | no       |               |
| the value of a column                                                                                                                        | string | no       |               |
| the name of the column                                                                                                                       | string | no       |               |

### get_query_result: returns

| return | type   | always | condition |
| ------ | ------ | ------ | --------- |
| 0      | number | yes    |           |

### get_query_result: example

there is no example. (that is on purpose)

## check_cache_table method

The **check_cache_table** method checks if the sc_cache table exists and, if not, create it.

### check_cache_table: example

```lua
test_cache_sqlite:check_cache_table() 
```

## create_cache_table method

The **create_cache_table** method creates the sc_cache table.

### create_cache_table: example

```lua
test_cache_sqlite:create_cache_table() 
```

## run_query method

The **run_query** method executes the given query

### run_query: parameters

| parameter                                                                                                                                  | type    | optional | default value |
| ------------------------------------------------------------------------------------------------------------------------------------------ | ------- | -------- | ------------- |
| the query that must be run                                                                                                                 | string  | no       |               |
| When set to true, the query results will be stored in the self.last_query_result table. If set to false, no query result will be available | boolean | yes      | false         |

### run_query: returns

| return                                | type    | always | condition |
| ------------------------------------- | ------- | ------ | --------- |
| false if query failed, true otherwise | boolean | yes    |           |

### run_query: example

```lua
local query = "INSERT OR REPLACE INTO sc_cache VALUES ('host_2712', 'city', 'Barcelone du Gers');"
local result = test_cache_sqlite:run_query(query)
-->  result is true, 
--[[
  --> test_cache_sqlite.last_query_result structure is:
  {}
]]

local query = "SELECT object_id, property, value FROM sc_cache WHERE object_id = 'host_2712' AND property = 'city';"
local result = test_cache_sqlite:run_query(query, true)
-->  result is true, 
--[[
  --> test_cache_sqlite.last_query_result structure is:
  {
    {
      object_id = 'host_2712',
      property = 'city',
      value = 'Barcelone du Gers'
    }
  }
]]
```

## set method

The **set** method inserts or updates an object property value in the sc_cache table

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

local result = test_cache_sqlite:set(object_id, property, value) 
--> result is true
```

## set_multiple method

The **set_multiple** method sets multiple object properties in the cache

### set_multiple: parameters

| parameter                                     | type   | optional | default value |
| --------------------------------------------- | ------ | -------- | ------------- |
| the object with the property that must be set | string | no       |               |
| a table of properties and their values        | table  | no       |               |

### set_multiple: returns

| return        | type    | always | condition                                            |
| ------------- | ------- | ------ | ---------------------------------------------------- |
| true or false | boolean | yes    | true if value properly set in cache, false otherwise |

### set_multiple: example

```lua
local object_id = "host_2712"
local properties = {
  city = "Bordeaux",
  country = "France"
}

local result = test_cache_sqlite:set_multiple(object_id, properties) 
--> result is true
```

## get method

The **get** method retrieves a single property value of an object

### get: parameters

| parameter                                           | type   | optional | default value |
| --------------------------------------------------- | ------ | -------- | ------------- |
| the object with the property that must be retrieved | string | no       |               |
| the name of the property                            | string | no       |               |

### get: returns

| return               | type                    | always | condition                                                    |
| -------------------- | ----------------------- | ------ | ------------------------------------------------------------ |
| true or false        | boolean                 | yes    | true if value properly retrieved from cache, false otherwise |
| value from the cache | string, number, boolean | yes    | empty string if status false, value otherwise                |

### get: example

```lua
local object_id = "host_2712"
local property = "city"

local status, value = test_cache_sqlite:get(object_id, property) 
--> status is true, value is "Bordeaux"

property = "a_random_property_not_in_the_cache"
status, value = test_cache_sqlite:get(object_id, property)
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

| return                | type    | always | condition                                                                  |
| --------------------- | ------- | ------ | -------------------------------------------------------------------------- |
| true or false         | boolean | yes    | true if value properly retrieved from cache, false otherwise               |
| values from the cache | table   | yes    | empty table if status false, table of properties and their value otherwise |

### get_multiple: example

```lua
local object_id = "host_2712"
local properties = {"city", "country"}

local status, values = test_cache_sqlite:get_multiple(object_id, properties) 
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

local status, value = test_cache_sqlite:delete(object_id, property) 
--> status is true
```

## delete_multiple method

The **delete_multiple** method deletes an object properties in the cache

### delete_multiple: parameters

| parameter                                         | type   | optional | default value |
| ------------------------------------------------- | ------ | -------- | ------------- |
| the object with the property that must be deleted | string | no       |               |
| list of properties                                | table  | no       |               |

### delete_multiple: returns

| return        | type    | always | condition                                                |
| ------------- | ------- | ------ | -------------------------------------------------------- |
| true or false | boolean | yes    | true if value properly deleted in cache, false otherwise |

### delete_multiple: example

```lua
local object_id = "host_2712"
local properties = {"city", "country"}

local status= test_cache_sqlite:delete_multiple(object_id, properties) 
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

local status = test_cache_sqlite:show(object_id) 
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

local status = test_cache_sqlite:clear() 
--> status is true
```
