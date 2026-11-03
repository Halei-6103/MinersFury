extends Node2D
## Little sparkles drifting on the sea around the clam, so the water feels alive.

const R := 540.0
var _glints: Array = []
var _t: float = 0.0


func _ready() -> void:
	for i in 140:
		_glints.append(_new_glint(randf()))


func _new_glint(age: float) -> Array:
	var p := Vector2.ZERO
	while true:
		p = Vector2(randf_range(-1300, 1300), randf_range(-800, 820))
		# stay off the island (a mesa about 1024 x 608, cliffs at the bottom)
		if absf(p.x) > 540.0 or p.y < -310.0 or p.y > 340.0:
			break
	# [pos, life, age, width]
	return [p, randf_range(1.2, 2.6), age * 2.0, randf_range(4, 11)]


func _process(delta: float) -> void:
	_t += delta
	for g in _glints:
		g[2] += delta
		g[0].x += delta * 6.0
	for i in _glints.size():
		if _glints[i][2] > _glints[i][1]:
			_glints[i] = _new_glint(0.0)
	queue_redraw()


func _draw() -> void:
	for g in _glints:
		var k: float = g[2] / g[1]
		var a := sin(k * PI)
		var w: float = g[3] * (0.6 + 0.4 * a)
		var c := Color(0.85, 0.97, 1.0, 0.75 * a)
		draw_line(g[0] - Vector2(w, 0), g[0] + Vector2(w, 0), c, 2.0)
		if a > 0.8:
			draw_rect(Rect2(g[0] - Vector2(1, 2), Vector2(2, 2)), Color(1, 1, 1, a))
	# soft lines of surf around the island that breathe in and out
	var isl := Rect2(-512, -288, 1024, 608)
	var g1 := 10.0 + sin(_t * 1.6) * 4.0
	draw_rect(isl.grow(g1), Color(0.8, 0.95, 1.0, 0.25), false, 3.0)
	draw_rect(isl.grow(g1 + 16.0 + sin(_t * 1.6 + 1.0) * 4.0), Color(0.8, 0.95, 1.0, 0.12), false, 2.0)
