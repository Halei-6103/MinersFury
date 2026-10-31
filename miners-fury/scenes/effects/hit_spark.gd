extends Node2D
## Impact: a hot star flash on the hit point and anime impact rays shooting
## out the back of whatever got hit. Dark rims so it reads on sand.
## Spawn through Juice.spark(...).

var dir: Vector2 = Vector2.RIGHT
var big: bool = false          # finisher / kill = way more of everything
var ichor_color: Color = Color(0.5, 0.06, 0.32)

const FLASH_TIME := 0.18
var _t: float = 0.0
var _rays: Array = []


func _ready() -> void:
	z_index = 30
	var k := 1.9 if big else 1.0

	# impact rays: speed lines shooting out the back
	for i in int(7 * k):
		var a := randf_range(-0.45, 0.45)
		_rays.append([dir.rotated(a), randf_range(0.6, 1.0), randf_range(0.0, 0.04)])

	# (no falling particle bits: just the flash and rays, the splats land on the ground)
	get_tree().create_timer(0.4, false).timeout.connect(queue_free)


func _burst(amount: int, life: float, spread: float, vmin: float, vmax: float, smin: float, smax: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = max(amount, 1)
	p.lifetime = life
	p.direction = dir
	p.spread = spread
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.damping_min = vmax * 1.0
	p.damping_max = vmax * 1.5
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	add_child(p)
	p.emitting = true
	return p


func _ramp(colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	for i in colors.size():
		g.add_point(float(i) / float(colors.size() - 1), colors[i])
	return g


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if _t > FLASH_TIME:
		return
	var k := 1.0 - _t / FLASH_TIME
	var r := (44.0 if big else 30.0) * (0.75 + 0.5 * (1.0 - k))
	var side := dir.orthogonal()

	# impact rays shooting out the back
	for ray in _rays:
		var d: Vector2 = ray[0]
		var len_k: float = ray[1]
		var p: float = clamp((_t - ray[2]) / FLASH_TIME, 0.0, 1.0)
		var a := d * r * (0.3 + p * 1.6) * len_k
		var b := d * r * (0.9 + p * 2.6) * len_k
		draw_line(a, b, Color(0.12, 0.02, 0.08, k), 5.0)
		draw_line(a, b, Color(1, 1, 0.9, k), 2.0)

	# star: dark rim, then white
	var spike := PackedVector2Array([dir * r * 1.5, side * r * 0.24, -dir * r * 0.45, -side * r * 0.24])
	var cross := PackedVector2Array([side * r * 0.8, dir * r * 0.16, -side * r * 0.8, -dir * r * 0.16])
	draw_colored_polygon(_grow(spike, 3.0), Color(0.12, 0.02, 0.08, k))
	draw_colored_polygon(_grow(cross, 3.0), Color(0.12, 0.02, 0.08, k))
	draw_colored_polygon(spike, Color(1, 1, 1, k))
	draw_colored_polygon(cross, Color(1, 0.92, 0.5, k))
	draw_circle(Vector2.ZERO, r * 0.3 * k + 3.0, Color(1, 1, 1, k))


func _grow(pts: PackedVector2Array, px: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in pts:
		out.append(v + v.normalized() * px if v != Vector2.ZERO else v)
	return out
