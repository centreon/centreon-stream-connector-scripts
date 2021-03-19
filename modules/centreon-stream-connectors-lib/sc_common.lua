#!/usr/bin/lua

--- 
-- Module with common methods for Centreon Stream Connectors
-- @module sc_common
-- @alias sc_common

local sc_common = {}

--- ifnil_or_empty: change a nil or empty variable for a specified value
-- @param var (string|number) the variable that needs to be checked
-- @param alt (string|number|table) the alternate value if "var" is nil or empty
-- @return var or alt (string|number|table) the variable or the alternate value
local function ifnil_or_empty(var, alt)
  if var == nil or var == '' then
    return alt
  else
    return var
  end
end

--- ifnil_or_empty: change a nil or empty variable for a specified value
-- @param var (string|number) the variable that needs to be checked
-- @param alt (string|number|table) the alternate value if "var" is nil or empty
-- @return var or alt (string|number|table) the variable or the alternate value
function sc_common.ifnil_or_empty(var, alt)
  return ifnil_or_empty(var, alt)
end


--- boolean_to_number: convert boolean variable to number
-- @param boolean (boolean) the boolean that will be converted
-- @return (number) a number according to the boolean value
--------------------------------------------------------------------------------
function sc_common.boolean_to_number(boolean)
  return boolean and 1 or 0
end


--- check_boolean_number_option_syntax: make sure the number is either 1 or 0
-- @param number (number)  the boolean number that must be validated
-- @param default (number) the default value that is going to be return if the default number is not validated
-- @return number (number) a boolean number
--------------------------------------------------------------------------------
function sc_common.check_boolean_number_option_syntax(number, default)
  if number ~= 1 and number ~= 0 then
    number = default
  end

  return number
end

--- split: convert a string into a table
-- @param string (string) the string that is going to be splitted into a table
-- @param [opt] separator (string) the separator character that will be used to split the string
-- @return table (table) a table of strings
--------------------------------------------------------------------------------
function sc_common.split (text, separator)
  local hash = {}
  
  -- return empty string if text is nil
  if text == nil or text == '' then
    -- broker_log:error(1, 'split: could not split text because it is nil')
    return ''
  end
  
  -- set default separator
  separator = ifnil_or_empty(separator, ',')

  for value in string.gmatch(text, "([^" .. separator .. "]+)") do
    table.insert(hash, value)
  end

  return hash
end

--- compare_numbers: compare two numbers, if comparison is valid, then return true
-- @param firstNumber {number} 
-- @param secondNumber {number} 
-- @param operator {string} the mathematical operator that is used for the comparison
-- @return {boolean}
--------------------------------------------------------------------------------
function sc_common.compare_numbers (firstNumber, secondNumber, operator)
  if operator ~= '==' and operator ~= '~=' and operator ~= '<' and operator ~= '>' and operator ~= '>=' and operator ~= '<=' then
    return nil
  end

  if type(firstNumber) ~= 'number' or type(secondNumber) ~= 'number' then
    return nil
  end

  if operator == '<' then
    if firstNumber < secondNumber then
      return true
    end
  elseif operator == '>' then
    if firstNumber > secondNumber then
      return true
    end
  elseif operator == '>=' then
    if firstNumber >= secondNumber then
      return true
    end
  elseif operator == '<=' then
    if firstNumber <= secondNumber then
      return true
    end
  elseif operator == '==' then
    if firstNumber == secondNumber then
      return true
    end
  elseif operator == '~=' then
    if firstNumber ~= secondNumber then
      return true
    end
  end

  return false
end

return sc_common