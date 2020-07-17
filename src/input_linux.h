#ifndef LUA_INPUT_LINUX_H
#define LUA_INPUT_LINUX_H


#include <stdint.h>

#define INPUT_LINUX_VERSION "2.0"
#define INPUT_LINUX_UDATA_NAME "input_linux"

#define LUA_INPUT_LINUX_CHECK(L, I, U) U=(input_linux_t *)luaL_checkudata(L, I, INPUT_LINUX_UDATA_NAME); if ((U==NULL) || (U->fd==0)) { lua_pushnil(L); lua_pushfstring(L, "Argument %d must be a Linux input handle", I); return 2; }
#define LUA_INPUT_LINUX_WRITE_CHECK(L, I, U) U=(input_linux_t *)luaL_checkudata(L, I, INPUT_LINUX_UDATA_NAME); if ((U==NULL) || (U->fd==0) || (!U->can_write)) { lua_pushnil(L); lua_pushfstring(L, "Argument %d must be a writeable Linux input handle", I); return 2; }


typedef struct {
	int fd;
	char* path;
	int can_write;
} input_linux_t;



// common C functions for input_source_linux/input_sink_linux
// declared and defined as static functions here so both C modules stay independent
// the include guard should make sure they are only defined once.


#endif
