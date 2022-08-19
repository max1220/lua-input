local input_event_codes = require("lua-input.input_event_codes")

-- This file exports a single function, `ev_to_str`.
-- This function takes an event type and code and converts it
-- to an event name string.

-- prepare lookup of event names in ev_to_str()
local ev_types = {
	[input_event_codes.EV_KEY] = "KEY",
	[input_event_codes.EV_ABS] = "ABS",
	[input_event_codes.EV_REL] = "REL",
	[input_event_codes.EV_MSC] = "MSC",
	[input_event_codes.EV_SYN] = "SYN",
}
local ev_codes = {}
for k,v in pairs(ev_types) do
	local codes = {}
	for ke,va in pairs(input_event_codes) do
		if ke:match("^"..v.."_") then
			codes[va] = ke
		end
	end
	ev_codes[k] = codes
end

-- convert the event type and code numbers to a human-readable strings(best-guess)
local function ev_to_str(type, code)
	if not ev_types[type] then
		return
	end
	local type_str = "EV_"..ev_types[type]
	if not code then
		return type_str
	end
	return type_str, ev_codes[type][code]
end

-- the module returns a single function
return ev_to_str
