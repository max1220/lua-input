#!/usr/bin/env lua5.1
local dev = assert(arg[1], "First command-line argument must be a device!")
local duration = math.abs(assert(tonumber(arg[2])))
local input = require("lua-input")
local time = require("time")
local input_dev = assert(input.linux.new_input_source_linux(dev))

local fmt = "type(0x%.4x): %.20s  code(0x%.4x): %25s  value: %d"

local stop = time.monotonic()+duration
input_dev:grab(1)
while time.monotonic()<stop do
	local ev = input_dev:read()
	if ev then
		local type_str,code_str = input.linux:ev_to_str(ev)
		print(fmt:format(ev.type, type_str or "?", ev.code, code_str or "?", ev.value))
	end
end
input_dev:grab(0)
