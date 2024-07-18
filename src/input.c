#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include <linux/input.h>
#include <linux/uinput.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#define LUA_T_PUSH_S_N(S, N) lua_pushstring(L, S); lua_pushnumber(L, N); lua_settable(L, -3);
#define LUA_T_PUSH_S_I(S, N) lua_pushstring(L, S); lua_pushinteger(L, N); lua_settable(L, -3);
#define LUA_T_PUSH_S_CF(S, CF) lua_pushstring(L, S); lua_pushcfunction(L, CF); lua_settable(L, -3);
#define LUA_T_PUSH_S_S(S, S2) lua_pushstring(L, S); lua_pushstring(L, S2); lua_settable(L, -3);


// get a fd from Lua argument, if not found cause a Lua error and return -1
static int get_fd_from_lua_or_err(lua_State *L, int index) {
	// if argument is a number, assume it is a file descriptor already
	if (lua_isnumber(L, index)) {
		return lua_tointeger(L, index);
	}

	// get a FILE* userdata from Lua(as returned by io.open(), e.g. io.stderr)
	FILE* f = *(FILE**) luaL_checkudata(L, index, LUA_FILEHANDLE);
	if (f==NULL) {
		luaL_error(L, "Expected a file as argument %d!", index);
		return -1;
	}

	// get the file descriptor from the FILE*
	int fd = fileno(f);
	if (fd<0) {
		luaL_error(L, "Can't get fd from file!");
		return -1;
	}

	return fd;
}



// perform the EVIOCGABS ioctl to get info about an absolute axis
static int lua_input_abs_info(lua_State *L) {
	int fd = get_fd_from_lua_or_err(L, 1);
	int abs_code = lua_tointeger(L, 2);

	struct input_absinfo abs_info;
	memset(&abs_info, 0, sizeof(abs_info));
	if (ioctl(fd, EVIOCGABS(abs_code), &abs_info)<0) {
		return 0;
	}

	lua_newtable(L);

	LUA_T_PUSH_S_I("value", abs_info.value);
	LUA_T_PUSH_S_I("minimum", abs_info.minimum);
	LUA_T_PUSH_S_I("maximum", abs_info.maximum);
	LUA_T_PUSH_S_I("fuzz", abs_info.fuzz);
	LUA_T_PUSH_S_I("flat", abs_info.flat);
	LUA_T_PUSH_S_I("resolution", abs_info.resolution);

	// return the abs_info table
	return 1;
}

// perform the UI_ABS_SETUP ioctl
static int lua_input_abs_setup(lua_State *L) {
	int fd = get_fd_from_lua_or_err(L, 1);

	struct uinput_abs_setup abs_setup;
	memset(&abs_setup, 0, sizeof(abs_setup));
	abs_setup.code = lua_tointeger(L, 2);
	abs_setup.absinfo.value = lua_tointeger(L, 3);
	abs_setup.absinfo.minimum = lua_tointeger(L, 4);
	abs_setup.absinfo.maximum = lua_tointeger(L, 5);
	abs_setup.absinfo.fuzz = lua_tointeger(L, 6);
	abs_setup.absinfo.flat = lua_tointeger(L, 7);
	abs_setup.absinfo.resolution = lua_tointeger(L, 8);

	if (ioctl(fd, UI_ABS_SETUP, &abs_setup)<0) {
		return 0;
	}

	// return true
	lua_pushboolean(L, 1);
	return 1;
}

// return true if the fd is available for immediate reading
static int lua_input_can_read(lua_State *L) {
	int fd = get_fd_from_lua_or_err(L, 1);

	// Check if read return ok
	if (read(fd, NULL, 0) < 0) {
		return 0;
	}

	// return true
	lua_pushboolean(L, 1);
	return 1;
}

// return true if the fd is available for immediate writing
static int lua_input_can_write(lua_State *L) {
	int fd = get_fd_from_lua_or_err(L, 1);

	// Check if write return ok
	if (write(fd, NULL, 0) < 0) {
		return 0;
	}

	// return true
	lua_pushboolean(L, 1);
	return 1;
}

// close the specified file descriptor
static int lua_input_close(lua_State *L) {
	int fd = get_fd_from_lua_or_err(L, 1);

	if (close(fd)<0) {
		lua_pushboolean(L, 0);
	} else {
		lua_pushboolean(L, 1);
	}

	return 1;
}

// perform the UI_DEV_DESTROY ioctl
static int lua_input_dev_destroy(lua_State *L) {
	int fd = get_fd_from_lua_or_err(L, 1);

	if (ioctl(fd, UI_DEV_DESTROY)<0) {
		return 0;
	}

	// return true
	lua_pushboolean(L, 1);
	return 1;
}

