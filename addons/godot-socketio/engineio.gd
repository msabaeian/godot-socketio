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
	NOOP
}

enum State {
	CONNECTED,
	DISCONNECTED
}

signal conncetion_opened()
signal conncetion_closed()
signal message_received(data: String)
signal transport_upgraded()

const ENGINE_VERSION: int = 4

@export var autoconnect: bool = true
@export var base_url: String = "localhost"
@export var path: String = "/engine.io"

var session_id: String = ""
var state: State = State.DISCONNECTED

var _websocket: WebSocketPeer
var _polling_http_request: HTTPRequest
var _pong_http_request: HTTPRequest
var _send_data_http_request: HTTPRequest
var _close_http_request: HTTPRequest
var _send_data_quee: Array[String] = []
var _pong_http_request_in_process = false
var _polling_http_request_in_process = false
var _probe_sent = false
var _transport_type: TransportType = TransportType.POLLING
var _ping_interval: int = 0
var _pong_timeout: int = 0
var _max_payload: int = 0


func _ready():
	if autoconnect:
		make_connection()


func _process(_delta):
	if not _transport_type == TransportType.WEBSOCKET:
		return
	
	_websocket.poll()
	var _socket_state := _websocket.get_ready_state()
	if _socket_state == WebSocketPeer.STATE_OPEN:
		if not _probe_sent:
			_websocket.send_text("%sprobe" % str(EnginePacketType.PING))
			_probe_sent = true

		while _websocket.get_available_packet_count():
			var packets = _websocket.get_packet().get_string_from_utf8()
			if not packets.is_empty():
				_parse_packet(packets)
	elif _socket_state == WebSocketPeer.STATE_CLOSED:
		# TODO: reconnect if needed
		state = State.DISCONNECTED
		close()
			
		
func send(data: String):
	if state == State.DISCONNECTED:
		push_error("Connection has not established yet, make sure to call make_connection() before sending data or set autoconnect to true")
		return

	if _transport_type == TransportType.WEBSOCKET:
		_websocket.send_text("%s%s" % [str(EnginePacketType.MESSAGE), data])
		return
	
	if _send_data_http_request == null:
		_send_data_http_request = HTTPRequest.new()
		_send_data_http_request.request_completed.connect(self._send_data_http_completed)
		add_child(_send_data_http_request)
		
	_send_data_quee.append(data)
	if _send_data_quee.size() == 1:
		_send_data()


func make_connection():
	if state == State.CONNECTED:
		push_error("Connection has already established")
		return

	_polling_http_request = HTTPRequest.new()
	add_child(_polling_http_request)
	_polling_http_request.request_completed.connect(self._polling_http_completed)
	_handshake()


func close():
	if _transport_type == TransportType.WEBSOCKET:
		if state == State.CONNECTED: _websocket.send_text(str(EnginePacketType.CLOSE))
		_websocket.close()
		
	else:
		if _polling_http_request:
			_polling_http_request.cancel_request()
			remove_child(_polling_http_request)

		if _pong_http_request:
			_pong_http_request.cancel_request()
			remove_child(_pong_http_request)

		if _send_data_http_request:
			_send_data_http_request.cancel_request()
			remove_child(_send_data_http_request)

		if state == State.CONNECTED:
			_close_http_request = HTTPRequest.new()
			add_child(_close_http_request)
			_close_http_request.request_completed.connect(_close_http_completed)
			_close_http_request.request(_get_url(), [], HTTPClient.METHOD_POST, str(EnginePacketType.CLOSE))

	conncetion_closed.emit()
	_clear_values()


func _clear_values():
	session_id = ""
	state = State.DISCONNECTED
	_websocket = null
	_polling_http_request = null
	_pong_http_request = null
	_send_data_http_request = null
	_send_data_quee.clear()
	_pong_http_request_in_process = false
	_polling_http_request_in_process = false
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
				close()
			EnginePacketType.PING:
				_on_ping()
			EnginePacketType.PONG:
				_on_pong()
			EnginePacketType.MESSAGE:
				_on_message(message.substr(1))
			EnginePacketType.NOOP:
				_on_noop()
			_:
				push_error("unknown packet type in EngineIO, payload" % data)


