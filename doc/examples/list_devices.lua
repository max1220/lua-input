#!/usr/bin/env lua
local input = require("lua-input")

-- get list of devices and info
local devices = input.get_devices_list()

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
end
