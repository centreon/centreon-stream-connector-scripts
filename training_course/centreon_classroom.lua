local centreon_classroom = {}

local CentreonClassroom = {}

function centreon_classroom.new(teacher)
  local self = {}
  
  if teacher then
    self.teacher = teacher
  else
    self.teacher = {
      first_name = "Minerva",
      last_name = "McGonagall",
      speciality = "Transfiguration"
    }
  end

  setmetatable(self, { __index = CentreonClassroom })
  return self
end

function CentreonClassroom:put_tables(tables)
  if not tables then
    math.randomseed(os.time())
    self.tables = math.random(1,20)
  elseif tables > 20 then
    print(tables .. " tables is a bit much, it is a classroom not a stadium")
    math.randomseed(os.time())
    self.tables = math.random(1,20)
  else
    self.tables = tables
  end
end

function CentreonClassroom:put_chairs(chairs)
  if not self.tables then
    self:put_tables()
  end

  if chairs > self.tables * 2 then
    print("there are only " .. tostring(self.tables) .. " tables in the classroom,"
      .. "you can't have more than 2 chairs per table")
  end
  
  self.chairs = chairs
end

return centreon_classroom
