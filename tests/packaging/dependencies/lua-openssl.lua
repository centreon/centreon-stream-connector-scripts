#!/usr/bin/env lua

-- Check if the module can be loaded
local status, openssl = pcall(require, 'openssl')

if not status then
  print("ERROR: Unable to load openssl module")
  print(openssl)
  os.exit(1)
end

print("✓ openssl module loaded successfully")

-- Check that pkey module is available
if not openssl.pkey then
  print("ERROR: openssl.pkey not available")
  os.exit(1)
end

if not openssl.pkey.read then
  print("ERROR: openssl.pkey.read not available")
  os.exit(1)
end

print("✓ openssl.pkey module available")

-- Generate a test RSA key pair and verify signing works
local ok, pk = pcall(function()
  return openssl.pkey.new({type = "RSA", bits = 1024})
end)

if not ok or not pk then
  print("ERROR: Unable to generate RSA key pair")
  print(tostring(pk))
  os.exit(1)
end

print("✓ RSA key generation successful")

-- Export private key to PEM and reload it (mimics Google OAuth flow)
local ok2, pem = pcall(function()
  return pk:export("pem", true)
end)

if not ok2 or not pem then
  print("ERROR: Unable to export private key to PEM")
  print(tostring(pem))
  os.exit(1)
end

local ok3, loaded_pk = pcall(function()
  return openssl.pkey.read(pem, true)
end)

if not ok3 or not loaded_pk then
  print("ERROR: Unable to reload private key from PEM")
  print(tostring(loaded_pk))
  os.exit(1)
end

print("✓ Private key export and reload successful")

-- Sign data using RSA-SHA256
local test_data = "header.payload"
local ok4, sig = pcall(function()
  return loaded_pk:sign(test_data, "sha256")
end)

if not ok4 or not sig or #sig == 0 then
  print("ERROR: RSA-SHA256 signing failed")
  print(tostring(sig))
  os.exit(1)
end

print("✓ RSA-SHA256 signing successful")

print("\nAll tests passed - lua-openssl is working correctly!")
