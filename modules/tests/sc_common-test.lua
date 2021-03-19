#!/usr/bin/lua

local sc_common = require("centreon-stream-connectors-lib.sc_common")

---
-- test1: ifnil_or_empty
local test1_nil = nil
local test1_alt = 'alternate'

print("-- test1: ifnil_or_empty --")
-- test nil value
print("test nil value: must display 'alternate'. Test value: " .. sc_common.ifnil_or_empty(test1_nil, test1_alt))

-- test empty value
local test1_empty = ''
print("test empty value: must display 'alternate'. Test value: " .. sc_common.ifnil_or_empty(test1_empty, test1_alt))

-- test a value
local test1_not_empty = 'valid'
print("test a value: must display 'valid'. Test value: " .. sc_common.ifnil_or_empty(test1_not_empty, test1_alt))

---
-- test2: boolean_to_number
local test2_boolean_true = true
local test2_boolean_false = false

print("-- test2: boolean_to_number --")

-- test a true and false boolean
print("test a true value: must display '1'. Test value: " .. sc_common.boolean_to_number(test2_boolean_true))
print("test a false value: must display '0'. Test value: " .. sc_common.boolean_to_number(test2_boolean_false))

-- test invalid type (string)
local test2_boolean_invalid = 'a string'
print("test a string value: must display '1'. Test value: " .. sc_common.boolean_to_number(test2_boolean_invalid))

-- test invalid type (nil)
local test2_boolean_nil = nil
print("test a nil value: must display '0'. Test value: " .. sc_common.boolean_to_number(test2_boolean_nil))

---
-- test3: check_boolean_number_option_syntax
local test3_default = 0
local test3_wrong = 'hello'
local test3_good_1 = 1
local test3_good_0 = 0
local test3_true = true
local test3_false = false

print("-- test3: check_boolean_number_option_syntax --")

-- test a string value
print("test a string value: must display '0'. Test value: " .. sc_common.check_boolean_number_option_syntax(test3_wrong, test3_default))

-- test boolean numbers (0 and 1)
print("test a boolean number: must display '1'. Test value: " .. sc_common.check_boolean_number_option_syntax(test3_good_1, test3_default))
print("test a boolean number: must display '0'. Test value: " .. sc_common.check_boolean_number_option_syntax(test3_good_0, test3_default))

-- test a boolean (true)
print("test a boolean (true): must display '0'. Test value: " .. sc_common.check_boolean_number_option_syntax(test3_true, test3_default))

---
-- test4: split
local test4_default_separator = 'value_0,value_1,value_2'
local test4_custom_separator = 'value_0:value_1:value_2'
local test4_no_separator = 'a string without separator'
local test4_empty_string = ''
local test4_nil_string = nil

print("-- test4: split --")

-- test a coma separated string
print("test a coma separated string")
local coma = sc_common.split(test4_default_separator)

for i, v in pairs(coma) do 
  print("must display 'value_'" .. i .. ". Test value: " .. v)
end

-- test a colon separated string
print("test a colon separated string")
local colon = sc_common.split(test4_custom_separator, ':')

for i, v in pairs(colon) do 
  print("must display 'value_'" .. i .. ". Test value: " .. v)
end

-- test a string without separators
print("test a string without separators")
local no_separator = sc_common.split(test4_no_separator)

for i, v in pairs(no_separator) do
  print("must display 'a string without separator'. Test Value: " .. v)
end

-- test an empty string
print("test an empty string")
local empty = sc_common.split(test4_empty_string)

for i, v in pairs(empty) do
  print("must display (empty) ''. Test value: " .. v)
end

-- test a nil value 
print("test a nil value. must display (empty) ''. Test value: " .. sc_common.split(test4_nil_string))
