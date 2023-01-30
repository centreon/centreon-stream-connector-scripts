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

function sc_common.new(sc_logger)
  local self = {}
  
  self.sc_logger = sc_logger
  if not self.sc_logger then 
    self.sc_logger = sc_logger.new()
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

--- number_to_boolean: convert a 0, 1 number to its boolean counterpart
-- @param number (number) the number to convert
-- @return (boolean) true if param is 1, false if param is 0
function ScCommon:number_to_boolean(number)
  if number ~= 0 and number ~= 1 then
    self.sc_logger:error("[sc_common:number_to_boolean]: number is not 1 or 0. Returning nil. Parameter value is: " .. tostring(number))
    return nil
  end

  if number == 1 then
    return true
  end

  return false
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
function ScCommon:split(text, separator)
  -- return false if text is nil or empty
  if text == nil or text == "" then
    self.sc_logger:error("[sc_common:split]: could not split text because it is nil or empty")
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
    self.sc_logger:error("[sc_common:generate_postfield_param_string]: parameters to convert aren't in a table")
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

--- load_json_file: load a json file
-- @param json_file (string) path to the json file
-- @return true|false (boolean) if json file is valid or not
-- @return content (table) the parsed json
function ScCommon:load_json_file(json_file)
  local file = io.open(json_file, "r")

  -- return false if we can't open the file
  if not file then
    self.sc_logger:error("[sc_common:load_json_file]: couldn't open file "
      .. tostring(json_file) .. ". Make sure your file is there and that it is readable by centreon-broker")
    return false
  end

  -- get content of the file
  local file_content = file:read("*a")
  io.close(file)

  -- parse it
  local content, error = broker.json_decode(file_content)

  -- return false if json couldn't be parsed
  if error then
    self.sc_logger:error("[sc_common:load_json_file]: could not parse json file "
      .. tostring(json_file) .. ". Error is: " .. tostring(error))
    return false
  end

  return true, content
end

--- json_escape: escape json special characters in a string
-- @param string (string) the string that must be escaped
-- @return string (string) the string with escaped characters
function ScCommon:json_escape(string)
  if type(string) ~= "string" then
    self.sc_logger:error("[sc_common:json_escape]: the input parameter is not valid, it must be a string. Sent value: " .. tostring(string))
    return string
  end

  return string:gsub('\\', '\\\\')
    :gsub('\t', '\\t')
    :gsub('\n', '\\n')
    :gsub('\b', '\\b')
    :gsub('\r', '\\r')
    :gsub('\f', '\\f')
    :gsub('/', '\\/')
    :gsub('"', '\\"')
end

--- xml_escape: escape xml special characters in a string
-- @param string (string) the string that must be escaped
-- @return string (string) the string with escaped characters
function ScCommon:xml_escape(string)
  if type(string) ~= "string" then
    self.sc_logger:error("[sc_common:xml_escape]: the input parameter is not valid, it must be a string. Sent value: " .. tostring(string))
    return string
  end

  return string:gsub('&', '&amp')
    :gsub('<', '$lt;')
    :gsub('>', '&gt;')
    :gsub('"', '&quot;')
    :gsub("'", "&apos;")
end

--- lua_regex_escape: escape lua regex special characters in a string
-- @param string (string) the string that must be escaped
-- @return string (string) the string with escaped characters
function ScCommon:lua_regex_escape(string)
  if type(string) ~= "string" then
    self.sc_logger:error("[sc_common:lua_regex_escape]: the input parameter is not valid, it must be a string. Sent value: " .. tostring(string))
    return string
  end

  return string:gsub('%%', '%%%%')
    :gsub('%.', '%%.')
    :gsub("%*", "%%*")
    :gsub("%-", "%%-")
    :gsub("%(", "%%(")
    :gsub("%)", "%%)")
    :gsub("%[", "%%[")
    :gsub("%]", "%%]")
    :gsub("%$", "%%$")
    :gsub("%^", "%%^")
    :gsub("%+", "%%+")
    :gsub("%?", "%%?")
