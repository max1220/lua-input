#!/usr/bin/env lua5.1
local dev = assert(arg[1])
local input = require("lua-input")
local input_dev = assert(input.linux.new_input_source_linux(dev))

local fmt = "type(0x%.4x): %.20s  code(0x%.4x): %25s  value: %d"
while true do
	local ev = input_dev:read()
	if ev then
		local type_str,code_str = input.linux:ev_to_str(ev)
		print(fmt:format(ev.type, type_str or "?", ev.code, code_str or "?", ev.value))
	end
end
