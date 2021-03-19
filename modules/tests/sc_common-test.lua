#!/usr/bin/lua

local sc_common = require("centreon-stream-connectors-lib.sc_common")

local vempty = ''
local vnil = nil
local string = 'value_1,value_2,value_3'
local vtbool = true
local vfbool = false

---
-- test1: ifnil_or_empty
local test1_alt = 'alternate'

print("-- test1: ifnil_or_empty --")
-- test nil value
print("test nil value: must display 'alternate'. Test value: " .. sc_common.ifnil_or_empty(vnil, test1_alt))

-- test empty value
print("test empty value: must display 'alternate'. Test value: " .. sc_common.ifnil_or_empty(vempty, test1_alt))

-- test a value
local test1_not_empty = 'valid'
print("test a value: must display '".. string .. "'. Test value: " .. sc_common.ifnil_or_empty(string, test1_alt))

---
-- test2: boolean_to_number
print("-- test2: boolean_to_number --")

-- test a true and false boolean
print("test a true value: must display '1'. Test value: " .. sc_common.boolean_to_number(vtbool))
print("test a false value: must display '0'. Test value: " .. sc_common.boolean_to_number(vfbool))

-- test invalid type (string)
print("test a string value: must display '1'. Test value: " .. sc_common.boolean_to_number(string))

-- test invalid type (nil)
print("test a nil value: must display '0'. Test value: " .. sc_common.boolean_to_number(vnil))

---
-- test3: check_boolean_number_option_syntax
local test3_default = 0
local test3_good_1 = 1
local test3_good_0 = 0

print("-- test3: check_boolean_number_option_syntax --")

-- test a string value
print("test a string value: must display '0'. Test value: " .. sc_common.check_boolean_number_option_syntax(string, test3_default))

-- test boolean numbers (0 and 1)
print("test a boolean number: must display '1'. Test value: " .. sc_common.check_boolean_number_option_syntax(test3_good_1, test3_default))
print("test a boolean number: must display '0'. Test value: " .. sc_common.check_boolean_number_option_syntax(test3_good_0, test3_default))

-- test a boolean (true)
print("test a boolean (true): must display '0'. Test value: " .. sc_common.check_boolean_number_option_syntax(vtbool, test3_default))

---
-- test4: split
local test4_custom_separator = 'value_1:value_2:value_3'
local test4_no_separator = 'a string without separator'

print("-- test4: split --")

-- test a coma separated string
print("test a coma separated string")
local coma = sc_common.split(string)

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
print("test an empty string. must display (empty) ''. Test value: " .. sc_common.split(vempty))

-- test a nil value 
print("test a nil value. must display (empty) ''. Test value: " .. sc_common.split(vnil))

---
-- test5: compare_numbers
local test5_num1 = 5
local test5_num2 = 12
local test5_float = 5.5
local test5_operator = '<='

print("-- test5: compare_numbers --")
-- test inferior number
print("test a <= b. must display true. Test value: " .. tostring(sc_common.compare_numbers(test5_num1, test5_num2, test5_operator)))

-- test with fload number
print("test a <= b (b is a float number). must display true. Test value: " .. tostring(sc_common.compare_numbers(test5_num1, test5_float, test5_operator)))

-- test superior number
print("test a <= b. must display false. Test value: " .. tostring(sc_common.compare_numbers(test5_num2, test5_num1, test5_operator)))

-- test nil operator
print("test with a nil operator. must display nil. Test value: " .. tostring(sc_common.compare_numbers(test5_num2, test5_num1, vnil)))

-- test empty operator
print("test with a empty operator. must display nil. Test value: " .. tostring(sc_common.compare_numbers(test5_num2, test5_num1, string)))

-- test nil number
print("test with a nil number. must display nil. Test value: " .. tostring(sc_common.compare_numbers(vnil, test5_num1, test5_operator)))

-- test empty number
print("test with a empty number. must display nil. Test value: " .. tostring(sc_common.compare_numbers(vempty, test5_num1, test5_operator)))

-- test with string as number
print("test with a string. must display nil. Test value: " .. tostring(sc_common.compare_numbers(string, test5_num1, test5_operator)))