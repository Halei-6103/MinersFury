extends Node2D
## On fire. Hangs off a monster and burns it for 1 damage every second until it
## runs out. Hitting it again tops the timer back up (no stacking, unlike poison).
##   BurnStatus.apply(enemy, 3.0)

const TICK := 1.0
const COLOR := Color(1.0, 0.55, 0.15)
const RunState = preload("res://scenes/colosseum/run_state.gd")
const PoisonStatus = preload("res://scenes/effects/poison_status.gd")
const FxSprite = preload("res://scenes/effects/fx_sprite.gd")

var left: float = 0.0
## Colosseum: Hotter crystals (+1 per tick each)
var bonus: int = 0
var _ran_out: bool = false
var _death_done: bool = false
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
	b.bonus = maxi(b.bonus, RunState.base_n("fire_hot"))
	b._ran_out = false


func _ready() -> void:
	z_index = 4
	var hb = get_parent().get_node_or_null("Hurtbox")
	if hb:
		position = hb.position


func _process(delta: float) -> void:
	var e := get_parent()
	if e.get("state") != null and e.state == e.State.DEAD:
		if left > 0.0:
			_on_death(e)
		queue_free()
		return
	left -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		if left > 0.0 and e.has_method("dot_damage"):
			e.dot_damage(1 + bonus, COLOR)
			RunState.add_dmg("Burn", 1 + bonus)
	if left <= 0.0 and not _ran_out:
		_ran_out = true
		# Heat Lightning: when the burn runs out, lightning finds it
		if RunState.now("heat_lightning"):
			var p = get_tree().get_first_node_in_group("player")
			if p and p.has_method("_sky_strike"):
				p._sky_strike(e, 2, "Heat Lightning")
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


## a burning enemy died (Colosseum crystals)
func _on_death(e: Node2D) -> void:
	if _death_done:
		return
	_death_done = true
	var lvl := e.get_parent()
	# Wildfire: the fire jumps to anyone close
	if RunState.now("wildfire"):
		FxSprite.spawn(lvl, "knight_fireball_end", e.global_position + Vector2(0, -16), {"scale": 1.4, "z": 36})
		for o in get_tree().get_nodes_in_group("enemy"):
			if o == e or (o.get("state") != null and o.state == o.State.DEAD):
				continue
			if o.global_position.distance_to(e.global_position) < 120.0:
				apply(o, 3.0)
	# Fumes: a poison cloud where it fell
	if RunState.now("fumes"):
		FxSprite.spawn(lvl, "poison_cloud", e.global_position, {"scale": 2.0, "z": 30})
		for o in get_tree().get_nodes_in_group("enemy"):
			if o == e or (o.get("state") != null and o.state == o.State.DEAD):
				continue
			var off: Vector2 = o.global_position - e.global_position
			if Vector2(off.x, off.y * 2.0).length() < 100.0:
				PoisonStatus.apply(o, 2)


func _draw() -> void:
	for m in _embers:
		var k: float = clampf(m[2] / 0.5, 0.0, 1.0)
		var c := Color(1.0, 0.85, 0.4).lerp(Color(0.9, 0.2, 0.05), 1.0 - k)
		c.a = k
		draw_rect(Rect2(m[0] - Vector2(1.5, 1.5), Vector2(3, 3) * (0.6 + k * 0.6)), c)
