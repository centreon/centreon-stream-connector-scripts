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
if not openssl.pkey or not openssl.pkey.read then
  print("ERROR: openssl.pkey API not available")
  os.exit(1)
end

-- Try various key generation approaches and capture actual error messages
-- openssl.pkey.new returns nil, errmsg on failure (not a Lua exception)
local pk
local gen_errors = {}

local gen_attempts = {
  {label="pkey.new({type='rsa', bits=2048})", fn=function() return openssl.pkey.new({type='rsa', bits=2048}) end},
  {label="pkey.new({type='RSA', bits=2048})", fn=function() return openssl.pkey.new({type='RSA', bits=2048}) end},
  {label="pkey.new('rsa', 2048)",             fn=function() return openssl.pkey.new('rsa', 2048) end},
  {label="pkey.new('RSA', 2048)",             fn=function() return openssl.pkey.new('RSA', 2048) end},
}

-- Also try via openssl.rsa module if available
if type(openssl.rsa) == 'table' and type(openssl.rsa.generate) == 'function' then
  table.insert(gen_attempts, {
    label = "rsa.generate(2048) + pkey.read",
    fn = function()
      local rsa = openssl.rsa.generate(2048)
      if not rsa then return nil, "rsa.generate returned nil" end
      local pem = rsa:export('pem', true)
      if not pem then pem = rsa:export() end
      if not pem then return nil, "rsa export returned nil" end
      return openssl.pkey.read(pem, true)
    end
  })
end

for _, attempt in ipairs(gen_attempts) do
  -- Capture ok, first_return (pkey or nil), second_return (errmsg if nil)
  local ok2, r1, r2 = pcall(attempt.fn)
  if ok2 and r1 then
    pk = r1
    break
  else
    local err = ok2 and tostring(r2) or tostring(r1)
    table.insert(gen_errors, attempt.label .. ": " .. err)
  end
end

if not pk then
  print("ERROR: Unable to generate RSA key pair")
  for _, err in ipairs(gen_errors) do
    print("  " .. err)
  end
  if type(openssl.pkey) == 'table' then
    print("  Available openssl.pkey functions:")
    for k in pairs(openssl.pkey) do
      print("    pkey." .. k)
    end
  end
  os.exit(1)
end

print("✓ RSA key generation successful")

-- Export to PEM, then reload with pkey.read (mirrors oauth.lua flow)
local pem
for _, args in ipairs({{"pem", true}, {}}) do
  local eok, result = pcall(function() return pk:export(table.unpack(args)) end)
  if eok and result and type(result) == "string" and result:match("BEGIN") then
    pem = result
    break
  end
end

if not pem then
  print("ERROR: Unable to export private key to PEM")
  os.exit(1)
end

-- oauth.lua line: openssl.pkey.read(self.key_table.private_key, true)
local ok2, loaded_pk, load_err = pcall(openssl.pkey.read, pem, true)

if not ok2 or not loaded_pk then
  print("ERROR: openssl.pkey.read from PEM failed")
  print(tostring(load_err or loaded_pk))
  os.exit(1)
end

print("✓ openssl.pkey.read from PEM successful")

-- oauth.lua line: private_key_object:sign(string_to_sign, "sha256")
local ok3, sig, sign_err = pcall(function()
  return loaded_pk:sign("header.payload", "sha256")
end)

if not ok3 or not sig or #sig == 0 then
  print("ERROR: RSA-SHA256 signing failed")
  print(tostring(sign_err or sig))
  os.exit(1)
end

print("✓ RSA-SHA256 signing (pkey:sign) successful")

print("\nAll tests passed - lua-openssl is working correctly!")
