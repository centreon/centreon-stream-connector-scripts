#!/usr/bin/lua

--- 
-- Module to handle centreon macros (e.g: $HOSTADDRESS$) and sc macros (e.g: {cache.host.address})
-- @module sc_macros
-- @alias sc_macros
local sc_macros = {}

local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_common = require("centreon-stream-connectors-lib.sc_common")

local ScMacros = {}

--- sc_macros.new: sc_macros constructor
-- @param params (table) the stream connector parameter table
-- @param logger (object) object instance from sc_logger module
-- @param common (object) object instance from sc_common module
function sc_macros.new(params, logger, common)
  local self = {}

  -- initiate mandatory libs
  self.sc_logger = logger
  if not self.sc_logger then 
    self.sc_logger = sc_logger.new()
  end

  self.sc_common = common
  if not self.sc_common then
    self.sc_common = sc_common.new(self.sc_logger)
  end

  -- initiate params
  self.params = params

  -- mapping of macro that we will convert if asked
  self.transform_macro = {
    date = function (macro_value) return self:transform_date(macro_value) end,
    type = function (macro_value) return self:transform_type(macro_value) end,
    short = function (macro_value) return self:transform_short(macro_value) end,
    state = function (macro_value, event) return self:transform_state(macro_value, event) end
  }

  -- mapping of centreon standard macros to their stream connectors counterparts
  self.centreon_macros = {
    HOSTNAME = "{cache.host.name}",
    HOSTDISPLAYNAME = "{cache.host.name}",
    HOSTALIAS = "{cache.host.alias}",
    HOSTADDRESS = "{cache.host.address}",
    HOSTSTATE = "{cache.host.state_scstate}",
    HOSTSTATEID = "{cache.host.state}",
    LASTHOSTSTATE = "{cache.host.state_scstate}",
    LASTHOSTSTATEID = "{cache.host.state}",
    HOSTSTATETYPE = "{cache.host.state_type}",
    HOSTATTEMPTS = "{cache.host.check_attempt}",
    MAXHOSTATTEMPTS = "{cache.host.max_check_attempts}",
    -- HOSTEVENTID doesn't exist 
    -- LASTHOSTEVENTID doesn't exist
    -- HOSTPROBLEMID doesn't exist
    -- LASTHOSTPROBLEMID doesn't exist
    HOSTLATENCY = "{cache.host.latency}",
    HOSTEXECUTIONTIME = "{cache.host.execution_time}",
    -- HOSTDURATION doesn't exist 
    -- HOSTDURATIONSEC doesn't exist
    HOSTDOWNTIME = "{cache.host.scheduled_downtime_depth}",
    HOSTPERCENTCHANGE = "{percent_state_change}" , -- will be replaced by the service percent_state_change if event is about a service
    -- HOSTGROUPNAME doesn't exist
    -- HOSTGROUPNAMES doesn't exist
    LASTHOSTCHECK = "{cache.host.last_check_value}",
    LASTHOSTSTATECHANGE = "{cache.host.last_state_change}",
    LASTHOSTUP = "{cache.host.last_time_up}",
    LASTHOSTDOWN = "{cache.host.last_time_down}",
    LASTHOSTUNREACHABLE = "{cache.host.last_time_unreachable}",
    HOSTOUTPUT = "{cache.host.output_scshort}",
    HOSTLONGOUTPUT = "{cache.host.output}",
    HOSTPERFDATA = "{cache.host.perfdata}",
    -- HOSTCHECKCOMMAND doesn't really exist
    -- HOSTACKAUTHORS doesn't exist
    -- HOSTACKAUTHORNAMES doesn't exist
    -- HOSTACKAUTHORALIAS doesn't exist
    -- HOSTACKAUTHORCOMMENT doesn't exist
    HOSTACTIONURL = "{cache.host.action_url}",
    HOSTNOTESURL = "{cache.host.notes_url}",
    HOSTNOTES = "{cache.host.notes}",
    -- TOTALHOSTSERVICES doesn't exist
    -- TOTALHOSTSERVICESOK doesn't exist
    -- TOTALHOSTSERVICESWARNING doesn't exist
    -- TOTALHOSTSERVICESCRITICAL doesn't exist
    -- TOTALHOSTSERVICESUNKNOWN doesn't exist
    -- HOSTGROUPALIAS doesn't exist
    -- HOSTGROUPMEMBERS doesn't exist
    -- HOSTGROUPNOTES  doesn't exist
    -- HOSTGROUPNOTESURL doesn't exist
    -- HOSTGROUPACTIONURL doesn't exist
    SERVICEDESC = "{cache.service.description}",
    SERVICEDISPLAYNAME = "{cache.service.display_name}",
    SERVICESTATE = "{cache.service.state_scstate}",
    SERVICESTATEID = "{cache.service.state}",
    LASTSERVICESTATE = "{cache.service.state_state}",
    LASTSERVICESTATEID = "{cache.service.state}",
    SERVICESTATETYPE = "{cache.service.state_type}",
    SERVICEATTEMPT = "{cache.service.check_attempt}",
    MAXSERVICEATTEMPTS = "{cache.service.max_check_attempts}",
    SERVICEISVOLATILE = "{cache.service.volatile}",
    -- SERVICEEVENTID doesn't exist
    -- LASTSERVICEEVENTID doesn't exist
    -- SERVICEPROBLEMID doesn't exist
    -- LASTSERVICEPROBLEMID doesn't exist
    SERVICELATENCY = "{cache.service.latency}",
    SERVICEEXECUTIONTIME = "{cache.service.execution_time}",
    -- SERVICEDURATION doesn't exist
    -- SERVICEDURATIONSEC doesn't exist
    SERVICEDOWNTIME = "{cache.service.scheduled_downtime_depth}",
    SERVICEPERCENTCHANGE = "{percent_state_change}",
    -- SERVICEGROUPNAME doesn't exist
    -- SERVICEGROUPNAMES doesn't exist
    LASTSERVICECHECK = "{cache.service.last_check_value}",
    LASTSERVICESTATECHANGE = "{cache.service.last_state_change}",
    LASTSERVICEOK = "{cache.service.last_time_ok}",
    LASTSERVICEWARNING = "{cache.service.last_time_warning}",
    LASTSERVICEUNKNOWN = "{cache.service.last_time_unknown}",
    LASTSERVICECRITICAL = "{cache.service.last_time_critical}",
    SERVICEOUTPUT = "{cache.service.output_scshort}",
    LONGSERVICEOUTPUT = "{cache.service.output}",
    SERVICEPERFDATA = "{cache.service.perfdata}",
    -- SERVICECHECKCOMMAND doesn't exist
    -- SERVICEACKAUTHOR doesn't exist
    -- SERVICEACKAUTHORNAME  doesn't exist
    -- SERVICEACKAUTHORALIAS doesn't exist
    -- SERVICEACKCOMMENT doesn't exist
    SERVICEACTIONURL = "{cache.service.action_url}",
    SERVICENOTESURL = "{cache.service.notes_url}",
    SERVICENOTES = "{cache.service.notes}"
    -- SERVICEGROUPALIAS  doesn't exist
    -- SERVICEGROUPMEMBERS  doesn't exist
    -- SERVICEGROUPNOTES  doesn't exist
    -- SERVICEGROUPNOTESURL doesn't exist
    -- SERVICEGROUPACTIONURL doesn't exist
    -- CONTACTNAME doesn't exist
    -- CONTACTALIAS doesn't exist
    -- CONTACTEMAIL doesn't exist
    -- CONTACTPAGER doesn't exist
    -- CONTACTADDRESS doesn't exist
    -- CONTACTGROUPALIAS  doesn't exist
    -- CONTACTGROUPMEMBERS  doesn't exist
    -- TOTALHOSTSUP  doesn't exist
    -- TOTALHOSTSDOWN  doesn't exist
    -- TOTALHOSTSUNREACHABLE  doesn't exist
    -- TOTALHOSTSDOWNUNHANDLED  doesn't exist
    -- TOTALHOSTSUNREACHABLEUNHANDLED  doesn't exist
    -- TOTALHOSTPROBLEMS  doesn't exist
    -- TOTALHOSTPROBLEMSUNHANDLED  doesn't exist
    -- TOTALSERVICESOK  doesn't exist
    -- TOTALSERVICESWARNING  doesn't exist
    -- TOTALSERVICESCRITICAL  doesn't exist
    -- TOTALSERVICESUNKNOWN  doesn't exist
    -- TOTALSERVICESWARNINGUNHANDLED  doesn't exist
    -- TOTALSERVICESCRITICALUNHANDLED  doesn't exist
    -- TOTALSERVICESUNKNOWNUNHANDLED  doesn't exist
    -- TOTALSERVICEPROBLEMS  doesn't exist
    -- TOTALSERVICEPROBLEMSUNHANDLED  doesn't exist
    -- NOTIFICATIONTYPE doesn't exist
    -- NOTIFICATIONRECIPIENTS doesn't exist
    -- NOTIFICATIONISESCALATED doesn't exist
    -- NOTIFICATIONAUTHOR doesn't exist
    -- NOTIFICATIONAUTHORNAME doesn't exist
    -- NOTIFICATIONAUTHORALIAS doesn't exist
    -- NOTIFICATIONCOMMENT doesn't exist
    -- HOSTNOTIFICATIONNUMBER doesn't exist
    -- HOSTNOTIFICATIONID doesn't exist
    -- SERVICENOTIFICATIONNUMBER doesn't exist
    -- SERVICENOTIFICATIONID doesn't exist
  }

  setmetatable(self, { __index = ScMacros })
  return self
