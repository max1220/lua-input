#!/usr/bin/env lua
local input = require("lua-input")
-- This example takes runs commands on specific key sequences that
-- can be specified via command-line arguments.

-- Usage: key_combinations device command1 sequence1 [command2] [sequence2] ...
-- Each sequence is a string, with keys that should be pressed
-- together separated by plus, and the next item in the sequence
-- separated by comma(or space).
-- Even for keys that should be pressed together, the specified order is significant:
-- leftctrl+leftalt is *not* the same as leftalt+leftctrl.

-- Examples:
-- # Launch xterm when ctrl-alt-enter is pressed on /dev/input/event2
-- key_combinations.lua /dev/input/event2 xterm leftctrl+leftalt+enter
-- # Show zenity message when ctrl-alt-delete is pressed
-- key_combinations.lua /dev/input/event2 "zenity --info --text \"three-finger salute\"" leftctrl+leftalt+delete
-- # show zenity message when user types hello
-- key_combinations.lua /dev/input/event2 "zenity --info --text \"hello user\"" h,e,l,l,o





-- parse the key_bind_str into the sequence table to resolve to command.
-- A special key code "ALL_UP" is inserted to indicate that all keys should
-- be released.
local function parse_key_bind_str(sequence, key_bind_str, command)
	local csequence = sequence
	local last, last_i
	local function enter(i)
		local t = {}
		csequence[i] = t
		last, last_i = csequence, i
		csequence = t
	end
	for key_set in key_bind_str:gmatch("([^%s,]+)") do
		-- each space-separated key_set represents some keys that are
		-- pressed together, like the typical accelerator keys(e.g. KEY_LEFTCTRL+KEY_LEFTALT+KEY_DELETE)
		for key in key_set:gmatch("([^%+]+)") do
			local key_name = "KEY_"..key:upper()
			if not input.event_codes[key_name] then
				key_name = "BTN_"..key:upper()
				assert(input.event_codes[key_name], "Unknown key: "..tostring(key))
			end
			enter(key_name)
		end

		-- create sentinel value after each space to check that all keys are up
		enter("ALL_UP")
	end

	-- replace the last empty table with a "hint" to execute command.
	if last then
		last[last_i] = command
	end
end

-- read only key events(ignore non-key/btn events)
local function read_event_filtered(dev)
	while true do
		local ev = dev:read_event(true)
		if (ev.type == input.event_codes.EV_KEY) or (ev.type == input.event_codes.EV_BTN) then
			return ev
		end
	end
end

local downs = {}
-- check if any key is in the down-table
local function is_any_down()
	if next(downs) then return true end
end

-- look up successively read events from the device in the seq table,
-- return a resolved sequence.
local cindex
local function resolve_sequence(dev, seq)
	cindex = cindex or seq

	-- get event, and name(string) of the event code
	local ev = read_event_filtered(dev)
	local _, code_name = input.ev_to_str(ev.type, ev.code)

	-- maintain table of pressed keys
	if ev.value == 0 then
		downs[code_name] = nil
	else
		downs[code_name] = ev.time
	end
	-- generate special code_name for when all keys are up
	if not is_any_down() then
		code_name = "ALL_UP"
	end

	-- look up code_name in the current index
	local resolved = cindex[code_name]

	if type(resolved)=="table" then
		-- key returned to a table, "enter" that table
		print("recurse : "..code_name)
		cindex = resolved
	elseif resolved then
		-- key resolved to a non-table, return it
		print("resolved: "..resolved)
		return resolved
	elseif (ev.value == 1) or ((code_name == "ALL_UP") and (not cindex.ALL_UP))then
		-- reset index because wrong key was pressed/keys were released at wrong time
		print("reset   : "..code_name)
		cindex = seq
	end
end





-- open the specified device
local dev = assert(arg[1], "First command-line argument must be a device!")
local input_dev = assert(input.open_input(dev), "Can't open input device!")

if not arg[2] then
	print("Usage: global_keys_combinations [device] [command1] [key_bind1] [command2] [key_bind2] ...")
	os.exit(1)
end

-- this table is used to look up successive key events
local sequence = {}
if arg[2]:match("%.lua") then
	-- load sequence table from Lua file
	sequence = assert(dofile(arg[2]))
	assert(type(sequence) == "table")
else
	-- fill sequence table with values from commandline
	for i=2, select("#", ...), 2 do
		local command_str = assert(arg[i])
		local key_bind = assert(arg[i+1])
		parse_key_bind_str(sequence, key_bind, command_str)
	end
end

-- resolve key sequences and run the resolved values
local run = true
while run do
	local resolved = resolve_sequence(input_dev, sequence)

	-- resolve a set of key presses to symbols
	if resolved == "stop" then
		-- resolved command is stop
		run = false
	elseif type(resolved) == "string" then
		-- resolved command is a string(shell command)
		os.execute(resolved)
	elseif type(resolved) == "function" then
		-- resolved command is a Lua function
		resolved()
	end
end
