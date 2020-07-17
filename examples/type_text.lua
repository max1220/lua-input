#!/usr/bin/env lua5.1
local time = require("time")
local input_linux = require("lua-input").linux
local input_event_codes = input_linux.input_event_codes


-- get a list of characters and associated key values
local text_keys = {}
for keyname,keyvalue in pairs(input_event_codes) do
	local key = keyname:match("^KEY_(%a)$")
	if key then
		text_keys[key] = keyvalue
		text_keys[key:lower()] = keyvalue
	end
end
text_keys[" "] = input_event_codes.KEY_SPACE


local function type_text(str, input, sleep)
	local function syn()
		input:write(input_event_codes.EV_SYN,input_event_codes.SYN_REPORT,0)
	end
	for i=1, #str do
		local char = str:sub(i,i)
		local key = text_keys[char]

		local shift = char:upper()==char
		if shift then
			input:write(input_event_codes.EV_KEY, input_event_codes.KEY_LEFTSHIFT, 1) -- key down
			syn()
		end
		input:write(input_event_codes.EV_KEY, key, 1) -- key down
		syn()
		if sleep then
			sleep() -- call sleep callback
		end
		input:write(input_event_codes.EV_KEY, key, 0) -- key up
		syn()
		if shift then
			input:write(input_event_codes.EV_KEY, input_event_codes.KEY_LEFTSHIFT, 0) -- key up
			syn()
		end
	end
end

-- open /dev/uinput for a new device
local input = input_linux.new_input_sink_linux()

-- enable the EV_KEY events for the device
input:set_bit("EVBIT", input_event_codes.EV_KEY)

-- enable the supported key values
for _,value in pairs(text_keys) do
	input:set_bit("KEYBIT", value)
end
input:set_bit("KEYBIT", input_event_codes.KEY_LEFTSHIFT)

-- setup the device parameters and create a device
input:setup("lua-input test", 0x1234, 0x5678, false)

-- wait for userland to become ready
time.sleep(1)

-- type a string of text by pressing the corresponding keys
type_text("Hello from Lua Input", input)

-- detroy input
input:close()
