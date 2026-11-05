# Documentation of the sc_database_mysql module

- [Documentation of the sc\_database\_mysql module](#documentation-of-the-sc_database_mysql-module)
  - [Introduction](#introduction)
  - [Prerequisites](#prerequisites)
  - [Parameters](#parameters)
  - [Module initialization](#module-initialization)
    - [Module constructor](#module-constructor)
    - [constructor: Example](#constructor-example)
  - [check\_mandatory\_params method](#check_mandatory_params-method)
    - [check\_mandatory\_params: returns](#check_mandatory_params-returns)
    - [check\_mandatory\_params: example](#check_mandatory_params-example)
  - [open\_connection method](#open_connection-method)
    - [open\_connection: returns](#open_connection-returns)
    - [open\_connection: example](#open_connection-example)
  - [close\_connection method](#close_connection-method)
    - [close\_connection: returns](#close_connection-returns)
    - [close\_connection: example](#close_connection-example)
  - [build\_result method](#build_result-method)
    - [build\_result: parameters](#build_result-parameters)
    - [build\_result: returns](#build_result-returns)
    - [build\_result: example](#build_result-example)
  - [execute method](#execute-method)
    - [execute: parameters](#execute-parameters)
    - [execute: returns](#execute-returns)
    - [execute: example](#execute-example)
  - [escape\_nil method](#escape_nil-method)
    - [escape\_nil: returns](#escape_nil-returns)
    - [escape\_nil: example](#escape_nil-example)
  - [escape\_string method](#escape_string-method)
    - [escape\_string: parameters](#escape_string-parameters)
    - [escape\_string: returns](#escape_string-returns)
    - [escape\_string: example](#escape_string-example)
  - [escape\_boolean method](#escape_boolean-method)
    - [escape\_boolean: parameters](#escape_boolean-parameters)
    - [escape\_boolean: returns](#escape_boolean-returns)
    - [escape\_boolean: example](#escape_boolean-example)
  - [escape\_number method](#escape_number-method)
    - [escape\_number: parameters](#escape_number-parameters)
    - [escape\_number: returns](#escape_number-returns)
    - [escape\_number: example](#escape_number-example)

## Introduction

The sc_database_mysql module provides methods to use a MySQL or MariaDB database as a database backend for the [sc_database module](../sc_database.md). It is made in OOP (object oriented programming).

You should not use this module directly. Use the sc_database module with `mysql` as the database backend instead.

## Prerequisites

To be able to use this backend, you need to install luasql-mysql. Since this backend is not the standard one, the installation part will not explain every step nor cover every operating system.

Example for Enterprise Linux:

```bash
dnf install lua-devel make gcc mariadb-connector-c-devel epel-release
dnf install luarocks
luarocks install luasql-mysql MYSQL_INCDIR=/usr/include/mysql
```

## Parameters

The following parameters are mandatory. They are first read from the db_params table. If a parameter is missing from the db_params table, the module will use the stream connector parameter with the `sc_database.mysql.` prefix.

| db_params name | stream connector parameter name | type   | default value | description                              |
| -------------- | ------------------------------- | ------ | ------------- | ---------------------------------------- |
| db_user        | sc_database.mysql.db_user       | string |               | the user used to connect to the database |
| db_password    | sc_database.mysql.db_password   | string |               | the password of the database user        |
| db_address     | sc_database.mysql.db_address    | string |               | the address of the database server       |
| db_name        | sc_database.mysql.db_name       | string |               | the name of the database                 |
| db_port        | sc_database.mysql.db_port       | number | 3306          | the port of the database server          |

> Every parameter must be a non empty value of the expected type. If it is not the case, the module will log the invalid parameters and will not try to connect to the database.

## Module initialization

Since this is OOP, it is required to initiate your module.

### Module constructor

Constructor must be initialized with three parameters, the fourth one (db_params) is optional:

- common. This is an instance of the sc_common module
- logger. This is an instance of the sc_logger module
- a params table. This is the stream connector parameters table
- db_params. A table with the parameters used to connect to the database (see [Parameters](#parameters))

The constructor checks the mandatory parameters (using the [check_mandatory_params method](#check_mandatory_params-method)) and stores the result in `self.is_configuration_valid`. It does not open the connection to the database, this is done by the [execute method](#execute-method) or the [open_connection method](#open_connection-method).

### constructor: Example

```lua
-- load modules
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_database_mysql = require("centreon-stream-connectors-lib.database_backends.sc_database_mysql")

-- initiate "mandatory" informations for the logger module
local logfile = "/var/log/test_logger.log"
local severity = 1

-- create a new instance of the sc_logger and sc_common module
local test_logger = sc_logger.new(logfile, severity)
local test_common = sc_common.new(test_logger)

-- create the required table of parameters
local params = {
  ["sc_database.mysql.db_user"] = "centreon",
  ["sc_database.mysql.db_password"] = "my_secret_password",
  ["sc_database.mysql.db_address"] = "10.0.0.12",
  ["sc_database.mysql.db_port"] = 3306
}

-- db_name is only set in the db_params table, other parameters come from the params table
local db_params = {
  db_name = "cmdb"
}

-- create a new instance of the sc_database_mysql module
local test_database_mysql = sc_database_mysql.new(test_common, test_logger, params, db_params)
```

## check_mandatory_params method

The **check_mandatory_params** method makes sure that every mandatory parameter is set with the expected type. Missing parameters in the db_params table are filled with the values from the params table.

> This method is automatically called by the constructor.

### check_mandatory_params: returns

| return        | type    | always | condition                                                      |
| ------------- | ------- | ------ | -------------------------------------------------------------- |
| true or false | boolean | yes    | true if all mandatory parameters are valid, false otherwise |

### check_mandatory_params: example

```lua
local result = test_database_mysql:check_mandatory_params()
--> result is true

--[[
  --> test_database_mysql.db_params structure is:
  {
    db_user = "centreon",
    db_password = "my_secret_password",
    db_address = "10.0.0.12",
    db_name = "cmdb",
    db_port = 3306
  }
]]
```

## open_connection method

The **open_connection** method opens the connection to the database using the luasql.mysql module. It sets `self.is_db_connection_active` to true when the connection is opened.

> The connection will not be opened if the parameters are invalid or if the luasql.mysql module can't be loaded.

### open_connection: returns

| return        | type    | always | condition                                               |
| ------------- | ------- | ------ | ------------------------------------------------------- |
| true or false | boolean | yes    | true if the connection has been opened, false otherwise |

### open_connection: example

```lua
local result = test_database_mysql:open_connection()
--> result is true
--> test_database_mysql.is_db_connection_active is true
```

## close_connection method

The **close_connection** method closes the connection to the database.

### close_connection: returns

| return        | type    | always | condition                                               |
| ------------- | ------- | ------ | ------------------------------------------------------- |
| true or false | boolean | yes    | true if the connection has been closed, false otherwise |

### close_connection: example

```lua
local result = test_database_mysql:close_connection()
--> result is true
```

## build_result method

The **build_result** method converts a luasql cursor into a table. Each row of the result is a table indexed by column names.

### build_result: parameters

| parameter                                                                                   | type   | optional | default value |
| ------------------------------------------------------------------------------------------- | ------ | -------- | ------------- |
| a luasql cursor. Refer to [this documentation](https://lunarmodules.github.io/luasql/manual.html#cursor_object) | object | no       |               |

### build_result: returns

| return                    | type  | always | condition                                  |
| ------------------------- | ----- | ------ | ------------------------------------------ |
| the content of the cursor | table | yes    | an empty table if the cursor has no row |

### build_result: example

There is no example (that is on purpose).

## execute method

The **execute** method runs the given query.

- if the connection to the database is not active, it will try to open it first.
- if the query fails, it considers that the connection may have been lost. It will try to open the connection again and run the query a second time.

### execute: parameters

| parameter                  | type   | optional | default value |
| -------------------------- | ------ | -------- | ------------- |
| the query that must be run | string | no       |               |

### execute: returns

| return                           | type             | always | condition                                                                                    |
| -------------------------------- | ---------------- | ------ | -------------------------------------------------------------------------------------------- |
| false or the result of the query | boolean or table | yes    | false if something went wrong. A table otherwise (an empty table if the query has no result) |

### execute: example

```lua
local query = "SELECT host_id, name FROM hosts WHERE name LIKE 'central%';"
local result = test_database_mysql:execute(query)
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
result = test_database_mysql:execute(query)
--> result is {}
```

## escape_nil method

The **escape_nil** method converts a nil value into its MySQL equivalent: `NULL`.

> You should not call this method directly. Use the [escape method](../sc_database.md#escape-method) of the sc_database module instead.

### escape_nil: returns

| return | type   | always | condition |
| ------ | ------ | ------ | --------- |
| NULL   | string | yes    |           |

### escape_nil: example

```lua
local result = test_database_mysql:escape_nil()
--> result is "NULL"
```

## escape_string method

The **escape_string** method escapes a string using the luasql escape method and wraps it in single quotes so it can be used as is in a query.

The luasql escape method relies on the charset of the connection. Therefore, the connection to the database is opened if it is not already active.

> You should not call this method directly. Use the [escape method](../sc_database.md#escape-method) of the sc_database module instead.

### escape_string: parameters

| parameter                | type   | optional | default value |
| ------------------------ | ------ | -------- | ------------- |
| the raw string to escape | string | no       |               |

### escape_string: returns

| return                                 | type              | always | condition                                                                                 |
| -------------------------------------- | ----------------- | ------ | ----------------------------------------------------------------------------------------- |
| false or the escaped and quoted string | boolean or string | yes    | false if the connection to the database couldn't be opened, the escaped string otherwise |

### escape_string: example

```lua
local result = test_database_mysql:escape_string("O'Brien")
--> result is the string 'O\'Brien' (quotes included)
```

## escape_boolean method

The **escape_boolean** method converts a boolean into its MySQL equivalent. MySQL doesn't have a real boolean type (TRUE and FALSE are aliases of 1 and 0), so the boolean is converted to `1` or `0`.

> You should not call this method directly. Use the [escape method](../sc_database.md#escape-method) of the sc_database module instead.

### escape_boolean: parameters

| parameter                 | type    | optional | default value |
| ------------------------- | ------- | -------- | ------------- |
| the boolean to convert    | boolean | no       |               |

### escape_boolean: returns

| return | type   | always | condition                                    |
| ------ | ------ | ------ | -------------------------------------------- |
| 1 or 0 | string | yes    | "1" if the value is true, "0" if it is false |

### escape_boolean: example

```lua
local result = test_database_mysql:escape_boolean(true)
--> result is "1"

result = test_database_mysql:escape_boolean(false)
--> result is "0"
```

## escape_number method

The **escape_number** method converts a number into a MySQL number literal without losing precision:

- integers are written with all their digits.
- floats are written with their shortest representation (`%.14g`). If this representation loses precision, the full one (`%.17g`) is used instead.

Big or small numbers may be written using the scientific notation (for example `1e+20`), which is valid in MySQL.

> You should not call this method directly. Use the [escape method](../sc_database.md#escape-method) of the sc_database module instead. It refuses NaN and infinite numbers before calling this method.

### escape_number: parameters

| parameter             | type   | optional | default value |
| --------------------- | ------ | -------- | ------------- |
| the number to convert | number | no       |               |

### escape_number: returns

| return                  | type   | always | condition |
| ----------------------- | ------ | ------ | --------- |
| the number as a string  | string | yes    |           |

### escape_number: example

```lua
local result = test_database_mysql:escape_number(42)
--> result is "42"

result = test_database_mysql:escape_number(0.1)
--> result is "0.1"

result = test_database_mysql:escape_number(0.1 + 0.2)
--> result is "0.30000000000000004"

result = test_database_mysql:escape_number(1e20)
--> result is "1e+20"
```
