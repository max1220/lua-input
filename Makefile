# Adjust to your needs. lua5.1 is ABI-Compatible with luajit.
LUA_DIR = $(PREFIX)
LUA_LIBDIR = $(LUA_DIR)/lib/lua/5.1
LUA_SHAREDIR = $(LUA_DIR)/share/lua/5.1

# input-event-codes.h location
LINUX_INPUT_EVENT_CODES_H = /usr/src/linux-headers-5.7.0-1-common/include/uapi/linux/input-event-codes.h

CFLAGS = -g -fPIC -std=c99 -Wall -Wextra -Wpedantic
#CFLAGS = -O3 -fPIC -std=c99 -Wall -Wextra -Wpedantic -march=native -mtune=native
LIBFLAG = -shared -llua5.1

LUA_CFLAGS = -I/usr/include/lua5.1
LUA_LIBS = -llua5.1

.PHONY: clean all install
.DEFAULT_GOAL := all

clean:
	make -C src/ clean
	rm -f lua/input-event-codes.lua

all: lua/input-event-codes.lua
	make -C src/ all

install:
	@echo "TODO"

lua/input-event-codes.lua: $(LINUX_INPUT_EVENT_CODES_H)
	./lua/input_event_codes_to_lua_table.lua $^ > $@
