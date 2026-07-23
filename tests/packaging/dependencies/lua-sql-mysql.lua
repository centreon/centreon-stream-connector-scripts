#!/usr/bin/env lua

-- Check if the module can be loaded
local status, luasql = pcall(require, 'luasql.mysql')

if not status then
  print("ERROR: Unable to load luasql.mysql module")
  print(luasql)
  os.exit(1)
end

print("✓ luasql.mysql module loaded successfully")

-- Check that the environment can be created
local ok, env = pcall(luasql.mysql)

if not ok then
  print("ERROR: Unable to create MySQL environment")
  print(env)
  os.exit(1)
end

print("✓ MySQL environment created successfully")

-- Verify environment type
if type(env) ~= "userdata" then
  print("ERROR: Environment is not of the expected type")
  os.exit(1)
end

print("✓ Environment type is correct")

-- Test connection attempt with invalid parameters (should fail gracefully)
local conn, err = env:connect("test_db", "test_user", "test_pass", "localhost", 3306)

if conn then
  print("✓ Connection object created (MySQL server may be running)")
  conn:close()
else
  -- Expected behavior when MySQL is not running
  if err and type(err) == "string" then
    print("✓ Connection failed as expected (no MySQL server): " .. err)
  else
    print("✓ Connection failed as expected (no MySQL server)")
  end
end

-- Close environment
env:close()
print("✓ Environment closed successfully")

print("\nAll tests passed - lua-sql-mysql is working correctly!")
