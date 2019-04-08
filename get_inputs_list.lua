local function trim(str)
   return str:match("^%s*(.-)%s*$")
end

local function get_inputs_list()
	local list_f = assert(io.open("/proc/bus/input/devices", "r"))
	local devs = {}
	local cdev = { lines = {} }
	for line in list_f:lines() do
		if line == "" then
			table.insert(devs, cdev)
			cdev = { lines = {} }
		else
			table.insert(cdev.lines, line)
			local line_type = line:sub(1,3)
			if line_type == "I: " then
				local bus, vendor, product, version = line:match("^I: Bus=(%d+) Vendor=(%d+) Product=(%d+) Version=(%d+)$")
				cdev.bus = bus
				cdev.vendor = vendor
				cdev.product = product
				cdev.version = version
			elseif line_type == "N: " then
				cdev.name = line:match("^N: Name=\"(.*)\"$")
			elseif line_type == "P: " then
				cdev.phys = line:match("^P: Phys=\"(.*)\"$")
			elseif line_type == "S: " then
				cdev.sysfs = line:match("^S: Sysfs=\"(.*)\"$")
			elseif line_type == "H: " then
				cdev.handlers = {}
				for handler in line:sub(13):gmatch("[^%s]*%s*") do
					table.insert(cdev.handlers, handler)
					if handler:match("event%d+") then
						cdev.has_dev = trim(handler)
					end
				end
			end
		end
	end
	if cdev.name then
		table.insert(devs, cdev)
	end
	return devs
end
return get_inputs_list
