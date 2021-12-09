-- initiate centreon_cafeteria object
local centreon_cafeteria = {}
local CentreonCafeteria = {}

-- begin the centreon_cafeteria constructor
function centreon_cafeteria.new(menu, cook)
  local self = {}
  
  -- use the hired cook or hire one if there is none
  if cook then
    self.cook = cook
  else
    self.cook = {
      nickname = "Ratatouille",
      favourite_dish = "Apple pie"
    }
  end

  -- use provided menu or use a default one is there is none
  if menu then
    self.menu = menu
  else
    self.menu = {
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
  end

  -- end the constructor
  setmetatable(self, { __index = CentreonCafeteria })
  return self
end


function CentreonCafeteria:check_alergy(dish, alergies)
  -- find dish
  local type = false

  if self.menu.starters[dish] then
    type = "starters"
  elseif self.menu.dishes[dish] then
    type = "dishes"
  elseif self.menu.desserts[dish] then
    type = "desserts"
  end

  if not type then
    return false, "dish: " .. tostring(dish) .. " is not on the menu today."
  end

  for index, customer_ingredient in pairs(alergies) do
    for key, dish_ingredient in pairs(self.menu[type][dish].ingredients) do
      if customer_ingredient == dish_ingredient then
        return false, "you are alergic to: " .. tostring(customer_ingredient) .. " and there is: " .. tostring(dish_ingredient) .. " in the dish: " .. tostring(dish)
      end
    end
  end

  return true, "Here is your: " .. tostring(dish)
end

return centreon_cafeteria