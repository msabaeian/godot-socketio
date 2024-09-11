class_name SocketIO
extends EngineIO

enum SocketPacketType {
	CONNECT,
	DISCONNECT,
	EVENT,
	ACK, # not supported
	CONNECT_ERROR,
	BINARY_EVENT, # not supported
	BINARY_ACK # not supported
}

# triggrered when the socket is connected to the server and namespace is connected
signal socket_connected(ns: String)
# triggrered when a namespace is connected
signal namespace_connected(name: String)
# triggrered when a namespace is disconnecte)
signal namespace_disconnected(name: String)
# triggrered when a namespace connection error occurred
signal namespace_connection_error(name: String, data: Variant)
# triggrered when an event is received
signal event_received(event: String, data: Variant, ns: String)
# triggered when the socket is disconnected (all namespaces have been disconnected)
signal socket_disconnected()

@export var default_namespace: String = ""
@export var socket_path = "/socket.io"

var _namespaces := {}

func _ready():
	self.path = socket_path
	if default_namespace.is_empty():
		default_namespace = "/"
	elif not default_namespace.begins_with("/"):
		default_namespace = "/" + default_namespace

	conncetion_opened.connect(_on_engine_io_conncetion_opened)
	message_received.connect(_socket_parse_packet)


## connects to the socket server, uses default namespace if not provided[br]
func connect_socket(ns: String = default_namespace):
	ns = _get_namespace_key(ns)
	_namespaces[ns] = {
		"sid": "",
		"state": State.DISCONNECTED
	}
	_send_socketio_packet(SocketPacketType.CONNECT, ns)


## emits an event to the socket server[br]
## Usage:
## [codeblock]
## emit("mesage", "hello!")
## emit("message", {"text": "hello!", priority: 1})
## emit("set_port", 22)
## emit("remove_user", {"id": 22}, "/admin") # custom namespace
## [/codeblock]
func emit(event: String, data: Variant = null, ns: String = default_namespace):
	ns = _get_namespace_key(ns)
	
	if not _namespace_exists(ns):
		return
	
	if not _namespaces[ns].state == State.CONNECTED:
		push_error("namespace is not connected")
		return
	
	if not data == null:
		_send_socketio_packet(SocketPacketType.EVENT, ns, JSON.stringify([event, data]))
	else:
		_send_socketio_packet(SocketPacketType.EVENT, ns, JSON.stringify([event]))


## disconnects a namespace[br]
## Usage:
## [codeblock]
## disconnect_namespace()
## disconnect_namespace("admin")
## disconnect_namespace("user")
## [/codeblock]
func disconnect_namespace(ns: String = default_namespace):
	ns = _get_namespace_key(ns)
	if not _namespace_exists(ns):
		return
	
	if not _namespaces[ns].state == State.CONNECTED:
		push_error("namespace is not connected")
		return
	
	_namespaces[ns].state = State.DISCONNECTED
	_send_socketio_packet(SocketPacketType.DISCONNECT, ns)


## disconnects all namespaces
func disconnect_socket():
	for ns in _namespaces.keys().filter(func(key): return _namespaces[key].state == State.CONNECTED):
		disconnect_namespace(ns)
	
	close()


func _on_engine_io_conncetion_opened():
	connect_socket()


func _on_namespace_connected(ns: String, data: Variant):
	if _namespaces.has(ns):
		_namespaces[ns].state = State.CONNECTED
		_namespaces[ns].sid = data["sid"]
	else:
		push_error("An error occurred in socket packet data, namespace not found in the client side")


func _on_namespace_disconnected(ns: String, data: Variant):
	if _namespaces.has(ns):
		_namespaces[ns].state = State.DISCONNECTED
	else:
		push_error("An error occurred in socket packet data, namespace not found in the client side")


func _on_namespace_connect_error(ns: String, data: Variant):
	if _namespaces.has(ns):
		_namespaces[ns].state = State.DISCONNECTED
		push_error("namespace connection error", data)


func _binary_not_supported():
	push_error("binary packets are not supported yet")


func _socket_parse_packet(data: String):
	var namespace_name = _get_namespace_key(default_namespace)
	var packet_type = _get_socket_packet_type(data)
	data = data.substr(1)

	if data.begins_with("/"): # this is from a custom namespace
		var sepretator_index := data.find(",")
		if sepretator_index == -1:
			push_error("An error occurred in parsing socket packet data, payload starts with an spash (/) but no separator found")
			return
		
		namespace_name = data.substr(0, sepretator_index)
		data = data.substr(sepretator_index + 1)

	if not _namespace_exists(namespace_name):
		return

	var payload = _parse_json(data);
	if payload == null:
		return
	
	match packet_type:
		SocketPacketType.CONNECT:
			_on_namespace_connected(namespace_name, payload)
		SocketPacketType.DISCONNECT:
			_on_namespace_disconnected(namespace_name, payload)
		SocketPacketType.EVENT:
			print("EVENT received", data)
		SocketPacketType.ACK:
			push_error("ACK packets are not supported yet")
		SocketPacketType.CONNECT_ERROR:
			_on_namespace_connect_error(namespace_name, payload)
		SocketPacketType.BINARY_EVENT:
			_binary_not_supported()
		SocketPacketType.BINARY_ACK:
			_binary_not_supported()
	
	
func _get_socket_packet_type(data: String) -> SocketPacketType:
	if data.is_empty():
		return -1

	return int(data[0]) as SocketPacketType


func _parse_json(data: String):
	if data.is_empty():
		return null
	var json = JSON.new()
	var error = json.parse(data)
	if error != OK:
		push_error("An error occurred in parsing socket packet data" + json.get_error_message(), "\n")
		return null
		
	return json.data


func _get_namespace_key(ns: String):
	if ns.begins_with("/"):
		return ns
	
	return "/" + ns


func _namespace_exists(ns: String):
	if not _namespaces.has(ns):
		push_error("namespace not found in the client")
		return false
	
	return true


func _send_socketio_packet(type: SocketPacketType, ns: String = default_namespace, payload: String = ""):
	ns = ns if ns != "/" else ""
	if not ns.is_empty() and not payload.is_empty():
		ns += ","
	send("%s%s%s" % [type, ns, payload])
