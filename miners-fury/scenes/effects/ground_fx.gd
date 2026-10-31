extends Node2D
## Ground-level effects drawn flat on the floor (iso ellipses):
##  - "splat": an ichor splatter that sits on the sand and slowly fades
##  - "shockwave": an expanding ring when something slams down
## Spawn through Juice.splat(...) / Juice.shockwave(...).

var kind: String = "splat"
var color: Color = Color(0.45, 0.05, 0.28)
var radius: float = 8.0
var linger: float = 7.0
## seconds before it appears (splats wait for the droplets to land)
var delay: float = 0.0

var _t: float = 0.0
var _blobs: Array = []
var _popped: bool = false


func _ready() -> void:
	_t = -delay
	visible = delay <= 0.0
	if kind == "splat":
		# a main blob plus a few droplets, squashed 2:1 for the iso floor
		_blobs.append([Vector2.ZERO, radius])
		for i in randi_range(3, 6):
			var off := Vector2(randf_range(-1.6, 1.6), randf_range(-0.8, 0.8)) * radius
			_blobs.append([off, radius * randf_range(0.2, 0.45)])
		scale = Vector2(0.2, 0.2)


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.0:
		return
	if not _popped:
		_popped = true
		visible = true
		if kind == "splat":
			var tw := create_tween()
			tw.tween_property(self, "scale", Vector2.ONE, 0.08)
	if kind == "shockwave":
		if _t > 0.45:
			queue_free()
		queue_redraw()
	elif _t > linger:
		modulate.a = 1.0 - (_t - linger) / 1.5
		if _t > linger + 1.5:
			queue_free()


func _draw() -> void:
	if kind == "splat":
		for b in _blobs:
			_ellipse(b[0], b[1], color)
		# wet highlight
		_ellipse(Vector2(-radius * 0.25, -radius * 0.15), radius * 0.28, color.lightened(0.35))
	else:
		var p := _t / 0.45
		var r := radius * (0.3 + p * 1.7)
		var a := 1.0 - p
		_ring(r, Color(1, 0.95, 0.8, a), 4.0 * (1.0 - p) + 1.0)
		_ring(r * 0.75, Color(1, 0.8, 0.4, a * 0.6), 2.0)


func _ellipse(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * r * 1.4, sin(a) * r * 0.7))
	draw_colored_polygon(pts, col)


func _ring(r: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(Vector2(cos(a) * r * 1.4, sin(a) * r * 0.7))
	draw_polyline(pts, col, w)
