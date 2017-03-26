#include <stdio.h>
#include <stdlib.h>
#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <string.h>

#include <sys/ioctl.h>

#include <linux/input.h>


#define LUA_T_PUSH_S_N(S, N) lua_pushstring(L, S); lua_pushnumber(L, N); lua_settable(L, -3);
#define LUA_T_PUSH_S_S(S, S2) lua_pushstring(L, S); lua_pushstring(L, S2); lua_settable(L, -3);
#define LUA_T_PUSH_S_CF(S, CF) lua_pushstring(L, S); lua_pushcfunction(L, CF); lua_settable(L, -3);

typedef struct {
	int fd;
	char *path;
} input_t;



static int l_input_read(lua_State *L) {
	input_t *input = (input_t *)lua_touserdata(L, 1);
	struct input_event data;
	
	if(read(input->fd, &data, sizeof(data)) > 0) {
		lua_newtable(L);
		LUA_T_PUSH_S_N("time", (double) data.time.tv_sec)
		LUA_T_PUSH_S_N("utime", (double) data.time.tv_usec)
		LUA_T_PUSH_S_N("type", data.type)
		LUA_T_PUSH_S_N("code", data.code)
		LUA_T_PUSH_S_N("value", data.value)
		return 1;
	}

	return 0;
}


static int l_input_tostring(lua_State *L) {
	input_t *input = (input_t *)lua_touserdata(L, 1);
	lua_pushfstring(L, "Input device: %s", input->path);
	return 1;
}


static int l_open(lua_State *L) {
	input_t *dev = (input_t *)lua_newuserdata(L, sizeof(*dev));

	dev->path = strdup(luaL_checkstring(L, 1));

	if (lua_toboolean(L, 2)) {
		dev->fd = open(dev->path, O_RDONLY | O_NONBLOCK);
	} else {
		dev->fd = open(dev->path, O_RDONLY);
	}

	if(dev->fd < 0) {
		lua_pushnil(L);
		lua_pushfstring(L, "Can't open device!");
		return 2;
	}

	lua_createtable(L, 0, 9);
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");
	LUA_T_PUSH_S_CF("read", l_input_read)
	//LUA_T_PUSH_S_CF("close", l_input_close)
	//LUA_T_PUSH_S_CF("__gc", l_input_close)
	LUA_T_PUSH_S_CF("__tostring", l_input_tostring)
	lua_setmetatable(L, -2);

	return 1;
}


static int l_read_multiple(lua_State *L) {
	int count = lua_gettop(L);
	input_t *dev;
	struct input_event data;
	int i;
	
	for (i=1; i<=count; i=i+1) {
		dev = (input_t *)lua_touserdata(L, i);
		if(read(dev != NULL && dev->fd, &data, sizeof(data)) > 0) {
			lua_newtable(L);
			LUA_T_PUSH_S_N("time", (double) data.time.tv_sec)
			LUA_T_PUSH_S_N("utime", (double) data.time.tv_usec)
			LUA_T_PUSH_S_N("type", data.type)
			LUA_T_PUSH_S_N("code", data.code)
			LUA_T_PUSH_S_N("value", data.value)
		} else {
			lua_pushnil(L);
		}
	}

	return count;
}


static int l_list(lua_State *L) {
	FILE *fp;
	char *line = NULL;
	size_t len = 0;

	int index = 1;
	int bus = 0;
	int vendor = 0;
	int product = 0;
	int version = 0;
	char name[255];
	char phys[255];
	char sysfs[255];
	char handlers[255];

	fp = fopen("/proc/bus/input/devices", "r");
	if (fp == NULL) {
		lua_pushnil(L);
		lua_pushstring(L, "Can't open /proc/bus/input/devices");
		return 2;
	}

	lua_newtable(L);

	while (getline(&line, &len, fp) != -1) {
		if (strlen(line) - 1 > 0) {
			line[strlen(line)-1] = '\0';
			if (line[0] == 'I') {
				sscanf(line, "I: Bus=%4x Vendor=%4x Product=%4x Version=%4x", &bus, &vendor, &product, &version);
			} else if (line[0] == 'N') {
				sscanf(line, "N: Name=\"%254c", name);
				phys[strlen(line) - strlen("N: Name=\"") - 2] = '\0';
			} else if (line[0] == 'P') {
				sscanf(line, "P: Phys=%254c", phys);
				phys[strlen(line) - strlen("P: Phys=") - 1] = '\0';
			} else if (line[0] == 'S') {
				sscanf(line, "S: Sysfs=%254c", sysfs);
				sysfs[strlen(line) - strlen("S: Sysfs=") - 1] = '\0';
			} else if (line[0] == 'H') {
				sscanf(line, "H: Handlers=%254c", handlers);
				handlers[strlen(line) - strlen("H: Handlers=") - 1] = '\0';
			}
		} else {			
			lua_pushnumber(L, index);
			lua_newtable(L);

			LUA_T_PUSH_S_S("handlers", handlers)
			LUA_T_PUSH_S_S("sysfs", sysfs)
			LUA_T_PUSH_S_S("phys", phys)
			LUA_T_PUSH_S_S("name", name)

			lua_pushstring(L, "id");
			lua_newtable(L);

			LUA_T_PUSH_S_N("bus", bus)
			LUA_T_PUSH_S_N("vendor", vendor)
			LUA_T_PUSH_S_N("product", product)
			LUA_T_PUSH_S_N("version", version)

			lua_settable(L, -3);

			lua_settable(L, -3);

			index = index + 1;
		}
	}

	fclose(fp);
	free(line);

	return 1;
}



LUALIB_API int luaopen_input(lua_State *L) {
	lua_newtable(L);
	LUA_T_PUSH_S_CF("open", l_open)
	LUA_T_PUSH_S_CF("read_multiple", l_read_multiple)
	LUA_T_PUSH_S_CF("list", l_list)
	return 1;
}
