extends Node2D
## Storm Blade finisher: lightning slams down from the sky and an electric
## ring blasts out along the ground. Visual only, the player does the damage.

const LightningBolt = preload("res://scenes/effects/lightning_bolt.gd")

var radius: float = 100.0
const LIFE := 0.38
var _t: float = 0.0
var _arcs: Array = []


func _ready() -> void:
	z_index = 20
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	material = m
	# the strike from above (2 bolts, one fat)
	var p := global_position
	LightningBolt.zap(get_parent(), p + Vector2(randf_range(-40, 40), -320), p, 2.6, 0.3)
	LightningBolt.zap(get_parent(), p + Vector2(randf_range(-90, 90), -300), p + Vector2(randf_range(-20, 20), 0), 1.3, 0.22)
	_regen()


func _regen() -> void:
	_arcs.clear()
	var r := radius * _k()
	for i in 10:
		var a := randf() * TAU
		var s := Vector2(cos(a), sin(a) * 0.5) * r * 0.3
		var e := Vector2(cos(a), sin(a) * 0.5) * r
		_arcs.append(LightningBolt.zigzag(s, e, 6.0, 10.0))


func _k() -> float:
	var x := clampf(_t / (LIFE * 0.6), 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


func _process(delta: float) -> void:
	var before := _t
	_t += delta / maxf(Engine.time_scale, 0.001)
	if _t >= LIFE:
		queue_free()
		return
	if int(_t / 0.04) != int(before / 0.04):
		_regen()
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - _t / LIFE
	var r := radius * _k()
	# ground ring, squashed for the iso floor
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, r, Color(0.25, 0.55, 1.0, 0.16 * a))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(0.35, 0.7, 1.0, 0.7 * a), 10.0)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(1.0, 0.9, 0.35, a), 3.0)
	draw_circle(Vector2.ZERO, 26.0 * a, Color(1, 1, 0.85, a))
	draw_set_transform(Vector2.ZERO)
	for pts in _arcs:
		LightningBolt.draw_bolt(self, pts, a * 0.9, 0.8)
