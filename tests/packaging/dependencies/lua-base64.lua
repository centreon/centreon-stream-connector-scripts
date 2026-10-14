#!/usr/bin/env lua

-- Check if the module can be loaded
local status, base64 = pcall(require, 'base64')

if not status then
  print("ERROR: Unable to load base64 module")
  print(base64)
  os.exit(1)
end

print("✓ base64 module loaded successfully")

-- Test encoding of a known string
local encoded = base64.encode("Hello, World!")
if encoded ~= "SGVsbG8sIFdvcmxkIQ==" then
  print("ERROR: Encoding failed")
  print("Expected: SGVsbG8sIFdvcmxkIQ==")
  print("Got: " .. tostring(encoded))
  os.exit(1)
end

print("✓ Encoding successful")

-- Test decoding of a known base64 string
local decoded = base64.decode("SGVsbG8sIFdvcmxkIQ==")
if decoded ~= "Hello, World!" then
  print("ERROR: Decoding failed")
  print("Expected: Hello, World!")
  print("Got: " .. tostring(decoded))
  os.exit(1)
end

print("✓ Decoding successful")

-- Test encode/decode roundtrip
local original = "Centreon stream connector - lua-base64 test 1234!@#$"
local roundtrip = base64.decode(base64.encode(original))
if roundtrip ~= original then
  print("ERROR: Roundtrip encode/decode failed")
  print("Expected: " .. original)
  print("Got: " .. tostring(roundtrip))
  os.exit(1)
end

print("✓ Roundtrip encode/decode successful")

-- Test encoding of empty string
local encoded_empty = base64.encode("")
if encoded_empty ~= "" then
  print("ERROR: Empty string encoding failed")
  print("Expected: ''")
  print("Got: " .. tostring(encoded_empty))
  os.exit(1)
end

print("✓ Empty string encoding successful")

-- Test decoding of empty string
local decoded_empty = base64.decode("")
if decoded_empty ~= "" then
  print("ERROR: Empty string decoding failed")
  print("Expected: ''")
  print("Got: " .. tostring(decoded_empty))
  os.exit(1)
end

print("✓ Empty string decoding successful")

-- Test encoding of binary-like data (all byte values 0-255)
local binary_data = ""
for i = 0, 255 do
  binary_data = binary_data .. string.char(i)
end

local ok, err = pcall(function()
  local enc = base64.encode(binary_data)
  local dec = base64.decode(enc)
  if dec ~= binary_data then
    error("Binary roundtrip mismatch")
  end
end)

if not ok then
  print("ERROR: Binary data roundtrip failed")
  print(err)
  os.exit(1)
end

print("✓ Binary data roundtrip successful")

print("\nAll tests passed - lua-base64 is working correctly!")
