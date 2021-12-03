# centreon_classroom module documentation

- [centreon_classroom module documentation](#centreon_classroom-module-documentation)
  - [Introduction](#introduction)
  - [Module initialization](#module-initialization)
    - [Module constructor](#module-constructor)
    - [constructor: Example](#constructor-example)
  - [put_tables method](#put_tables-method)
    - [put_tables: parameters](#put_tables-parameters)
    - [put_tables: example](#put_tables-example)
  - [put_chairs method](#put_chairs-method)
    - [put_chairs: parameters](#put_chairs-parameters)
    - [put_chairs: example](#put_chairs-example)

## Introduction

The centreon_classroom module provides methods to help setting up your classroom. It has been made in OOP (object oriented programming)

## Module initialization

Since this is OOP, it is required to initiate your module

### Module constructor

Constructor can be initialized with one parameter or it will use a default value.

- teacher. This is a table with teacher informations
  
If you don't provide this parameter it will hire a default teacher

### constructor: Example

```lua
-- load classroom module
local centreon_classroom = require("centreon_classroom")

local teacher = {
  first_name = "Horace",
  last_name = "Slughorn",
  speciality = "Potions"
}

-- create a new instance of the centreon_classroom module
local classroom = centreon_classroom.new(teacher)
```

## put_tables method

The **put_tables** method put tables in the classroom. You can decide how many tables you want or it will put between 1 or 20 tables in your classroom

### put_tables: parameters

| parameter                      | type           | optional | default value |
| ------------------------------ | -------------- | -------- | ------------- |
| tables | number | yes       |               |

### put_tables: example

```lua
local tables = 15

classroom:put_tables(tables) 
print(classroom.tables)
--> it will print 15

classroom:put_tables()
print(classroom.tables)
--> it will print a number  between 1 and 20
```

## put_chairs method

The **put_chairs** method add chairs in your classroom. You can't have more than 2 chairs per table.
If you don't have any tables in your classroom, it will add tables before and put 2 chairs per table.

### put_chairs: parameters

| parameter                      | type           | optional | default value |
| ------------------------------ | -------------- | -------- | ------------- |
| chairs | number | no       |               |

### put_chairs: example

```lua
local chairs = 14

classroom:put_chairs(14)
print(classroom.chairs)
--> result is 14
```
