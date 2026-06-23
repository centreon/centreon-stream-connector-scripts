#!/usr/bin/env lua

-- Check if the module can be loaded
local status, ffi = pcall(require, 'cffi')

if not status then
  print("ERROR: Unable to load cffi module")
  print(ffi)
  os.exit(1)
end

print("✓ cffi module loaded successfully")

-- Basic test: define a C structure
local ok, err = pcall(function()
  ffi.cdef[[
    typedef struct { int x; int y; } point_t;
  ]]
end)

if not ok then
  print("ERROR: Unable to define C structure")
  print(err)
  os.exit(1)
end

print("✓ C structure definition successful")

-- Create and test an instance
local ok, point = pcall(function()
  return ffi.new('point_t', {x = 10, y = 20})
end)

if not ok then
  print("ERROR: Unable to create instance")
  print(point)
  os.exit(1)
end

if point.x ~= 10 or point.y ~= 20 then
  print("ERROR: Values do not match")
  os.exit(1)
end

print("✓ Instance creation and data access successful")
print("\nAll tests passed - lua-cffi is working correctly!")
