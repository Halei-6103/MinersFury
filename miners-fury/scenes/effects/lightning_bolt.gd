extends Node2D
## A jagged lightning bolt between two points that flickers and fades.
## Spawn with LightningBolt.zap(parent, from, to). Also has static helpers
## other effects use to draw bolts.

var from := Vector2.ZERO
var to := Vector2.ZERO
var life: float = 0.24
var width: float = 1.3          # 1.3 = chain bolt, 2+ = thunderclap strike
var forks: int = 1

const CORE := Color(1.0, 0.98, 0.82)
const YELLOW := Color(1.0, 0.86, 0.25)
const BLUE := Color(0.3, 0.6, 1.0)

var _t: float = 0.0
var _flick: float = 0.0
var _pts := PackedVector2Array()
var _forks: Array = []


static func zap(parent: Node, a: Vector2, b: Vector2, w: float = 1.0, life_: float = 0.24) -> Node2D:
	var z = load("res://scenes/effects/lightning_bolt.gd").new()
	z.from = a
	z.to = b
	z.width = w
	z.life = life_
	parent.add_child(z)
	return z


## jagged points from a to b
static func zigzag(a: Vector2, b: Vector2, jag: float, seg: float = 14.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var d := b - a
	var n := maxi(2, int(d.length() / seg))
	var side := d.orthogonal().normalized()
	pts.append(a)
	for i in range(1, n):
		var k := float(i) / n
		pts.append(a + d * k + side * randf_range(-jag, jag) * (1.0 - absf(k - 0.5)))
	pts.append(b)
	return pts


## glow + yellow + white-hot core, all with dark-free additive look
static func draw_bolt(ci: CanvasItem, pts: PackedVector2Array, alpha: float, w: float = 1.0) -> void:
	if pts.size() < 2:
		return
	ci.draw_polyline(pts, Color(BLUE.r, BLUE.g, BLUE.b, 0.55 * alpha), 7.0 * w)
	ci.draw_polyline(pts, Color(YELLOW.r, YELLOW.g, YELLOW.b, 0.9 * alpha), 4.0 * w)
	ci.draw_polyline(pts, Color(CORE.r, CORE.g, CORE.b, alpha), 1.6 * w)


func _ready() -> void:
	z_index = 40
	top_level = true
	global_position = Vector2.ZERO
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	material = m
	_regen()


func _regen() -> void:
	var jag := clampf(from.distance_to(to) * 0.12, 6.0, 18.0) * width
	_pts = zigzag(from, to, jag)
	_forks.clear()
	for i in forks:
		if _pts.size() < 3:
			break
		var at: Vector2 = _pts[randi_range(1, _pts.size() - 2)]
		var dir := (to - from).normalized().rotated(randf_range(-1.1, 1.1))
		_forks.append(zigzag(at, at + dir * randf_range(14.0, 26.0) * width, 4.0, 7.0))


func _process(delta: float) -> void:
	# flicker on the real clock so it still crackles during freeze frames
	var real := delta / maxf(Engine.time_scale, 0.001)
	_t += real
	_flick += real
	if _flick > 0.035:
		_flick = 0.0
		_regen()
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - _t / life
	a = a * a * (0.75 + 0.25 * randf())
	draw_bolt(self, _pts, a, width)
	for f in _forks:
		draw_bolt(self, f, a * 0.8, width * 0.6)
	draw_circle(to, 5.0 * width * a + 2.0, Color(CORE.r, CORE.g, CORE.b, a))
