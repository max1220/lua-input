#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <fcntl.h>

#include <linux/input.h>
#include <linux/uinput.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include "input_linux.h"

#define LUA_T_PUSH_S_N(S, N) lua_pushstring(L, S); lua_pushnumber(L, N); lua_settable(L, -3);
#define LUA_T_PUSH_S_I(S, N) lua_pushstring(L, S); lua_pushinteger(L, N); lua_settable(L, -3);
#define LUA_T_PUSH_S_CF(S, CF) lua_pushstring(L, S); lua_pushcfunction(L, CF); lua_settable(L, -3);
#define LUA_T_PUSH_S_S(S, S2) lua_pushstring(L, S); lua_pushstring(L, S2); lua_settable(L, -3);



static int lua_input_linux_close(lua_State *L) {
	// Close the file descriptor and free memory.
	input_linux_t *input;
	LUA_INPUT_LINUX_CHECK(L, 1, input)

	if (input->fd < 0) {
		return 0;
	}
	if (close(input->fd)==0) {
		input->fd = -1;
	}
	free(input->path);
	input->path = NULL;

	lua_pushboolean(L, 1);
	return 1;
}

static int lua_input_linux_tostring(lua_State *L) {
	// return a string with info about the linux input handle to Lua
	// can't use LUA_INPUT_LINUX_CHECK(L, 1, db) because we want to return a string even if closed
	input_linux_t *input = (input_linux_t *)luaL_checkudata(L, 1, INPUT_LINUX_UDATA_NAME);
	if (input==NULL) {
		lua_pushstring(L, "Unknow");
		return 1;
	}
	if (input->fd < 0) {
		lua_pushstring(L, "Closed Linux input handle");
		return 1;
	} else {
		lua_pushfstring(L, "Linux input handle for '%s'(fd %d, write: %s)", input->path, input->fd, input->can_write ? "yes" : "no");
		return 1;
	}
}

static int lua_input_linux_can_write(lua_State *L) {
	// returns true if you can write on this file descriptor(opened with O_RDRW)
	input_linux_t *input;
	LUA_INPUT_LINUX_CHECK(L, 1, input)

	// check if we opened the file with O_RDWR
	if (input->can_write) {
		return 0;
	}

	// Chech if write return ok
	if (write(input->fd, NULL, 0) < 0) {
		return 0;
	}

	lua_pushboolean(L, input->can_write);
	return 1;
}

static int lua_input_linux_can_read(lua_State *L) {
	// check if the fd is ready to read(non-blocking)
	input_linux_t *input;
	LUA_INPUT_LINUX_CHECK(L, 1, input)

	// Chech if read return ok
	if (read(input->fd, NULL, 0) < 0) {
		return 0;
	}

	lua_pushboolean(L, 1);
	return 1;
}

static int lua_input_linux_get_fd(lua_State *L) {
	// returns the file descriptor number
	input_linux_t *input;
	LUA_INPUT_LINUX_CHECK(L, 1, input)

	lua_pushinteger(L, input->fd);
	return 1;
}



static int lua_input_linux_read(lua_State *L) {
	// Read an input event, blocking
	input_linux_t *input;
	LUA_INPUT_LINUX_CHECK(L, 1, input)

	// read into input_event struct
	struct input_event data;
	if (read(input->fd, &data, sizeof(data)) < 0) {
		return 0;
	}

	//push table containing event information
	lua_newtable(L);
	LUA_T_PUSH_S_I("time", (double) data.time.tv_sec)
	LUA_T_PUSH_S_I("utime", (double) data.time.tv_usec)
	LUA_T_PUSH_S_I("type", data.type)
	LUA_T_PUSH_S_I("code", data.code)
	LUA_T_PUSH_S_I("value", data.value)
	return 1;
}

static int lua_input_linux_write(lua_State *L) {
	// write the specified event to the device
	struct input_event ie;
	input_linux_t *input;
	LUA_INPUT_LINUX_CHECK(L, 1, input)

	int type = lua_tointeger(L, 2);
	int code = lua_tointeger(L, 3);
	int value = lua_tointeger(L, 4);

	if ((!input->can_write) || (type<0) || (type>0xffff) || (code<0) || (code>0xffff)){
		return 0;
	}

	ie.type = (uint16_t) type;
	ie.code = (uint16_t) code;
	ie.value = value;
	ie.time.tv_sec = 0;
	ie.time.tv_usec = 0;

	if (write(input->fd, &ie, sizeof(ie)) < 0)  {
		return 0;
	}

	lua_pushboolean(L, 1);
	return 1;
}



