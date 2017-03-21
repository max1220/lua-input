#!/bin/bash

# Adjust to your needs. lua5.1 is ABI-Compatible with luajit.
CFLAGS= -O3 -Wall -Wextra -fPIC -I/usr/include/lua5.1
LIBS= -shared -llua5.1

.PHONY: clean all
.DEFAULT_GOAL := all

all: input.so input-event-codes.lua

clean:
	rm input.so input-event-codes.lua

input.so: input.c
	$(CC) -o $@ $(CFLAGS) $(LIBS) $<
#	strip $@

input-event-codes.h:
	wget "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/include/uapi/linux/input-event-codes.h"

input-event-codes.lua: input-event-codes.h
	./defines_to_table.lua input-event-codes.h > input-event-codes.lua
