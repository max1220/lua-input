# Global configuration
CFLAGS = -g -fPIC -std=gnu99 -Wall -Wextra -Wpedantic
#CFLAGS = -O3 -fPIC -std=c99 -Wall -Wextra -Wpedantic -march=native -mtune=native
LIBFLAG = -shared -fpic -lm -Wl,--as-needed

# Lua configuration
LUA_CFLAGS = -I/usr/include/lua5.1
LUA_LIBS = -llua5.1

#STRIP = strip
STRIP = true

.PHONY: all
all: module_linux

.PHONY: help
help:
	@echo "Available make targets: "
	@echo " help (this message)"
	@echo " all (build all modules)"
	@echo " module_linux (only build Linux input/uinput binding)"
	@echo " clean (remove build artifacts)"

.PHONY: module_linux
module_linux: input_linux.so
	$(STRIP) $^
	@echo "-> Building Linux input/uinput module finished"

.PHONY: clean
clean:
	@echo "-> Cleaning up build artifacts"
	rm -f input_linux.so input_linux.o

input_linux.o: input_linux.c
	$(CC) -o $@ $(CFLAGS) $(LUA_CFLAGS) -c $^

input_linux.so: input_linux.o
	$(CC) -o $@ $(CFLAGS) $(LUA_CFLAGS) $^ $(LIBFLAG) $(LUA_LIBS)