static int lua_input_linux_grab(lua_State *L) {
	input_linux_t *input;
	LUA_INPUT_LINUX_CHECK(L, 1, input)
	int grab = lua_toboolean(L, 2);

	//if (!input->can_write) {
	//	return 0;
	//}

	if (ioctl(input->fd, EVIOCGRAB, grab)<0) {
		return 0;
	}

	lua_pushboolean(L, 1);
	return 1;
}

static int lua_input_linux_set_bit(lua_State *L) {
	input_linux_t *input;
	LUA_INPUT_LINUX_CHECK(L, 1, input)
	const char* field_str = lua_tostring(L, 2);
	int bit = lua_tointeger(L, 3);

	if ((!input->can_write) || (lua_isnumber(L, 3)==0) || (field_str==NULL)) {
		return 0;
	}

	if (strcmp(field_str, "EVBIT")==0) {
		ioctl(input->fd, UI_SET_EVBIT, bit);
	} else if (strcmp(field_str, "KEYBIT")==0) {
		ioctl(input->fd, UI_SET_KEYBIT, bit);
	} else if (strcmp(field_str, "RELBIT")==0) {
		ioctl(input->fd, UI_SET_RELBIT, bit);
	} else if (strcmp(field_str, "ABSBIT")==0) {
		ioctl(input->fd, UI_SET_ABSBIT, bit);
	} else if (strcmp(field_str, "MSCBIT")==0) {
		ioctl(input->fd, UI_SET_MSCBIT, bit);
	} else if (strcmp(field_str, "LEDBIT")==0) {
		ioctl(input->fd, UI_SET_LEDBIT, bit);
	} else if (strcmp(field_str, "SNDBIT")==0) {
		ioctl(input->fd, UI_SET_SNDBIT, bit);
	} else if (strcmp(field_str, "SWBIT")==0) {
		ioctl(input->fd, UI_SET_SWBIT, bit);
	} else if (strcmp(field_str, "PROPBIT")==0) {
		ioctl(input->fd, UI_SET_PROPBIT, bit);
	} else {
		return 0;
	}

	lua_pushboolean(L, 1);
	return 1;
}

static int lua_input_linux_abs_info(lua_State *L) {
	struct input_absinfo abs_info;
	input_linux_t *input;
	LUA_INPUT_LINUX_CHECK(L, 1, input)
	int abs_code = lua_tointeger(L, 2);

	memset(&abs_info, 0, sizeof(abs_info));
	if (ioctl(input->fd, EVIOCGABS(abs_code), &abs_info)<0) {
		return 0;
	}

	lua_newtable(L);

	LUA_T_PUSH_S_I("value", abs_info.value);
	LUA_T_PUSH_S_I("minimum", abs_info.minimum);
	LUA_T_PUSH_S_I("maximum", abs_info.maximum);
	LUA_T_PUSH_S_I("fuzz", abs_info.fuzz);
	LUA_T_PUSH_S_I("flat", abs_info.flat);
	LUA_T_PUSH_S_I("resolution", abs_info.resolution);

	return 1;
}

static int lua_input_linux_vibr_effect(lua_State *L) {
	input_linux_t *input;
	LUA_INPUT_LINUX_CHECK(L, 1, input)

	struct ff_effect my_effect = {
        .type = FF_PERIODIC,
        .id = -1,
        .replay = {
                .length = lua_tointeger(L, 2),
                .delay = lua_tointeger(L, 3)
        },
		.trigger = {
			.button = 0,
			.interval = 0
		},
        .u.periodic = {
				.waveform = FF_SINE,
				.period = lua_tointeger(L, 4),
                .magnitude = lua_tointeger(L, 5),
				.offset = 0,
				.phase = 0,
				.envelope = {
					.attack_length = lua_tointeger(L, 6),
					.attack_level = lua_tointeger(L, 7),
					.fade_length = lua_tointeger(L, 8),
					.fade_level = lua_tointeger(L, 9)
				}
        },
    };

	if (ioctl(input->fd, EVIOCSFF, &my_effect)<0) {
		return 0;
	}

	lua_pushinteger(L, my_effect.id);
	return 1;
}

