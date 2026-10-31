extends Area2D
## A spot in the hub the player can walk up to and press E on.
## The hub listens for `interacted` and opens the right menu.

signal interacted(station: Area2D)
signal player_left(station: Area2D)

@export var station_id: String = "station"
@export var station_name: String = "Station"
@export_multiline var description: String = ""
@export var prompt_path: NodePath

var player_in_range: bool = false

@onready var prompt: Label = get_node_or_null(prompt_path)


func _ready() -> void:
	add_to_group("hub_station")
	_ensure_interact_action()
	collision_mask |= 8   # the player lives on layer 4
	if prompt:
		prompt.text = "[E] " + station_name
		prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## "interact" isn't in the Input Map yet, so add E at runtime.
## Once you add it in Project Settings > Input Map this does nothing.
static func _ensure_interact_action() -> void:
	if InputMap.has_action("interact"):
		return
	InputMap.add_action("interact")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	InputMap.action_add_event("interact", ev)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if prompt:
			prompt.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		if prompt:
			prompt.visible = false
		player_left.emit(self)


func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		interacted.emit(self)
