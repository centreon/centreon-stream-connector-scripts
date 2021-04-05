#!/usr/bin/lua

local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_test = require("centreon-stream-connectors-lib.sc_test")

local common = sc_common.new()

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
print("test nil value: " .. sc_test.compare_result('alternate', common:ifnil_or_empty(vnil, test1_alt)))

-- test empty value
print("test empty value: " .. sc_test.compare_result('alternate', common:ifnil_or_empty(vempty, test1_alt)))

-- test a value
print("test a value: " .. sc_test.compare_result(string, common:ifnil_or_empty(string, test1_alt)))

---
-- test2: boolean_to_number
print("-- test2: boolean_to_number --")

-- test a true and false boolean
print("test a true value: " .. sc_test.compare_result(1, common:boolean_to_number(vtbool)))
print("test a false value: " .. sc_test.compare_result(0, common:boolean_to_number(vfbool)))

-- test invalid type (string)
print("test a string value: " .. sc_test.compare_result(1, common:boolean_to_number(string)))

-- test invalid type (nil)
print("test a nil value: " .. sc_test.compare_result(0, common:boolean_to_number(vnil)))

---
-- test3: check_boolean_number_option_syntax
local test3_default = 0
local test3_good_1 = 1
local test3_good_0 = 0

print("-- test3: check_boolean_number_option_syntax --")

-- test a string value
print("test a string value: " .. sc_test.compare_result(0, common:check_boolean_number_option_syntax(string, test3_default)))

-- test boolean numbers (0 and 1)
print("test a boolean number: " .. sc_test.compare_result(1, common:check_boolean_number_option_syntax(test3_good_1, test3_default)))
print("test a boolean number: " .. sc_test.compare_result(0, common:check_boolean_number_option_syntax(test3_good_0, test3_default)))

-- test a boolean (true)
print("test a boolean (true): " .. sc_test.compare_result(0, common:check_boolean_number_option_syntax(vtbool, test3_default)))

---
-- test4: split
local test4_no_separator = 'a string without separator'
local test4_custom_separator = 'value_1:value_2:value_3'
print("-- test4: split --")

-- test a coma separated string
local table = {
  [1] = value_1,
  [2] = value_2,
  [3] = value_3
}
print("test a coma separated string: " .. sc_test.compare_tables(table, common:split(string)))

-- test a colon separated string
print("test a colon separated string: " .. sc_test.compare_tables(table, common:split(test4_custom_separator, ':')))

-- test a string without separator
table = {
  [1] = test4_no_separator
}
print("test a string without separators: " .. sc_test.compare_tables(table, common:split(test4_no_separator)))

-- test an empty string
print("test an empty string: " .. sc_test.compare_result('', common:split(vempty)))

-- test a nil value 
print("test a nil value: " .. sc_test.compare_result('', common:split(vnil)))

---
-- test5: compare_numbers

print("-- test5: compare_numbers --")
-- test inferior number
print("test a <= b. " .. sc_test.compare_result(true, common:compare_numbers(1, 3, '<=')))

-- test with fload number
print("test a <= b (b is a float number): " .. sc_test.compare_result(true, common:compare_numbers(1, 3.5, '<=')))

-- test superior number
print("test a <= b: " .. sc_test.compare_result(false, common:compare_numbers(3, 1, '<=')))

-- test nil operator
print("test with a nil operator: " .. sc_test.compare_result(nil, common:compare_numbers(3, 1, nil)))

-- test empty operator
print("test with a empty operator: " .. sc_test.compare_result(nil, common:compare_numbers(3, 1, '')))

-- test nil number
print("test with a nil number: " .. sc_test.compare_result(nil, common:compare_numbers(nil, 1, '<=')))

-- test empty number
print("test with a empty number: " .. sc_test.compare_result(nil, common:compare_numbers('', 1, '<=')))

-- test with string as number
print("test with a string: " .. sc_test.compare_result(nil, common:compare_numbers(string, 1, '<=')))