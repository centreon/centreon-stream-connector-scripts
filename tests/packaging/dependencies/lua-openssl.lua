#!/usr/bin/env lua

-- Check if the module can be loaded
local status, openssl = pcall(require, 'openssl')

if not status then
  print("ERROR: Unable to load openssl module")
  print(openssl)
  os.exit(1)
end

print("✓ openssl module loaded successfully")

-- Test SHA256 digest computation
local ok, md = pcall(function()
  return openssl.digest.new("sha256")
end)

if not ok or not md then
  print("ERROR: Unable to create sha256 digest context")
  print(tostring(md))
  os.exit(1)
end

md:update("test")
local hash = md:final()

if not hash or #hash == 0 then
  print("ERROR: SHA256 digest returned empty result")
  os.exit(1)
end

print("✓ SHA256 digest computation successful")

-- Test RSA key generation, pkey.read and pkey:sign
-- These are the exact functions used in google/auth/oauth.lua:create_signature()
if not openssl.pkey or not openssl.pkey.new or not openssl.pkey.read then
  print("ERROR: openssl.pkey API not available")
  os.exit(1)
end

-- Try key generation with known API variants
local pk
for _, params in ipairs({{type='rsa', bits=1024}, {type='RSA', bits=1024}}) do
  local gok, gpk = pcall(openssl.pkey.new, params)
  if gok and gpk then
    pk = gpk
    break
  end
end

if not pk then
  print("ERROR: Unable to generate RSA key pair")
  os.exit(1)
end

print("✓ RSA key generation successful")

-- Export to PEM, then reload with pkey.read (mirrors oauth.lua flow)
local pem
for _, args in ipairs({{"pem", true}, {}}) do
  local eok, result = pcall(function() return pk:export(table.unpack(args)) end)
  if eok and result and type(result) == "string" then
    pem = result
    break
  end
end

if not pem then
  print("ERROR: Unable to export private key to PEM")
  os.exit(1)
end

-- oauth.lua line: openssl.pkey.read(self.key_table.private_key, true)
local ok2, loaded_pk = pcall(openssl.pkey.read, pem, true)

if not ok2 or not loaded_pk then
  print("ERROR: openssl.pkey.read from PEM failed")
  print(tostring(loaded_pk))
  os.exit(1)
end

print("✓ openssl.pkey.read from PEM successful")

-- oauth.lua line: private_key_object:sign(string_to_sign, "sha256")
local ok3, sig = pcall(function()
  return loaded_pk:sign("header.payload", "sha256")
end)

if not ok3 or not sig or #sig == 0 then
  print("ERROR: RSA-SHA256 signing failed")
  print(tostring(sig))
  os.exit(1)
end

print("✓ RSA-SHA256 signing (pkey:sign) successful")

print("\nAll tests passed - lua-openssl is working correctly!")
