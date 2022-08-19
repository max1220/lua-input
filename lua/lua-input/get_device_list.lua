-- return str without leading/trailing whitespace
local function trim(str)
   return str:match("^%s*(.-)%s*$")
end

-- get a Lua table of the attached input devices
-- (parsed information from /proc/bus/input/devices)
local function get_devices_list()
	local list_f = assert(io.open("/proc/bus/input/devices", "r"))
	local devs = {}
	local cdev = { lines = {} }
	for line in list_f:lines() do
		if line == "" then
			table.insert(devs, cdev)
			cdev = {
				lines = {},
				open = lua_input.open_input
			}
		else
			table.insert(cdev.lines, line)
			local line_type = line:sub(1,3)
			if line_type == "I: " then
				local bus, vendor, product, version = line:match("^I: Bus=(%x+) Vendor=(%x+) Product=(%x+) Version=(%x+)$")
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
				for handler in line:sub(13):gmatch("[^%s]*%s*") do
					handler = trim(handler)
					if #handler > 0 then
						cdev.handlers = cdev.handlers or {}
						table.insert(cdev.handlers, handler)
					end
					if handler:match("event%d+") then
						cdev.dev_handlers = cdev.dev_handlers or {}
						table.insert(cdev.dev_handlers, handler)
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

-- the module exports a single function
return get_devices_list
