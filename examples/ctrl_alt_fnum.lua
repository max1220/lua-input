#!/usr/bin/env lua5.1
local time = require("time")
local input_linux = require("lua-input").linux
local input_event_codes = input_linux.input_event_codes

-- open /dev/uinput for a new device
local input = input_linux.new_input_sink_linux()

-- enable the EV_KEY events for the device
input:set_bit("EVBIT", input_event_codes.EV_KEY)

-- enable the supported key values
input:set_bit("KEYBIT", input_event_codes.KEY_LEFTCTRL)
input:set_bit("KEYBIT", input_event_codes.KEY_LEFTALT)
for ttynum=1, 7 do
	input:set_bit("KEYBIT", input_event_codes["KEY_F"..ttynum])
end

-- setup the device parameters and create a device
input:setup("lua-input test", 0x1234, 0x5678, false)

-- wait for userland to become ready
time.sleep(d)

local function syn()
	input:write(input_event_codes.EV_SYN,input_event_codes.SYN_REPORT,0)
end

local function ctrl_alt_fnum(ttynum)
	input:write(input_event_codes.EV_KEY, input_event_codes.KEY_LEFTCTRL, 1)
	syn()
	input:write(input_event_codes.EV_KEY, input_event_codes.KEY_LEFTALT, 1)
	syn()
	input:write(input_event_codes.EV_KEY, input_event_codes["KEY_F"..ttynum], 1)
	syn()

	input:write(input_event_codes.EV_KEY, input_event_codes["KEY_F"..ttynum], 0)
	syn()
	input:write(input_event_codes.EV_KEY, input_event_codes.KEY_LEFTALT, 0)
	syn()
	input:write(input_event_codes.EV_KEY, input_event_codes.KEY_LEFTCTRL, 0)
	syn()
end

local d = 0.2

ctrl_alt_fnum(1)
time.sleep(d)
ctrl_alt_fnum(2)
time.sleep(d)
ctrl_alt_fnum(3)
time.sleep(d)
ctrl_alt_fnum(4)
time.sleep(d)
ctrl_alt_fnum(5)
time.sleep(d)
ctrl_alt_fnum(6)
time.sleep(d)
ctrl_alt_fnum(7)
time.sleep(d)


-- detroy input
input:close()
