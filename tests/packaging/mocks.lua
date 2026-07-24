-- Mock the broker globals injected at runtime by Centreon Broker
broker_log = {
  set_parameters = function() end,
  error = function() end,
  warning = function() end,
  info = function() end,
}
broker = {
  bbdo_version = function() return "3.0.0" end,
  json_encode = function() return "{}" end,
  json_decode = function() return {} end,
  parse_perfdata = function() return {}, nil end,
}
-- flexible mock: any method call returns nil without crashing
broker_cache = setmetatable({}, {__index = function() return function() return nil end end})
