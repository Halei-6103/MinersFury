extends Node2D
## Little lightning crackles living on the Storm Blade.
## Child of the player. Idle: small sparks along the blade. Swinging: a storm
## around the sword's reach.

const LightningBolt = preload("res://scenes/effects/lightning_bolt.gd")

## blade from hand to tip, in player space, facing right (matches the idle pose)
const BLADE_A := Vector2(13, 0)
const BLADE_B := Vector2(33, 9)

var _bolts: Array = []   # [points, life, max_life, width]
var _spawn_t: float = 0.0
var _glow_t: float = 0.0


func _ready() -> void:
	z_index = 3
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	material = m


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.001)
	var p := get_parent()
	_glow_t += real
	var attacking: bool = p.state == p.State.ATTACK
	_spawn_t -= real
	if _spawn_t <= 0.0:
		_spawn_t = randf_range(0.02, 0.05) if attacking else randf_range(0.06, 0.14)
		if attacking:
			_spawn_swing(p)
		elif p.state != p.State.DEAD and p.state != p.State.ROLL:
			_spawn_blade(p)
	for b in _bolts:
		b[1] -= real
	_bolts = _bolts.filter(func(b): return b[1] > 0.0)
	queue_redraw()


func _spawn_blade(p) -> void:
	var a := BLADE_A
	var b := BLADE_B
	if not p.facing_right:
		a.x = -a.x
		b.x = -b.x
	var start := a.lerp(b, randf())
	var dir := Vector2.UP.rotated(randf_range(-1.4, 1.4))
	var pts := LightningBolt.zigzag(start, start + dir * randf_range(5.0, 11.0), 2.5, 4.0)
	var life := randf_range(0.05, 0.1)
	_bolts.append([pts, life, life, 0.45])


func _spawn_swing(p) -> void:
	var center: Vector2 = p.sword_hitbox.position
	var aim: Vector2 = p.aim_indicator.last_direction
	var at := center + aim.rotated(randf_range(-1.6, 1.6)) * randf_range(10.0, 40.0)
	var dir := (at - center).normalized().rotated(randf_range(-0.8, 0.8))
	var pts := LightningBolt.zigzag(at, at + dir * randf_range(12.0, 24.0), 4.0, 6.0)
	var life := randf_range(0.06, 0.12)
	_bolts.append([pts, life, life, 0.7])


func _draw() -> void:
	var p := get_parent()
	# faint charge glow along the blade when not swinging
	if p.state != p.State.ATTACK and p.state != p.State.ROLL and p.state != p.State.DEAD:
		var a := BLADE_A
		var b := BLADE_B
		if not p.facing_right:
			a.x = -a.x
			b.x = -b.x
		var k := 0.5 + 0.5 * sin(_glow_t * 9.0)
		draw_line(a, b, Color(0.25, 0.55, 1.0, 0.4 + 0.2 * k), 6.0)
		draw_line(a, b, Color(1.0, 0.86, 0.3, 0.55 + 0.25 * k), 2.0)
	for b in _bolts:
		var alpha: float = b[1] / b[2]
		LightningBolt.draw_bolt(self, b[0], alpha, b[3])
