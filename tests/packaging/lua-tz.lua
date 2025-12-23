#!/usr/bin/env lua

-- Check if the module can be loaded
local status, luatz = pcall(require, 'luatz')

if not status then
  print("ERROR: Unable to load luatz module")
  print(luatz)
  os.exit(1)
end

print("✓ luatz module loaded successfully")

-- Test basic functionality: get current time
local ok, now = pcall(function()
  return luatz.time()
end)

if not ok then
  print("ERROR: Unable to get current time")
  print(now)
  os.exit(1)
end

print("✓ Current time retrieved successfully: " .. now)

-- Test timezone parsing
local ok, tz = pcall(function()
  return luatz.time_in(nil)
end)

if not ok then
  print("ERROR: Unable to create time_in object")
  print(tz)
  os.exit(1)
end

print("✓ time_in object created successfully")

-- Test timestamp conversion
local ok, ts = pcall(function()
  local t = luatz.timetable()
  t.year = 2024
  t.month = 1
  t.day = 1
  t.hour = 0
  t.min = 0
  t.sec = 0
  return t:timestamp()
end)

if not ok then
  print("ERROR: Unable to convert timetable to timestamp")
  print(ts)
  os.exit(1)
end

print("✓ Timetable to timestamp conversion successful: " .. ts)

-- Test timestamp parsing
local ok, tt = pcall(function()
  return luatz.timetable.new_from_timestamp(ts)
end)

if not ok then
  print("ERROR: Unable to parse timestamp")
  print(tt)
  os.exit(1)
end

if tt.year ~= 2024 or tt.month ~= 1 or tt.day ~= 1 then
  print("ERROR: Parsed values do not match")
  os.exit(1)
end

print("✓ Timestamp parsing successful")

print("\nAll tests passed - lua-tz is working correctly!")
