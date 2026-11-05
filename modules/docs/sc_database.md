# Documentation of the sc_database module

- [Documentation of the sc\_database module](#documentation-of-the-sc_database-module)
  - [Introduction](#introduction)
  - [Available database backends](#available-database-backends)
  - [How are database parameters handled](#how-are-database-parameters-handled)
  - [Module initialization](#module-initialization)
    - [Module constructor](#module-constructor)
    - [Constructor: Example](#constructor-example)
  - [execute method](#execute-method)
    - [execute: parameters](#execute-parameters)
    - [execute: returns](#execute-returns)
    - [execute: example](#execute-example)
  - [open\_connection method](#open_connection-method)
    - [open\_connection: returns](#open_connection-returns)
    - [open\_connection: example](#open_connection-example)
  - [close\_connection method](#close_connection-method)
    - [close\_connection: returns](#close_connection-returns)
    - [close\_connection: example](#close_connection-example)

## Introduction

The sc_database module is a generic wrapper that helps you communicate with a database (to enrich your events with data coming from a CMDB for example). It is made in OOP (object oriented programming).

It doesn't talk to any database by itself. Instead, it loads a **database backend** and forwards every call to it. This means that your stream connector code always uses the same methods (execute, open_connection, close_connection) whatever the database engine is.

## Available database backends

Database backends are stored in the `centreon-stream-connectors-lib/database_backends` folder. Each backend file must be named `sc_database_<backend_name>.lua`. When you initialize the sc_database module with a backend name, it will try to load the file `centreon-stream-connectors-lib.database_backends.sc_database_<backend_name>`.

| backend name | module                                                    | documentation                                                |
| ------------ | --------------------------------------------------------- | ------------------------------------------------------------ |
| mysql        | centreon-stream-connectors-lib.database_backends.sc_database_mysql | [Documentation](database_backends/sc_database_mysql.md) |

Every database backend must at least provide the following methods:

- a `new(sc_common, sc_logger, params, db_params)` constructor
- an `execute(query)` method
- an `open_connection()` method
- a `close_connection()` method

## How are database parameters handled

Connection parameters (user, password, address...) can be given in two different ways:

- using the `db_params` table when initializing the module. Parameter names are the ones expected by the backend (for example `db_user`).
- using the stream connector parameters table (`params`). Parameter names are prefixed with `sc_database.<backend_name>.` (for example `sc_database.mysql.db_user`). This is what you will use when configuring your stream connector from the Centreon web interface.

**Values from the db_params table always take precedence over the ones from the params table.** The params table is only used when a parameter is missing from the db_params table.

This is useful if you need multiple database connections in the same stream connector: you can use the stream connector parameters for the first one and a dedicated db_params table for the other ones.

Each backend has its own list of mandatory parameters. Refer to the backend documentation for more information.

## Module initialization

Since this is OOP, it is required to initiate your module.

### Module constructor

Constructor must be initialized with four parameters, the fifth one (db_params) is optional:

- db_backend. The name of the database backend that must be used (for example: `mysql` to use the sc_database_mysql backend)
- common. This is an instance of the sc_common module
- logger. This is an instance of the sc_logger module
- a params table. This is the stream connector parameters table
- db_params. A table with the parameters used to connect to the database. If a mandatory parameter is missing from this table, the backend will use the one from the params table. (see [How are database parameters handled](#how-are-database-parameters-handled))

> The constructor returns **false** (and logs an error) if the database backend can't be loaded (for example: the file sc_database_<db_backend>.lua does not exist on your server).

### Constructor: Example

```lua
-- load modules
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_database = require("centreon-stream-connectors-lib.sc_database")

-- initiate "mandatory" informations for the logger module
local logfile = "/var/log/test_logger.log"
local severity = 1

-- create a new instance of the sc_logger and sc_common module
local test_logger = sc_logger.new(logfile, severity)
local test_common = sc_common.new(test_logger)

-- create the required table of parameters (usually, this is the params table from the sc_params module)
local params = {
  ["sc_database.mysql.db_user"] = "centreon",
  ["sc_database.mysql.db_password"] = "my_secret_password",
  ["sc_database.mysql.db_address"] = "10.0.0.12",
  ["sc_database.mysql.db_name"] = "cmdb",
  ["sc_database.mysql.db_port"] = 3306
}

-- create a new instance of the sc_database module using the mysql backend and the params table
local test_database = sc_database.new("mysql", test_common, test_logger, params)

-- create another instance of the sc_database module, this one connects to another database
-- db_user, db_password, db_address and db_port are not set in the db_params table so they will be taken from the params table
local db_params = {
  db_name = "inventory"
}

local test_database_inventory = sc_database.new("mysql", test_common, test_logger, params, db_params)

-- try to load a backend that doesn't exist
local test_database_fail = sc_database.new("oracle", test_common, test_logger, params)
--> test_database_fail is false
```

## execute method

The **execute** method runs the given query using the database backend. If the connection to the database is not opened yet, the backend will open it.

### execute: parameters

| parameter                  | type   | optional | default value |
| -------------------------- | ------ | -------- | ------------- |
| the query that must be run | string | no       |               |

### execute: returns

| return                         | type    | always | condition                                                                                                                         |
| ------------------------------ | ------- | ------ | --------------------------------------------------------------------------------------------------------------------------------- |
| false or the result of the query | boolean or table | yes    | false if the query is not a string or if something went wrong. A table otherwise (an empty table if the query has no result) |

### execute: example

```lua
local query = "SELECT host_id, name FROM hosts WHERE name LIKE 'central%';"
local result = test_database:execute(query)
--> result structure is:
--[[
  {
    {
      id = "2712",
      name = "central_1"
    },
    {
      id = "2713",
      name = "central_2"
    }
  }
]]

query = "SELECT id, address FROM hosts WHERE name = 'host_that_does_not_exist';"
result = test_database:execute(query)
--> result is {}

query = 2712
result = test_database:execute(query)
--> result is false
```

## open_connection method

The **open_connection** method opens the connection to the database. You usually don't need to call it yourself because the **execute** method opens the connection if needed.

### open_connection: returns

| return        | type    | always | condition                                                   |
| ------------- | ------- | ------ | ----------------------------------------------------------- |
| true or false | boolean | yes    | true if the connection has been opened, false otherwise     |

### open_connection: example

```lua
local result = test_database:open_connection()
--> result is true
```

## close_connection method

The **close_connection** method closes the connection to the database.

### close_connection: returns

| return        | type    | always | condition                                                   |
| ------------- | ------- | ------ | ----------------------------------------------------------- |
| true or false | boolean | yes    | true if the connection has been closed, false otherwise     |

### close_connection: example

```lua
local result = test_database:close_connection()
--> result is true
```
