# lua-input

## v2 is currently very WIP. Use at your own risk.


## Description

A library for handling input in Lua.

Currently supports Linux Input Subsystem(aka. `/dev/input/event*` and `/dev/uinput`).

Planned to support multiple input sources and converting between various event types.




## Build

For compiling the C libraries running this in the top-level directory should
suffice:
```
make clean && make all
```


## Installing symlinks

Instead of running `make install` to copy the generated files, you can use these
commands to create symlinks(for development purposes):

```
sudo ln -s $(pwd)/lua/ /usr/local/share/lua/5.1/lua-input
sudo ln -s $(pwd)/src/input_linux.so /usr/local/lib/lua/5.1/

```



## Examples

Examples are in the `examples/` folder.



## Usage

You should always use `require("lua-input")` so that the Lua wrapper around the
C module can extend the functionality.

TODO(Currently see examples)
