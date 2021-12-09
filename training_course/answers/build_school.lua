#!/usr/bin/lua

-- load required dependencies
local JSON = require("JSON")
local centreon_classroom = require("centreon_classroom")
local centreon_cafeteria = require("centreon_cafeteria")
local centreon_school = require("centreon_school")

-- hire our first teacher
local first_teacher = {
  first_name = "John",
  last_name = "Doe",
  speciality = "Maths"
}
-- build our first classroom
local first_classroom = centreon_classroom.new(first_teacher)

-- put chairs and tables in our classroom
first_classroom:put_tables(13)
first_classroom:put_chairs(26)

-- hire our second teacher
local second_teacher = {
  first_name = "Jane",
  last_name = "Doe",
  speciality = "History"
}
-- build our second classroom
local second_classroom = centreon_classroom.new(second_teacher)

-- put chairs and tables in our classroom
second_classroom:put_tables(5)
second_classroom:put_chairs(10)

-- hire our third teacher
local third_teacher = {
  first_name = "Robert",
  last_name = "Bridge",
  speciality = "Chemistry"
}
-- build our third classroom
local third_classroom = centreon_classroom.new(third_teacher)

-- put chairs and tables in our classroom
third_classroom:put_tables(16)
third_classroom:put_chairs(32)

-- hire a cook
local cook = {
  nickname = "SpicyBob",
  favourite_dish = "water"
}

-- create a menu
local menu = {
  starters = {
    ["apple pie"] = {
      name = "apple pie",
      calories = 35,
      ingredients = {"apple", "pie"}
    },
    ["oignon soup"] = {
      name = "oignon soup",
      calories = 64,
      ingredients = {"oignon", "soup"}
    }
  },
  dishes = {
    ["fish and chips"] = {
      name = "fish and chips",
      calories = 666,
      ingredients = {"fish", "chips"}
    },
    ["mashed potatoes"] = {
      name = "mashed potatoes",
      calories = 25,
      ingredients = {"potatoes", "milk"}
    }
  },
  desserts = {
    ["cheese cake"] = {
      name = "cheese cake",
      calories = 251,
      ingredients = {"cheese", "cake"}
    },
    ["ice cream"] = {
      name = "ice cream",
      calories = 353,
      ingredients = {"ice", "cream"}
    }
  }
}

-- build our cafeteria
local cafeteria = centreon_cafeteria.new(menu, cook)

-- add all classrooms in a table
local classrooms = { 
  first_classroom,
  second_classroom,
  third_classroom 
}

-- chose a city in which the school will be build
local city = {
  country = "USA",
  state = "Louisiana",
  name = "New Orleans"
}

-- build our school
local school = centreon_school.new(classrooms, cafeteria, city)

-- display the capacity of the school
print("school capacity: " .. school:get_capacity())

-- get the school latitude and longitude
local school_location = JSON:decode(school:get_school_geocoordinates())
-- store them in the appropriate table inside our school object
school.city.lat = school_location[1].lat
school.city.lon = school_location[1].lon

-- open the list of facilities
local sport_facilities_file = io.open("/tmp/sport_facilities.json", "r")
-- read the content of the file and store it
local file_content = sport_facilities_file:read("*a")
-- close the file
io.close(sport_facilities_file)

-- decode the list of facilities
local sport_facilities = JSON:decode(file_content)
-- try to find the best facility
local code, sport_facility = school:get_nearest_sport_facility(sport_facilities)

-- print the result with the appropriate message 
if code then
  print("facility name is: " .. sport_facility.name .. ". Distance from school is: " .. sport_facility.distance .. "m")
else
  print("no sport for our children, we should find new partnership with facilities near: " .. school.city.name)
end