func _handshake():
	var error: int = _polling_http_request.request(_get_url())
	if error != OK:
		push_error("An error occurred in HTTP request for EngineIO handshake, error code = %d" % error)


func _close_http_completed(result: HTTPRequest.Result, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	remove_child(_close_http_request)


func _polling_http_completed(result: HTTPRequest.Result, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	_polling_http_request_in_process = false
	if result == HTTPRequest.Result.RESULT_SUCCESS and response_code == 200:
		_parse_packet(body.get_string_from_utf8())
	else:
		push_error("An error occurred in HTTP response of EngineIO, response code = %d, response body = %s" % [response_code, body.get_string_from_utf8()])


func _pong_http_completed(result: HTTPRequest.Result, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	_pong_http_request_in_process = false

	if not result == HTTPRequest.Result.RESULT_SUCCESS or not response_code == 200:
		push_error("An error occurred in HTTP response of EngineIO for pong, response code = %d, response body = %s" % [response_code, body.get_string_from_utf8()])
	else:
		_poll()


func _send_data_http_completed(result: HTTPRequest.Result, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if result == HTTPRequest.Result.RESULT_SUCCESS and response_code == 200:
		_send_data_quee.pop_front()

		if _send_data_quee.size() > 0:
			_send_data()
	else:
		push_error("An error occurred in HTTP response of EngineIO for sending data, response code = %d, response body = %s" % [response_code, body.get_string_from_utf8()])


func _upgrade_transport():
	transport_upgraded.emit()
	_polling_http_request.cancel_request()
	if _pong_http_request: _pong_http_request.cancel_request()
	_websocket = WebSocketPeer.new()
	_websocket.connect_to_url(_get_url())


func _on_open(body: String = ""):
	if body.is_empty():
		push_error("An error occurred in decoding socket packet, body is empty", "\n")
		return null
		
	var json = JSON.new()
	var error = json.parse(body.substr(1))
	if error != OK:
		push_error("An error occurred in decoding socket packet" + json.get_error_message(), "\n")
		return


	state = State.CONNECTED
	conncetion_opened.emit()

	session_id = json.data["sid"]
	_ping_interval = json.data["pingInterval"]
	_pong_timeout = json.data["pingTimeout"]
	_max_payload = json.data["maxPayload"]
	if "websocket" in json.data["upgrades"]:
		_transport_type = TransportType.WEBSOCKET
		_upgrade_transport()
	else:
		_transport_type = TransportType.POLLING
		_poll()


func _on_ping():
	if _transport_type == TransportType.WEBSOCKET:
		_websocket.send_text(str(EnginePacketType.PONG))
		return

	_send_http_pong()


func _on_pong():
	_websocket.send_text(str(EnginePacketType.UPGRADE))
	_transport_type = TransportType.WEBSOCKET


func _on_message(body: String = ""):
	message_received.emit(body)
	_poll()


func _on_noop():
	print("NOOP\n")


func _poll():
	if not _transport_type == TransportType.POLLING or _polling_http_request_in_process:
		return

	_polling_http_request_in_process = true
	var error: int = _polling_http_request.request(_get_url())
	if error != OK:
		push_error("An error occurred in HTTP request for polling, error code = %d" % error, "\n")


func _send_ping():
	var error: int = _polling_http_request.request(_get_url(), [], HTTPClient.METHOD_POST, str(EnginePacketType.PING))
	if error != OK:
		push_error("An error occurred in HTTP request for EngineIO ping, error code = %d" % error, "\n")


func _send_http_pong():
	if _pong_http_request_in_process:
		return

	if _pong_http_request == null:
		_pong_http_request = HTTPRequest.new()
		add_child(_pong_http_request)
		_pong_http_request.request_completed.connect(self._pong_http_completed)

	_pong_http_request_in_process = true
	var error: int = _pong_http_request.request(_get_url(), [], HTTPClient.METHOD_POST, str(EnginePacketType.PONG))
	if error != OK:
		push_error("An error occurred in HTTP request for EngineIO pong, error code = %d" % error, "\n")


func _send_data():
	_send_data_http_request.request(_get_url(), [], HTTPClient.METHOD_POST, "%s%s" % [str(EnginePacketType.MESSAGE), _send_data_quee[0]])


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

	return int(data[0]) as EnginePacketType
