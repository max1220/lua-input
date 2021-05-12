#!/usr/bin/env lua5.1
local input = require("lua-input")
local devices = input.linux.get_devices_list()
for i,device in pairs(devices) do
	print("Device:",i,device)
	for _,k in pairs({"has_dev", "bus", "name", "version", "vendor", "product"}) do
		print("",k,device[k])
	end
	print("\tHandlers:")
	for k,v in pairs(device.handlers) do
		print("\t\t",k,v)
	end
	print("\n")
end
