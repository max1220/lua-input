#!/usr/bin/env lua5.1
local input = require("lua-input")
local time = require("time")
local codes = input.linux.input_event_codes

local vibr_dev = assert(input.linux.new_input_source_linux(arg[1], true, true), "Can't open!")

local effect_id = assert(vibr_dev:vibr_effect(10000, 1000, 100), "Can't upload effect!")

for i=1, 10 do
	assert(vibr_dev:vibr_start(effect_id, 10), "Can't start effect")
	time.sleep(0.5)
end

assert(vibr_dev:vibr_remove(effect_id), "Can't remove")
