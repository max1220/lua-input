#!/usr/bin/env lua5.1
local time = require("time")
local input_linux = require("lua-input").linux
local input_event_codes = input_linux.input_event_codes

local dev = assert(arg[1])
local w,h = 40, 20
-- open /dev/input/eventX for a new device
local input = input_linux.new_input_source_linux(dev)

--io.write = function() end

local last_ev
local mouse = {}
local function draw()
	if not last_ev then
		return
	end


	local abs_cur_x, abs_cur_y, abs_pct_x, abs_pct_y
	if mouse.last_abs_x and mouse.last_abs_y then
		abs_pct_x = (mouse.last_abs_x - mouse.min_abs_x) / (mouse.max_abs_x - mouse.min_abs_x)
		abs_pct_y = (mouse.last_abs_y - mouse.min_abs_y) / (mouse.max_abs_y - mouse.min_abs_y)
		abs_cur_x, abs_cur_y = math.floor(abs_pct_x*w), math.floor(abs_pct_y*h)
	end


	local center_x, center_y = math.floor(w/2), math.floor(h/2)
	local rel_cur_x, rel_cur_y, rel_pct_x, rel_pct_y
	if mouse.last_rel_x and mouse.last_rel_y then
		rel_pct_x = (mouse.last_rel_x - mouse.min_rel_x) / (mouse.max_rel_x - mouse.min_rel_x)
		rel_pct_y = (mouse.last_rel_y - mouse.min_rel_y) / (mouse.max_rel_y - mouse.min_rel_y)
		--rel_pct_x = 0.2
		rel_cur_x, rel_cur_y = math.floor(rel_pct_x*w*0.5), math.floor(rel_pct_y*h*0.5)
	end


	local debug_lines = {
		("rel: x:%5d(min: %5d; max:%5d %4d%%) y:%5d(min: %5d; max:%5d %4d%%)"):format(
			mouse.last_rel_x or 0,
			mouse.min_rel_x or 0,
			mouse.max_rel_x or 0,
			(rel_pct_x or 0)*200-100,
			mouse.last_rel_y or 0,
			mouse.min_rel_y or 0,
			mouse.max_rel_y or 0,
			(rel_pct_y or 0)*200-100
		),
		("abs: x:%5d(min: %5d; max:%5d %4d%%) y:%5d(min: %5d; max:%5d %4d%%)"):format(
			mouse.last_abs_x or 0,
			mouse.min_abs_x or 0,
			mouse.max_abs_x or 0,
			(abs_pct_x or 0)*200-100,
			mouse.last_abs_y or 0,
			mouse.min_abs_y or 0,
			mouse.max_abs_y or 0,
			(abs_pct_y or 0)*200-100
		),
		("lmb: %4s mmb: %4s rmb: %4s"):format(mouse.lmb and "[#]" or "[ ]", mouse.mmb and "[#]" or "[ ]", mouse.rmb and "[#]" or "[ ]"),
		("read: %s"):format(input:can_read() and "[#]" or "[ ]"),
		("ev: type=%s, code=%s"):format(tostring(last_ev.type_str), tostring(last_ev.code_str)),
	}
	io.write("\027[0H") -- set cursor to top-left
	io.write("\027[J") -- clear screen
	io.write("+" .. ("-"):rep(w) .. "+\n")

	for y=1, h do
		io.write("|")
		for x=1, w do
			local char = " "
			if (abs_cur_x == x) and (abs_cur_y == y) then
				char = "a"
			end
			if rel_cur_x and rel_cur_y and (mouse.last_rel + 0.1>time.realtime()) then
				if (y == center_y) and (x<center_x) and (x>center_x-(w*0.5-rel_cur_x)) and (mouse.last_rel_x<0) then
					-- left side
					char = "<"
				end
				if (y == center_y) and (x>center_x) and (x<center_x+rel_cur_x) and (mouse.last_rel_x>0) then
					-- right side
					char = ">"
				end
				if (x == center_x) and (y<center_y) and (y>center_y-(h*0.5-rel_cur_y)) and (mouse.last_rel_y<0) then
					-- top side
					char = "^"
				end
				if (x == center_x) and (y>center_y) and (y<center_y+rel_cur_y) and (mouse.last_rel_y>0) then
					-- bottom side
					char = "v"
				end
				if (x == center_x) and (y == center_y) then
					char = "O"
				end
			end
			io.write(char)
		end
		io.write("| ")
		if debug_lines[y] then
			io.write(debug_lines[y])
		end
		io.write("\n")
	end
	io.write("+" .. ("-"):rep(w) .. "+\n")
	io.flush()
	time.sleep(0.01)
end

local function handle_event(ev)
	ev.type_str, ev.code_str = input_linux:ev_to_str(ev)

	if (ev.type == input_event_codes.EV_ABS) and (ev.code == input_event_codes.ABS_X) then
		mouse.last_abs_x = ev.value
		mouse.min_abs_x = math.min(ev.value, mouse.min_abs_x or math.huge)
		mouse.max_abs_x = math.max(ev.value, mouse.max_abs_x or -math.huge)
	elseif (ev.type == input_event_codes.EV_ABS) and (ev.code == input_event_codes.ABS_Y) then
		mouse.last_abs_y = ev.value
		mouse.min_abs_y = math.min(ev.value, mouse.min_abs_y or math.huge)
		mouse.max_abs_y = math.max(ev.value, mouse.max_abs_y or -math.huge)
	elseif (ev.type == input_event_codes.EV_REL) and (ev.code == input_event_codes.REL_X) then
		mouse.last_rel_x = ev.value
		mouse.min_rel_x = math.min(ev.value, mouse.min_rel_x or math.huge)
		mouse.max_rel_x = math.max(ev.value, mouse.max_rel_x or -math.huge)
		mouse.last_rel = time.realtime()
	elseif (ev.type == input_event_codes.EV_REL) and (ev.code == input_event_codes.REL_Y) then
		mouse.last_rel_y = ev.value
		mouse.min_rel_y = math.min(ev.value, mouse.min_rel_y or math.huge)
		mouse.max_rel_y = math.max(ev.value, mouse.max_rel_y or -math.huge)
		mouse.last_rel = time.realtime()
	end

	if ev.type ~= input_event_codes.EV_SYN then
		last_ev = ev
	end
end

io.stdout:setvbuf("full")
while true do
	while input:can_read() do
		local ev = input:read()
		handle_event(ev)
	end
	draw()
end
