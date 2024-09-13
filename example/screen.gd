extends Node2D

@onready var client: SocketIO = $SocketIO
@onready var log_label: Label = $LogLabel
func _ready() -> void:
	client.event_received.connect(_on_socket_io_event_received)

func _on_socket_io_event_received(event: String, data: Variant, ns: String) -> void:
	print("SocketIO event received: name=", event, " --- data = ", data, " --- namespace = ", ns)
	log_label.text += "\n" + "event =" + event + " - data = " + str(data) + " --- namespace = " + ns

func _on_connect_pressed() -> void:
	client.connect_socket()

func _on_emit_search_pressed() -> void:
	client.emit("search", {"query": "Godot Engine", "limit": 5})


func _on_emit_simple_pressed() -> void:
	client.emit("ping")

func _on_connect_namespace_pressed() -> void:
	client.connect_to_namespace("/admin")

func _on_emit_in_admin_pressed() -> void:
	client.emit("version", null, "/admin")
