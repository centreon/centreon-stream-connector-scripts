#!/usr/bin/lua

local JSON = require("JSON")
local centreon_classroom = require("centreon_classroom")
local centreon_cafeteria = require("centreon_cafeteria")
local centreon_school = require("centreon_school")

local first_teacher = {
  first_name = "John",
  last_name = "Doe",
  speciality = "Maths"
}
local first_classroom = centreon_classroom.new(first_teacher)

first_classroom:put_tables(13)
first_classroom:put_chairs(26)

local second_teacher = {
  first_name = "Jane",
  last_name = "Doe",
  speciality = "History"
}
local second_classroom = centreon_classroom.new(second_teacher)

second_classroom:put_tables(5)
second_classroom:put_chairs(10)

local third_teacher = {
  first_name = "Robert",
  last_name = "Bridge",
  speciality = "Chemistry"
}
local third_classroom = centreon_classroom.new(third_teacher)

third_classroom:put_tables(16)
third_classroom:put_chairs(32)

local cook = {
  nickname = "SpicyBob",
  favourite_dish = "water"
}

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

local cafeteria = centreon_cafeteria.new(menu, cook)

local classrooms = { 
  first_classroom,
  second_classroom,
  third_classroom 
}

local city = {
  country = "USA",
  state = "Louisiana",
  name = "New Orleans"
}

local school = centreon_school.new(classrooms, cafeteria, city)

print("school capacity: " .. school:get_capacity())

local school_location = JSON:decode(school:get_school_geocoordinates())
school.city.lat = school_location[1].lat
school.city.lon = school_location[1].lon

local sport_facilities_file_list = io.open("/tmp/sport_facilities.json", "r")
local file_content = file:read("*a")
io.close(sport_facilities_file_list)

local sport_facilities = JSON:decode(file_content)
school:get_nearest_sport_facility(sport_facilities)



