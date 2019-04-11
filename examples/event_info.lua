#!/usr/bin/env luajit
local input = require("lua-input")
local input_event_codes = input.event_codes

local max_evs = tonumber(arg[1])

function list_by_pattern_value(pattern, value)
  for k,v in pairs(input_event_codes) do
    if k:match(pattern) and v == value then
      return k,v
    end
  end
end

local list = input.list()


print("Listing aviable input devices...")
for i,dev in pairs(list) do
	if dev.has_dev then
		print("Device",i,dev.name)
	end
end
print("Ok!\n")


print("Obtaining handle for all input devices...")
local devices = {}
for i,dev in pairs(list) do
	if dev.has_dev then
		local path = "/dev/input/" .. dev.has_dev
		print("path", path)
		dev.dev = assert(input.open(path, true))
		table.insert(devices, dev)
	end
end
print("Ok!\n")


print("Entering event loop... (^C to quit)")
local evs = 0
local run = true
while run do
	for i,dev in ipairs(devices) do
		local ev = dev.dev:read()
		if ev then
			evs = evs + 1
			if max_evs and evs > max_evs then
				run = false
			end
			local type = list_by_pattern_value("^EV_", ev.type) or ""
			local code
			if type == "EV_KEY" then
				code = list_by_pattern_value("^KEY_", ev.code) or list_by_pattern_value("^BTN_", ev.code)
			elseif type == "EV_ABS" then
				code = list_by_pattern_value("^ABS_", ev.code)
			elseif type == "EV_REL" then
				code = list_by_pattern_value("^REL_", ev.code)
			end
			code = code or ""
			print(("Got event from %q: time=%d, utime=%06d, type=%12s(0x%03X), code=%18s(0x%03X), value=0x%016X"):format(dev.name, ev.time, ev.utime, type, ev.type, code, ev.code, ev.value))
		end
	end
end

print("terminated! cleaning up...")
for i, dev in ipairs(devices) do
	dev.dev:close()
end
print("bye!")
