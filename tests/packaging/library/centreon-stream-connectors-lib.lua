#!/usr/bin/env lua

dofile("tests/packaging/mocks.lua")

local ok = true
local function assert_eq(label, expected, result)
  if expected == result then
    print("✓ " .. label)
  else
    print("✗ " .. label .. " (expected=" .. tostring(expected) .. " got=" .. tostring(result) .. ")")
    ok = false
  end
end

local function find_lib_path()
  for _, version in ipairs({"5.3", "5.4"}) do
    local path = "/usr/share/lua/" .. version
    local f = io.open(path .. "/centreon-stream-connectors-lib/sc_common.lua", "r")
    if f then
      f:close()
      return path
    end
  end
end

local lib_path = find_lib_path()
if not lib_path then
  print("ERROR: centreon-stream-connectors-lib not found in /usr/share/lua/5.3 or /usr/share/lua/5.4")
  os.exit(1)
end
print("Library found at: " .. lib_path)

-- sc_logger
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local logger = sc_logger.new("/tmp/test-packaging.log", 3)
print("✓ sc_logger: loaded and instantiated")

-- sc_common
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local common = sc_common.new(logger)
print("✓ sc_common: loaded and instantiated")
assert_eq("sc_common:ifnil_or_empty(nil)   → alt",    "alt",  common:ifnil_or_empty(nil, "alt"))
assert_eq("sc_common:ifnil_or_empty(\"\")  → alt",    "alt",  common:ifnil_or_empty("", "alt"))
assert_eq("sc_common:ifnil_or_empty(value) → value",  "kept", common:ifnil_or_empty("kept", "alt"))
assert_eq("sc_common:if_wrong_type(ok)     → value",  42,     common:if_wrong_type(42, "number", 0))
assert_eq("sc_common:if_wrong_type(bad)    → default", 0,     common:if_wrong_type("str", "number", 0))
assert_eq("sc_common:boolean_to_number(true)  → 1",   1,      common:boolean_to_number(true))
assert_eq("sc_common:boolean_to_number(false) → 0",   0,      common:boolean_to_number(false))
assert_eq("sc_common:split result[1]",                "a",    common:split("a,b,c", ",")[1])
assert_eq("sc_common:split result[3]",                "c",    common:split("a,b,c", ",")[3])
assert_eq("sc_common:compare_numbers(<)",             true,   common:compare_numbers(1, 2, "<"))
assert_eq("sc_common:compare_numbers(>)",             false,  common:compare_numbers(1, 2, ">"))

-- sc_broker
local sc_broker = require("centreon-stream-connectors-lib.sc_broker")
local broker_obj = sc_broker.new(logger)
print("✓ sc_broker: loaded and instantiated")
assert_eq("sc_broker:get_host_all_infos(nil) → false", false, broker_obj:get_host_all_infos(nil))

-- sc_params
local sc_params = require("centreon-stream-connectors-lib.sc_params")
local params = sc_params.new(common, logger)
print("✓ sc_params: loaded and instantiated")
assert_eq("sc_params:is_mandatory_config_set(set)   → true",  true,  params:is_mandatory_config_set({"key"}, {key = "value"}))
assert_eq("sc_params:is_mandatory_config_set(unset) → false", false, params:is_mandatory_config_set({"key"}, {}))
params:build_accepted_elements_info()

-- sc_macros
local sc_macros = require("centreon-stream-connectors-lib.sc_macros")
local macros = sc_macros.new(params.params, logger, common)
print("✓ sc_macros: loaded and instantiated")
assert_eq("sc_macros:transform_short(multiline) → first line", "line1", macros:transform_short("line1\nline2"))
assert_eq("sc_macros:transform_type(0) → SOFT",                "SOFT",  macros:transform_type(0))
assert_eq("sc_macros:transform_type(1) → HARD",                "HARD",  macros:transform_type(1))
assert_eq("sc_macros:transform_number(\"42\") → 42",           42,      macros:transform_number("42"))
assert_eq("sc_macros:transform_string(3.14) → \"3.14\"",       "3.14",  macros:transform_string(3.14))

-- sc_flush
local sc_flush = require("centreon-stream-connectors-lib.sc_flush")
local flush = sc_flush.new(params.params, logger)
print("✓ sc_flush: loaded and instantiated")
assert_eq("sc_flush:get_queues_size() → 0", 0, flush:get_queues_size())

-- sc_storage
local sc_storage = require("centreon-stream-connectors-lib.sc_storage")
local storage = sc_storage.new(common, logger, params.params)
print("✓ sc_storage: loaded and instantiated")
assert_eq("sc_storage:is_valid_storage_object(host_1)  → true",  true,  storage:is_valid_storage_object("host_1"))
assert_eq("sc_storage:is_valid_storage_object(invalid) → false", false, storage:is_valid_storage_object("invalid"))

-- sc_event
local sc_event = require("centreon-stream-connectors-lib.sc_event")
local event = sc_event.new({}, params.params, common, logger, broker_obj, storage)
print("✓ sc_event: loaded and instantiated")
assert_eq("sc_event:find_in_mapping(match)    → true",  true,  event:find_in_mapping({neb = 1}, "neb", 1))
assert_eq("sc_event:find_in_mapping(no match) → false", false, event:find_in_mapping({neb = 1}, "storage", 1))

-- sc_test
local sc_test = require("centreon-stream-connectors-lib.sc_test")
print("✓ sc_test: loaded")
assert_eq("sc_test:compare_result(match)    contains OK",  true, string.find(sc_test.compare_result("x", "x"), "OK")  ~= nil)
assert_eq("sc_test:compare_result(no match) contains NOK", true, string.find(sc_test.compare_result("x", "y"), "NOK") ~= nil)

if not ok then
  os.exit(1)
end
print("\nAll tests passed!")
