# Documentation of the sc_common module

- [Documentation of the sc\_common module](#documentation-of-the-sc_common-module)
  - [Introduction](#introduction)
  - [Module initialization](#module-initialization)
    - [Module constructor](#module-constructor)
    - [constructor: Example](#constructor-example)
  - [ifnil\_or\_empty method](#ifnil_or_empty-method)
    - [ifnil\_or\_empty: parameters](#ifnil_or_empty-parameters)
    - [ifnil\_or\_empty: returns](#ifnil_or_empty-returns)
    - [ifnil\_empty: example](#ifnil_empty-example)
  - [if\_wrong\_type method](#if_wrong_type-method)
    - [if\_wrong\_type: parameters](#if_wrong_type-parameters)
    - [if\_wrong\_type: returns](#if_wrong_type-returns)
    - [if\_wrong\_type: example](#if_wrong_type-example)
  - [boolean\_to\_number method](#boolean_to_number-method)
    - [boolean\_to\_number: parameters](#boolean_to_number-parameters)
    - [boolean\_to\_number: returns](#boolean_to_number-returns)
    - [boolean\_to\_number: example](#boolean_to_number-example)
  - [number\_to\_boolean method](#number_to_boolean-method)
    - [number\_to\_boolean: parameters](#number_to_boolean-parameters)
    - [number\_to\_boolean: returns](#number_to_boolean-returns)
    - [number\_to\_boolean: example](#number_to_boolean-example)
  - [check\_boolean\_number\_option\_syntax method](#check_boolean_number_option_syntax-method)
    - [check\_boolean\_number\_option\_syntax: parameters](#check_boolean_number_option_syntax-parameters)
    - [check\_boolean\_number\_option\_syntax: returns](#check_boolean_number_option_syntax-returns)
    - [check\_boolean\_number\_option\_syntax: example](#check_boolean_number_option_syntax-example)
  - [split method](#split-method)
    - [split: parameters](#split-parameters)
    - [split: returns](#split-returns)
    - [split: example](#split-example)
  - [compare\_numbers method](#compare_numbers-method)
    - [compare\_numbers: parameters](#compare_numbers-parameters)
    - [compare\_numbers: returns](#compare_numbers-returns)
    - [compare\_numbers: example](#compare_numbers-example)
  - [generate\_postfield\_param\_string method](#generate_postfield_param_string-method)
    - [generate\_postfield\_param\_string: parameters](#generate_postfield_param_string-parameters)
    - [generate\_postfield\_param\_string: returns](#generate_postfield_param_string-returns)
    - [generate\_postfield\_param\_string: example](#generate_postfield_param_string-example)
  - [load\_json\_file method](#load_json_file-method)
    - [load\_json\_file: parameters](#load_json_file-parameters)
    - [load\_json\_file: returns](#load_json_file-returns)
    - [load\_json\_file: example](#load_json_file-example)
  - [json\_escape method](#json_escape-method)
    - [json\_escape: parameters](#json_escape-parameters)
    - [json\_escape: returns](#json_escape-returns)
    - [json\_escape: example](#json_escape-example)
  - [xml\_escape method](#xml_escape-method)
    - [xml\_escape: parameters](#xml_escape-parameters)
    - [xml\_escape: returns](#xml_escape-returns)
    - [xml\_escape: example](#xml_escape-example)
  - [lua\_regex\_escape method](#lua_regex_escape-method)
    - [lua\_regex\_escape: parameters](#lua_regex_escape-parameters)
    - [lua\_regex\_escape: returns](#lua_regex_escape-returns)
    - [lua\_regex\_escape: example](#lua_regex_escape-example)
  - [dumper method](#dumper-method)
    - [dumper: parameters](#dumper-parameters)
    - [dumper: returns](#dumper-returns)
    - [dumper: example](#dumper-example)
  - [trim method](#trim-method)
    - [trim: parameters](#trim-parameters)
    - [trim: returns](#trim-returns)
    - [trim: example](#trim-example)
  - [get\_bbdo\_version method](#get_bbdo_version-method)
    - [get\_bbdo\_version: returns](#get_bbdo_version-returns)
    - [get\_bbdo\_version: example](#get_bbdo_version-example)
  - [is\_valid\_pattern method](#is_valid_pattern-method)
    - [is\_valid\_pattern: parameters](#is_valid_pattern-parameters)
    - [is\_valid\_pattern: returns](#is_valid_pattern-returns)
    - [is\_valid\_pattern: example](#is_valid_pattern-example)

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

## json_escape method

The **json_escape** method escape json special characters.

### json_escape: parameters

| parameter                     | type   | optional | default value |
| ----------------------------- | ------ | -------- | ------------- |
| a string that must be escaped | string | no       |               |

### json_escape: returns

| return                                                                 | type                             | always | condition |
| ---------------------------------------------------------------------- | -------------------------------- | ------ | --------- |
| an escaped string (or the raw parameter if it was nil or not a string) | string (or input parameter type) | yes    |           |

### json_escape: example

```lua
local string = 'string with " and backslashes \\ and tab:\tend tab'
--> string is 'string with " and backslashes \ and tab: end tab'

local result = test_common:json_escape(string)
--> result is 'string with \" and backslashes \\ and tab:\tend tab'
```

## xml_escape method

The **xml_escape** method escape xml special characters.

### xml_escape: parameters

| parameter                     | type   | optional | default value |
| ----------------------------- | ------ | -------- | ------------- |
| a string that must be escaped | string | no       |               |

### xml_escape: returns

| return                                                                 | type                             | always | condition |
| ---------------------------------------------------------------------- | -------------------------------- | ------ | --------- |
| an escaped string (or the raw parameter if it was nil or not a string) | string (or input parameter type) | yes    |           |

### xml_escape: example

```lua
local string = 'string with " and < and >'
--> string is 'string with " and < and >'

local result = test_common:xml_escape(string)
--> result is 'string with &quot; and &lt; and &gt;'
```

## lua_regex_escape method

The **lua_regex_escape** method escape lua regex special characters.

### lua_regex_escape: parameters

| parameter                     | type   | optional | default value |
| ----------------------------- | ------ | -------- | ------------- |
| a string that must be escaped | string | no       |               |

### lua_regex_escape: returns

| return                                                                 | type                             | always | condition |
| ---------------------------------------------------------------------- | -------------------------------- | ------ | --------- |
| an escaped string (or the raw parameter if it was nil or not a string) | string (or input parameter type) | yes    |           |

### lua_regex_escape: example

```lua
local string = 'string with % and . and *'
--> string is 'string with % and . and *'

local result = test_common:lua_regex_escape(string)
--> result is 'string with %% and %. and %*'
```

## dumper method

The **dumper** method dumps variables for debug purpose

### dumper: parameters

| parameter                                                                                           | type   | optional | default value |
| --------------------------------------------------------------------------------------------------- | ------ | -------- | ------------- |
| the variable that must be dumped                                                                    | any    | no       |               |
| the string that contains the dumped variable. ONLY USED INTERNALLY FOR RECURSIVE PURPOSE            | string | yes      |               |
| the string that contains the tab character. ONLY USED INTERNALLY FOR RECURSIVE PURPOSE (and design) | string | yes      |               |

### dumper: returns

| return              | type   | always | condition |
| ------------------- | ------ | ------ | --------- |
| the dumped variable | string | yes    |           |

### dumper: example

```lua
local best_city = {
  name = "mont-de-marsan",
  geocoord = {
    lat = 43.89446,
    lon = -0.4964242
  }
}

local result = "best city info: " .. test_common:dumper(best_city)
--> result is
--[[
  best city info: 
  [table]
        [string] name: mont-de-marsan
        [table] geocoord:
                [number] lon: -0.4964242
                [number] lat: 43.89446
]]--
```

## trim method

The **trim** methods remove spaces (or the specified character) at the beginning and the end of a string

### trim: parameters

| parameter                                                                         | type   | optional | default value |
| --------------------------------------------------------------------------------- | ------ | -------- | ------------- |
| the string that must be trimmed                                                   | string | no       |               |
| the character the must be removed (if not provided, will remove space characters) | string | yes      |               |

### trim: returns

| return               | type   | always | condition |
| -------------------- | ------ | ------ | --------- |
| the trimmed variable | string | yes    |           |

### trim: example

```lua
local string = "                 I'm a space maaaaan        "

local result = test_common:trim(string)
--> result is: "I'm a space maaaaan"

local string = ";;;;;;I'm no longer a space maaaaan;;;;;;;;;;;;;;"

local result = test_common:trim(string, ";")
--> result is: "I'm no longer a space maaaaan"
```

## get_bbdo_version method

The **get_bbdo_version** method returns the first digit of the bbdo protocol version.

### get_bbdo_version: returns

| return           | type   | always | condition |
| ---------------- | ------ | ------ | --------- |
| the bbdo version | number | yes    |           |

### get_bbdo_version: example

```lua
local result = test_common:get_bbdo_version()
--> result is: 3
```

## is_valid_pattern method

The **is_valid_pattern** check if a Lua pattern is valid or not

### is_valid_pattern: parameters

| parameter                                                                         | type   | optional | default value |
| --------------------------------------------------------------------------------- | ------ | -------- | ------------- |
| the pattern that must be checked                                                  | string | no       |               |

### is_valid_pattern: returns

| return              | type   | always | condition |
| ------------------- | ------ | ------ | --------- |
| true or false | boolean | yes    |           |

### is_valid_pattern: example

```lua
local good_pattern = "a random pattern .*"

local result = test_common:is_valid_pattern(good_pattern)
--> result is: true

local wrong_pattern = "a random pattern %2"

local result = test_common:is_valid_pattern(wrong_pattern)
--> result is: false
```
