#!/usr/bin/env lua5.1
-- this is a utillity function to parse a Linux kernel header file to
-- grab the required constant values for the lua-input library.
-- You should normally not need it, since the headers rarely change.



local input_path = assert(arg[1])
local input_file = assert(io.open(input_path, "r"))
--local define_pattern = "^#define ([%u_]+)%s+(.*)+"
local define_pattern = "^#define ([%u%w_]+)%s+(.+)"

-- resolve all defines that have an immediate value
local codes = {}
local resolve = {}
for line in input_file:lines() do
	if line:match(define_pattern) then
		local name,raw_value = line:match(define_pattern)
		if name and raw_value then
			local hex_match = raw_value:match("^0x(%x+)")
			local dec_match = raw_value:match("^(%d+)")
			if hex_match then
				codes[name] = assert(tonumber(hex_match, 16))
			elseif dec_match then
				codes[name] = assert(tonumber(dec_match))
			else
				resolve[name] = raw_value
			end
		end
	end
end
-- resolve defines that reference other defines
for name,raw_value in pairs(resolve) do
	local ref_match = raw_value:match("^([%u%w_]+)%s")
	local brace_match = raw_value:match("%((.+)%)")
	if codes[raw_value] then
		codes[name] = codes[raw_value]
	elseif ref_match then
		codes[name] = codes[raw_value]
	elseif brace_match then
		local index = assert(brace_match:gsub("%s",""):match("^(.+)%+1$"))
		codes[name] = codes[index]+1
	end
end

-- create sorted table for export
local export = {}
for name, value in pairs(codes) do
	table.insert(export, {name,value})
end
table.sort(export, function(a,b)
	return a[1]<b[1]
end)

-- export as a Lua table
io.write("return {\n")
for i, item in ipairs(export) do
	io.write(("\t[%q] = %d"):format(item[1], item[2]))
	if i ~= #export then
		io.write(",")
	end
	io.write("\n")
end
io.write("}\n")
