local input_event_codes = require("lua-input.input_event_codes")

-- this module contains extra Lua functionallity for a handler.
-- The functions in this table will be copied into every device handler table.
-- Thus, in these functions `self` will refer to the device.
local device_utils = {}

-- simple wrapper for checking using can_read() before trying to read_event
-- to emulate "non-blocking" behaviour
function device_utils:read_event_nonblocking()
	if not self:can_read() then
		return
	end
	return self:read_event()
end

-- write a start force-feedback effect event code
function device_utils:vibr_start(id, count)
	return self:write_event(
		input_event_codes.EV_FF,
		id,
		count
	)
end

-- write a set force-feedback gain event code
function device_utils:vibr_gain(gain)
	return self:write_event(
		input_event_codes.EV_FF,
		input_event_codes.FF_GAIN,
		gain
	)
end

return device_utils
