local input = require("input")
local device_utils = require("lua-input.device_utils")

-- This is the returned module for require("lua-input"), and
-- combines C functionality with Lua functionality.
local lua_input = {}

-- shortcut to event codes
lua_input.event_codes = require("lua-input.input_event_codes")

-- shortcut to ev_to_str
lua_input.ev_to_str = require("lua-input.ev_to_str")

-- shortcut to get_device_list
lua_input.get_devices = require("lua-input.get_devices")


-- wrap the C-functions in a table for this fd
-- All C functions require a file descriptor(either a Lua file userdata or fd number)
-- as first parameter.
-- The handler is also augmented with some Lua functions.
function lua_input.make_handler_from_fd(fd)
	local handler = {
		fd = fd,
	}

	-- wrapped function gets self.fd instead of self as first argument
	-- (The C functions all expect the first argument to be a file descriptor)
	local function wrap_fd(func)
		return function(self, ...)
			return func(self.fd, ...)
		end
	end

	-- add C functions
	handler.abs_info = wrap_fd(input.abs_info)
	handler.abs_setup = wrap_fd(input.abs_setup)
	handler.can_read = wrap_fd(input.can_read)
	handler.can_write = wrap_fd(input.can_write)
	handler.dev_destroy = wrap_fd(input.dev_destroy)
	handler.dev_setup = wrap_fd(input.dev_setup)
	handler.grab = wrap_fd(input.grab)
	handler.read_event = wrap_fd(input.read_event)
	handler.set_bit = wrap_fd(input.set_bit)
	handler.vibr_effect = wrap_fd(input.vibr_effect)
	handler.vibr_gain = wrap_fd(input.vibr_gain)
	handler.vibr_remove = wrap_fd(input.vibr_remove)
	handler.vibr_start = wrap_fd(input.vibr_start)
	handler.write_event = wrap_fd(input.write_event)

	-- add Lua functions
	for k,v in pairs(device_utils) do
		handler[k] = v
	end

	return handler
end

-- TODO: Add a function to read from multiple input devices

-- return true if f is a Lua file object
local function is_file(f)
	return (type(f) == "userdata") and (getmetatable(f) == getmetatable(io.stdin))
end

-- open the specified input device.
function lua_input.open_input(input_dev)
	if (type(input_dev) == "number") or is_file(input_dev) then
		-- Lua file or file descriptor number
		return lua_input.make_handler_from_fd(input_dev)
	elseif input_dev == "uinput" then
		-- use /dev/uinput
		return lua_input.make_handler_from_fd(input.open_rw("/dev/uinput"))
	elseif type(input_dev) == "string" then
		-- path to device
		return lua_input.make_handler_from_fd(input.open_rw(input_dev))
	elseif (type(input_dev) == "table") and input_dev.dev_handlers then
		-- device-list entry
		return lua_input.make_handler_from_fd(input.open_rw("/dev/input/"..input_dev.dev_handlers[1]))
	end
end





-- return the module with combined C and Lua functionality
return lua_input
