#!/usr/bin/env luajit
local infile = io.open(arg[1] or "input-event-codes.h")
if not infile then
  io.stderr:write("Can't open input file!\n")
  os.exit(1)
end

local ret = "return {\n"

local defines = {}
for line in infile:lines() do
  local key, value = line:match("^%s*#define (%S+)%s+(%S+).*$")
  local value = tonumber(value) or defines[key]
  if key and value then
    ret = ret .. "\t[\"" .. key ..  "\"] = " .. value .. ",\n"
    defines[key] = value
  end
end

infile:close()

ret = ret:sub(1, -3)
ret = ret .. "\n}"

print(ret)
