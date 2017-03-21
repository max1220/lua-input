lua-input
=========

Description
-----------
A simple binding to linux's sys/input.h.



Build
-----

    make

The build module is input.so.
Also downloads input-event-codes.h from git, and saves usefull defines in input-event-codes.lua
Install by putting input-event-codes.lua somewhere in Lua's package.path, and input.so in Lua's package.cpath:

    lua -e "print("", package.path:gsub(';', '\n'):gsub('?', '[?]'))"
    lua -e "print("", package.path:gsub(';', '\n'):gsub('?', '[?]'))"



Examples
--------
Examples are in the examples/ folder.



Usage
-----
The library exports 2 functions:

* open(path, blocking):
  + Returns a handler to the device specified via path. Return nil,err on error.
    * This device has exactly one function, :read(), which will return the next event as a table if aviable, nil otherwise. (non-blocking)
* list()
  + Returns a list of all aviable inputs.

Each device can be read(), which returns a table containing time, type, code, and value of the event.
