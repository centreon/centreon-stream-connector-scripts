# Documentation of the sc_logger module

- [Documentation of the sc_logger module](#documentation-of-the-sc_logger-module)
  - [Introduction](#introduction)
  - [Best practices](#best-practices)
  - [Module initialization](#module-initialization)
    - [module constructor](#module-constructor)
    - [constructor: Example](#constructor-example)
  - [error method](#error-method)
    - [error: parameters](#error-parameters)
    - [error: example](#error-example)
  - [warning method](#warning-method)
    - [warning: parameters](#warning-parameters)
    - [warning: example](#warning-example)
  - [debug method](#debug-method)
    - [debug: parameters](#debug-parameters)
    - [debug: example](#debug-example)
  - [info method](#info-method)
    - [info: parameters](#info-parameters)
    - [info: example](#info-example)
  - [notice method](#notice-method)
    - [notice: parameters](#notice-parameters)
    - [notice: example](#notice-example)

## Introduction

The sc_logger module provides methods to help you handle logging in your stream connectors. It has been made in OOP (object oriented programming)

Logs can be configured with two parameters called

- logfile
- log_level

there are three different **log_level** going from 1 to 3. Below is the list of the logs message type you can expect with their corresponding **log_level**.

| log_level | message type                        |
| --------- | ----------------------------------- |
| 1         | notice, error                       |
| 2         | info, warning, notice, error        |
| 3         | debug, info, warning, notice, error |

## Best practices

All the stream-connectors-lib are using the following syntax when logging:

"[module_name:method_name]: your error message"

For example

```lua
function EventQueue:do_things()
  -- do things -- 

  test_logger:debug("[EventQueue:do_things]: this is a debug message that is using the best practices")
end
```

This is important for a more efficient troubleshooting. Log messages can come from various places and using this convention drastically improves the readability of the situation

## Module initialization

Since this is OOP, it is required to initiate your module.

### module constructor

Constructor can be initialized with two parameters or it will use default values

- the log file. **Default value: /var/log/centreon-broker/stream-connector.log**
- the maximum accepted severity level. Going from 1 (only error and notice message) to 3 (all messages including debug). **Default value: 1**

### constructor: Example

```lua
-- load module
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")

-- initiate "mandatory" information for the logger module
local logfile = "/var/log/test_logger.log"
local severity = 1

-- create a new instance of the sc_logger module
local test_logger = sc_logger.new(logfile, severity)
```

If the logfile and severity are not provided, default values are going to be used.

## error method

The **error** method will print an error message in the logfile if **severity is equal or superior to 1**

### error: parameters

- message. A string that is the error message you want to display in your logfile

### error: example

```lua
-- call error method
test_logger:error("[module_name:method_name]: This is an error message.")
```

## warning method

The **warning** method will print a warning message in the logfile if **severity is equal or superior to 2**

### warning: parameters

- message. A string that is the warning message you want to display in your logfile

### warning: example

```lua
-- call warning method
test_logger:warning("[module_name:method_name]: This is a warning message.")
```

## debug method

The **debug** method will print a debug message in the logfile if **severity is equal or superior to 3**

### debug: parameters

- message. A string that is the debug message you want to display in your logfile

### debug: example

```lua
-- call debug method
test_logger:debug("[module_name:method_name]: This is a debug message.")
```

## info method

The **info** method will print an info message in the logfile if **severity is equal or superior to 2**.

### info: parameters

- message. A string that is the info message you want to display in your logfile

### info: example

```lua
-- call info method
test_logger:info("[module_name:method_name]: This is a info message.")
```

## notice method

The **notice** method will print a notice message in the logfile if **severity is equal or superior to 1**.

### notice: parameters

- message. A string that is the notice message you want to display in your logfile

### notice: example

```lua
-- call notice method
test_logger:notice("[module_name:method_name]: This is a notice message.")
```
