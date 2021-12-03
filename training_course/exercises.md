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
  - [Exercise 4](#exercise-4)
    - [Exercice 4: What you must do](#exercice-4-what-you-must-do)
    - [Exercice 4: How can you check that it works](#exercice-4-how-can-you-check-that-it-works)
  - [Exercise 5](#exercise-5)
    - [Exercice 5: What you must do](#exercice-5-what-you-must-do)

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

## Exercise 4

There is an old legend saying that people must eat and drink in order to survive. We are going to build a cafeteria

### Exercice 4: What you must do

- create a lua module called centreon_cafeteria
- a cafeteria must have a cook and a menu.
  - a menu is made of starters, dishes and desserts
    - each starter, dish and dessert has a name, a number of calories and a list of ingredients
  - a cook has a nickname and a favourite dish

### Exercice 4: How can you check that it works

```lua
local centreon_cafeteria = require("centreon_cafeteria")
local cafeteria = centreon_cafeteria.new(cook, menu)

print(tostring(cook.nickname))
--> must print the nickname of your cook

print(tostring(menu.starters[1].name))
--> must print the name of the first dishes
```

## Exercise 5

We should make sure that we don't serve dishes to people that are not alergic to an ingredient. Our cafeteria module will have a method called check_alergy() that has two parameters, the dish that our student wants and the list of ingredients that the studend is alergic to. 

### Exercice 5: What you must do

- create a method called check_alergy in your module
- it needs to have the dish and the list of ingredients that the studend can't eat
- it must return false if there is at least one ingredient that the student can't eat it the dish
- it must return true if the dish is safe for the student

