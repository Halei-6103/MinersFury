extends Node2D
## Electrical transfer board. Stand on it, press E, get zapped to another map.
## Put a Marker2D in the target scene named `arrival_spawn` and you'll land there.

@export var label: String = "Transfer"
@export_file("*.tscn") var target_scene: String = ""
@export var arrival_spawn: String = ""

@onready var glow: Sprite2D = $Glow
@onready var interact: Area2D = $Interact

var _t: float = 0.0
var _busy: bool = false


func _ready() -> void:
	interact.station_id = "transfer"
	interact.station_name = label
	if interact.prompt:
		interact.prompt.text = "[E] " + label
	interact.interacted.connect(_on_interacted)


func _process(delta: float) -> void:
	_t += delta
	if not _busy:
		glow.modulate.a = 0.55 + 0.3 * sin(_t * 3.0) + randf() * 0.08  # hum + flicker


func _on_interacted(_station: Area2D) -> void:
	if _busy or target_scene == "":
		return
	_busy = true
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(false)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color(0.7, 0.95, 1.0, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	var tw := create_tween()
	tw.tween_property(glow, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(glow, "scale", Vector2(1.2, 1.2), 0.35)
	tw.tween_property(flash, "color:a", 1.0, 0.3)
	tw.tween_callback(_go)


func _go() -> void:
	Engine.set_meta("arrival_spawn", arrival_spawn)
	get_tree().change_scene_to_file(target_scene)


## Call from a level's _ready(). Moves the player to the spawn marker
## the last transfer asked for, and fades in from the zap.
static func place_player(level: Node) -> void:
	if not Engine.has_meta("arrival_spawn"):
		return
	var spawn_name: String = Engine.get_meta("arrival_spawn")
	Engine.remove_meta("arrival_spawn")
	var marker := level.find_child(spawn_name, true, false) as Node2D
	var player = level.get_tree().get_first_node_in_group("player")
	if marker and player:
		player.global_position = marker.global_position
	var layer := CanvasLayer.new()
	layer.layer = 100
	level.add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color(0.7, 0.95, 1.0, 1.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	var tw := level.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.5)
	tw.tween_callback(layer.queue_free)
