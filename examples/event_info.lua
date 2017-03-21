#!/usr/bin/env luajit
package.cpath = package.cpath .. ";../?.so"
package.path = package.path .. ";../?.lua"
local input = require("input")
local input_event_codes = require("input-event-codes")


local list = input.list()

function list_by_pattern_value(pattern, value)
  for k,v in pairs(input_event_codes) do
    if k:match(pattern) and v == value then
      return k,v
    end
  end
end

print("Listing aviable input devices...")
for k,v in pairs(list) do
  local dev = v.handlers:match("(event%d)")
  local path = "/dev/input/"..dev
  print(k..": ".. path)
  for ke,va in pairs(v) do
    print("",ke,va)
  end
  if dev then
    v.path = "/dev/input/"..dev
  end
end
print("Ok!\n")

print("Obtaining handle for all input devices...")
local devices = {}
for k,v in pairs(list) do
  if v.path then
    devices[v.path] = input.open(v.path)
  end
end
print("Ok!\n")

print(input_event_codes.ABS_MT_TRACKING_ID)

print("Entering event loop... (^C to quit)")
while true do
  for k,v in pairs(devices) do
    local ev = v:read()
    if ev and ev.type ~= input_event_codes.EV_SYN then
    
      local type = list_by_pattern_value("^EV_", ev.type) or ""
      local code
      if type == "EV_KEY" then
        code = list_by_pattern_value("^KEY_", ev.code) or list_by_pattern_value("^BTN_", ev.code)
      elseif type == "EV_ABS" then
        code = list_by_pattern_value("^ABS_", ev.code)
      elseif type == "EV_REL" then
        code = list_by_pattern_value("^REL_", ev.code)
      end
      code = code or ""
      -- local 
      print(("Got event from %q: time=%d, utime=%06d, type=%12s(0x%03X), code=%18s(0x%03X), value=0x%016X"):format(k, ev.time, ev.utime, type, ev.type, code, ev.code, ev.value))
    end
  end
end
