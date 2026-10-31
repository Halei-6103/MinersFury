extends Node2D
## Big crescent sword swipe toward the aim. Spawn through Juice.slash(...).
## Drawn as segments (always renders), white-hot core with a dark rim so it
## pops on light sand and dark rock alike.

var dir: Vector2 = Vector2.RIGHT
var radius: float = 46.0
var thickness: float = 18.0
var sweep: float = 2.5          # radians the arc covers
var flip: bool = false          # swing the other way (combos alternate)
var color: Color = Color(1, 1, 1)

const LIFE := 0.18
var _t: float = 0.0


func _ready() -> void:
	z_index = 28
	get_tree().create_timer(0.6, false).timeout.connect(queue_free)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if _t > LIFE:
		return
	var p := _t / LIFE                       # 0 -> 1
	# the arc wipes in fast, then the tail eats it
	var head: float = clamp(0.6 + p * 2.0, 0.0, 1.0)
	var tail: float = clamp((p - 0.35) * 1.6, 0.0, 1.0)
	if head - tail < 0.02:
		return
	var fade := 1.0 - p * 0.5
	_band(head, tail, thickness + 6.0, radius, Color(0.12, 0.03, 0.1, 0.85 * fade))   # dark rim
	_band(head, tail, thickness, radius, Color(color.r, color.g, color.b, fade))         # main
	_band(head, tail, thickness * 0.35, radius + thickness * 0.15, Color(1, 1, 1, fade)) # hot edge


func _band(head: float, tail: float, thick: float, rad: float, col: Color) -> void:
	var steps := 20
	var start := dir.angle() - sweep / 2.0
	var prev_o := Vector2.ZERO
	var prev_i := Vector2.ZERO
	for i in steps + 1:
		var u := float(i) / steps
		var f := lerpf(tail, head, u)
		var a := start + (sweep * (1.0 - f) if flip else sweep * f)
		# fat in the middle, pointed at both ends, fatter toward the leading edge
		var w := thick * sin(u * PI) * (0.55 + 0.45 * u)
		var o := Vector2.from_angle(a) * (rad + w * 0.5)
		var n := Vector2.from_angle(a) * (rad - w * 0.5)
		if i > 0:
			var quad := PackedVector2Array([prev_o, o, n, prev_i])
			if (prev_o - prev_i).length() + (o - n).length() > 0.6:
				draw_polygon(quad, PackedColorArray([col, col, col, col]))
		prev_o = o
		prev_i = n
