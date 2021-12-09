-- load required dependencies
local curl = require("cURL")
local JSON = require("JSON")


-- initiate centreon_school object
local centreon_school = {}
local CentreonSchool = {}

-- beginning of the constructor
function centreon_school.new(classrooms, cafeteria, city)
  local self = {}

  -- create a default city if there's none
  if not city or type(city) ~= "table" then
    self.city = {
      country = "France",
      state = "Landes",
      name = "Mont de Marsan"
    }
  else
    self.city = city
  end

  -- store classrooms and cafeteria inside the school object
  self.classrooms = classrooms
  self.cafeteria = cafeteria

  -- end of constructor
  setmetatable(self, { __index = CentreonSchool })
  return self
end

-- get capacity method
function CentreonSchool:get_capacity()
  -- one chair per people
  local chairs_number = 0

  -- count each chair in each classroom
  for index, classroom in ipairs(self.classrooms) do
    chairs_number = chairs_number + classroom.chairs
  end

  -- return the numbers of chairs that is equal to the maximum capacity of the school
  return chairs_number
end

-- get school geocoordinates method
function CentreonSchool:get_school_geocoordinates()
  -- using openstreetmap to get lat and lon of our school
  local openstreetmap = "https://nominatim.openstreetmap.org"
  -- remote " " from names and replace it with "-" to build the OSM query
  local query = "/search?q=" .. string.gsub(self.city.name, " ", "-") 
    .. "-" .. string.gsub(self.city.state, " ", "-") 
    .. "-" .. string.gsub(self.city.country, " ", "-") 
    .. "&format=json&polygon=1&addressdetails=1"
  
  local url = openstreetmap .. query

  -- create curl object
  local http_response_body = ""
  local http_request = curl.easy()
    -- use the url we just built
    :setopt_url(url)
    -- store curl body result inside a dedicated variable
    :setopt_writefunction(
      function (response)
        http_response_body = tostring(response)
      end
    )
    -- add a timeout to the connection
    :setopt(curl.OPT_TIMEOUT, 60)
    -- make sure we check the certificates
    :setopt(curl.OPT_SSL_VERIFYPEER, true)
    -- add the user-agent header so we don't get blocked
    :setopt(
      curl.OPT_HTTPHEADER,
      {
        "user-agent: user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Safari/537.36"
      }
  )

  -- run the query
  http_request:perform()
  -- store http code
  http_response_code = http_request:getinfo(curl.INFO_RESPONSE_CODE) 
  -- close curl object
  http_request:close()
  -- return result (we could at least check http return code before doing that)
  return http_response_body
end

-- get nearest sport facility. It requires a table with all the sport facilities
function CentreonSchool:get_nearest_sport_facility(sport_facilities_list)
  -- use project OSRM to get routing info from OSM
  local routing_osm = "https://router.project-osrm.org"
  -- kids do not drive so they are going to walk
  local endpoint = "/route/v1/foot/"
  local option = "overview=false"

  -- at the moment, we do not have any best facility
  local best_facility = {
    name = nil,
    distance = nil
  }

  local result
  -- create curl object
  local http_request = curl.easy()
  -- store curl response body
  :setopt_writefunction(
    function (response)
      http_response_body = tostring(response)
    end
  )
  -- add a connection timeout
  :setopt(curl.OPT_TIMEOUT, 60)
  -- make sure we check the certificates
  :setopt(curl.OPT_SSL_VERIFYPEER, true)
  -- add user-agent header to not be blocked
  :setopt(
    curl.OPT_HTTPHEADER,
    {
      "user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Safari/537.36"
    }
  )

  -- we are going to get the distance from our school to every sport facility
  for index, facility in ipairs(sport_facilities_list.facilities) do
    -- build the OSRM query
    query = endpoint .. self.city.lon .. "," .. self.city.lat .. ";" .. facility.lon .. "," .. facility.lat

    -- add the url to our curl object
    http_request:setopt(curl.OPT_URL, routing_osm .. query .. "?" .. option)
    -- run the curl query
    http_request:perform()

    -- get the http return code
    http_response_code = http_request:getinfo(curl.INFO_RESPONSE_CODE)
    -- decode result (should check before if it is a json to avoid getting an error)
    result = JSON:decode(http_response_body)

    -- apparently kids don't know how to walk over water so they can't go to some specific facilities
    if result.code ~= "Ok" or http_response_code ~= 200 then
      print("can't use facility located in: " .. tostring(facility.comment))
    -- if there is walkable route to the facility, this might be the good one
    else
      -- only store the facitility info in the best_facility table if it is the best one
      if best_facility.distance == nil or result.routes[1].distance < best_facility.distance then
        best_facility.name = facility.name
        best_facility.distance = result.routes[1].distance
      end
    end
  end

  -- do not forget to close the curl object when all the queries are done
  http_request:close()

  -- maybe there wasn't any facility that could be reach by the kids
  if not best_facility.name then
    return false, best_facility
  end

  return true, best_facility
end


return centreon_school