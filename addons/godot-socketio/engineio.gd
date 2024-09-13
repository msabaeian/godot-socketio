class_name EngineIO
extends Node

enum TransportType {
	POLLING,
	WEBSOCKET
}

enum EnginePacketType {
	OPEN,
	CLOSE,
	PING,
	PONG,
	MESSAGE,
	UPGRADE,
	NOOP,
	OK # only for pong response
}

enum State {
	CONNECTED,
	DISCONNECTED
}

# to avoid missunderstanding/missusage, the engine signals have been prefixed with "engine_" to distinguish them from the socket.io signals
signal engine_conncetion_opened()
signal engine_conncetion_closed()
signal engine_message_received(data: String)
signal engine_transport_upgraded()

const ENGINE_VERSION: int = 4

@export var autoconnect: bool = true
@export var base_url: String = "http://localhost"
@export var path: String = "/engine.io"

var session_id: String = ""
var state: State = State.DISCONNECTED

var _websocket: WebSocketPeer
var _polling_http_request: Request
var _send_data_http_request: Request
var _close_http_request: Request
var _send_data_queue: Array[String] = []
var _probe_sent = false
var _transport_type: TransportType = TransportType.POLLING
var _ping_interval: int = 0
var _pong_timeout: int = 0
var _max_payload: int = 0


func _ready():
	if autoconnect:
		engine_make_connection()


func _process(_delta):
	if not _transport_type == TransportType.WEBSOCKET:
		return

	_websocket.poll()
	var _socket_state := _websocket.get_ready_state()
	if _socket_state == WebSocketPeer.STATE_OPEN:
		if not _probe_sent:
			_websocket_send(EnginePacketType.PING, "probe")
			_probe_sent = true

		while _websocket.get_available_packet_count():
			var packets = _websocket.get_packet().get_string_from_utf8()
			if not packets.is_empty():
				_parse_packet(packets)
	elif _socket_state == WebSocketPeer.STATE_CLOSED:
		# TODO: reconnect if needed
		state = State.DISCONNECTED
		engine_close()
			
		
func engine_send(data: String):
	if state == State.DISCONNECTED:
		push_error("Connection has not established yet, make sure to call engine_make_connection() before sending data or set autoconnect to true")
		return

	if _transport_type == TransportType.WEBSOCKET:
		_websocket_send(EnginePacketType.MESSAGE, data)
		return

	_send_data_queue.append(data)
	if _send_data_queue.size() == 1:
		_http_send_data()


func engine_make_connection():
	if state == State.CONNECTED:
		push_error("Connection has already established")
		return

	if _polling_http_request == null:
		_polling_http_request = Request.new()
		add_child(_polling_http_request)
		_polling_http_request.on_response_received.connect(_parse_packet)
	
	_handshake()


func engine_close():
	if _transport_type == TransportType.WEBSOCKET:
		if state == State.CONNECTED:
			_websocket_send(EnginePacketType.CLOSE)
		_websocket.close()
		
	else:
		_clear_requests()

		if state == State.CONNECTED:
			_close_http_request = Request.new()
			add_child(_close_http_request)
			_close_http_request.on_response_received.connect(_close_http_completed)
			_close_http_request.request_post(_get_url(), str(EnginePacketType.CLOSE))

	engine_conncetion_closed.emit()
	_clear_values()


func _clear_values():
	session_id = ""
	state = State.DISCONNECTED
	_websocket = null
	_clear_requests()
	_send_data_queue.clear()
	_probe_sent = false
	_transport_type = TransportType.POLLING
	_ping_interval = 0
	_pong_timeout = 0
	_max_payload = 0


func _parse_packet(data: String):
	var messages := data.split("")
	for message in messages:
		match _get_packet_type(message):
			EnginePacketType.OPEN:
				_on_open(message)
			EnginePacketType.CLOSE:
				state = State.DISCONNECTED
				engine_close()
			EnginePacketType.PING:
				_on_ping()
			EnginePacketType.PONG:
				_on_pong()
			EnginePacketType.MESSAGE:
				_on_message(message.substr(1))
			EnginePacketType.NOOP:
				_on_noop()
			EnginePacketType.OK:
				_poll()
			_:
				push_error("unknown packet type in EngineIO, payload" % data)


