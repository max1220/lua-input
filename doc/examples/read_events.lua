#!/usr/bin/env lua
local input = require("lua-input")

-- open the specified device
local dev = assert(arg[1], "First command-line argument must be a device!")
local input_dev = assert(input.open_input(dev), "Can't open input device!")

-- the output format string for events
local fmt_str = arg[2] or "type({{type_hex}})={{type_str_align}} code({{code_hex}})={{code_str_align}} value={{value_align}} time={{time}}"

-- print a single event by expanding the fmt_str
local function print_ev(type, code, value, time)
	-- look up human-readable names for type and code
	local type_str,code_str = input.ev_to_str(type, code)

	-- possible substitutions in fmt
	local lookup = {
		type = tostring(type),
		type_hex = ("%.4x"):format(type),
		type_str = type_str or "?",
		type_str_align = ("%6s"):format(type_str or "?"),
		code = tostring(code),
		code_hex = ("%.4x"):format(code),
		code_str = code_str or "?",
		code_str_align = ("%-20s"):format(code_str or "?"),
		value = tostring(value),
		value_align = ("%6s"):format(tostring(value)),
		time = tostring(time),
	}

	-- substitute the format strings to get the final print_str
	local print_str = fmt_str:gsub("{{(.-)}}", function(s)
		return lookup[s]
	end)

	-- output the finished string
	print(print_str)
end

-- read events and print details
while true do
	print_ev(input_dev:read_event())
end
