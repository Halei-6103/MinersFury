extends Node2D
## Scorched Path crystal: a small fire left on the ground behind the tornado
## (fire pack v1, Fellor). Burns anything standing in it for a couple of seconds.
##   FirePatch.drop(level, at)

const FxSprite = preload("res://scenes/effects/fx_sprite.gd")
const BurnStatus = preload("res://scenes/effects/burn_status.gd")

const LIFE := 2.6
const RADIUS := 30.0

var _t: float = 0.0
var _check: float = 0.0
var _spr: AnimatedSprite2D


static func drop(level: Node, at: Vector2) -> void:
	var f = load("res://scenes/colosseum/fire_patch.gd").new()
	level.add_child(f)
	f.global_position = at


func _ready() -> void:
	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = FxSprite.frames_for("brazier_fire", true)
	_spr.offset = FxSprite.anchor_offset("brazier_fire")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(0.55, 0.55)
	add_child(_spr)
	_spr.play("default")
	_spr.frame = randi() % 12


func _process(delta: float) -> void:
	_t += delta
	if _t > LIFE:
		_spr.modulate.a = maxf(_spr.modulate.a - delta * 3.0, 0.0)
		if _spr.modulate.a <= 0.0:
			queue_free()
		return
	_check -= delta
	if _check <= 0.0:
		_check = 0.4
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.get("state") != null and e.state == e.State.DEAD:
				continue
			var off: Vector2 = e.global_position - global_position
			if Vector2(off.x, off.y * 2.0).length() < RADIUS:
				BurnStatus.apply(e, 2.0)
