# centreon_classroom exercices

- [centreon_classroom exercices](#centreon_classroom-exercices)
  - [Exercise 1](#exercise-1)
    - [Exercise 1: What you must do](#exercise-1-what-you-must-do)
    - [Exercise 1: How can you check that it works](#exercise-1-how-can-you-check-that-it-works)
  - [Exercise 2](#exercise-2)
    - [Exercise 2:  What you must do](#exercise-2--what-you-must-do)
    - [Exercise 2: How can you check that it works](#exercise-2-how-can-you-check-that-it-works)
  - [Exercise 3](#exercise-3)
    - [Exercice 3: What you must do](#exercice-3-what-you-must-do)
    - [Exercice 3: How can you check that it works](#exercice-3-how-can-you-check-that-it-works)

## Exercise 1

Create a `my_first_lesson.lua` script.

To get your first lesson, you will need a classroom. Luckily, we got you covered.
In your lua script, you must build a new classroom. To do so, use the centreon_classroom module.
Maybe this module documentation can help you go through that

### Exercise 1: What you must do

- instantiate a new classroom
- check if a teacher is in your classroom

### Exercise 1: How can you check that it works

```lua
print(tostring(classroom.teacher.first_name))
--> must print the first name of your teacher
```

## Exercise 2

You have a classroom, maybe you want to sit somewhere. So add at least one table and one chair

### Exercise 2:  What you must do

- add tables in your classroom
- add chairs in your classroom

### Exercise 2: How can you check that it works

```lua
  print("tables: " .. tostring(classroom.tables) .. ", chairs: " .. tostring(classroom.chairs))
  --> must print "tables: xx, chairs: yy"
```

## Exercise 3

You do not like numbers and for some reason, you don't want **2** tables but **two** tables

This means that you are going to use the following method

```lua
classroom:put_tables("two")
```

Now that you have tables, you want chairs.

```lua
classroom:put_chairs()
```

This is going to break all the classroom.

### Exercice 3: What you must do

- find a way to handle bad parameters

### Exercice 3: How can you check that it works

```lua
classroom:put_tables("two")
classroom:put_chairs()

print("tables: " .. tostring(classroom.tables) .. ", chairs: " .. tostring(classroom.chairs))

--> must print "tables: xx, chairs: yy"
```
