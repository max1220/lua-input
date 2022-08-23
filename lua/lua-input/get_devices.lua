local input_event_codes = require("lua-input.input_event_codes")

-- return str without leading/trailing whitespace
local function trim(str)
   return str:match("^%s*(.-)%s*$")
end

-- this function checks if the n'th bit is set in a string of
-- hexadecimal digits.
-- (without requiring a bit library, and for arbitrarily long hex_str)
local function has_bit_set(hex_str, nthbit)
	-- determine the position of the byte in the string
	local nibble_position = #hex_str - math.floor(nthbit/4)

	-- get the nibble that contains the bit
	local nibble_value = tonumber(hex_str:sub(nibble_position,nibble_position), 16)
	if not nibble_value then
		return false
	end

	-- check if the bit at bit_position in the nibble_value is set
	local bit_position = nthbit%4
	for i=3,0,-1 do -- iterate over all bits in nibble, "msb to lsb"
		local m = 2^i -- get the bit mask
		if i == bit_position then -- if currently checking the bit_position bit, ...
			return nibble_value-m >= 0 -- ... return boolean if the bit is set, ...
		elseif nibble_value-m>=0 then -- ... otherwise if current bit is set, ...
			nibble_value = nibble_value-m -- ... subtract the current bit.
		end
	end
end

-- parse the capability values from cap_name
-- by looking up flags in the hex_str.
local function parse_capability(cap_name, hex_str)
	cap_name = cap_name:upper()
	local prefix = cap_name.."_"
	if cap_name == "PROP" then
		prefix = "INPUT_PROP_"
	end
	local capability = {}
	local max_i = input_event_codes[prefix.."MAX"]
	for name,code in pairs(input_event_codes) do
		-- some of the EV_KEY codes are prefixed by BTN_* instead of KEY_*
		local is_btn = (cap_name == "KEY") and name:match("^BTN_")
		if code<max_i and (name:match("^"..prefix) or is_btn) then
			-- add a boolean for every matching event type
			capability[name] = has_bit_set(hex_str, code)
		end
	end
	return capability
end

-- parse the specified capability by it's name from the space-separated,
-- hex-endoded longs_str.
local function parse_capability_longs(cap_name, longs_str)
	local longs = {}

	-- iterate over space-separated hex strings
	for long_str in longs_str:gmatch("(%x+)") do
		-- fix length of each sub-string to 16(fill leading 0's)
		long_str = ("%16s"):format(long_str):gsub(" ", "0")
		table.insert(longs, long_str)
	end

	-- concatenate all long values into a single string
	local hex_str = table.concat(longs)

	-- parse the capability
	return parse_capability(cap_name, hex_str)
end

-- parse the "Handlers=" line into a device
local function parse_handlers(dev, line)
	for handler in line:sub(13):gmatch("[^%s]*%s*") do
		handler = trim(handler)
		if #handler > 0 then
			table.insert(dev.handlers, handler)
		end
	end
end

-- parse a single line from /proc/bus/input/devices for a specific device
local function parse_line(dev, line)
	table.insert(dev.lines, line)
	local line_type = line:sub(1,3)
	if line_type == "I: " then
		local bus, vendor, product, version = line:match("^I: Bus=(%x+) Vendor=(%x+) Product=(%x+) Version=(%x+)$")
		dev.bus = assert(tonumber(bus, 16))
		dev.vendor = assert(tonumber(vendor, 16))
		dev.product = assert(tonumber(product, 16))
		dev.version = assert(tonumber(version, 16))
	elseif line_type == "N: " then
		dev.name = assert(line:match("^N: Name=\"(.*)\"$"))
	elseif line_type == "P: " then
		dev.phys = assert(line:match("^P: Phys=(.*)$"))
	elseif line_type == "S: " then
		dev.sysfs = assert(line:match("^S: Sysfs=(.*)$"))
	elseif line_type == "U: " then
		dev.sysfs = assert(line:match("^U: Uniq=(.*)$"))
	elseif line_type == "H: " then
		parse_handlers(dev, line)
	elseif line_type == "B: " then
		local cap_name, longs_str = line:match("^B: (.*)=(.*)$")
		dev.capabilities[cap_name] = parse_capability_longs(cap_name, longs_str)
	else
		-- Unknown line type
		return false
	end

	-- successfully parsed line
	return true
end

-- get a Lua table of the attached input devices
-- (parsed information from /proc/bus/input/devices)
local function get_devices_list()
	local list_f = assert(io.open("/proc/bus/input/devices", "r"))
	local devs = {}
	local cdev
	for line in list_f:lines() do
		-- prepare for a new device on empty line or first device
		if (line == "") or not cdev then
			-- save current device to list of finished devices
			if cdev then
				table.insert(devs, cdev)
			end

			-- create new device
			cdev = {
				-- list of parsed lines from /proc/bus/input/devices
				lines = {},

				-- table of capabilities by name(e.g. capabilities.key.KEY_UP)
				capabilities = {},

				-- list of handlers
				handlers = {}
			}
		end

		-- current line contains some data
		if line ~= "" then
			parse_line(cdev, line)
		end
	end
	if cdev.name then
		table.insert(devs, cdev)
	end
	return devs
end

-- the module exports a single function
return get_devices_list
