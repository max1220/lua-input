# lua-input

Library for using the Linux input/uinput subsystem to read input events
or create input devices and events.

This allows reading keyboard/mouse/touchscreen events,
and emulating input devices for all other applications on the system.

Compatible with Lua5.1, LuaJIT, Lua5.2, Lua5.3, Lua5.4.





# Installation

See [doc/INSTALLATION.md](doc/INSTALLATION.md)

This library is packaged and build using Luarocks, which makes building
and installing easy.

```
git clone https://github.com/max1220/lua-input
cd lua-input
# install locally, usually to ~/.luarocks
luarocks make --local
```

When installing locally you need to tell Lua where to look for modules
installed using Luarocks, e.g.:

```
luarocks path >> ~/.bashrc
```

You can also install the library manually, see documentation.





## Library usage

Full usage see [doc/USAGE.md](doc/USAGE.md)

### Reading events from a device

```
local input = require("lua-input")

-- read events from a device
local input_dev = input.open_input("/dev/input/event0")
while true do
	local ev = input_dev:read_event()
	print("event",ev.type, ev.code, ev.value)
end
```
