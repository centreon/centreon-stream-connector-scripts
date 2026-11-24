# Documentation of the sc_database module

- [Documentation of the sc\_database module](#documentation-of-the-sc_database-module)
  - [Introduction](#introduction)
  - [Available database backends](#available-database-backends)
  - [TLS support](#tls-support)
  - [Triggers](#triggers)
  - [How are database parameters handled](#how-are-database-parameters-handled)
  - [Module initialization](#module-initialization)
    - [Module constructor](#module-constructor)
    - [Constructor: Example](#constructor-example)
  - [escape method](#escape-method)
    - [escape: parameters](#escape-parameters)
    - [escape: returns](#escape-returns)
    - [escape: example](#escape-example)
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

It doesn't talk to any database by itself. Instead, it loads a **database backend** and forwards every call to it. This means that your stream connector code always uses the same methods (escape, execute, open_connection, close_connection) whatever the database engine is.

## Available database backends

Database backends are stored in the `centreon-stream-connectors-lib/database_backends` folder. Each backend file must be named `sc_database_<backend_name>.lua`. When you initialize the sc_database module with a backend name, it will try to load the file `centreon-stream-connectors-lib.database_backends.sc_database_<backend_name>`.

| backend name | module                                                             | documentation                                           |
| ------------ | ------------------------------------------------------------------ | ------------------------------------------------------- |
| mysql        | centreon-stream-connectors-lib.database_backends.sc_database_mysql | [Documentation](database_backends/sc_database_mysql.md) |

Every database backend must at least provide the following methods:

- a `new(sc_common, sc_logger, sc_trigger, params, db_params)` constructor
- an `execute(query)` method
- an `open_connection()` method
- a `close_connection()` method
- an `escape_nil()` method
- an `escape_string(value)` method
- an `escape_boolean(value)` method
- an `escape_number(value)` method

The escape_* methods are not meant to be called by stream connectors. They are called by the [escape method](#escape-method) of the sc_database module.

## TLS support

> **Disclaimer:** not every database backend is able to encrypt the connection to the database. When a backend doesn't support TLS, the user name, the password and the data are sent in clear text. In this case, only use it with a database running on the same server as the stream connector (localhost), through a trusted network or through an encrypted tunnel (stunnel, SSH tunnel...).

| backend name | TLS support     | details                                                                                                                                                                                                                       |
| ------------ | --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| mysql        | ❌ not supported | the luasql-mysql driver doesn't provide any TLS option. The connection is not encrypted, even if TLS is enabled on the database server. See the [sc_database_mysql documentation](database_backends/sc_database_mysql.md#tls) |

## Triggers

The sc_database module and its database backends fire triggers at specific moments, so you can run your own Lua code without editing the stream connector (see [how to use triggers](how_to_use_triggers.md)).

| category                           | event_type | when triggered                                                                    | documentation                                                                                 |
| ---------------------------------- | ---------- | --------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| sc_database:execute                | on-success | a query has been successfully run                                                 | [Documentation](how_to_use_triggers.md#sc_databaseexecute--on-success)                        |
| sc_database:execute                | on-fail    | a query failed                                                                    | [Documentation](how_to_use_triggers.md#sc_databaseexecute--on-fail)                           |
| sc_database_mysql:open_connection  | on-success | the mysql backend opened a connection (including automatic reconnections)        | [Documentation](how_to_use_triggers.md#sc_database_mysqlopen_connection--on-success)          |
| sc_database_mysql:open_connection  | on-fail    | the mysql backend couldn't open a connection                                      | [Documentation](how_to_use_triggers.md#sc_database_mysqlopen_connection--on-fail)             |
| sc_database_mysql:close_connection | on-success | the mysql backend closed a connection (including before automatic reconnections) | [Documentation](how_to_use_triggers.md#sc_database_mysqlclose_connection--on-success)         |

The sc_database:execute triggers are fired by the sc_database module, whatever the database backend is. The other ones are fired by the database backend itself and their category starts with the name of the backend.

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

Constructor must be initialized with the following parameters. The trigger (it can be nil) and db_params parameters are optional:

- db_backend. The name of the database backend that must be used (for example: `mysql` to use the sc_database_mysql backend)
- common. This is an instance of the sc_common module
- logger. This is an instance of the sc_logger module
- trigger. This is an instance of the sc_trigger module, it is used to run the triggers registered by the user (see [how to use triggers](how_to_use_triggers.md)). It is also given to the database backend. If you give nil, a default sc_trigger instance is created. You should give the sc_trigger instance of your stream connector, otherwise the trigger file is executed a second time to create the default instance
- a params table. This is the stream connector parameters table
- db_params. A table with the parameters used to connect to the database. If a mandatory parameter is missing from this table, the backend will use the one from the params table. (see [How are database parameters handled](#how-are-database-parameters-handled))

> The constructor returns **false** (and logs an error) if the database backend can't be loaded (for example: the file sc_database_<db_backend>.lua does not exist on your server).

### Constructor: Example

```lua
-- load modules
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_trigger = require("centreon-stream-connectors-lib.sc_trigger")
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

-- create a new instance of the sc_trigger module
local test_trigger = sc_trigger.new(params, test_common, test_logger)

-- create a new instance of the sc_database module using the mysql backend and the params table
local test_database = sc_database.new("mysql", test_common, test_logger, test_trigger, params)

-- create another instance of the sc_database module, this one connects to another database
-- db_user, db_password, db_address and db_port are not set in the db_params table so they will be taken from the params table
local db_params = {
  db_name = "inventory"
}

local test_database_inventory = sc_database.new("mysql", test_common, test_logger, test_trigger, params, db_params)

-- try to load a backend that doesn't exist
local test_database_fail = sc_database.new("oracle", test_common, test_logger, test_trigger, params)
--> test_database_fail is false
```

## escape method

The **escape** method converts a Lua value into a SQL value that can be safely used **as is** in a query. It checks the type of the value and calls the appropriate method of the database backend:

| Lua type | backend method                                                         | MySQL example             |
| -------- | ---------------------------------------------------------------------- | ------------------------- |
| nil      | escape_nil()                                                           | `NULL`                    |
| string   | escape_string(value): escapes the string and wraps it in single quotes | `O'Brien` -> `'O\'Brien'` |
| boolean  | escape_boolean(value)                                                  | `true` -> `1`             |
| number   | escape_number(value)                                                   | `0.1` -> `0.1`            |

Any other type (table, function...) as well as NaN and infinite numbers are refused.

Since the returned value is already formatted for the database engine (quotes included for strings), you must follow the rules listed below:

- **never** put quotes around a value returned by the escape method.
- always give the raw value to the escape method. **Never** escape a value twice, the second escape would change the data (`O'Brien` would be stored as `O\'Brien`).
- never use the escape method on a whole query, only on the values that you put in it.
- the escape method can't be used for table or column names. If they come from a parameter, check them against a list of allowed values.
- `nil` is converted to `NULL`, which is mostly useful in INSERT and UPDATE queries. In a WHERE clause, remember that `column = NULL` never matches anything in SQL (use `column IS NULL` instead).

> If you build your query without the escape method, you are responsible for its syntax and its security.

### escape: parameters

| parameter               | type                         | optional | default value |
| ----------------------- | ---------------------------- | -------- | ------------- |
| the raw value to escape | string, number, boolean, nil | no       |               |

### escape: returns

| return                     | type              | always | condition                                                                                                            |
| -------------------------- | ----------------- | ------ | -------------------------------------------------------------------------------------------------------------------- |
| false or the escaped value | boolean or string | yes    | false if the type is not supported, if the number is NaN or infinite, or if escaping failed. The SQL value otherwise |

### escape: example

```lua
local host_name = test_database:escape("O'Brien")
--> host_name is the string 'O\'Brien' (quotes included, with the mysql backend)

local state = test_database:escape(2)
--> state is "2"

local acknowledged = test_database:escape(true)
--> acknowledged is "1" (with the mysql backend)

local comment = test_database:escape(nil)
--> comment is "NULL"

local query = "INSERT INTO events (host_name, state, acknowledged, comment) VALUES ("
  .. host_name .. ", " .. state .. ", " .. acknowledged .. ", " .. comment .. ");"
--> query is: INSERT INTO events (host_name, state, acknowledged, comment) VALUES ('O\'Brien', 2, 1, NULL);

local result = test_database:escape({ "a", "table" })
--> result is false

result = test_database:escape(0/0)
--> result is false
```

## execute method

The **execute** method runs the given query using the database backend. If the connection to the database is not opened yet, the backend will open it.

If the query fails because the connection has been lost (database restart, network issue, idle connection closed by the server...), the backend opens the connection again and runs the query a second time. If the query fails for another reason (syntax error, missing table, missing permission...), it is not run again.

### execute: parameters

| parameter                  | type   | optional | default value |
| -------------------------- | ------ | -------- | ------------- |
| the query that must be run | string | no       |               |

### execute: returns

| return                           | type             | always | condition                                                                                                                    |
| -------------------------------- | ---------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------- |
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

query = "UPDATE hosts SET address = '10.0.0.1' WHERE id = 2712;"
result = test_database:execute(query)
--> result is {}

query = 2712
result = test_database:execute(query)
--> result is false
```

## open_connection method

The **open_connection** method opens the connection to the database. You usually don't need to call it yourself because the **execute** method opens the connection if needed.

### open_connection: returns

| return        | type    | always | condition                                               |
| ------------- | ------- | ------ | ------------------------------------------------------- |
| true or false | boolean | yes    | true if the connection has been opened, false otherwise |

### open_connection: example

```lua
local result = test_database:open_connection()
--> result is true
```

## close_connection method

The **close_connection** method closes the connection to the database. If no connection has been opened, there is nothing to do and the method returns true.

### close_connection: returns

| return        | type    | always | condition                                                                                        |
| ------------- | ------- | ------ | ------------------------------------------------------------------------------------------------ |
| true or false | boolean | yes    | true if the connection has been closed (or if there was no connection to close), false otherwise |

### close_connection: example

```lua
local result = test_database:close_connection()
--> result is true
```
