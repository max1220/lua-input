#!/usr/bin/env lua5.1
-- this client opens an input device to listen for input events, then semds
-- them to a server

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
	local rand_id = "source_client_"..string.char(math.random(65,90),math.random(65,90),math.random(65,90),math.random(65,90),math.random(65,90))
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
	end
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

	-- handle input event
	if self.dev and self.dev:can_read() then
		local ev = self.dev:read()
		if ev then
			local cmd_str = {"CLIENT_EVENT", ev.type, ev.code, ev.value}
			local cmd = table.concat(cmd_str, " ")
			local ok, err = self.con:send(cmd)
			if not ok then
				self:log("send failed: " .. tostring(err))
				return
			end
		end
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
	elseif (command == "LIST") then
		self:log("Server requested client input device list")
		local input_devices = input_linux:get_devices_list()
		local cmd = {"CLIENT_DEVICE"}
		for _,device in ipairs(input_devices) do
			table.insert(cmd, '"'..device.name..'"')
		end
		local ok, err = self.con:send(table.concat(cmd, " "))
		if not ok then
			self:log("send failed: " .. tostring(err))
			return
		end
	elseif (command == "LISTEN") and (not self.dev) then
		self:log("Server requested events from input device(listen)")
		local dev_str = tostring(args[1])
		local dev = input_linux.new_input_source_linux(dev_str)
		if not dev then
			self:log("new_input_sink_linux failed!")
			return
		end
		self.dev = dev
	elseif (command == "CLOSE") and self.dev then
		-- destroy the device
		self:log("Closing device")
		self.dev:close()
		self.dev = nil
		return
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