end

--- replace_sc_macro: replace any stream connector macro with it's value
-- @param string (string) the string in which there might be some stream connector macros to replace
-- @param event (table) the current event table
-- @param json_string (boolean)  
-- @return converted_string (string) the input string but with the macro replaced with their json escaped values
function ScMacros:replace_sc_macro(string, event, json_string)
  local cache_macro_value = false
  local event_macro_value = false
  local converted_string = string

  -- find all macros for exemple the string: 
  -- {cache.host.name} is the name of host with id: {host_id} 
  -- will generate two macros {cache.host.name} and {host_id})
  for macro in string.gmatch(string, "{[%w_.]+}") do
    self.sc_logger:debug("[sc_macros:replace_sc_macro]: found a macro, name is: " .. tostring(macro))
    
    -- check if macro is in the cache
    cache_macro_value = self:get_cache_macro(macro, event)
    
    -- replace all cache macro such as {cache.host.name} with their values
    if cache_macro_value then
      self.sc_logger:debug("[sc_macros:replace_sc_macro]: macro is a cache macro. Macro name: "
        .. tostring(macro) .. ", value is: " .. tostring(cache_macro_value) .. ", trying to replace it in the string: " .. tostring(converted_string))
      
      -- if the input string was a json encoded string, we must make sure that the value we are going to insert is json ready
      if json_string then
        cache_macro_value = self.sc_common:json_escape(cache_macro_value)
      end

      converted_string = string.gsub(converted_string, macro, self.sc_common:json_escape(string.gsub(cache_macro_value, "%%", "%%%%")))
    else
      -- if not in cache, try to find a matching value in the event itself
      event_macro_value = self:get_event_macro(macro, event)
      
      -- replace all event macro such as {host_id} with their values
      if event_macro_value then
        self.sc_logger:debug("[sc_macros:replace_sc_macro]: macro is an event macro. Macro name: "
          .. tostring(macro) .. ", value is: " .. tostring(event_macro_value) .. ", trying to replace it in the string: " .. tostring(converted_string))

        -- if the input string was a json encoded string, we must make sure that the value we are going to insert is json ready
        if json_string then
          cache_macro_value = self.sc_common:json_escape(cache_macro_value)
        end
        
        converted_string = string.gsub(converted_string, macro, self.sc_common:json_escape(string.gsub(event_macro_value, "%%", "%%%%")))
      else
        self.sc_logger:error("[sc_macros:replace_sc_macro]: macro: " .. tostring(macro) .. ", is not a valid stream connector macro")
      end
    end
  end

  -- the input string was a json, we decode the result
  if json_string then
    local decoded_json, error = broker.json_decode(converted_string)

    if error then
      self.sc_logger:error("[sc_macros:replace_sc_macro]: couldn't decode json string: " .. tostring(converted_string)
        .. ". Error is: " .. tostring(error))
      return converted_string
    end

    return decoded_json
  end

  return converted_string