// perform the UI_DEV_SETUP ioctl
static int lua_input_dev_setup(lua_State *L) {
	int fd = get_fd_from_lua_or_err(L, 1);
	const char* str = lua_tostring(L, 2);
	int vendor = lua_tointeger(L, 3);
	int product = lua_tointeger(L, 4);
	int is_usb = lua_toboolean(L, 5);

	struct uinput_setup usetup;

	if ((!str) ||(vendor<0) || (vendor>0xffff) || (product<0) || (product>0xffff)) {
		return 0;
	}

	memset(&usetup, 0, sizeof(usetup));
	usetup.id.bustype = is_usb ? BUS_USB : BUS_VIRTUAL;
	usetup.id.vendor = (uint16_t)vendor;
	usetup.id.product = (uint16_t)product;
	strncpy(usetup.name, str, UINPUT_MAX_NAME_SIZE-1);

	if (ioctl(fd, UI_DEV_SETUP, &usetup)<0) {
		return 0;
	}
	if (ioctl(fd, UI_DEV_CREATE)<0) {
		return 0;
	}

	// return true
	lua_pushboolean(L, 1);
	return 1;
}

// perform the EVIOCGRAB ioctl to grab/ungrab the input device
static int lua_input_grab(lua_State *L) {
	int fd = get_fd_from_lua_or_err(L, 1);
	int grab = lua_toboolean(L, 2);

	if (ioctl(fd, EVIOCGRAB, grab)<0) {
		return 0;
	}

	// return true
	lua_pushboolean(L, 1);
	return 1;
}

// open a file R/W for use with this library
static int lua_input_open_rw(lua_State *L) {
	// Check if we have a path specified(required argumenst)
	const char* path = lua_tostring(L, 1);
	if (!path) {
		lua_pushnil(L);
		lua_pushstring(L, "Argument 1 needs to be a string");
		return 2;
	}

	//int flags = lua_toboolean(L, 2) ? 0 : O_NONBLOCK;
	// open file read-write if second argument is true, read-only otherwise
	//flags |= lua_toboolean(L, 3) ? O_RDWR : O_RDONLY;

	// try to get a file descriptor for the input device
	//int fd = open(path, flags);
	int fd = open(path, O_RDWR);
	if (fd<0) {
		lua_pushnil(L);
		lua_pushfstring(L, "Can't open file: %s", path);
		return 2;
	}

	// return the fd number
	lua_pushinteger(L, fd);
	return 1;
}

// blockingly read an event from the file descriptor
static int lua_input_read_event(lua_State *L) {
	int fd = get_fd_from_lua_or_err(L, 1);

	// read into input_event struct
	struct input_event data;
	if (read(fd, &data, sizeof(data)) != sizeof(data)) {
		return 0;
	}

	//push table containing event information
	double time = (double) data.time.tv_sec + ((double) data.time.tv_usec / 1000000.0);

	if (lua_toboolean(L, 2)) {
		// return a table
		lua_newtable(L);
		LUA_T_PUSH_S_I("type", data.type);
		LUA_T_PUSH_S_I("code", data.code);
		LUA_T_PUSH_S_I("value", data.value);
		LUA_T_PUSH_S_N("time", time);
		return 1;
	}

	// return the 4 values
	lua_pushinteger(L, data.type);
	lua_pushinteger(L, data.code);
	lua_pushinteger(L, data.value);
	lua_pushnumber(L, time);
	return 4;
}

// perform the UI_SET_*BIT ioctl
static int lua_input_set_bit(lua_State *L) {
	int fd = get_fd_from_lua_or_err(L, 1);
	const char* field_str = lua_tostring(L, 2);
	int bit = lua_tointeger(L, 3);
	int ret = -1;

	if ((lua_isnumber(L, 3)==0) || (field_str==NULL)) {
		return 0;
	}

	if (strcmp(field_str, "EVBIT")==0) {
		ret = ioctl(fd, UI_SET_EVBIT, bit);
	} else if (strcmp(field_str, "KEYBIT")==0) {
		ret = ioctl(fd, UI_SET_KEYBIT, bit);
	} else if (strcmp(field_str, "RELBIT")==0) {
		ret = ioctl(fd, UI_SET_RELBIT, bit);
	} else if (strcmp(field_str, "ABSBIT")==0) {
		ret = ioctl(fd, UI_SET_ABSBIT, bit);
	} else if (strcmp(field_str, "MSCBIT")==0) {
		ret = ioctl(fd, UI_SET_MSCBIT, bit);
	} else if (strcmp(field_str, "LEDBIT")==0) {
		ret = ioctl(fd, UI_SET_LEDBIT, bit);
	} else if (strcmp(field_str, "SNDBIT")==0) {
		ret = ioctl(fd, UI_SET_SNDBIT, bit);
	} else if (strcmp(field_str, "SWBIT")==0) {
		ret = ioctl(fd, UI_SET_SWBIT, bit);
	} else if (strcmp(field_str, "PROPBIT")==0) {
		ret = ioctl(fd, UI_SET_PROPBIT, bit);
	} else {
		return 0;
	}

	if (ret<0) {
		return 0;
	}

	// return true
	lua_pushboolean(L, 1);
	return 1;
}

