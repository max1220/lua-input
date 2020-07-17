-- load the C module(returns a table)
local input_linux = require("input_linux")

-- load list of constants
input_linux.input_event_codes = require("lua-input.input-event-codes")

local function trim(str)
   return str:match("^%s*(.-)%s*$")
end

function input_linux:get_devices_list()
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

function input_linux:list_by_pattern_value(pattern, value)
	-- get an event code by matching the name and the value
	for k,v in pairs(self.input_event_codes) do
		if k:match(pattern) and v == value then
			return k,v
		end
	end
end

function input_linux:ev_to_str(ev)
	-- get a best-guess for the event type string and code string
	local type = self:list_by_pattern_value("^EV_", ev.type)
	local code
	if type == "EV_KEY" then
		code = self:list_by_pattern_value("^KEY_", ev.code) or self:list_by_pattern_value("^BTN_", ev.code)
	elseif type == "EV_ABS" then
		code = self:list_by_pattern_value("^ABS_", ev.code)
	elseif type == "EV_REL" then
		code = self:list_by_pattern_value("^REL_", ev.code)
	elseif type == "EV_MSC" then
		code = self:list_by_pattern_value("^MSC_", ev.code)
	elseif type == "EV_SYN" then
		code = self:list_by_pattern_value("^SYN_", ev.code)
	end
	return type,code
end

return input_linux
