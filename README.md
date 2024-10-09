# Socket.IO Godot Client

This is a [Socket.IO](https://socket.io/) and [Engine.IO](https://socket.io/docs/v4/engine-io-protocol/) client addon for [Godot](https://godotengine.org/) written in [GDScript](https://gdscript.com/) that supports both HTTP long-polling and Websocket.

> This is still a work in progress and is not yet fully featured. Please make sure to check out the [#features](#features) section before using it. The current implementation is functional and works, but there are some known cases that have not been implemented or covered yet (like binary messages)

## Compatibility

| Godot | plugin version | Socket.IO server |
| -------------- | ---------------- | ---------------- |
| 4.3 | 0.1.x | 4.x |

> I haven’t checked the current implementation with older versions of the Godot and Socket.IO server. I hereby ask you to do this and inform me if it works or not.

## Quickstart

Add the Socket.IO node to your tree and fill out the parameters in the Inspector, connect the signals via code or IDE, and use it.

```py
@onready var client: SocketIO = $SocketIO

func _ready() -> void:
    client.socket_connected.connect(_on_socket_connected)
    client.event_received.connect(_on_event_received)

func _on_connect_pressed() -> void:
    client.make_connection()

func func _on_socket_connected() -> void:
    client.emit("hello")
    client.emit("some_event", { "value": 10 })

func _on_event_received(event: String, data: Variant, ns: String) -> void:
    print("event %s with %s as data received" % [event, data])
```

## Features

| Name | Status | Description
| -------------- | ---------------- | ---------------- |
| HTTP long-polling            | ✔️              | 
| Websocket            | ✔️              | 
| WebTransport            | ❌              | [requires: Add support for WebTransport in Godot](https://github.com/godotengine/godot-proposals/issues/3899)
| auto upgrade            | ✔️              | 
| emit events            | ✔️              | 
| listen to events            | ✔️              | 
| namespaces            | ✔️              | Multiplexing
| custom path            | ✔️              | 
| auth            | ✔️              | 
| automatic reconnection            | ❌              | reconnection attempts, delay, factor
| connection timeout            | ❌              | if the client does not receive a ping packet within pingInterval + pingTimeout, then it SHOULD consider that the connection is closed ([link](https://github.com/socketio/socket.io/blob/main/docs/engine.io-protocol/v4-current.md#heartbeat))
| query            | ❌              | additional query parameters that are sent when connecting a namespace `socket.handshake.query`
| extra headers            | ❌              |
| emit with acknowledgement            | ❌              | [acknowledgement](https://github.com/socketio/socket.io/blob/main/docs/socket.io-protocol/v5-current.md#acknowledgement-1)
| Websocket only            | ❌              | connect to Websocket only (disable polling)
| binary messages            | ❌              | 
| noop packet            | ❌              |
| error handling for HTTP requests            | ❌              | inside `request.gd`
| custom serializer            | ❌              | [Custom parser](https://socket.io/docs/v4/custom-parser/)
| C# API            | ❌              | 

## License

MIT