static int lua_input_linux_vibr_gain(lua_State *L) {
	input_linux_t *input;
	LUA_INPUT_LINUX_CHECK(L, 1, input)

	int gain = lua_tointeger(L, 2);
	if (gain<0) {
		return 0;
	}

	struct input_event gain = {
        .type = EV_FF,
        .code = FF_GAIN,
        .value = gain,
    };

	if (write(input->fd, &play, sizeof play) < 0) {
		return 0;
	}

	lua_pushboolean(L, 1);
	return 1;
}

static int lua_input_linux_vibr_start(lua_State *L) {
	input_linux_t *input;
	LUA_INPUT_LINUX_CHECK(L, 1, input)

	int id = lua_tointeger(L, 2);
	int count = lua_tointeger(L, 3);
	if ((id<0) || (count<0)) {
		return 0;
	}

	struct input_event play = {
        .type = EV_FF,
        .code = id,
        .value = count,
    };

	if (write(input->fd, &play, sizeof play) < 0) {
		return 0;
	}

	lua_pushboolean(L, 1);
	return 1;
}

static int lua_input_linux_vibr_remove(lua_State *L) {
	input_linux_t *input;
	LUA_INPUT_LINUX_CHECK(L, 1, input)

	int id = lua_tointeger(L, 2);
	if (id<0) {
		return 0;
	}

	if (ioctl(input->fd, EVIOCRMFF, id)<0) {
		return 0;
	}

	lua_pushboolean(L, 1);
	return 1;
}

static int lua_input_linux_abs_setup(lua_State *L) {
	struct uinput_abs_setup abs_setup;
	input_linux_t *input;
	LUA_INPUT_LINUX_CHECK(L, 1, input)

	if (!input->can_write) {
		return 0;
	}

	memset(&abs_setup, 0, sizeof(abs_setup));
	abs_setup.code = lua_tointeger(L, 2);
	abs_setup.absinfo.value = lua_tointeger(L, 3);
	abs_setup.absinfo.minimum = lua_tointeger(L, 4);
	abs_setup.absinfo.maximum = lua_tointeger(L, 5);
	abs_setup.absinfo.fuzz = lua_tointeger(L, 6);
	abs_setup.absinfo.flat = lua_tointeger(L, 7);
	abs_setup.absinfo.resolution = lua_tointeger(L, 8);

	if (ioctl(input->fd, UI_ABS_SETUP, &abs_setup)<0) {
		return 0;
	}

	lua_pushboolean(L, 1);
	return 1;
}

static int lua_input_linux_dev_setup(lua_State *L) {
	struct uinput_setup usetup;
	input_linux_t *input;
	LUA_INPUT_LINUX_CHECK(L, 1, input)

	const char* str = lua_tostring(L, 2);
	int vendor = lua_tointeger(L, 3);
	int product = lua_tointeger(L, 4);

	if ((!input->can_write) || (!str) ||(vendor<0) || (vendor>0xffff) || (product<0) || (product>0xffff)) {
		return 0;
	}

	memset(&usetup, 0, sizeof(usetup));
	usetup.id.bustype = lua_toboolean(L, 5) ? BUS_USB : BUS_VIRTUAL;
	usetup.id.vendor = (uint16_t)vendor;
	usetup.id.product = (uint16_t)product;
	strncpy(usetup.name, str, UINPUT_MAX_NAME_SIZE-1);

	ioctl(input->fd, UI_DEV_SETUP, &usetup);
	ioctl(input->fd, UI_DEV_CREATE);

	lua_pushboolean(L, 1);
	return 1;
}

static int lua_input_linux_dev_destroy(lua_State *L) {
	input_linux_t *input;
	LUA_INPUT_LINUX_CHECK(L, 1, input)

	if (!input->can_write) {
		return 0;
	}

	if (ioctl(input->fd, UI_DEV_DESTROY)<0) {
		return 0;
	}

	lua_pushboolean(L, 1);
	return 1;
}