end

--- dumper: dump variables for debug purpose
-- @param variable (any) the variable that must be dumped
-- @param result (string) [opt] the string that contains the dumped variable. ONLY USED INTERNALLY FOR RECURSIVE PURPOSE
-- @param tab_char (string) [opt] the string that contains the tab character. ONLY USED INTERNALLY FOR RECURSIVE PURPOSE (and design)
-- @return result (string) the dumped variable
function ScCommon:dumper(variable, result, tab_char)
  -- tabulation handling
  if not tab_char then
    tab_char = ""
  else
    tab_char = tab_char .. "\t"
  end

  -- non table variables handling
  if type(variable) ~= "table" then
    if result then
      result = result .. "\n" .. tab_char .. "[" .. type(variable) .. "]: " .. tostring(variable)
    else
      result = "\n[" .. type(variable) .. "]: " .. tostring(variable)
    end
  else
    if not result then
      result = "\n[table]"
      tab_char = "\t"
    end

    -- recursive looping through each tables in the table
    for index, value in pairs(variable) do
      if type(value) ~= "table" then
        if result then
          result = result .. "\n" .. tab_char .. "[" .. type(value) .. "] " .. tostring(index) .. ": " .. tostring(value)
        else
          result = "\n" .. tostring(index) .. " [" .. type(value) .. "]: " .. tostring(value)
        end
      else
        if result then
          result = result .. "\n" .. tab_char .. "[" .. type(value) .. "] " .. tostring(index) .. ": "
        else
          result = "\n[" .. type(value) .. "] " .. tostring(index) .. ": "
        end
        result = self:dumper(value, result, tab_char)
      end
    end
  end

  return result
end

--- trim: remove spaces at the beginning and end of a string (or remove the provided character)
-- @param string (string) the string that will be trimmed
-- @param character [opt] (string) the character to trim
-- @return string (string) the trimmed string
function ScCommon:trim(string, character)
  local result = ""
  local count = ""
  if not character then
    result, count = string.gsub(string, "^%s*(.-)%s*$", "%1")
  else
    result, count = string.gsub(string, "^" .. character .. "*(.-)" .. character .. "*$", "%1")
  end

  return result
end

--- get_curl_command: build a shell curl command based on given parameters
-- @param url (string) the url to which curl will send data
-- @param metadata (table) a table that contains headers information and http method for curl
-- @param params (table) the param table that contains proxy information for example
-- @param data (string) [opt] the data that must be send by curl
-- @return curl_string (string) the shell curl command
function ScCommon:get_curl_command(url, metadata, params, data)
  local curl_string = "curl "

  -- handle proxy
  local proxy_url
  if params.proxy_address ~= "" then  
    if params.proxy_username ~= "" then
      proxy_url = params.proxy_protocol .. "://" .. params.proxy_username .. ":" .. params.proxy_password
        .. "@" .. params.proxy_address .. ":" .. params.proxy_port
    else
      proxy_url = params.proxy_protocol .. "://" .. params.proxy_address .. ":" .. params.proxy_port
    end

    curl_string = curl_string .. "--proxy " .. proxy_url .. " "
  end

  -- handle certificate verification
  if params.allow_insecure_connection == 1 then
    curl_string = curl_string .. "-k "
  end

  -- handle http method
  if metadata.method then
    curl_string = curl_string .. "-X " .. metadata.method .. " "
  elseif data then
    curl_string = curl_string .. "-X POST "
  else
    curl_string = curl_string .. "-X GET "
  end

  -- handle headers
  for _, header in ipairs(metadata.headers) do
    curl_string = curl_string .. "-H " .. tostring(header) .. " "
  end

  curl_string = curl_string .. tostring(url) .. " "

  -- handle curl data
  if data and data ~= "" then
    curl_string = curl_string .. data
  end

  return curl_string
end

return sc_common
