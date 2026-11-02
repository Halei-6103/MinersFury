extends Node2D
## Sparks (Storm Blade) or poison drips (Venom Blade) flying off the swing.
## The blade's color is baked into the player sprite, this only adds the extras.

const LightningBolt = preload("res://scenes/effects/lightning_bolt.gd")

## blade from hand to tip, in player space, facing right (matches the idle pose)
const BLADE_A := Vector2(13, 0)
const BLADE_B := Vector2(33, 9)

## Venom Blade uses the same aura in green: poison drips instead of sparks
var venom: bool = false
## Flame Blade: embers float up off the blade instead
var flame: bool = false
var _bolts: Array = []   # [points, life, max_life, width]
var _drips: Array = []   # [pos, vel, life, max_life]
var _spawn_t: float = 0.0
var _glow_t: float = 0.0


func _ready() -> void:
	z_index = 3
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	material = m


func _process(delta: float) -> void:
	var real := minf(delta / maxf(Engine.time_scale, 0.001), 0.05)
	var p := get_parent()
	_glow_t += real
	var attacking: bool = p.state == p.State.ATTACK
	_spawn_t -= real
	if _spawn_t <= 0.0:
		_spawn_t = randf_range(0.02, 0.05) if attacking else randf_range(0.06, 0.14)
		# only while swinging: the blade sprite itself carries the color now
		if attacking:
			if venom or flame:
				_spawn_drip(p, true)
			else:
				_spawn_swing(p)
	for b in _bolts:
		b[1] -= real
	_bolts = _bolts.filter(func(b): return b[1] > 0.0)
	for d in _drips:
		d[2] -= real
		d[1].y += (-40.0 if flame else 260.0) * real
		d[0] += d[1] * real
	_drips = _drips.filter(func(d): return d[2] > 0.0)
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


func _spawn_drip(p, attacking: bool) -> void:
	var at: Vector2
	if attacking:
		var aim: Vector2 = p.aim_indicator.last_direction
		at = p.sword_hitbox.position + aim.rotated(randf_range(-1.4, 1.4)) * randf_range(10.0, 36.0)
	else:
		var a := BLADE_A
		var b := BLADE_B
		if not p.facing_right:
			a.x = -a.x
			b.x = -b.x
		at = a.lerp(b, randf())
	var life := randf_range(0.25, 0.45)
	var vel := Vector2(randf_range(-10, 10), randf_range(-20, 5))
	if flame:
		vel = Vector2(randf_range(-14, 14), randf_range(-70, -35))
	_drips.append([at, vel, life, life])


func _spawn_swing(p) -> void:
	var center: Vector2 = p.sword_hitbox.position
	var aim: Vector2 = p.aim_indicator.last_direction
	var at := center + aim.rotated(randf_range(-1.6, 1.6)) * randf_range(10.0, 40.0)
	var dir := (at - center).normalized().rotated(randf_range(-0.8, 0.8))
	var pts := LightningBolt.zigzag(at, at + dir * randf_range(12.0, 24.0), 4.0, 6.0)
	var life := randf_range(0.06, 0.12)
	_bolts.append([pts, life, life, 0.7])


func _draw() -> void:
	for d in _drips:
		var al: float = d[2] / d[3]
		if flame:
			var c := Color(1.0, 0.9, 0.5).lerp(Color(0.95, 0.25, 0.05), 1.0 - al)
			draw_rect(Rect2(d[0] - Vector2(1.5, 1.5), Vector2(3, 3)), Color(c.r, c.g, c.b, al))
			continue
		draw_rect(Rect2(d[0] - Vector2(1.5, 1.5), Vector2(3, 4)), Color(0.12, 0.25, 0.08, al))
		draw_rect(Rect2(d[0] - Vector2(1, 1), Vector2(2, 3)), Color(0.55, 1.0, 0.35, al))
	for b in _bolts:
		var alpha: float = b[1] / b[2]
		LightningBolt.draw_bolt(self, b[0], alpha, b[3])
