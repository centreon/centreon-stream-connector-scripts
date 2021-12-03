# Exercices Answers

- [Exercices Answers](#exercices-answers)
  - [Exercise 1](#exercise-1)
  - [Exercise 2](#exercise-2)

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
