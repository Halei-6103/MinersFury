extends Node2D
## A blob of poison lobbed from one enemy to another when venom spreads.
## Homes in on its target and adds stacks when it lands.

const FxSprite = preload("res://scenes/effects/fx_sprite.gd")

var target: Node2D
var stacks: int = 2
var _from := Vector2.ZERO
var _t: float = 0.0
var _trail: Array = []
const FLIGHT := 0.35
const ARC := 46.0


static func throw(parent: Node, from: Vector2, to: Node2D, n: int) -> void:
	var g = load("res://scenes/effects/poison_glob.gd").new()
	g.target = to
	g.stacks = n
	g._from = from
	parent.add_child(g)
	g.global_position = from


func _ready() -> void:
	z_index = 33


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		queue_free()
		return
	_t += delta
	var k := minf(_t / FLIGHT, 1.0)
	var to: Vector2 = target.global_position + Vector2(0, -20)
	var p := _from.lerp(to, k) + Vector2(0, -sin(k * PI) * ARC)
	global_position = p
	_trail.push_front(p)
	if _trail.size() > 6:
		_trail.pop_back()
	queue_redraw()
	if k >= 1.0:
		FxSprite.spawn(get_parent(), "poison_pop", target.global_position + Vector2(0, -16), {"scale": 1.0, "z": 32})
		load("res://scenes/effects/poison_status.gd").apply(target, stacks, true)
		queue_free()


func _draw() -> void:
	for i in _trail.size():
		var q: Vector2 = _trail[i] - global_position
		var a := 1.0 - float(i) / _trail.size()
		draw_circle(q, 5.0 * a, Color(0.35, 0.75, 0.25, 0.6 * a))
	draw_circle(Vector2.ZERO, 7.0, Color(0.1, 0.2, 0.08))
	draw_circle(Vector2.ZERO, 5.5, Color(0.45, 0.9, 0.3))
	draw_circle(Vector2(-2, -2), 2.0, Color(0.85, 1.0, 0.7))
