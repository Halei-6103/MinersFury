extends Node2D
## While you hold R: a ring showing how far your ultimate can reach, and a
## marker where it will land (your cursor, pulled back inside the ring).

var color: Color = Color(0.3, 0.95, 1.0)
var max_range: float = 260.0
## size of the effect at the target (iso radius)
var target_radius: float = 90.0
var center := Vector2.ZERO
var target := Vector2.ZERO
## > 0: the ult runs in a line (Flame Blade tornado). Draws its path instead of a landing spot
var path_len: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	top_level = true
	z_index = 2


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	global_position = Vector2.ZERO
	var k := 0.5 + 0.5 * sin(_t * 8.0)
	if path_len > 0.0:
		_draw_path(k)
		return
	# reach ring around you
	draw_set_transform(center, 0.0, Vector2(1, 0.5))
	draw_arc(Vector2.ZERO, max_range, 0.0, TAU, 72, Color(0, 0, 0, 0.35), 5.0)
	draw_arc(Vector2.ZERO, max_range, 0.0, TAU, 72, Color(color.r, color.g, color.b, 0.45), 2.0)
	# where it lands
	draw_set_transform(target, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, target_radius, Color(color.r, color.g, color.b, 0.12 + 0.06 * k))
	draw_arc(Vector2.ZERO, target_radius, 0.0, TAU, 48, Color(0, 0, 0, 0.5), 5.0)
	draw_arc(Vector2.ZERO, target_radius, 0.0, TAU, 48, Color(color.r, color.g, color.b, 0.9), 2.0)
	draw_set_transform(Vector2.ZERO)
	draw_line(target + Vector2(-8, 0), target + Vector2(8, 0), Color.WHITE, 2.0)
	draw_line(target + Vector2(0, -5), target + Vector2(0, 5), Color.WHITE, 2.0)


## the tornado's lane: from you, out past your cursor
func _draw_path(k: float) -> void:
	var to := target - center
	var flat := Vector2(to.x, to.y * 2.0)
	if flat.length() < 1.0:
		flat = Vector2.RIGHT
	var d := flat.normalized()
	var nrm := Vector2(-d.y, d.x) * target_radius
	var sc := func(v: Vector2) -> Vector2: return center + Vector2(v.x, v.y * 0.5)
	var a: Vector2 = sc.call(nrm)
	var b: Vector2 = sc.call(d * path_len + nrm)
	var c: Vector2 = sc.call(d * path_len - nrm)
	var e: Vector2 = sc.call(-nrm)
	draw_colored_polygon(PackedVector2Array([a, b, c, e]), Color(color.r, color.g, color.b, 0.10 + 0.06 * k))
	for pair in [[a, b], [e, c]]:
		draw_line(pair[0], pair[1], Color(0, 0, 0, 0.5), 5.0)
		draw_line(pair[0], pair[1], Color(color.r, color.g, color.b, 0.9), 2.0)
	# chevrons running down the lane
	var n := 5
	for i in n:
		var t := fmod(_t * 0.8 + float(i) / n, 1.0)
		var p: Vector2 = d * path_len * t
		var tip: Vector2 = sc.call(p + d * 14.0)
		draw_line(sc.call(p + nrm * 0.5), tip, Color(1, 1, 1, 0.6 * (1.0 - t)), 2.0)
		draw_line(sc.call(p - nrm * 0.5), tip, Color(1, 1, 1, 0.6 * (1.0 - t)), 2.0)
