# Network Implementation

The file `network_server.lua` is a simple server for distributing input events.

`network_client_sink.lua` contains a client for this server that receives input
events from the server and forwards them to an input device.

`network_client_source.lua` contain a client that forwards the events generated
by an input device to the server.

They all use `lua-socket` for networking.

This document describes the protocol used by these scripts.

# Network Protocol

All communication is line-based and case-sensitive.

The server accepts TCP connections from the clients.

On connection, the `server` requests the clients unique identifier via the `ID`
command.

The `client` responds with an `CLIENT_ID` command.

The `server` can now either configure the client to create a new input devices
for the `network_client_sink.lua` client, or configure the client for listening
to input events for the `network_client_source.lua` client:


## `network_client_sink.lua`

The server now sends a `CREATE` command to the sink client.
Now the server configures the new input device by calling the `BIT` command to
enable the correct event types and event codes. Afterwards the sever sends
the `SETUP` command to enable the device.


## `network_client_source.lua`

The server now sends a `LIST` command to list the available input devices on the
client. The client responds with a `CLIENT_DEVICE` command for each device.

Then the server sends the `LISTEN` command to start receiving events
from the specified device.
For each client input event, the client now sends a CLIENT_EVENT command.


# Packets

## Server -> Client
 * `ID` - Request client to send client ID(sink/source)
 * `CREATE` - Request client to create a new input device(sink)
 * `BIT [field] [bit]`- Request client to set a bit in the config field(sink)
 * `SETUP` - request a created input device to be made available(sink)
 * `CLOSE` - request to close an input device(sink/source)
 * `LIST` - request list of available input devices(source)
 * `LISTEN` - request to get the events from the specified input device(source)
 * `PING` - request the PONG command from the client(sent periodically)


## Client -> server
 * `CLIENT_ID [id] [type]` - answer to ID command, the client ID(sink/source). Type is the client type.
 * `CLIENT_EVENT [type] [code] [value]` - after LISTEN, this contains an client input event(source)
 * `CLIENT_DEVICE [name]` - after LIST, this contains an input device(source)
