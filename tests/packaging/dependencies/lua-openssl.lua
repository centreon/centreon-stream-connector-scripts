#!/usr/bin/env lua

-- Check if the module can be loaded
local status, openssl = pcall(require, 'openssl')

if not status then
  print("ERROR: Unable to load openssl module")
  print(openssl)
  os.exit(1)
end

print("✓ openssl module loaded successfully")

-- Check that pkey and digest modules are available
if not openssl.pkey or not openssl.pkey.read then
  print("ERROR: openssl.pkey.read not available")
  os.exit(1)
end

print("✓ openssl.pkey module available")

if not openssl.digest then
  print("ERROR: openssl.digest not available")
  os.exit(1)
end

print("✓ openssl.digest module available")

-- Test SHA256 digest computation
local ok, md = pcall(function()
  return openssl.digest.new("sha256")
end)

if not ok or not md then
  print("ERROR: Unable to create sha256 digest context")
  print(tostring(md))
  os.exit(1)
end

md:update("hello world")
local hash = md:final(true)

if not hash or #hash == 0 then
  print("ERROR: SHA256 digest returned empty result")
  os.exit(1)
end

print("✓ SHA256 digest computation successful")

print("\nAll tests passed - lua-openssl is working correctly!")