end

--- get_cache_macro: check if the macro is a macro which value must be found in the cache 
-- @param macro (string) the macro we want to check (for example: {cache.host.name})
-- @param event (table) the event table (obivously, cache must be in the event table if we want to find something in it)
-- @return false (boolean) if the macro is not a cache macro ({host_id} instead of {cache.xxxx.yyy} for example) or we can't find the cache type or the macro in the cache
-- @return macro_value (string|boolean|number) the value of the macro
function ScMacros:get_cache_macro(raw_macro, event)

  -- try to cut the macro in three parts
  local cache, cache_type, macro = string.match(raw_macro, "^{(cache)%.(%w+)%.(.*)}")

  -- if cache is not set, it means that the macro wasn't a cache macro
  if not cache then
    self.sc_logger:info("[sc_macros:get_cache_macro]: macro: " .. tostring(raw_macro) .. " is not a cache macro")
    return false
  end

  -- make sure that the type of cache is in the event table (for example event.cache.host must exist if the macro is {cache.host.name})
  if event.cache[cache_type] then
    -- check if it is asked to transform the macro and if so, separate the real macro from the transformation flag
    local macro_value, flag = self:get_transform_flag(macro)
    
    -- check if the macro is in the cache 
    if event.cache[cache_type][macro_value] then
      if flag then
        self.sc_logger:info("[sc_macros:get_cache_macro]: macro has a flag associated. Flag is: " .. tostring(flag)
          .. ", a macro value conversion will be done.")
        -- convert the found value according to the flag that has been sent
        return self.transform_macro[flag](event.cache[cache_type][macro_value], event)
      else
        -- just return the value if there is no conversion required
        return event.cache[cache_type][macro_value]
      end
    end
  end

  return false
