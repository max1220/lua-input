# Adjust to your needs. lua5.1 is ABI-Compatible with luajit.
PREFIX = /usr/local
LUA_DIR = $(PREFIX)
LUA_LIBDIR = $(LUA_DIR)/lib/lua/5.1
LUA_SHAREDIR = $(LUA_DIR)/share/lua/5.1

# input-event-codes.h location(for debian/maybe ubuntu)
KERNEL_RELEASE = $(shell uname -r)
KERNEL_VER = $(subst amd64,common,$(KERNEL_RELEASE))
LINUX_INPUT_EVENT_CODES_H = /usr/src/linux-headers-$(KERNEL_VER)/include/uapi/linux/input-event-codes.h

CFLAGS = -g -fPIC -std=c99 -Wall -Wextra -Wpedantic
#CFLAGS = -O3 -fPIC -std=c99 -Wall -Wextra -Wpedantic -march=native -mtune=native
LIBFLAG = -shared -llua5.1

LUA_CFLAGS = -I/usr/include/lua5.1
LUA_LIBS = -llua5.1


.DEFAULT_GOAL := all
.PHONY: all
all: lua/input-event-codes.lua build
	@echo "-> Build finished!"

.PHONY: build
build:
	make -C src/ all

lua/input-event-codes.lua: $(LINUX_INPUT_EVENT_CODES_H)
	./lua/input_event_codes_to_lua_table.lua $^ > $@

.PHONY: help
help:
	@echo "Available make targets: help(this message)"
	@echo " build(build the libraries)"
	@echo " clean(remove build artifacts)"
	@echo " install(install build files)"
	@echo "You can controll more aspects of the library build if you run make in the src/ directory(run make -C src/ help)."

.PHONY: clean
clean:
	make -C src/ clean
	rm -f lua/input-event-codes.lua

.PHONY: install
install:
	@echo "-> Installing in $(PREFIX)"
	install -b -d $(LUA_SHAREDIR)/lua-input
	install -b -t $(LUA_SHAREDIR)/lua-input lua/*.lua
	install -b -d $(LUA_LIBDIR)/
	install -b -t $(LUA_LIBDIR)/ src/*.so
