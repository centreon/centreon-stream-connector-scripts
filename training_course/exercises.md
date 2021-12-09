# centreon_classroom Exercises

- [centreon_classroom Exercises](#centreon_classroom-exercises)
  - [CHAPTER 1: use a module](#chapter-1-use-a-module)
    - [Exercise 1](#exercise-1)
      - [Exercise 1: What you must do](#exercise-1-what-you-must-do)
      - [Exercise 1: How can you check that it works](#exercise-1-how-can-you-check-that-it-works)
    - [Exercise 2](#exercise-2)
      - [Exercise 2:  What you must do](#exercise-2--what-you-must-do)
      - [Exercise 2: How can you check that it works](#exercise-2-how-can-you-check-that-it-works)
    - [Exercise 3](#exercise-3)
      - [Exercise 3: What you must do](#exercise-3-what-you-must-do)
      - [Exercise 3: How can you check that it works](#exercise-3-how-can-you-check-that-it-works)
  - [CHAPTER 2: create your lua module](#chapter-2-create-your-lua-module)
    - [Exercise 4](#exercise-4)
      - [Exercise 4: What you must do](#exercise-4-what-you-must-do)
      - [Exercise 4: How can you check that it works](#exercise-4-how-can-you-check-that-it-works)
    - [Exercise 5](#exercise-5)
      - [Exercise 5: What you must do](#exercise-5-what-you-must-do)
  - [CHAPTER 6: module interactions](#chapter-6-module-interactions)
    - [Exercise 6](#exercise-6)
      - [Exercise 6: What you must do](#exercise-6-what-you-must-do)
    - [Exercise 7](#exercise-7)
      - [Exercise 7: What you must do](#exercise-7-what-you-must-do)
      - [Exercie 7: important information](#exercie-7-important-information)
    - [Exercise 8](#exercise-8)
      - [Exercise 8: What you must do](#exercise-8-what-you-must-do)
      - [Exercise 8: how to succeed](#exercise-8-how-to-succeed)
    - [Exercise 9](#exercise-9)
      - [Exercise 9: What you must do](#exercise-9-what-you-must-do)
      - [Exercise 9: How to succeed](#exercise-9-how-to-succeed)

## CHAPTER 1: use a module

What you will learn:

- use a simple lua module using its documentation
- use its methods
- improve lua codes

### Exercise 1

Create a `my_first_lesson.lua` script.

To get your first lesson, you will need a classroom. Luckily, we got you covered.
In your lua script, you must build a new classroom. To do so, use the centreon_classroom module.
Maybe this module documentation can help you go through that

#### Exercise 1: What you must do

- instantiate a new classroom
- check if a teacher is in your classroom

#### Exercise 1: How can you check that it works

```lua
print(tostring(classroom.teacher.first_name))
--> must print the first name of your teacher
```

### Exercise 2

You have a classroom, maybe you want to sit somewhere. So add at least one table and one chair

#### Exercise 2:  What you must do

- add tables in your classroom
- add chairs in your classroom

#### Exercise 2: How can you check that it works

```lua
  print("tables: " .. tostring(classroom.tables) .. ", chairs: " .. tostring(classroom.chairs))
  --> must print "tables: xx, chairs: yy"
```

### Exercise 3

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

#### Exercise 3: What you must do

- find a way to handle bad parameters

#### Exercise 3: How can you check that it works

```lua
classroom:put_tables("two")
classroom:put_chairs()

print("tables: " .. tostring(classroom.tables) .. ", chairs: " .. tostring(classroom.chairs))

--> must print "tables: xx, chairs: yy"
```

## CHAPTER 2: create your lua module

What you will learn:

- create your first lua module
- create your first method
- looping through tables 

### Exercise 4

There is an old legend saying that people must eat and drink in order to survive. We are going to build a cafeteria

#### Exercise 4: What you must do

- create a lua module called centreon_cafeteria
- a cafeteria must have a cook and a menu.
  - a menu is made of starters, dishes and desserts
    - each starter, dish and dessert has a name, a number of calories and a list of ingredients
  - a cook has a nickname and a favourite dish

#### Exercise 4: How can you check that it works

```lua
local centreon_cafeteria = require("centreon_cafeteria")
local cafeteria = centreon_cafeteria.new(cook, menu)

print(tostring(cook.nickname))
--> must print the nickname of your cook

print(tostring(menu.starters["duck soup"].name))
--> must print the name of the dish "duck soup"
```

### Exercise 5

We should make sure that we don't serve dishes to people that are not alergic to an ingredient. Our cafeteria module will have a method called check_alergy() that has two parameters, the dish that our student wants and the list of ingredients that the studend is alergic to.

#### Exercise 5: What you must do

- create a method called check_alergy in your module
- it needs to have the dish and the list of ingredients that the studend can't eat as parameters
- it must return false and a message if there is at least one ingredient that the student can't eat in the dish or if the dish doesn't exist
- it must return true and a message if the dish is safe for the student

## CHAPTER 6: module interactions

What you will learn:

- use external modules such as lua-json
- work with basic API using cURL
- create/update an object
- interactions between objects

### Exercise 6

We know how to build a classroom and a cafeteria. Nothing is stopping us from building our school.
A school needs three or more classroom and one cafeteria and a city to be built in.

#### Exercise 6: What you must do

- create a lua module called centreon_school
- a school must have two parameters
  - a list of classrooms
  - one cafeteria
  - a city that is caracterised by the following information (you must use a real city):
    - country
    - state
    - name

### Exercise 7

The city mayor needs to know how many children can attend classes in your school.

#### Exercise 7: What you must do

- create a method called get_capacity() that returns the number of children that can sit in your school

#### Exercie 7: important information

The maximum number of children is equal to the number of chairs in all classrooms. We are not monsters, they will not learn by standing up all day.

### Exercise 8

We want the children that attend classes in our school to be as healthy as possible. To do so, we need to send them to the closest sport facility. First of all, we need to know the geo coordinates of our school

#### Exercise 8: What you must do

- create a method called get_school_geocoordinates() that returns a table with the latitude and the longitude
- you must use the following user agent http header with curl to not be blocked **user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Safari/537.36**

#### Exercise 8: how to succeed

- to get your locations data, you can use the following url where:
  - Mont de Marsan is the city name
  - Landes is the state
  - France is the country

https://nominatim.openstreetmap.org/search?q=mont-de-marsan-landes-france&format=json&polygon=1&addressdetails=1

- your script needs to use a json parser, the answers use lua-json.

### Exercise 9

Find the closest sport facility. Our administrative department concluded a partnership with 6 sport facilities across the world. Our children may have to walk a few thousand kilometers in order to play basketball but if they don't attend their sport class, they are going to be expelled from our school!

#### Exercise 9: What you must do

- use the sport_facilities.json file to locate every sport facility
- return the name of the closest sport facility and the distance the children will have to walk to get there

#### Exercise 9: How to succeed

- depending on where your school is located, there might not be any facility where children can go. You should handle that specific case
- to get distance information between your school and the sport_facilities you can use the following api documentation http://project-osrm.org/docs/v5.24.0/api/#
