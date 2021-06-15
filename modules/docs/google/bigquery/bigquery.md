# Documentation of the google bigquery module

- [Documentation of the google bigquery module](#documentation-of-the-google-bigquery-module)
  - [Introduction](#introduction)
  - [Module initialization](#module-initialization)
    - [Module constructor](#module-constructor)
    - [constructor: Example](#constructor-example)
  - [get_tables_schema method](#get_tables_schema-method)
    - [get_tables_schema: returns](#get_tables_schema-returns)
    - [get_tables_schema: example](#get_tables_schema-example)
  - [default_host_table_schema method](#default_host_table_schema-method)
    - [default_host_table_schema: returns](#default_host_table_schema-returns)
    - [default_host_table_schema: example](#default_host_table_schema-example)
  - [default_service_table_schema method](#default_service_table_schema-method)
    - [default_service_table_schema: returns](#default_service_table_schema-returns)
    - [default_service_table_schema: example](#default_service_table_schema-example)
  - [default_ack_table_schema method](#default_ack_table_schema-method)
    - [default_ack_table_schema: returns](#default_ack_table_schema-returns)
    - [default_ack_table_schema: example](#default_ack_table_schema-example)
  - [default_dt_table_schema method](#default_dt_table_schema-method)
    - [default_dt_table_schema: returns](#default_dt_table_schema-returns)
    - [default_dt_table_schema: example](#default_dt_table_schema-example)
  - [default_ba_table_schema method](#default_ba_table_schema-method)
    - [default_ba_table_schema: returns](#default_ba_table_schema-returns)
    - [default_ba_table_schema: example](#default_ba_table_schema-example)
  - [load_tables_schema_file method](#load_tables_schema_file-method)
    - [load_tables_schema_file: returns](#load_tables_schema_file-returns)
    - [load_tables_schema_file: example](#load_tables_schema_file-example)
  - [build_table_schema method](#build_table_schema-method)
    - [build_table_schema: parameters](#build_table_schema-parameters)
    - [build_table_schema: example](#build_table_schema-example)

## Introduction

The google bigquery module provides methods to handle table schemas . It has been made in OOP (object oriented programming)

## Module initialization

Since this is OOP, it is required to initiate your module

### Module constructor

Constructor can be initialized with two parameters, if the second one is not provided it will use a default value

- params. This is a table of all the stream connectors parameters
- sc_logger. This is an instance of the sc_logger module

If you don't provide the sc_logger parameter it will create a default sc_logger instance with default parameters ([sc_logger default params](./sc_logger.md#module-initialization))

### constructor: Example

```lua
-- load modules
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_bq = require("centreon-stream-connecotrs-lib.google.bigquery.bigquery")

-- initiate "mandatory" informations for the logger module
local logfile = "/var/log/test_logger.log"
local severity = 1

-- create a new instance of the sc_logger module
local test_logger = sc_logger.new(logfile, severity)

-- some stream connector params
local params = {
  my_param = "my_value"
}

-- create a new instance of the google bigquery module
local test_bq = sc_bq.new(params, test_logger)
```

## get_tables_schema method

The **get_tables_schema** method retrieves the schemas for host_status, service_status, downtime, acknowledgement and BA events. Depending on the configuration, it creates them from a default configuration, a JSON configuration file or straight from the stream connector parameters

head over the following chapters for more information

For the default tables schema that are provided:

- [default_host_table_schema](#default_host_table_schema-method)
- [default_service_table_schema](#default_service_table_schema-method)
- [default_ack_table_schema](#default_ack_table_schema-method)
- [default_dt_table_schema](#default_dt_table_schema-method)
- [default_ba_table_schema](#default_ba_table_schema-method)

For the other methods:

- [load_tables_schema_file](#load_tables_schema_file-method)
- [build_table_schema](#build_table_schema-method)

### get_tables_schema: returns

| return | type    | always | condition |
| ------ | ------- | ------ | --------- |
| true   | boolean | yes    |           |

### get_tables_schema: example

```lua
local result = test_bq:get_tables_schema()
--> result is true
--> schemas are stored in test_bq.schemas[<category_id>][<element_id>]
```

## default_host_table_schema method

The **default_host_table_schema** method retrieves the schemas for host_status events

### default_host_table_schema: returns

| return            | type  | always | condition |
| ----------------- | ----- | ------ | --------- |
| host schema table | table | yes    |           |

### default_host_table_schema: example

```lua
local result = test_bq:default_host_table_schema()
--> result is : 
--[[
  {
    host_id = "{host_id}",
    host_name = "{cache.host.name}",
    status = "{state}",
    last_check = "{last_check}",
    output = "{output}",
    instance_id = "{cache.host.instance_id}"
  }
]]--
```

## default_service_table_schema method

The **default_service_table_schema** method retrieves the schemas for service_status events

### default_service_table_schema: returns

| return               | type  | always | condition |
| -------------------- | ----- | ------ | --------- |
| service schema table | table | yes    |           |

### default_service_table_schema: example

```lua
local result = test_bq:default_service_table_schema()
--> result is : 
--[[
  {
    host_id = "{host_id}",
    host_name = "{cache.host.name}",
    service_id = "{service_id}",
    service_description = "{cache.service.description}",
    status = "{state}",
    last_check = "{last_check}",
    output = "{output}",
    instance_id = "{cache.host.instance_id}"
  }
]]--
```

## default_ack_table_schema method

The **default_ack_table_schema** method retrieves the schemas for acknowledgement events

### default_ack_table_schema: returns

| return           | type  | always | condition |
| ---------------- | ----- | ------ | --------- |
| ack schema table | table | yes    |           |

### default_ack_table_schema: example

```lua
local result = test_bq:default_ack_table_schema()
--> result is : 
--[[
  {
    author = "{author}",
    host_id = "{host_id}",
    host_name = "{cache.host.name}",
    service_id = "{service_id}",
    service_description = "{cache.service.description}",
    status = "{state}",
    output = "{output}",
    instance_id = "{cache.host.instance_id}",
    entry_time = "{entry_time}"
  }
]]--
```

## default_dt_table_schema method

The **default_dt_table_schema** method retrieves the schemas for downtime events

### default_dt_table_schema: returns

| return                | type  | always | condition |
| --------------------- | ----- | ------ | --------- |
| downtime schema table | table | yes    |           |

### default_dt_table_schema: example

```lua
local result = test_bq:default_dt_table_schema()
--> result is : 
--[[
  {
    author = "{author}",
    host_id = "{host_id}",
    host_name = "{cache.host.name}",
    service_id = "{service_id}",
    service_description = "{cache.service.description}",
    status = "{state}",
    output = "{output}",
    instance_id = "{cache.host.instance_id}",
    actual_start_time = "{actual_start_time}",
    actual_end_time = "{deletion_time}"
  }
]]--
```

## default_ba_table_schema method

The **default_ba_table_schema** method retrieves the schemas for ba_status events

### default_ba_table_schema: returns

| return          | type  | always | condition |
| --------------- | ----- | ------ | --------- |
| BA schema table | table | yes    |           |

### default_ba_table_schema: example

```lua
local result = test_bq:default_ba_table_schema()
--> result is : 
--[[
  {
    ba_id = "{ba_id}",
    ba_name = "{cache.ba.ba_name}",
    status = "{state}"
  }
]]--
```

## load_tables_schema_file method

The **load_tables_schema_file** method retrieves the schemas from a json file. The json file must have the following structure

```json
{
  "host": {
    "column_1": "value_1",
    "column_2": "value_2"
  },
  "service": {
    "column_1": "value_1",
    "column_2": "value_2"
  },
  "ack": {
    "column_1": "value_1",
    "column_2": "value_2"
  },
  "dt": {
    "column_1": "value_1",
    "column_2": "value_2"
  },
  "ba": {
    "column_1": "value_1",
    "column_2": "value_2"
  }
}
```

If you only want to send service_status events, you can just put the service part of the json.

### load_tables_schema_file: returns

| return        | type    | always | condition                                                                                    |
| ------------- | ------- | ------ | -------------------------------------------------------------------------------------------- |
| true or false | boolean | yes    | false if we can't open the configuration file or it is not a valid json file, true otherwise |

### load_tables_schema_file: example

```lua
local result = test_bq:load_tables_schema_file()
--> result is true or false 
--> if true, schemas are stored in test_bq.schemas[<category_id>][<element_id>]
```

## build_table_schema method

The **build_table_schema** method create tables schema using stream connector parameters.
Parameters must have the following syntax to be interpreted

For host_status events:
`_sc_gbq_host_column_<column_name>`
For service_status events:
`_sc_gbq_service_column_<column_name>`
For acknowledgement events:
`_sc_gbq_ack_column_<column_name>`
For downtime events:
`_sc_gbq_dt_column_<column_name>`
For ba_status events:
`_sc_gbq_ba_column_<column_name>`

### build_table_schema: parameters

| parameter                                                                                       | type   | optional | default value |
| ----------------------------------------------------------------------------------------------- | ------ | -------- | ------------- |
| regex, the regex to identify the stream connector parameter that is about a column              | string | no       |               |
| substract, the prefix that must be excluded from the parameter name to only get the column name | table  | no       |               |
| structure, the table in which the retrieved column and value are going to be stored             | string | yes      |               |

### build_table_schema: example

```lua
self.params._sc_gbq_host_column_MYNAME = "MYVALUE"
self.params._sc_gbq_host_column_OTHERNAME = "OTHERVALUE"
self.params.something = "hello"

-- any parameter starting with  _sc_gbq_host_column is going to be computed
-- any matching parameter is going to have _sc_gbq_host_column removed from its name
-- created table schema will be stored in self.schema[1][14] (1 because host_status is neb event, and 14 because host_status is the element 14 of the neb events table)
test_bq:build_table_schema("^_sc_gbq_host_column", "_sc_gbq_host_column", self.schemas[1][14])
--> self.schemas[1][14] is 
--[[
  {
    MYNAME = "MYVALUE",
    OTHERNAME = "OTHERVALUE"
  }
]]--
```