func _handshake():
	_polling_http_request.request_get(_get_url())


func _close_http_completed(_response: String):
	_close_http_request.clear()


func _send_data_response(response: String):
	_send_data_queue.pop_front()
	if _send_data_queue.size() > 0:
		_http_send_data()


func _upgrade_transport():
	_clear_requests()
	_websocket = WebSocketPeer.new()
	_websocket.connect_to_url(_get_url())
	engine_transport_upgraded.emit()


func _on_open(body: String = ""):
	if body.is_empty():
		push_error("An error occurred in decoding socket packet, body is empty")
		return null
		
	var json = JSON.new()
	var error = json.parse(body.substr(1))
	if error != OK:
		push_error("An error occurred in decoding socket packet" + json.get_error_message())
		return


	state = State.CONNECTED

	session_id = json.data["sid"]
	_ping_interval = json.data["pingInterval"]
	_pong_timeout = json.data["pingTimeout"]
	_max_payload = json.data["maxPayload"]
	if "websocket" in json.data["upgrades"]:
		_transport_type = TransportType.WEBSOCKET
		_upgrade_transport()
	else:
		_transport_type = TransportType.POLLING
		engine_conncetion_opened.emit()
		_poll()
	

func _on_ping():
	if _transport_type == TransportType.WEBSOCKET:
		_websocket_send(EnginePacketType.PONG)
		return

	_polling_http_request.request_post(_get_url(), str(EnginePacketType.PONG))


func _on_pong():
	_websocket_send(EnginePacketType.UPGRADE)
	_transport_type = TransportType.WEBSOCKET
	engine_conncetion_opened.emit()


func _on_message(body: String = ""):
	engine_message_received.emit(body)
	_poll()


func _on_noop():
	push_error("NOOP received which is not handled yet")


func _poll():
	if not state == State.CONNECTED or not _transport_type == TransportType.POLLING:
		return
	_polling_http_request.request_get(_get_url())


func _send_ping():
	var error: int = _polling_http_request.request(_get_url(), [], HTTPClient.METHOD_POST, str(EnginePacketType.PING))
	if error != OK:
		push_error("An error occurred in HTTP request for EngineIO ping, error code = %d" % error)


func _http_send_data():
	if not state == State.CONNECTED:
		return

	if _send_data_http_request == null:
		_send_data_http_request = Request.new()
		_send_data_http_request.on_response_received.connect(self._send_data_response)
		add_child(_send_data_http_request)

	_send_data_http_request.request_post(_get_url(), "%s%s" % [str(EnginePacketType.MESSAGE), _send_data_queue[0]])


func _convert_http_to_ws(url: String) -> String:
	if url.begins_with("https"):
		url = url.replace("https", "wss")
	elif url.begins_with("http"):
		url = url.replace("http", "ws")
	else:
		url = "ws://%s" % url

	return url


func _get_url():
	var _url = "%s%s/?EIO=%d&transport=%s" % [base_url, path, ENGINE_VERSION, "polling" if _transport_type == TransportType.POLLING else "websocket"]
	
	if session_id:
		_url = "%s&sid=%s" % [_url, session_id]

	if _transport_type == TransportType.WEBSOCKET:
		_url = _convert_http_to_ws(_url)

	return _url


func _get_packet_type(data: String) -> EnginePacketType:
	if data.is_empty():
		return -1

	if data == "ok":
		return EnginePacketType.OK

	return int(data[0]) as EnginePacketType


func _clear_requests():
	for request in [_polling_http_request, _send_data_http_request]:
		if not request == null:
			request.clear()


func _websocket_send(type: EnginePacketType, payload: String = ""):
	_websocket.send_text("%s%s" % [type, payload])
