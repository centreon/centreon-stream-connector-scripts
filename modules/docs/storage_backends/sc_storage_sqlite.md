# Documentation of the sc_storage_sqlite module

- [Documentation of the sc\_storage\_sqlite module](#documentation-of-the-sc_storage_sqlite-module)
  - [Introduction](#introduction)
  - [Prerequisites](#prerequisites)
  - [Module initialization](#module-initialization)
    - [Module constructor](#module-constructor)
    - [constructor: Example](#constructor-example)
  - [get\_query\_result method](#get_query_result-method)
    - [get\_query\_result: parameters](#get_query_result-parameters)
    - [get\_query\_result: returns](#get_query_result-returns)
    - [get\_query\_result: example](#get_query_result-example)
  - [check\_storage\_table method](#check_storage_table-method)
    - [check\_storage\_table: example](#check_storage_table-example)
  - [create\_storage\_table method](#create_storage_table-method)
    - [create\_storage\_table: example](#create_storage_table-example)
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
  - [get\_properties\_for\_object\_type method](#get_properties_for_object_type-method)
    - [get\_properties\_for\_object\_type: parameters](#get_properties_for_object_type-parameters)
    - [get\_properties\_for\_object\_type: returns](#get_properties_for_object_type-returns)
    - [get\_properties\_for\_object\_type: example](#get_properties_for_object_type-example)

## Introduction

The sc_storage_sqlite module provides methods to use sqlite as a storage backend. It is made in OOP (object oriented programming).

## Prerequisites

To be able to use this backend, you need to install luasqlite. Since this backend is not the standard one, the installation part will not explain every step nor cover every operating system.

Example for Enterprise Linux:

```bash
dnf install lua-devel make gcc sqlite-devel epel-release
dnf install luarocks
luarocks install lsqlite3
```

## Module initialization

Since this is OOP, it is required to initiate your module.

### Module constructor

The constructor can be initialized with one parameter or it will use a default value.

- sc_logger. This is an instance of the sc_logger module
- a params table.

### constructor: Example

```lua
-- load modules
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_storage_sqlite = require("centreon-stream-connectors-lib.sc_storage_sqlite")

-- initiate "mandatory" informations for the logger module
local logfile = "/var/log/test_logger.log"
local severity = 1

-- create a new instance of the sc_logger module
local test_logger = sc_logger.new(logfile, severity)

-- create the required table of parameters

local params = {
  storage_backend = "broker",
  ["sc_storage.sqlite.db_file"] = "/var/lib/centreon-broker/test-db.sdb"
}

-- create a new instance of the sc_common module
local test_storage_sqlite = sc_storage_sqlite.new(test_logger, params)
```

## get_query_result method

The **get_query_result** method is a callback function. It is called for each row found by a SQL query.

> This functions fills `self.last_query_result` with the result from the query.

### get_query_result: parameters

| parameter                                                                                                                                    | type   | optional | default value |
| -------------------------------------------------------------------------------------------------------------------------------------------- | ------ | -------- | ------------- |
| "udata": refer to [this documentation](http://lua.sqlite.org/index.cgi/doc/tip/doc/lsqlite3.wiki#db_exec) | string | no       |               |
| the number of columns from the SQL query                                                                                                     | number | no       |               |
| the value of a column                                                                                                                        | string | no       |               |
| the name of the column                                                                                                                       | string | no       |               |

### get_query_result: returns

| return | type   | always | condition |
| ------ | ------ | ------ | --------- |
| 0      | number | yes    |           |

### get_query_result: example

There is no example (that is on purpose).

## check_storage_table method

The **check_storage_table** method checks if the sc_storage table exists and, if not, creates it.

### check_storage_table: example

```lua
test_storage_sqlite:check_storage_table() 
```

## create_storage_table method

The **create_storage_table** method creates the sc_storage table.

### create_storage_table: example

```lua
test_storage_sqlite:create_storage_table() 
```

## run_query method

The **run_query** method executes the given query.

### run_query: parameters

| parameter                                                                                                                                  | type    | optional | default value |
| ------------------------------------------------------------------------------------------------------------------------------------------ | ------- | -------- | ------------- |
| the query that must be run                                                                                                                 | string  | no       |               |
| when set to true, the query results will be stored in the self.last_query_result table. If set to false, no query result will be available | boolean | yes      | false         |

### run_query: returns

| return                                | type    | always | condition |
| ------------------------------------- | ------- | ------ | --------- |
| false if query failed, true otherwise | boolean | yes    |           |

### run_query: example

```lua
local query = "INSERT OR REPLACE INTO sc_storage VALUES ('host_2712', 'city', 'Barcelone du Gers');"
local result = test_storage_sqlite:run_query(query)
-->  result is true, 
--[[
  --> test_storage_sqlite.last_query_result structure is:
  {}
]]

local query = "SELECT object_id, property, value FROM sc_storage WHERE object_id = 'host_2712' AND property = 'city';"
local result = test_storage_sqlite:run_query(query, true)
-->  result is true, 
--[[
  --> test_storage_sqlite.last_query_result structure is:
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

The **set** method inserts or updates an object property value in the sc_storage table.

### set: parameters

| parameter                                     | type                           | optional | default value |
| --------------------------------------------- | ------------------------------ | -------- | ------------- |
| the object with the property that must be set | string                         | no       |               |
| the name of the property                      | string                         | no       |               |
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

local result = test_storage_sqlite:set(object_id, property, value) 
--> result is true
```

## set_multiple method

The **set_multiple** method sets multiple object properties in the storage.

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

local result = test_storage_sqlite:set_multiple(object_id, properties) 
--> result is true
```

## get method

The **get** method retrieves a single property value for an object.

### get: parameters

| parameter                                           | type   | optional | default value |
| --------------------------------------------------- | ------ | -------- | ------------- |
| the object with the property that must be retrieved | string | no       |               |
| the name of the property                            | string | no       |               |

### get: returns

| return               | type                           | always | condition                                                    |
| -------------------- | ------------------------------ | ------ | ------------------------------------------------------------ |
| true or false        | boolean                        | yes    | true if value properly retrieved from storage, false otherwise |
| value from the storage | string, number, boolean, table | yes    | empty string if status false, value otherwise                |

### get: example

```lua
local object_id = "host_2712"
local property = "city"

local status, value = test_storage_sqlite:get(object_id, property) 
--> status is true, value is "Bordeaux"

property = "a_random_property_not_in_the_storage"
status, value = test_storage_sqlite:get(object_id, property)
--> status is true, value is ""
```

## get_multiple method

The **get_multiple** method retrieves a list of properties for an object.

### get_multiple: parameters

| parameter                                           | type   | optional | default value |
| --------------------------------------------------- | ------ | -------- | ------------- |
| the object with the property that must be retrieved | string | no       |               |
| a list of properties                                | table  | no       |               |

### get_multiple: returns

| return                | type    | always | condition                                                                  |
| --------------------- | ------- | ------ | -------------------------------------------------------------------------- |
| true or false         | boolean | yes    | true if value properly retrieved from storage, false otherwise               |
| values from the storage | table   | yes    | empty table if status false, table of properties and their value otherwise |

### get_multiple: example

```lua
local object_id = "host_2712"
local properties = {"city", "country"}

local status, values = test_storage_sqlite:get_multiple(object_id, properties) 
--> status is true
--[[
  values structure is:
  {
    city = "Bordeaux",
    country = "France"
  }
]]
```

## delete method

The **delete** method deletes an object property in the storage.

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

local status, value = test_storage_sqlite:delete(object_id, property) 
--> status is true
```

## delete_multiple method

The **delete_multiple** method deletes object properties in the storage.

### delete_multiple: parameters

| parameter                                         | type   | optional | default value |
| ------------------------------------------------- | ------ | -------- | ------------- |
| the object with the property that must be deleted | string | no       |               |
| list of properties                                | table  | no       |               |

### delete_multiple: returns

| return        | type    | always | condition                                                |
| ------------- | ------- | ------ | -------------------------------------------------------- |
| true or false | boolean | yes    | true if value properly deleted in storage, false otherwise |

### delete_multiple: example

```lua
local object_id = "host_2712"
local properties = {"city", "country"}

local status= test_storage_sqlite:delete_multiple(object_id, properties) 
--> status is true
```

## show method

The **show** method shows (in the log file) all stored properties of an object.

### show: parameters

| parameter                                         | type   | optional | default value |
| ------------------------------------------------- | ------ | -------- | ------------- |
| the object with the property that must be shown | string | no       |               |

### show: returns

| return        | type    | always | condition                                                |
| ------------- | ------- | ------ | -------------------------------------------------------- |
| true or false | boolean | yes    | true if object properties are retrieved, false otherwise |

### show: example

```lua
local object_id = "host_2712"

local status = test_storage_sqlite:show(object_id) 
--> status is true
```

## clear method

The **clear** method deletes all stored information in storage.

### clear: returns

| return        | type    | always | condition                                       |
| ------------- | ------- | ------ | ----------------------------------------------- |
| true or false | boolean | yes    | true if storage has been deleted, false otherwise |

### clear: example

```lua
local object_id = "host_2712"

local status = test_storage_sqlite:clear() 
--> status is true
```

## get_properties_for_object_type method

The **get_properties_for_object_type** method retrieves a list of properties for a given object.

### get_properties_for_object_type: parameters

| parameter                                           | type   | optional | default value |
| --------------------------------------------------- | ------ | -------- | ------------- |
| the object type with the properties that must be retrieved (can be host, service, BA or metric) | string | no       |               |
| a list of properties                                | table  | no       |               |

### get_properties_for_object_type: returns

| return                | type    | always | condition                                                                           |
| --------------------- | ------- | ------ | ----------------------------------------------------------------------------------- |
| true or false         | boolean | yes    | true if value properly retrieved from storage, false otherwise                        |
| values from the storage | table   | yes    | empty table if first return is false, table of properties and their value otherwise |

### get_properties_for_object_type: example

```lua
local object_type = "host"
local properties = {"city", "country"}

local status, values = test_storage:get_properties_for_object_type(object_type, properties) 
--> status is true
--[[
  values structure is:
  {
    host_2712 = {
      city = "Bordeaux",
      country = "France"
    },
    host_1911 = {
      city = "Rabanastre",
      country = "Dalmasca"
    }
  }
]]
```