static void input_linux_push_metatable(lua_State *L) {
	// push/create metatable for userdata.
	// The same metatable is used for every input_linux handle(sink/source).
	if (luaL_newmetatable(L, INPUT_LINUX_UDATA_NAME)) {
		lua_pushstring(L, "__index");
		lua_newtable(L);
		LUA_T_PUSH_S_CF("read", lua_input_linux_read)
		LUA_T_PUSH_S_CF("write", lua_input_linux_write)
		LUA_T_PUSH_S_CF("set_bit", lua_input_linux_set_bit)
		LUA_T_PUSH_S_CF("dev_setup", lua_input_linux_dev_setup)
		LUA_T_PUSH_S_CF("dev_destroy", lua_input_linux_dev_destroy)
		LUA_T_PUSH_S_CF("grab", lua_input_linux_grab)
		LUA_T_PUSH_S_CF("abs_info", lua_input_linux_abs_info)
		LUA_T_PUSH_S_CF("abs_setup", lua_input_linux_abs_setup)
		LUA_T_PUSH_S_CF("vibr_effect", lua_input_linux_vibr_effect)
		LUA_T_PUSH_S_CF("vibr_start", lua_input_linux_vibr_start)
		LUA_T_PUSH_S_CF("vibr_remove", lua_input_linux_vibr_remove)
		LUA_T_PUSH_S_CF("can_read", lua_input_linux_can_read)
		LUA_T_PUSH_S_CF("can_write", lua_input_linux_can_write)
		LUA_T_PUSH_S_CF("get_fd", lua_input_linux_get_fd)
		LUA_T_PUSH_S_CF("close", lua_input_linux_close)


		LUA_T_PUSH_S_CF("tostring", lua_input_linux_tostring)
		lua_settable(L, -3);

		LUA_T_PUSH_S_CF("__gc", lua_input_linux_close)
		LUA_T_PUSH_S_CF("__tostring", lua_input_linux_tostring)
	}
}

static int lua_new_input_source_linux(lua_State *L) {
	// Check if we have a path specified(required argumenst)
	const char* path = lua_tostring(L, 1);
	if (!path) {
		lua_pushnil(L);
		lua_pushstring(L, "Argument 1 needs to be a string");
		return 2;
	}

	// open file read-write if second argument is true, read-only otherwise
	int flags = lua_toboolean(L, 2) ? 0 : O_NONBLOCK;
	flags |= lua_toboolean(L, 3) ? O_RDWR : O_RDONLY;

	// try to get a file descriptor for the input device
	int fd = open(path, flags);
	if (fd<0) {
		lua_pushnil(L);
		lua_pushfstring(L, "Can't open file: %s", path);
		return 2;
	}

	// Create new userdata object
	input_linux_t *input = (input_linux_t *)lua_newuserdata(L, sizeof(input_linux_t));

	// duplicate path
	input->path = strdup(path);
	if (!input->path) {
		input->path = ""; // TODO
	}
	input->fd = fd;
	input->can_write = lua_toboolean(L, 3);

	// create/push the metatable for INPUT_LINUX_UDATA_NAME
	input_linux_push_metatable(L);

	// apply metatable to userdata
	lua_setmetatable(L, -2);

	// return userdata
	return 1;
}

static int lua_new_input_sink_linux(lua_State *L) {
	// try to get a file descriptor for the input device
	int fd = open("/dev/uinput", O_RDWR | O_NONBLOCK);
	if (fd<0) {
		lua_pushnil(L);
		lua_pushstring(L, "Can't open \"/dev/uinput\"");
		return 2;
	}

	// Create new userdata object
	input_linux_t *input = (input_linux_t *)lua_newuserdata(L, sizeof(input_linux_t));

	// duplicate path
	input->path = strdup("/dev/uinput");
	if (!input->path) {
		input->path = ""; // TODO
	}
	input->fd = fd;
	input->can_write = 1;

	// create/push the metatable for INPUT_LINUX_UDATA_NAME
	input_linux_push_metatable(L);

	// apply metatable to userdata
	lua_setmetatable(L, -2);

	// return userdata
	return 1;
}



LUALIB_API int luaopen_input_linux(lua_State *L) {
	// when the module is require()'ed, return a table with the new_input_linux function and some constants
	lua_newtable(L);

	LUA_T_PUSH_S_S("version", INPUT_LINUX_VERSION)
	LUA_T_PUSH_S_CF("new_input_source_linux", lua_new_input_source_linux)
	LUA_T_PUSH_S_CF("new_input_sink_linux", lua_new_input_sink_linux)

	return 1;
}
