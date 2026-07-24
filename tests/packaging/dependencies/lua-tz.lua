#!/usr/bin/env lua

-- Examples from the luatz repository

local luatz = require "luatz"

-- We do this a few times ==> Convert a timestamp to timetable and normalise
local function ts2tt(ts)
	return luatz.timetable.new_from_timestamp(ts)
end

-- Get the current time in UTC
local utcnow = luatz.time()
local now = ts2tt(utcnow)
print(now, "now (UTC)")

-- Get a new time object 6 months from now
local x = now:clone()
x.month = x.month + 6
x:normalise()
print(x, "6 months from now")

-- Find out what time it is in Melbourne at the moment
local melbourne = luatz.get_tz("Australia/Melbourne")
local now_in_melbourne = ts2tt(melbourne:localise(utcnow))
print(now_in_melbourne, "Melbourne")

-- Six months from now in melbourne (so month is incremented; but still the same time)
local m = now_in_melbourne:clone()
m.month = m.month + 6
m:normalise()
print(m, "6 months from now in melbourne")

-- Convert time back to utc; a daylight savings transition may have taken place!
-- There may be 2 results, but for we'll ignore the second possibility
local c, _ = melbourne:utctime(m:timestamp())
print(ts2tt(c), "6 months from now in melbourne converted to utc")


--[[
Re-implementation of `os.date` from the standard lua library
]]

local gettime = require "luatz.gettime".gettime
local new_from_timestamp = require "luatz.timetable".new_from_timestamp
local get_tz = require "luatz.tzcache".get_tz

local function os_date(format_string, timestamp)
	format_string = format_string or "%c"
	timestamp = timestamp or gettime()
	if format_string:sub(1, 1) == "!" then -- UTC
		format_string = format_string:sub(2)
	else -- Localtime
		timestamp = get_tz():localise(timestamp)
	end
	local tt = new_from_timestamp(timestamp)
	if format_string == "*t" then
		return tt
	else
		return tt:strftime(format_string)
	end
end

print(os_date())
print(os_date("%Y-%m-%d %H:%M:%S"))
print(os_date("!%Y-%m-%d %H:%M:%S", utcnow))
print(os_date("*t", utcnow + 3600 * 24 * 30))