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
        "user-agent: user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Safari/537.36"
      }
  )

  http_request:perform()

  -- collecting results
  http_response_code = http_request:getinfo(curl.INFO_RESPONSE_CODE) 

  http_request:close()

  return http_response_body
end

function CentreonSchool:get_nearest_sport_facility(sport_facilities_list)
  local routing_osm = "https://router.project-osrm.org"
  local query = "/route/v1/foot/"
  local option = "overview=false"
  local counter = 0
  
  for index, sport_facility in ipairs(sport_facilities_list) do
    if counter == 0 then
      query = query .. self.school.lon .. "," .. self.school.lat .. ";" .. sport_facility.lon .. "," .. sport_facility.lat
      counter = counter + 1
    else
      query = query .. ";" .. self.school.lon .. "," .. self.school.lat .. ";" .. sport_facility.lon .. "," .. sport_facility.lat
    end
  end

  local url = routing_osm .. query .. "?" .. option

  print(url)
end


return centreon_school