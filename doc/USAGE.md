# Basic library usage

The library is split into two parts:
A C library that performs `ioctl()`'s, `read()`'s, and `writes()`'s relating
to the Linux input/uinput subsystem.

The C functions all require a file descriptor as first parameter,
and accept either a Lua file userdata(such as returned by io.open()),
or a plain file descriptor number.

The Lua library wraps these C functions for a specified file for easy access,
and provides some utillity functions.



## Reading events from a device

```
local input = require("lua-input")

-- read events from a device
local input_dev = input.open_input("/dev/input/event0")
while true do
	local ev = input_dev:read_event()
end
```



## Creating a device and writing events

```
-- create a new device and some events
local uinput_dev = input.open_input("uinput")

-- enable some event-bits
uinput_dev:set_bit("EVBIT", input.event_codes.EV_KEY)
uinput_dev:set_bit("KEYBIT", input.event_codes.KEY_H)
uinput_dev:set_bit("KEYBIT", input.event_codes.KEY_I)

-- write some events
uinput_dev:write_event(input.event_codes.EV_KEY, input.event_codes.KEY_H, 1)
uinput_dev:write_event(input.event_codes.EV_KEY, input.event_codes.KEY_H, 0)
os.execute("sleep 1")
uinput_dev:write_event(input.event_codes.EV_KEY, input.event_codes.KEY_I, 1)
uinput_dev:write_event(input.event_codes.EV_KEY, input.event_codes.KEY_I, 0)
```





# API reference

In the reference below `input` refers to the loaded lua-input module,
as returned with `input = require("lua-input")`.

`device` refers to a table created by `input.make_handler_from_fd`, and
returned by `input.make_handler_from_fd` and `input.open_input` that wraps
a single file descriptor(`device.fd`) with the input-related functions.

Some knowledge about the Linux input/uinput subsystem is assumed,
for example event codes, etc.



## input.event_codes

This is a Lua table version of the C header file `include/uapi/linux/input-event-codes.h`,
which defines the event codes.
The index is a the event code name(e.g. "EV_KEY"), and the value is the
numeric value, as specified by the header(e.g. 0x01).



## list = input.get_devices()

Get a list of known input devices.
This is a Lua table version of `/proc/bus/input/devices`.

Each entry in the list might have some of the following fields:

 * bus(number)
 * vendor(number)
 * product(number)
 * version(number)
 * name(string)
 * phys(string)
 * sysfs(string)
 * handlers(table)
 * capabillities(table)

The capabillities table is first indexed by the lower-case capabillity
name, then by the event code. This value is parsed from the bitfields
in `/proc/bus/input/devices`(`B: ` lines), e.g:
```
assert(dev.capabillities.key["EV_A"]) -- Check that the A keycode is supported on the device
```

For the meaning of each field, see the Linux input/uinput documentation.



## type_str, code_str = input.ev_to_str(type, code)

Return a human-readable version of the type and code.



## device = input.open_input(dev)

Open the specified device.

`dev` can be one of:

 * number(treated as fd): Pre-opened file descriptor
 * string "uinput": Open /dev/uinput for creating new input devices
 * string(treated as path): Path to an input device(e.g. "/dev/input/event2")
 * table: Use a table returned by input.get_devices_list()



## device = input.make_handler_from_fd()

This is an internal function that creates a device table for the
specified file descriptor(input.open_input is a wrapper for this function).



## device

The device returned by input.open_input() contains the functions to
interact with the Linux input/uinput subsysten via a file descriptor.

This is the list of functions and constants in the device table:

###
