Engine.IO

- [ ] timeouts ([if the client does not receive a ping packet within pingInterval + pingTimeout, then it SHOULD consider that the connection is closed](https://github.com/socketio/socket.io/blob/main/docs/engine.io-protocol/v4-current.md#heartbeat))
- [ ] support binary data ([headers](https://github.com/socketio/socket.io/blob/main/docs/engine.io-protocol/v4-current.md#headers), [base64 encoded and `b` prefix](https://github.com/socketio/socket.io/blob/main/docs/engine.io-protocol/v4-current.md#packet-encoding))
- [ ] noop packet
- [ ] packet ordering for send data in case of client disconnection for a while?
- [ ] WebTransport [Add support for WebTransport in Godot](https://github.com/godotengine/godot-proposals/issues/3899)
- [ ] reconnection in case of network glitch or server restart?

Socket.IO

- [ ] TBD
