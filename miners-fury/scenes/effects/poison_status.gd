extends Node2D
## Venom Blade poison living on an enemy.
##   PoisonStatus.apply(enemy, stacks)
## Every hit adds a stack (max 5). Each stack ticks damage over time.
## Hitting 5 stacks makes the poison burst and jump to the 2 closest enemies
## nearby (never across the map), giving them stacks too. The burst knocks
## this enemy back down to 3 stacks so you can build it up again.

const FxSprite = preload("res://scenes/effects/fx_sprite.gd")
const Juice = preload("res://scenes/effects/juice.gd")
const PoisonGlob = preload("res://scenes/effects/poison_glob.gd")

const MAX_STACKS := 5
## how long poison lasts after the last new stack
const DURATION := 4.5
const TICK := 0.9
## how far the poison can jump at 5 stacks, and to how many enemies
const SPREAD_RANGE := 140.0
const SPREAD_COUNT := 2
const SPREAD_STACKS := 2
const AFTER_BURST := 3

const GREEN := Color(0.55, 1.0, 0.35)

var stacks: int = 0
var _time_left: float = 0.0
var _tick: float = TICK
var _aura: AnimatedSprite2D
var _t: float = 0.0


static func apply(enemy: Node2D, n: int = 1, from_spread: bool = false) -> void:
	if enemy == null or not is_instance_valid(enemy) or _dead(enemy):
		return
	var s = enemy.get_node_or_null("Poison")
	if s == null:
		s = load("res://scenes/effects/poison_status.gd").new()
		s.name = "Poison"
		enemy.add_child(s)
	s.add_stacks(n, from_spread)


static func _dead(e) -> bool:
	return e.get("state") != null and e.state == e.State.DEAD


func _ready() -> void:
	z_index = 4
	_aura = AnimatedSprite2D.new()
	_aura.sprite_frames = FxSprite.frames_for("poison_aura", true)
	_aura.offset = FxSprite.anchor_offset("poison_aura")
	_aura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_aura.scale = Vector2(1, 1)
	_aura.modulate = Color(1, 1, 1, 0.6)
	add_child(_aura)
	_aura.play("default")


## from_spread: poison that jumped here can't set off another burst by itself
## (you have to hit it to finish the 5), so one spread never chains across a crowd
func add_stacks(n: int, from_spread: bool = false) -> void:
	var before := stacks
	stacks = mini(stacks + n, MAX_STACKS - 1 if from_spread else MAX_STACKS)
	_time_left = DURATION
	_tint()
	if stacks >= MAX_STACKS and before < MAX_STACKS:
		_burst.call_deferred()


func _tint() -> void:
	var spr = get_parent().get_node_or_null("AnimatedSprite2D")
	if spr == null:
		spr = get_parent().get_node_or_null("Sprite")
	if spr:
		spr.self_modulate = Color(1, 1, 1).lerp(Color(0.6, 1.0, 0.5), 0.25 + 0.12 * stacks)


func _burst() -> void:
	var me := get_parent() as Node2D
	if me == null or _dead(me):
		return
	var lvl := me.get_parent()
	FxSprite.spawn(lvl, "poison_burst", me.global_position, {"scale": 1.5, "z": 32})
	Juice.damage_number(lvl, me.global_position + Vector2(0, -70), "SPREAD!", GREEN, 18)
	Juice.shake(me, 0.25)
	# the 2 closest enemies in range catch it
	var near: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == me or _dead(e):
			continue
		var d: float = me.global_position.distance_to(e.global_position)
		if d <= SPREAD_RANGE:
			near.append([d, e])
	near.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(SPREAD_COUNT, near.size()):
		PoisonGlob.throw(lvl, me.global_position + Vector2(0, -20), near[i][1], SPREAD_STACKS)
	stacks = AFTER_BURST
	_tint()


func _process(delta: float) -> void:
	_t += delta
	var me := get_parent() as Node2D
	if me == null or _dead(me):
		_clear()
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_clear()
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		var dmg: int = 1 if stacks < 4 else 2
		# standing in a Venom rune: poison hurts double
		if load("res://scenes/effects/venom_zone.gd").boosted(self, me.global_position):
			dmg *= 2
		if me.has_method("dot_damage"):
			me.dot_damage(dmg, GREEN)
	queue_redraw()


func _clear() -> void:
	var spr = get_parent().get_node_or_null("AnimatedSprite2D") if get_parent() else null
	if spr:
		spr.self_modulate = Color.WHITE
	queue_free()


## stack pips over the head
func _draw() -> void:
	var me = get_parent()
	var top := -60.0
	var hb = me.get_node_or_null("Hurtbox")
	if hb:
		top = hb.position.y * 2.0 - 16.0
	var w := 7.0
	var x0 := -(MAX_STACKS * w) / 2.0
	for i in MAX_STACKS:
		var r := Rect2(x0 + i * w, top, w - 2.0, 4.0)
		draw_rect(r.grow(1.0), Color(0.06, 0.1, 0.05, 0.9))
		if i < stacks:
			var pulse := 0.8 + 0.2 * sin(_t * 8.0 + i)
			draw_rect(r, Color(GREEN.r * pulse, GREEN.g * pulse, GREEN.b * pulse))
		else:
			draw_rect(r, Color(0.15, 0.25, 0.12))


## Toxic Tornado hit an already-poisoned enemy: maxes out right away and the
## poison flies to the `count` closest enemies (wider reach than a normal burst)
func toxic_burst(count: int = 4) -> void:
	var me := get_parent() as Node2D
	if me == null or _dead(me):
		return
	stacks = MAX_STACKS
	_time_left = DURATION
	var lvl := me.get_parent()
	FxSprite.spawn(lvl, "poison_burst", me.global_position, {"scale": 2.0, "z": 32})
	Juice.damage_number(lvl, me.global_position + Vector2(0, -70), "SPREAD x%d!" % count, GREEN, 20)
	var near: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == me or _dead(e):
			continue
		var d: float = me.global_position.distance_to(e.global_position)
		if d <= SPREAD_RANGE * 1.8:
			near.append([d, e])
	near.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(count, near.size()):
		PoisonGlob.throw(lvl, me.global_position + Vector2(0, -20), near[i][1], SPREAD_STACKS + 1)
	_tint()
