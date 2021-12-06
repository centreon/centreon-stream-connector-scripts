local curl = require "cURL"

local centreon_school = {}

local CentreonSchool = {}

function centreon_school.new(classrooms, cafeteria, city)
  local self = {}

  if not city or type(city) ~= "table" then
    self.city = {
      country = "France",
      state = "Landes",
      name = "Mont de Marsan"
    }
  else
    self.city = city
  end

  self.classrooms = classrooms
  self.cafeteria = cafeteria

  setmetatable(self, { __index = CentreonSchool })
  return self
end

function CentreonSchool:get_capacity()
  -- find dish
  local chairs_number = 0

  for index, classroom in ipairs(self.classrooms) do
    chairs_number = chairs_number + classroom.chairs
  end

  return chairs_number
end

function CentreonSchool:get_school_geocoordinates()
  local openstreetmap = "https://nominatim.openstreetmap.org"
  local query = "/search?q=" .. string.gsub(self.city.name, " ", "%-") 
    .. "-" .. string.gsub(self.city.state, " ", "%-") 
    .. "-" .. string.gsub(self.city.country, " ", "%-") 
    .. "&format=json&polygon=1&addressdetails=1"
    
  local url = openstreetmap .. query

  local http_response_body = ""
  local http_request = curl.easy()
    :setopt_url(url)
    :setopt_writefunction(
      function (response)
        http_response_body = http_response_body .. tostring(response)
      end
    )
    :setopt(curl.OPT_TIMEOUT, 60)
    :setopt(curl.OPT_SSL_VERIFYPEER, true)
    :setopt(
      curl.OPT_HTTPHEADER,
      {
        "content-type: application/json"
      }
  )

  http_request:perform()

  -- collecting results
  http_response_code = http_request:getinfo(curl.INFO_RESPONSE_CODE) 

  http_request:close()

  return http_response_body
end

return centreon_school