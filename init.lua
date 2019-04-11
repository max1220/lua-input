--[[
this file produces the actual module for lua-input, combining the
C functionallity with the lua functionallity. You can use the C module
directly by requiring lua-input.lua_input directly.
--]]

-- load the c module
local input = require("lua-input.lua_input")

-- add lua parts
input.list = require("lua-input.get_inputs_list")
input.event_codes = require("lua-input.input-event-codes")

-- return module table
return input
