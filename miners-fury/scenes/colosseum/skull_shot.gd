extends Node2D
## Charred Skull drop: a parry fires a flaming skull (Zerie's Ghostfire art) that
## homes in on the closest enemy.
##   SkullShot.fire(level, from, index)   # index fans them out when there's more than one

const FxSprite = preload("res://scenes/effects/fx_sprite.gd")
const Juice = preload("res://scenes/effects/juice.gd")
const RunState = preload("res://scenes/colosseum/run_state.gd")

const SPEED := 330.0
const TURN := 7.0
const DAMAGE := 2
const LIFE := 3.0

var vel := Vector2.ZERO
var _t: float = 0.0
var _spr: AnimatedSprite2D


static func fire(level: Node, from: Vector2, index: int = 0) -> void:
	var s = load("res://scenes/colosseum/skull_shot.gd").new()
	s.vel = Vector2.UP.rotated((index - 1) * 0.7) * SPEED
	level.add_child(s)
	s.global_position = from


func _ready() -> void:
	z_index = 34
	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = load("res://assets/sprites/enemies/ghostfire/ghostfire_frames.tres")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.position = Vector2(0, 12)
	add_child(_spr)
	_spr.play("idle")


func _target() -> Node2D:
	var best: Node2D = null
	var best_d := 520.0
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not e.has_method("take_damage"):
			continue
		if e.get("state") != null and e.state == e.State.DEAD:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _process(delta: float) -> void:
	_t += delta
	if _t > LIFE:
		queue_free()
		return
	var t := _target()
	if t:
		var want: Vector2 = (t.global_position + Vector2(0, -20) - global_position).normalized() * SPEED
		vel = vel.lerp(want, clampf(TURN * delta, 0.0, 1.0))
		if global_position.distance_to(t.global_position + Vector2(0, -20)) < 22.0:
			t.take_damage(DAMAGE, global_position, 0.6)
			RunState.add_dmg("Skulls", DAMAGE)
			FxSprite.spawn(get_parent(), "knight_fireball_end", global_position, {"scale": 0.8, "z": 35})
			Juice.damage_number(get_parent(), global_position + Vector2(0, -16), str(DAMAGE), Color(1.0, 0.6, 0.3), 22)
			queue_free()
			return
	global_position += vel * delta
	_spr.flip_h = vel.x < 0.0
