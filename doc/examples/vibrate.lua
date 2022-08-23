#!/usr/bin/env lua5.1
local input = require("lua-input")

-- function to sleep for specified amount of seconds
local sleep = require("time").sleep

-- open the specified device(must support force-feedback effects)
local dev = assert(arg[1], "First command-line argument must be a device!")
local vibr_dev = assert(input.open_input(dev), "Can't open input device!")

-- upload a force-feedback effect to the device
local effect_id = assert(vibr_dev:vibr_effect(10000, 1000, 100), "Can't upload effect!")

-- start the pattern every 0.5 seconds for 5 seconds
for _=1, 10 do
	assert(vibr_dev:vibr_start(effect_id, 10), "Can't start effect")
	sleep(0.5)
end

-- remove the effect
assert(vibr_dev:vibr_remove(effect_id), "Can't remove")

vibr_dev:close()
