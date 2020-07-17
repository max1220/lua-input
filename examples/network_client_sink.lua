#!/usr/bin/env lua5.1
-- this client established a connection to a server to receive input events from
-- the server and relay them to an input sink(created virtual input device).

local input_linux = require("lua-input").linux
local socket = require("socket")
math.randomseed(os.time())

local client = {}

function client:log(...)
	print(os.date(), ...)
end

function client:init(host, port, id)
	self.host = assert(host)
	self.port = assert(tonumber(port))
	local rand_id = "sink_client_"..string.char(math.random(65,90),math.random(65,90),math.random(65,90),math.random(65,90),math.random(65,90))
	self.id = id or rand_id
end

function client:step()
	if not self.con then
		self:log("Establishing connection")
		local con, err = socket.tcp()
		if not con then
			self:log("Can't create tcp socket: " .. tostring(err))
			return
		end
		self.con = con
		local ok,_err = self.con:connect(self.host, self.port)
		if not ok then
			self:log("Can't connect: " .. tostring(_err))
			return
		end
		self.con:settimeout(0)
	end

	-- get commans from server
	local data, status = self.con:receive("*l")
	if status=="timeout" then
		-- timeout
		self:log("receive timed out!")
		return
	elseif not data then
		-- closed?
		self:log("No data: " .. tostring(status))
		self.con:close()
		self.con = nil
		return
	end

	local command, args_str = data:match("^(%S+)%s?(.*)$")
	local args = {}
	for arg in (args_str or ""):gmatch("(%S+)") do
		table.insert(args, arg)
	end

	if command == "ID" then
		self:log("Server requested client id")
		local ok, err = self.con:send("CLIENT_ID " .. self.id.."\n")
		if not ok then
			self:log("send failed: " .. tostring(err))
			return
		end
	elseif (command == "CREATE") and (not self.dev) then
		self:log("Server sent init")
		local dev = input_linux.new_input_sink_linux()
		if not dev then
			self:log("new_input_sink_linux failed!")
			return
		end
		self.dev = dev
	elseif (command == "BIT") and self.dev then
		-- set a device configuration bit
		local field, bit = tostring(args[1]), tostring(args[2])
		self:log("Setting bit " .. bit .. " in field " .. field)
		local ok = self.dev:set_bit(field, input_linux.input_event_codes[bit])
		if not ok then
			self:log("set_bit failed!")
			return
		end
	elseif (command == "SETUP") and self.dev then
		-- perform the device setup
		self:log("Setting up device")
		local ok = self.dev:setup("lua-input network client", 0x1234, 0x5678)
		if not ok then
			self:log("setup failed!")
			return
		end
	elseif (command == "CLOSE") and self.dev then
		-- destroy the device
		self:log("Closing device")
		self.dev:close()
		self.dev = nil
		return
	elseif (command == "EVENT") and self.dev then
		-- trigger an event
		local type_str, code_str, value_str = tostring(args[1]), tostring(args[2]), tostring(args[3])
		local type = input_linux.input_event_codes[type_str] or tonumber(type_str)
		if not type then
			self:log("Unknown event type: " .. tostring(type_str))
			return
		end
		local code = input_linux.input_event_codes[code_str] or tonumber(code_str)
		if not code then
			self:log("Unknown event code: " .. tostring(code_str))
			return
		end
		local value = tonumber(value_str)
		if value_str:sub(1,2) == "0x" then
			value = tonumber(value_str:sub(3))
		end
		if not value then
			self:log("Invalid event value: " .. tostring(value_str))
			return
		end
		self:log("Sending event: type=%s, code=%s, value=%d", type_str, code_str, value)
		self.dev:write(type, code, value)
	else
		self:log("Got unknown command from server:"..tostring(command or data))
		return
	end

	-- no errors
	return true
end

function client:run_debug()
	-- run till first error
	while self:step() do
	end
end

function client:run()
	-- run till disconnect/timeout
	while self.con do
		self:step()
	end
end

function client:run_loop()
	-- run till stopped(auto reconnect)
	while true do
		self:step()
	end
end

client:init(arg[1], arg[2], arg[3], arg[4])
client:run_debug()