end

--- get_event_macro: check if the macro is a macro which value must be found in the event table (meaning not in the cache) 
-- @param macro (string) the macro we want to check (for example: {host_id})
-- @param event (table) the event table
-- @return false (boolean) if the macro is not found in the event
-- @return macro_value (string|boolean|number) the value of the macro
function ScMacros:get_event_macro(macro, event)
  -- isolate the name of the macro
  macro = string.match(macro, "{(.*)}")

  -- check if it is asked to transform the macro and if so, separate the real macro from the transformation flag
  local macro_value, flag = self:get_transform_flag(macro)
  
  -- check if the macro is in the event
  if event[macro_value] then
    if flag then
      self.sc_logger:info("[sc_macros:get_event_macro]: macro has a flag associated. Flag is: " .. tostring(flag)
          .. ", a macro value conversion will be done. Macro value is: " .. tostring(macro_value))
      -- convert the found value according to the flag that has been sent
      return self.transform_macro[flag](event[macro_value], event)
    else
      -- just return the value if there is no conversion required
      return event[macro_value]
    end
  end

  return false
end

--- convert_centreon_macro: replace a centreon macro with its value
-- @param string (string) the string that may contain centreon macros
-- @param event (table) the event table
-- @return converted_string (string) the input string with its macros replaced with their values
function ScMacros:convert_centreon_macro(string, event)
  local centreon_macro = false
  local sc_macro_value = false
  local converted_string = string
  
  -- get all standard macros 
  for macro in string.gmatch(string, "$%w$") do
    self.sc_logger:debug("[sc_macros:convert_centreon_macro]: found a macro, name is: " .. tostring(macro))
    -- try to find the macro in the mapping table table self.centreon_macro
    centreon_macro = self:get_centreon_macro(macro)

    -- if the macro has been found, try to get its value
    if centreon_macro then
      sc_macro_value = self:replace_sc_macro(centreon_macro, event)
      
      -- if a value has been found, replace the macro with the value
      if sc_macro_value then
        self.sc_logger:debug("[sc_macros:replace_sc_macro]: macro is a centreon macro. Macro name: "
        .. tostring(macro) .. ", value is: " .. tostring(sc_macro_value) .. ", trying to replace it in the string: " .. tostring(converted_string))
        converted_string = string.gsub(converted_string, centreon_macro, sc_macro_value)
      end
    else
      self.sc_logger:error("[sc_macros:convert_centreon_macro]: macro: " .. tostring(macro) .. " is not a valid centreon macro")
    end
  end

  return converted_string
