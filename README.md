# Socket.IO Godot Client

This is a [Socket.IO](https://socket.io/) and [Engine.IO](https://socket.io/docs/v4/engine-io-protocol/) client addon for [Godot](https://godotengine.org/) written in [GDScript](https://gdscript.com/) that supports both HTTP long-polling and Websocket.

> This is still a work in progress and is not yet fully featured. Please make sure to check out the [#features](#features) section before using it. The current implementation is functional and works, but there are some known cases that have not been implemented or covered yet (like binary messages)

## Compatibility

| Godot | plugin version | Socket.IO server |
| -------------- | ---------------- | ---------------- |
| 4.3, 4.4, 4.5, 4.6 | 0.1.x | 4.x |

> I haven’t checked the current implementation with older versions of the Godot and Socket.IO server. I hereby ask you to do this and inform me if it works or not.

## Quickstart

Add the Socket.IO node to your tree and fill out the parameters in the Inspector, connect the signals via code or IDE, and use it.

```gdscript
@onready var client: SocketIO = $SocketIO

func _ready() -> void:
    client.socket_connected.connect(_on_socket_connected)
    client.event_received.connect(_on_event_received)

func _on_connect_pressed() -> void:
    client.connect_socket()

func _on_socket_connected() -> void:
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

## Testing the Example

The [example/](example/) folder contains a ready-made Socket.IO server (`socket.js`) and a Godot project that exercises the client.

### 0 — Link the addon into the example project

The example project expects the addon at `example/addons/godot-socketio/`. Because Godot cannot load files outside the project root, a symlink is needed (run once):

```bash
mkdir -p example/addons
ln -s ../../addons/godot-socketio example/addons/godot-socketio
```

### 1 — Start the Node.js server

```bash
cd example
npm install        # first time only — installs socket.io
node socket.js
```

The server listens on **http://localhost:3000**. Verify it is up:

```bash
curl "http://localhost:3000/socket.io/?EIO=4&transport=polling"
# expected: 0{"sid":"...","upgrades":["websocket"],...}
```

### 2 — Open the Godot project

Open Godot 4 and import `example/project.godot`. Make sure the **SocketIO** addon is enabled under *Project → Project Settings → Plugins*.

### 3 — Run and interact

Press **F5** (or the Play button) to run the scene. The UI exposes these actions:

| Button | What it does |
|---|---|
| **Connect** | Connects to `ws://localhost:3000` (default namespace) |
| **Emit ping** | Sends a `ping` event → server responds with `pong` |
| **Emit search** | Sends a `search` event with `{"query": "Godot Engine", "limit": 5}` |
| **Connect namespace** | Connects to the `/admin` namespace |
| **Emit in admin** | Sends a `version` event → server responds with `{"version": "4.3"}` |

Received events are printed in the Godot output panel and displayed in the on-screen log label.

### 4 — What to look for on the server side

The terminal running `node socket.js` will print:

```
connected to the default namespace
search ->  { query: 'Godot Engine', limit: 5 }
connected to the /admin namespace
```

## License

MIT
