#!/usr/bin/lua

--- 
-- Test module to help check modules reliability
-- @module sc_test
-- @alias sc_test

local sc_test = {}

function sc_test.compare_result(expected, result)
  local state = ''
  if expected == result then
    state = '\27[32mOK\27[0m'
  else 
    state = '\27[31mNOK\27[0m'
  end
    
  return "[EXPECTED] " .. tostring(expected) .. " [RESULT] " .. tostring(result) .. ' ' .. state
end

function sc_test.compare_tables(expected, result)
  for i, v in pairs(expected) do
    if v ~= result[i] then
      return 'tables are not equal \27[31mNOK\27[0m'
    end
  end 

  return 'tables are equal \27[32mOK\27[0m'
end

return sc_test