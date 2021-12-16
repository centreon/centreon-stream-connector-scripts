# Exercices Answers

- [Exercices Answers](#exercices-answers)
  - [Exercise 1](#exercise-1)
  - [Exercise 2](#exercise-2)
  - [Exercise 3](#exercise-3)
  - [Exercise 4](#exercise-4)
  - [Exercise 5](#exercise-5)

## Exercise 1

you can use the default teacher

```lua
centreon_classroom = require("centreon_classroom")

local classroom = centreon_classroom.new()
print(tostring(classroom.teacher.first_name))
--> will print "Minerva"
```

or you can hire your own teacher

```lua
centreon_classroom = require("centreon_classroom")

local teacher = {
  first_name = "Sybill"
  last_name = "Trelawney"
  speciality = "Divination"
}

local classroom = centreon_classroom.new()
print(tostring(classroom.teacher.first_name))
--> will print "Sybill"
```

## Exercise 2

you can let someone else decide how many tables and chairs there will be

```lua
-- if you do not have tables, using put chairs will also put tables in the classroom
classroom:put_chairs()
print("tables: " .. tostring(classroom.tables) .. ", chairs: " .. tostring(classroom.chairs))
--> will print "tables: xx, chairs: yy"

-- or you can first add tables and then add chairs
classroom:put_tables()
classroom:put_chairs()
```

or you can decide how many tables and chairs you want

```lua
classroom:put_tables(10)
classroom:put_chairs(15)
print("tables: " .. tostring(classroom.tables) .. ", chairs: " .. tostring(classroom.chairs))
--> will print "tables: 10, chairs: 15"
```

## Exercise 3

you need to add a "security" layer in the centreon_school module. The table parameter must be a number so we are going to make sure people call the put_tables method with a number and nothing else. 

```lua
function CentreonClassroom:put_tables(tables)
  if not tables or type(tables) ~= "number" then
    math.randomseed(os.time())
    self.tables = math.random(1,20)
  elseif tables > 20 then
    print(tables .. " tables is a bit much, it is a classroom not a stadium")
    math.randomseed(os.time())
    self.tables = math.random(1,20)
  else
    self.tables = tables
  end
end
```

In the above example, we've added a check that says if the type of the "tables" variables is not a number, then we are going to ignore it and add a random number of tables in the classroom.

## Exercise 4 

In this exercise, you must create your first lua module and its constructor. There is an example in the [centreon_cafetria.lua module](answers/centreon_cafeteria.lua) file

you can test your constructor using the following code in a lua script

```lua
local centreon_cafeteria = require("centreon_cafeteria")
local cafeteria = centreon_cafeteria.new(cook, menu)

print(tostring(cafeteria.cook.nickname))
--> must print the nickname of your cook

print(tostring(cafeteria.menu.starters["duck soup"].name))
--> must print the name of the dish "duck soup"
```

## Exercise 5

In this exercise, you must check if a kid has an allergy to an ingredient that is in the dish that he want. There is an example of method that check allergies in the  [centreon_cafetria.lua module](answers/centreon_cafeteria.lua) file 

you can check your code using the following lua script 

```lua
local centreon_cafeteria = require("centreon_cafeteria")
local cafeteria = centreon_cafeteria.new(cook, menu)

local return_code, return_message = cafeteria:check_alergy("duck soup", {"duck", "salt"})

if not return_code then
  print(return_message)
end
```