end

--- get_centreon_macro: try to find the macro in the centreon_macro mapping table
-- @param macro_name (string) the name of the macro ($HOSTNAME$ for example)
-- @return string (string) the value of the macro
-- @return false (boolean) if the macro is not in the mapping table
function ScMacros:get_centreon_macro(macro_name)
  return self.centreon_macro[string.gsub(macro_name, "%$", "")] or false
end

--- get_transform_flag: check if there is a tranformation flag linked to the macro and separate them
-- @param macro (string) the macro that needs to be checked
-- @return macro_value (string) the macro name ONLY if there is a flag 
-- @return flag (string) the flag name if there is one
-- @return macro (string) the original macro if no flag were found
function ScMacros:get_transform_flag(macro)
  -- separate macro and flag
  local macro_value, flag = string.match(macro, "(.*)_sc(%w+)$")
  
  -- if there was a flag in the macro name, return the real macro name and its flag
  if macro_value then
    return macro_value, flag
  end

  -- if no flag were found, just return the original macro
  return macro
end

--- transform_date: convert a timestamp macro into a human readable date using the format set in the timestamp_conversion_format parameter
-- @param macro_value (number) the timestamp that needs to be converted
-- @return date (string) the converted timestamp
function ScMacros:transform_date(macro_value)
  return os.date(self.params.timestamp_conversion_format, os.time(os.date("!*t", macro_value) + self.params.local_time_diff_from_utc))
end

--- transform_short: mostly used to convert the event output into a short output by keeping only the data before the new line
-- @param macro_value (string) the string that needs to be shortened
-- @return string (string) the input string with only the first lne
function ScMacros:transform_short(macro_value)
  return string.match(macro_value, "^(.*)\n")
end

--- transform_type: convert a 0, 1 value into SOFT or HARD
-- @param macro_value (number) the number that indicates a SOFT or HARD state
-- @return string (string) HARD or SOFT
function ScMacros:transform_type(macro_value)
  if macro_value == 0 then
    return "SOFT"
  else
    return "HARD"
  end
end

--- transform_state: convert the number that represent the event status with its human readable counterpart
-- @param macro_value (number) the number that represents the status of the event
-- @param event (table) the event table
-- @return string (string) the status of the event in a human readable format (e.g: OK, WARNING)
function ScMacros:transform_state(macro_value, event)
  
  -- acknowledgement events are special, the state can be for a host or a service. 
  -- We force the element to be host_status or service_status in order to properly convert the state
  if event.element == 1 and event.service_id == 0 then
    return self.params.status_mapping[event.category][event.element].host_status[macro_value]
  elseif event.element == 1 and event.service_id ~= 0 then
    return self.params.status_mapping[event.category][event.element].service_status[macro_value]
  end

  return self.params.status_mapping[event.category][event.element][macro_value]
end

return sc_macros
