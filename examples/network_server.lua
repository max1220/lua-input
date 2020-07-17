#!/usr/bin/env lua5.1
-- network client(get events from network server)
local input_linux = require("lua-input").linux
local socket = require("socket")

local server = {}

function server:log(...)
	print(os.date(), ...)
end

function server:init(host, port)
	self.host = assert(host)
	self.port = assert(tonumber(port))
	self.clients = {}
end

function server:new_client(con)
	-- called when a new connection was made to the listening tcp object
	local client = {}
	client.con = con
	client.con:settimeout(0)
	local ok, err = client.con:send("ID\n")
	if not ok then
		self:log("Send failed" .. tostring(err))
		self:client_remove(client)
	end
	table.insert(self.clients, client)
	client.num = #self.clients
	self:log("Client connected: " .. client.num)
	self.clients[con] = client
end

function server:client_remove(client)
	-- called to disconnect and remove the client
	self:log("Removing client" .. tostring(client.id))
	client.con:send("CLOSE\n")
	client.con:close()
	table.remove(self.clients, client.num)
	self.clients[client.con] = nil
end

function server:broadcast(data, clients)
	-- broadcast data to a list of clients(default all)
	for _, client in ipairs(clients or self.clients) do
		local ok, err = client.con:send(data)
		if not ok then
			self:log("Send failed" .. tostring(err))
			self:client_remove(client)
		end
	end
end

function server:client_read(con)
	-- called when a client socket is read to read from
	local client = self.clients[con]
	if not client then
		self:log("Client not found ")
		return
	end

	local data, status = client.con:receive("*l")
	if not data then
		-- timeout or closed
		self:log("Client was ready but no data: " .. tostring(status))
		self:client_remove(client)
		return
	end

	local command, args_str = data:match("^(%S+)%s?(.*)$")
	local args = {}
	for arg in (args_str or ""):gmatch("(%S+)") do
		table.insert(args, arg)
	end

	if command == "CLIENT_ID" then
		self:log("Got client id: " .. tostring(arg[1]))
		client.id = tostring(arg[1])
	elseif command == "BROADCAST" then
		self:log("Got client broadcast request")
	end

	return true
end

function server:step()
	if not self.con then
		self:log("Binding connections")
		local con, err = socket.tcp()
		if not con then
			self:log("Can't create tcp socket: " .. tostring(err))
			return
		end
		self.con = con
		local ok,_err = self.con:bind(self.host, self.port)
		if not ok then
			self:log("Can't bind: " .. tostring(_err))
			return
		end
		con:settimeout(0)
	end

	-- handle a new client
	local new_client_con = server:accept()
	if new_client_con then
		server:new_client(new_client_con)
	end

	-- check if client has a command
	local read_ready = socket.select(self.clients, nil, 0)
	for _, con in ipairs(read_ready) do
		local ok = server:client_read(con)
		if not ok then
			return
		end
	end

	-- no errors
	return true
end

function server:run_debug()
	-- run till first error
	while self:step() do
	end
end

function server:run()
	-- run till stopped
	while true do
		self:step()
	end
end

server:init(arg[1] or "127.0.0.1", arg[2] or "1234")
server:run_debug()
