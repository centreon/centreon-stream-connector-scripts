#!/usr/bin/lua

--- 
-- Module with common methods for Centreon Stream Connectors
-- @module sc_common
-- @alias sc_common

local sc_common = {}

local sc_logger = require("centreon-stream-connectors-lib.sc_logger")

--- ifnil_or_empty: change a nil or empty variable for a specified value
-- @param var (string|number) the variable that needs to be checked
-- @param alt (string|number|table) the alternate value if "var" is nil or empty
-- @return var or alt (string|number|table) the variable or the alternate value
local function ifnil_or_empty(var, alt)
  if var == nil or var == "" then
    return alt
  else
    return var
  end
end

local ScCommon = {}

function sc_common.new(logger)
  local self = {}
  
  self.logger = logger
  if not self.logger then 
    self.logger = sc_logger.new()
  end

  setmetatable(self, { __index = ScCommon })

  return self
end

--- ifnil_or_empty: change a nil or empty variable for a specified value
-- @param var (string|number) the variable that needs to be checked
-- @param alt (string|number|table) the alternate value if "var" is nil or empty
-- @return var or alt (string|number|table) the variable or the alternate value
function ScCommon:ifnil_or_empty(var, alt)
  return ifnil_or_empty(var, alt)
end

--- if_wrong_type: change a wrong type variable with a default value
-- @param var (any) the variable that needs to be checked
-- @param type (string) the expected type of the variable
-- @param default (any) the default value for the variable if type is wrong
-- @return var or default (any) the variable if type is good or the default value
function ScCommon:if_wrong_type(var, var_type, default)
  if type(var) == var_type then
    return var
  end

  return default
end

--- boolean_to_number: convert boolean variable to number
-- @param boolean (boolean) the boolean that will be converted
-- @return (number) a number according to the boolean value
function ScCommon:boolean_to_number(boolean)
  return boolean and 1 or 0
end


--- check_boolean_number_option_syntax: make sure the number is either 1 or 0
-- @param number (number)  the boolean number that must be validated
-- @param default (number) the default value that is going to be return if the default number is not validated
-- @return number (number) a boolean number
function ScCommon:check_boolean_number_option_syntax(number, default)
  if number ~= 1 and number ~= 0 then
    number = default
  end

  return number
end

--- split: convert a string into a table
-- @param text (string) the string that is going to be splitted into a table
-- @param [opt] separator (string) the separator character that will be used to split the string
-- @return false (boolean) if text param is empty or nil
-- @return table (table) a table of strings
function ScCommon:split (text, separator)
  -- return false if text is nil or empty
  if text == nil or text == "" then
    self.logger:error("[sc_common:split]: could not split text because it is nil or empty")
    return false
  end

  local hash = {}

  -- set default separator
  separator = ifnil_or_empty(separator, ",")

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
function ScCommon:compare_numbers(firstNumber, secondNumber, operator)
  if operator ~= "==" and operator ~= "~=" and operator ~= "<" and operator ~= ">" and operator ~= ">=" and operator ~= "<=" then
    return nil
  end

  if type(firstNumber) ~= "number" or type(secondNumber) ~= "number" then
    return nil
  end

  if operator == "<" then
    if firstNumber < secondNumber then
      return true
    end
  elseif operator == ">" then
    if firstNumber > secondNumber then
      return true
    end
  elseif operator == ">=" then
    if firstNumber >= secondNumber then
      return true
    end
  elseif operator == "<=" then
    if firstNumber <= secondNumber then
      return true
    end
  elseif operator == "==" then
    if firstNumber == secondNumber then
      return true
    end
  elseif operator == "~=" then
    if firstNumber ~= secondNumber then
      return true
    end
  end

  return false
end

--- generate_postfield_param_string: convert a table of parameters into an url encoded url parameters string
-- @param params (table) the table of all url string parameters to convert
-- @return false (boolean) if params variable is not a table
-- @return param_string (string)  the url encoded parameters string
function ScCommon:generate_postfield_param_string(params)
  -- return false because params type is wrong
  if (type(params) ~= "table") then
    self.logger:error("[sc_common:generate_postfield_param_string]: parameters to convert aren't in a table")
    return false
  end

  local param_string = ""

  -- concatenate data in params table into a string
  for field, value in pairs(params) do
    if param_string == "" then
      param_string = field .. "=" .. broker.url_encode(value)
    else
      param_string = param_string .. "&" .. field .. "=" .. broker.url_encode(value)
    end
  end

  -- return url encoded string
  return param_string
end

return sc_common