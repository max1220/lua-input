#!/usr/bin/env lua5.1
local input = require("lua-input")

-- function to sleep for specified amount of seconds
local sleep = require("time").sleep


-- get a list of characters and associated key values
local text_keys = {}
text_keys[" "] = input.event_codes.KEY_SPACE -- add space key
text_keys["shift"] = input.event_codes.KEY_LEFTSHIFT -- add shift key
for keyname,keyvalue in pairs(input.event_codes) do
	local key = keyname:match("^KEY_(%a)$")
	if key then
		text_keys[key] = keyvalue
		text_keys[key:lower()] = keyvalue
	end
end


-- enable the needed event bits
local function set_bits(device)
	-- enable the EV_KEY events for the device
	device:set_bit("EVBIT", input.event_codes.EV_KEY)

	-- enable the supported key values
	for _,value in pairs(text_keys) do
		input:set_bit("KEYBIT", value)
	end
end

-- write a single key down/key up event to the device based on the character(upper-case)
local function write_event_from_character(device, char, down)
	local key = text_keys[char]
	device:write_event(input.event_codes.EV_KEY, key, down and 1 or 0)
	device:write_event(input.event_codes.EV_SYN,input.event_codes.SYN_REPORT,0)
end

-- convert a single character to a series of key down/key up events,
-- delay the key_up event delay seconds.
local function write_character(device, char, delay)
	local char_upper = char:upper()
	local need_shift = char_upper==char

	if need_shift then
		-- write shift down
		write_event_from_character(device, "shift", true)
	end

	-- write key down
	write_event_from_character(device, char_upper, true)

	sleep(delay)

	-- write key up
	write_event_from_character(device, char_upper, false)

	if need_shift then
		-- write shift up
		write_event_from_character(device, "shift", false)
	end
end

-- type the string on the device, using key down and up events
local function type_text(device, str, delay)
	for i=1, #str do
		write_character(device, str:sub(i,i), delay)
	end
end

-- open /dev/uinput to create a new input device
local input_device = input.open_input("uinput")

-- setup the device parameters and create a device
input_device:dev_setup("lua-input test", 0x1234, 0x5678, false)

-- register the needed event codes
set_bits(input_device)

-- wait for userland to become ready
sleep(1)

-- type a string of text by pressing the corresponding keys
local text = arg[1] or "Hello from lua-input"
type_text(input_device, text, 0.1)

-- wait for userland to handle all outstanding events
sleep(1)

-- detroy input
input:close()
