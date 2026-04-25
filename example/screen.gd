extends Node2D

@onready var client: SocketIO = $SocketIO
@onready var log_label: Label = $LogLabel
@onready var base_url_input: LineEdit = $BaseUrlInput
@onready var path_input: LineEdit = $PathInput
@onready var token_input: LineEdit = $TokenInput
func _ready() -> void:
	client.socket_connected.connect(_on_socket_connected)
	client.event_received.connect(_on_socket_io_event_received)
	client.namespace_connection_error.connect(_on_namespace_connection_error)

func _on_socket_connected(ns: String) -> void:
	print("Socket connected: namespace=", ns)
	log_label.text += "\n" + "connected --- namespace = " + ns

func _on_socket_io_event_received(event: String, data: Variant, ns: String) -> void:
	print("SocketIO event received: name=", event, " --- data = ", data, " --- namespace = ", ns)
	log_label.text += "\n" + "event =" + event + " - data = " + str(data) + " --- namespace = " + ns

func _on_namespace_connection_error(name: String, data: Variant) -> void:
	print("Namespace connection error: name=", name, " --- data=", data)
	log_label.text += "\n" + "NAMESPACE ERROR: " + name + " - " + str(data)

func _on_connect_pressed() -> void:
	if base_url_input.text:
		client.base_url = base_url_input.text
	if path_input.text:
		client.path = path_input.text
	if token_input.text:
		client.connect_socket({"token": token_input.text})
	else:
		client.connect_socket()

func _on_emit_search_pressed() -> void:
	client.emit("search", {"query": "Godot Engine", "limit": 5})


func _on_emit_simple_pressed() -> void:
	client.emit("ping")

func _on_connect_namespace_pressed() -> void:
	client.connect_to_namespace("/admin")

func _on_emit_in_admin_pressed() -> void:
	client.emit("version", null, "/admin")
