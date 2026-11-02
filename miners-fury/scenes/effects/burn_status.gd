extends Node2D
## On fire. Hangs off a monster and burns it for 1 damage every second until it
## runs out. Hitting it again tops the timer back up (no stacking, unlike poison).
##   BurnStatus.apply(enemy, 3.0)

const TICK := 1.0
const COLOR := Color(1.0, 0.55, 0.15)

var left: float = 0.0
var _tick: float = TICK
var _embers: Array = []   # [pos, vel, life]
var _spawn: float = 0.0


static func apply(enemy: Node, seconds: float = 3.0) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.get("state") != null and enemy.state == enemy.State.DEAD:
		return
	var b = enemy.get_node_or_null("Burn")
	if b == null:
		b = load("res://scenes/effects/burn_status.gd").new()
		b.name = "Burn"
		enemy.add_child(b)
	b.left = maxf(b.left, seconds)


func _ready() -> void:
	z_index = 4
	var hb = get_parent().get_node_or_null("Hurtbox")
	if hb:
		position = hb.position


func _process(delta: float) -> void:
	var e := get_parent()
	if e.get("state") != null and e.state == e.State.DEAD:
		queue_free()
		return
	left -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		if e.has_method("dot_damage"):
			e.dot_damage(1, COLOR)
	if left <= 0.0 and _embers.is_empty():
		queue_free()
		return
	# little flames licking up off it while it burns
	_spawn -= delta
	if left > 0.0 and _spawn <= 0.0:
		_spawn = randf_range(0.03, 0.08)
		_embers.append([Vector2(randf_range(-12, 12), randf_range(-4, 10)), Vector2(randf_range(-10, 10), randf_range(-70, -40)), randf_range(0.35, 0.6)])
	for m in _embers:
		m[2] -= delta
		m[0] += m[1] * delta
	_embers = _embers.filter(func(m): return m[2] > 0.0)
	queue_redraw()


func _draw() -> void:
	for m in _embers:
		var k: float = clampf(m[2] / 0.5, 0.0, 1.0)
		var c := Color(1.0, 0.85, 0.4).lerp(Color(0.9, 0.2, 0.05), 1.0 - k)
		c.a = k
		draw_rect(Rect2(m[0] - Vector2(1.5, 1.5), Vector2(3, 3) * (0.6 + k * 0.6)), c)
