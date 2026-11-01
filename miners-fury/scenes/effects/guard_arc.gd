extends Node2D
## Hex energy shield (effect pack 8) in front of the player while blocking.
## Pops up when you start blocking, hums while held, ripples when it eats a hit.
## Brighter and a bit bigger during the perfect-block (parry) window.

const FxSprite = preload("res://scenes/effects/fx_sprite.gd")

var dir: Vector2 = Vector2.RIGHT
var perfect: bool = false
## how far in front of you the shield floats
var radius: float = 26.0

var _arc: AnimatedSprite2D
var _was_visible: bool = false


func _ready() -> void:
	_arc = AnimatedSprite2D.new()
	_arc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_arc)
	_arc.animation_finished.connect(_on_arc_done)


func _play(fx_name: String, loop: bool) -> void:
	_arc.sprite_frames = FxSprite.frames_for(fx_name, loop)
	_arc.offset = FxSprite.anchor_offset(fx_name)
	_arc.play("default")


func _on_arc_done() -> void:
	if visible:
		_play("shield_idle", true)


func hit_flash(_c: Color = Color.WHITE) -> void:
	if visible:
		_play("shield_hit", false)


## full hex bubble bursting around you (parry)
func parry_burst() -> void:
	FxSprite.spawn(get_parent(), "shield_bubble", get_parent().global_position + Vector2(0, -14), {"z": 6, "speed": 1.2})


func _process(_delta: float) -> void:
	if visible and not _was_visible:
		_play("shield_start", false)
	_was_visible = visible
	if not visible:
		return
	# snap to 16 directions so the pixels stay tidy
	var a := snappedf(dir.angle(), PI / 8.0)
	_arc.rotation = a
	_arc.position = Vector2.from_angle(a) * radius
	_arc.scale = Vector2.ONE * (1.12 if perfect else 1.0)
	_arc.modulate = Color(1.5, 1.6, 1.6) if perfect else Color(1, 1, 1, 0.95)
