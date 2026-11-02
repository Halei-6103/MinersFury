extends Node2D
## Necromancer spell: a green rune glows on the ground where you're standing,
## then a bolt drops and bursts. Get out of the circle (or block facing it).
##   NecroBolt.cast(parent, ground_pos, damage)

const FxSprite = preload("res://scenes/effects/fx_sprite.gd")
const Juice = preload("res://scenes/effects/juice.gd")

## seconds of warning before it lands
const WARN := 0.85
## hit radius on the ground (iso ellipse)
const RADIUS := 38.0

var damage: int = 2
var _t: float = 0.0
var _fired: bool = false


static func cast(parent: Node, at: Vector2, dmg: int) -> void:
	var b = load("res://scenes/enemies/melee/necro_bolt.gd").new()
	b.damage = dmg
	b.position = at
	# the warning circle goes on the floor layer so it shows under everyone
	var ground = parent.get_tree().current_scene.get_node_or_null("Ground")
	(ground if ground else parent).add_child(b)
	b.global_position = at


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	_t += delta
	if not _fired and _t >= WARN:
		_fired = true
		_strike()
	if _t > WARN + 0.25:
		queue_free()
	queue_redraw()


func _strike() -> void:
	var lvl: Node = get_tree().current_scene.get_node_or_null("Entities")
	if lvl == null:
		lvl = get_parent()
	FxSprite.spawn(lvl, "necro_bolt", global_position, {"scale": 2.0, "z": 30})
	FxSprite.spawn(lvl, "poison_cloud", global_position, {"scale": 1.5, "z": 29})
	Juice.shake(self, 0.3)
	if damage <= 0:
		return   # a co-op copy, just for show
	for p in get_tree().get_nodes_in_group("players_all"):
		if not p.has_method("take_damage"):
			continue
		var off: Vector2 = p.global_position - global_position
		if Vector2(off.x, off.y * 2.0).length() <= RADIUS * 1.2:
			p.take_damage(damage, global_position, null)


func _draw() -> void:
	if _fired:
		return
	var k := _t / WARN
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, RADIUS * 1.2, Color(0.25, 0.6, 0.15, 0.12 + 0.18 * k))
	draw_arc(Vector2.ZERO, RADIUS * 1.2, 0.0, TAU, 40, Color(0.05, 0.12, 0.04, 0.8), 5.0)
	draw_arc(Vector2.ZERO, RADIUS * 1.2, 0.0, TAU, 40, Color(0.55, 1.0, 0.35, 0.9), 2.0)
	# inner ring closes in as it's about to land
	draw_arc(Vector2.ZERO, RADIUS * 1.2 * (1.0 - k), 0.0, TAU, 32, Color(0.75, 1.0, 0.55, 0.9), 2.0)
	draw_set_transform(Vector2.ZERO)
