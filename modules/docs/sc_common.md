# Documentation of the sc_common module

- [Documentation of the sc_common module](#documentation-of-the-sc_common-module)
  - [Introduction](#introduction)
  - [Module initialization](#module-initialization)
    - [Module constructor](#module-constructor)
    - [constructor: Example](#constructor-example)
  - [ifnil_or_empty method](#ifnil_or_empty-method)
    - [ifnil_or_empty: parameters](#ifnil_or_empty-parameters)
    - [ifnil_or_empty: returns](#ifnil_or_empty-returns)
    - [ifnil_empty: example](#ifnil_empty-example)
  - [if_wrong_type method](#if_wrong_type-method)
    - [if_wrong_type: parameters](#if_wrong_type-parameters)
    - [if_wrong_type: returns](#if_wrong_type-returns)
    - [if_wrong_type: example](#if_wrong_type-example)
  - [boolean_to_number method](#boolean_to_number-method)
    - [boolean_to_number: parameters](#boolean_to_number-parameters)
    - [boolean_to_number: returns](#boolean_to_number-returns)
    - [boolean_to_number: example](#boolean_to_number-example)
  - [number_to_boolean method](#number_to_boolean-method)
    - [number_to_boolean: parameters](#number_to_boolean-parameters)
    - [number_to_boolean: returns](#number_to_boolean-returns)
    - [number_to_boolean: example](#number_to_boolean-example)
  - [check_boolean_number_option_syntax method](#check_boolean_number_option_syntax-method)
    - [check_boolean_number_option_syntax: parameters](#check_boolean_number_option_syntax-parameters)
    - [check_boolean_number_option_syntax: returns](#check_boolean_number_option_syntax-returns)
    - [check_boolean_number_option_syntax: example](#check_boolean_number_option_syntax-example)
  - [split method](#split-method)
    - [split: parameters](#split-parameters)
    - [split: returns](#split-returns)
    - [split: example](#split-example)
  - [compare_numbers method](#compare_numbers-method)
    - [compare_numbers: parameters](#compare_numbers-parameters)
    - [compare_numbers: returns](#compare_numbers-returns)
    - [compare_numbers: example](#compare_numbers-example)
  - [generate_postfield_param_string method](#generate_postfield_param_string-method)
    - [generate_postfield_param_string: parameters](#generate_postfield_param_string-parameters)
    - [generate_postfield_param_string: returns](#generate_postfield_param_string-returns)
    - [generate_postfield_param_string: example](#generate_postfield_param_string-example)
  - [load_json_file method](#load_json_file-method)
    - [load_json_file: parameters](#load_json_file-parameters)
    - [load_json_file: returns](#load_json_file-returns)
    - [load_json_file: example](#load_json_file-example)

## Introduction

The sc_common module provides methods to help with common needs when writing stream connectors. It has been made in OOP (object oriented programming)

## Module initialization

Since this is OOP, it is required to initiate your module

### Module constructor

Constructor can be initialized with one parameter or it will use a default value.

- sc_logger. This is an instance of the sc_logger module

If you don't provide this parameter it will create a default sc_logger instance with default parameters ([sc_logger default params](./sc_logger.md#module-initialization))

### constructor: Example

```lua
-- load modules
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_common = require("centreon-stream-connectors-lib.sc_common")

-- initiate "mandatory" informations for the logger module
local logfile = "/var/log/test_logger.log"
local severity = 1

-- create a new instance of the sc_logger module
local test_logger = sc_logger.new(logfile, severity)

-- create a new instance of the sc_common module
local test_common = sc_common.new(test_logger)
```

## ifnil_or_empty method

The **ifnil_or_empty** method checks if the first parameter is empty or nil and returns the second parameter if that is the case. Otherwise, it will return the first parameter.

### ifnil_or_empty: parameters

| parameter                      | type           | optional | default value |
| ------------------------------ | -------------- | -------- | ------------- |
| the variable you want to check | string, number | no       |               |
| the default value to return    | any            | no       |               |

### ifnil_or_empty: returns

| return               | type                  | always | condition                              |
| -------------------- | --------------------- | ------ | -------------------------------------- |
| the first parameter  | first parameter type  | no     | if first parameter is not empty or nil |
| the second parameter | second parameter type | no     | if first paramter is empty or nil      |

### ifnil_empty: example

```lua
local first_param = "hello"
local second_param = "goodbye"

local result = test_common:ifnil_or_empty(first_param, second_param) 
--> result is "hello"

first_param = ""
result = test_common:ifnil_or_empty(first_param, second_param)
--> result is "goodbye"
```

## if_wrong_type method

This **if_wrong_type** method checks if the first parameter type is equal to the given type in the second parameter. If that is not the case, it returns the third parameter as a default value

### if_wrong_type: parameters

| parameter                                                                                                   | type   | optional | default value |
| ----------------------------------------------------------------------------------------------------------- | ------ | -------- | ------------- |
| the variable you want its type to be checked                                                                | any    | no       |               |
| the type that you want your variable to match                                                               | string | no       |               |
| the default value you want to return if the type of the first parameter doesn't match your second parameter | any    | no       |               |

### if_wrong_type: returns

| return              | type | always | condition                                                                |
| ------------------- | ---- | ------ | ------------------------------------------------------------------------ |
| the first parameter | any  | no     | if the type of the first parameter is equal to your second parameter     |
| the third parameter | any  | no     | if the type of the first parameter is not equal to your second parameter |

### if_wrong_type: example

```lua
local first_param = "i am a string"
local second_param = "string"
local third_param = "my default value"

local result = test_common:if_wrong_type(first_param, second_param, third_param)
--> result is "i am a string"

first_param = 3
result = test_common:if_wrong_type(first_param, second_param, third_param)
--> result is "my default value"
```

## boolean_to_number method

The **boolean_to_number** method converts a boolean to its number equivalent.

### boolean_to_number: parameters

| parameter          | type    | optional | default value |
| ------------------ | ------- | -------- | ------------- |
| a boolean variable | boolean | no       |               |

### boolean_to_number: returns

| return            | type   | always | condition |
| ----------------- | ------ | ------ | --------- |
| a number (0 or 1) | number | yes    |           |

### boolean_to_number: example

```lua
local my_boolean = true

local result = test_common:boolean_to_number(my_boolean)
--> result is 1
```

## number_to_boolean method

The **number_to_boolean** method converts a number to its boolean equivalent.

### number_to_boolean: parameters

| parameter         | type   | optional | default value |
| ----------------- | ------ | -------- | ------------- |
| a number (0 or 1) | number | no       |               |

### number_to_boolean: returns

| return                    | type    | always | condition                  |
| ------------------------- | ------- | ------ | -------------------------- |
| a boolean (true or false) | boolean | no     | if parameter is 0 or 1     |
| nil                       | nil     | no     | if parameter is not 0 or 1 |

### number_to_boolean: example

```lua
local my_number = 1

local result = test_common:number_to_boolean(my_number)
--> result is true
```

## check_boolean_number_option_syntax method

The **check_boolean_number_option_syntax** method checks if the first paramter is a boolean number (0 or 1) and if that is not the case, returns the second parameter

### check_boolean_number_option_syntax: parameters

| parameter                                                 | type | optional | default value |
| --------------------------------------------------------- | ---- | -------- | ------------- |
| the variable you want to check                            | any  | no       |               |
| a default value to return if the first parameter is wrong | any  | no       |               |

### check_boolean_number_option_syntax: returns

| return               | type   | always | condition                                    |
| -------------------- | ------ | ------ | -------------------------------------------- |
| the first parameter  | number | no     | the first parameter must be a boolean number |
| the second parameter | any    | no     | the first parameter is not a boolean number  |

### check_boolean_number_option_syntax: example

```lua
local first_parameter = 1
local second_parameter = "a default return value"

local result = test_common:check_boolean_number_option_syntax(first_parameter, second_parameter)
--> result is 1

first_parameter = "not a boolean number"
result = test_common:check_boolean_number_option_syntax(first_parameter, second_parameter)
--> result is "a default return value"
```

## split method

The **split** method split a string using a separator and returns a table of all the splitted parts

### split: parameters

| parameter                     | type   | optional | default value |
| ----------------------------- | ------ | -------- | ------------- |
| the string you need to split  | string | no       |               |
| the separator you want to use | string | yes      | ","           |

### split: returns

| return                          | type    | always | condition                                   |
| ------------------------------- | ------- | ------ | ------------------------------------------- |
| a table with all splitted parts | table   | no     | the string to split mustn't be empty or nil |
| false                           | boolean | no     | if the string to split is empty or nil      |

### split: example

***notice: to better understand the result, you need to know that, by convention, a table starts at index 1 in lua and not 0 like it is in most languages***

```lua
local my_string = "split;using;semicolon"
local separator = ";"

local result = test_common:split(my_string, separator)
--[[

  --> result structure is: 
  {
    [1] = "split",
    [2] = "using",
    [3] = "semicolon"
  }

  --> result[2] is "using"

--]]

my_string = ""
result = test_common:split(my_string, separator)
--> result is false 
```

## compare_numbers method

The **compare_numbers** method compare a first number with a second one using the provided mathematical operator

### compare_numbers: parameters

| parameter                                 | type   | optional | default value |
| ----------------------------------------- | ------ | -------- | ------------- |
| the first number you need to compare      | number | no       |               |
| the second number you need to compare     | number | no       |               |
| the mathematical operator you want to use | string | no       |               |

accepted operators: <, >, >=, <=, ==, ~=

### compare_numbers: returns

| return    | type    | always | condition                                                                           |
| --------- | ------- | ------ | ----------------------------------------------------------------------------------- |
| a boolean | boolean | no     | both numbers must be numbers and the mathematical operator must be a valid operator |
| nil       | nil     | no     | if one of the number is not a number or the mathematical operator is not valid      |

### compare_numbers: example

```lua
local first_number = 4
local second_number = 12
local operator = "=="

local result = test_common:compare_numbers(first_number, second_number, operator)
--> result is false (4 is not equal to 12)

operator = "~="
result = test_common:compare_numbers(first_number, second_number, operator)
--> result is true

first_number = "hello my friend"
result = test_common:compare_numbers(first_number, second_number, operator)
--> result is nil ("hello my friend" is not a valid number)
```

## generate_postfield_param_string method

The **generate_postfield_param_string** method generate an url encoded param string based on a table with said params.

### generate_postfield_param_string: parameters

| parameter                                                           | type  | optional | default value |
| ------------------------------------------------------------------- | ----- | -------- | ------------- |
| the table with all the parameters to convert in a parameters string | table | no       |               |

### generate_postfield_param_string: returns

| return        | type    | always | condition                                                                          |
| ------------- | ------- | ------ | ---------------------------------------------------------------------------------- |
| false         | boolean | no     | if the method parameter is not a table                                             |
| string_params | string  | no     | if the method parameter is a table, it will return an url encoded string of params |

### generate_postfield_param_string: example

```lua
local param_table = {
  key = "321Xzd",
  option = "full"
  name = "John Doe"
}

local result = test_common:generate_postfield_param_string(param_table)
--> result is "key=321Xzd&option=full&name=John%20Doe"
```

## load_json_file method

The **load_json_file** method loads a json file and parse it.

### load_json_file: parameters

| parameter                                                       | type   | optional | default value |
| --------------------------------------------------------------- | ------ | -------- | ------------- |
| the path to the json file (must be readable by centreon-broker) | string | no       |               |

### load_json_file: returns

| return                         | type  | always  | condition                  |
| ------------------------------ | ----- | ------- | -------------------------- |
| true                           | false | boolean | yes                        | false if the json file couldn't be loaded or parsed, true otherwise |
| the parsed content of the json | table | no      | only when true is returned |

### load_json_file: example

```lua
local json_file = "/etc/centreon-broker/sc_config.json"

local result, content = test_common:load_json_file(json_file)
--> result is true, content is a table

json_file = 3
result, content = test_common:load_json_file(json_file)
--> result is false, content is nil
```
