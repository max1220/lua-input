#!/usr/bin/env lua
local input = require("lua-input")

-- get list of devices and info
local devices = input.get_devices()

-- parse -v/--verbose command line argument
local verbose = (arg[1]=="-v") or (arg[1]=="--verbose")

-- show list
for i,device in pairs(devices) do
	print("Device:",i)
	for _,k in ipairs({"name", "has_dev", "bus", "vendor", "product", "version"}) do
		print("",k,device[k])
	end
	print("","Handlers:")
	for k,v in pairs(device.handlers) do
		print("","",k,v)
	end
	print("","Capabilities:")
	for cap_type,caps in pairs(device.capabilities) do
		print("","","cap_type:", cap_type)
		if verbose then
			local cap_names = {}
			for cap_name, enabled in pairs(caps) do
				if enabled then
					table.insert(cap_names, "\t\t\t"..cap_name)
				end
			end
			table.sort(cap_names)
			print(table.concat(cap_names, "\n"))
		end
	end
end