// perform the EVIOCSFF ioctl to upload a new force-feedback effect
static int lua_input_vibr_effect(lua_State *L) {
	int fd = get_fd_from_lua_or_err(L, 1);

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

	if (ioctl(fd, EVIOCSFF, &my_effect)<0) {
		return 0;
	}

	// return true
	lua_pushinteger(L, my_effect.id);
	return 1;
}

// write a FF_GAIN event to update the force-feedback gain
static int lua_input_vibr_gain(lua_State *L) {
	int fd = get_fd_from_lua_or_err(L, 1);
	int gain = lua_tointeger(L, 2);
	if (gain<0) {
		return 0;
	}

	struct input_event gain_ev = {
        .type = EV_FF,
        .code = FF_GAIN,
        .value = (int16_t) gain,
    };

	if (write(fd, &gain_ev, sizeof(gain)) < 0) {
		return 0;
	}

	// return true
	lua_pushboolean(L, 1);
	return 1;
}

// perform the EVIOCRMFF ioctl to remove a force-feedback effect
static int lua_input_vibr_remove(lua_State *L) {
	int fd = get_fd_from_lua_or_err(L, 1);
	int id = lua_tointeger(L, 2);
	if (id<0) {
		return 0;
	}

	if (ioctl(fd, EVIOCRMFF, id)<0) {
		return 0;
	}

	// return true
	lua_pushboolean(L, 1);
	return 1;
}

// write a EV_FF event to start a specified force-feedback effect
static int lua_input_vibr_start(lua_State *L) {
	int fd = get_fd_from_lua_or_err(L, 1);
	int id = lua_tointeger(L, 2);
	int count = lua_tointeger(L, 3);
	if ((id<0) || (count<0)) {
		return 0;
	}

	struct input_event play_ev = {
        .type = EV_FF,
        .code = id,
        .value = count,
    };

	if (write(fd, &play_ev, sizeof(play_ev)) < 0) {
		return 0;
	}

	// return true
	lua_pushboolean(L, 1);
	return 1;
}

// blockingly write an event to the the file descriptor
static int lua_input_write_event(lua_State *L) {
	int fd = get_fd_from_lua_or_err(L, 1);
	int type = lua_tointeger(L, 2);
	int code = lua_tointeger(L, 3);
	int value = lua_tointeger(L, 4);

	if ((type<0) || (type>0xffff) || (code<0) || (code>0xffff)){
		return 0;
	}

	struct input_event ie = {
		.type = (uint16_t) type,
		.code = (uint16_t) code,
		.value = (int32_t) value,
		.time.tv_sec = 0,
		.time.tv_usec = 0
	};

	if (write(fd, &ie, sizeof(ie)) < 0)  {
		return 0;
	}

	lua_pushboolean(L, 1);
	return 1;
}



LUALIB_API int luaopen_input(lua_State *L) {
	// when the module is require()'ed, return a table with the functions
	lua_newtable(L);

	LUA_T_PUSH_S_S("version", LUAROCK_PACKAGE_VERSION)
	LUA_T_PUSH_S_CF("abs_info", lua_input_abs_info)
	LUA_T_PUSH_S_CF("abs_setup", lua_input_abs_setup)
	LUA_T_PUSH_S_CF("can_read", lua_input_can_read)
	LUA_T_PUSH_S_CF("can_write", lua_input_can_write)
	LUA_T_PUSH_S_CF("close", lua_input_close)
	LUA_T_PUSH_S_CF("dev_destroy", lua_input_dev_destroy)
	LUA_T_PUSH_S_CF("dev_setup", lua_input_dev_setup)
	LUA_T_PUSH_S_CF("grab", lua_input_grab)
	LUA_T_PUSH_S_CF("open_rw", lua_input_open_rw)
	LUA_T_PUSH_S_CF("read_event", lua_input_read_event)
	LUA_T_PUSH_S_CF("set_bit", lua_input_set_bit)
	LUA_T_PUSH_S_CF("vibr_effect", lua_input_vibr_effect)
	LUA_T_PUSH_S_CF("vibr_gain", lua_input_vibr_gain)
	LUA_T_PUSH_S_CF("vibr_remove", lua_input_vibr_remove)
	LUA_T_PUSH_S_CF("vibr_start", lua_input_vibr_start)
	LUA_T_PUSH_S_CF("write_event", lua_input_write_event)


	return 1;
}
