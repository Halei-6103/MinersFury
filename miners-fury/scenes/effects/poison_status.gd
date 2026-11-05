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
const RunState = preload("res://scenes/colosseum/run_state.gd")
const LightningBolt = preload("res://scenes/effects/lightning_bolt.gd")

var stacks: int = 0
## Colosseum: Deep Wounds lets it stack higher
var max_stacks: int = MAX_STACKS
var _death_done: bool = false
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
	max_stacks = 8 if RunState.now("deep_wounds") else maxi(max_stacks, MAX_STACKS)
	stacks = mini(stacks + n, max_stacks - 1 if from_spread else max_stacks)
	_time_left = DURATION
	_tint()
	if stacks >= max_stacks and before < max_stacks:
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
		_spread_extras(me, near[i][1])
	_burst_extras(me)
	stacks = AFTER_BURST
	_tint()


## Colosseum crystals that ride along when poison jumps
func _spread_extras(from: Node2D, to: Node2D) -> void:
	if RunState.now("flashpoint"):
		load("res://scenes/effects/burn_status.gd").apply(to, 3.0)
	if RunState.now("live_wire"):
		LightningBolt.zap(from.get_parent(), from.global_position + Vector2(0, -20), to.global_position + Vector2(0, -20), 1.2, 0.25)
		if to.has_method("take_damage"):
			to.take_damage(1, from.global_position, 0.2)
			RunState.add_dmg("Live Wire", 1)


## Colosseum crystals that go off at full stacks
func _burst_extras(me: Node2D) -> void:
	if RunState.now("boiling_blood"):
		var lvl := me.get_parent()
		FxSprite.spawn(lvl, "knight_fireball_end", me.global_position + Vector2(0, -20), {"scale": 1.5, "z": 36})
		for o in get_tree().get_nodes_in_group("enemy"):
			if _dead(o):
				continue
			if o.global_position.distance_to(me.global_position) < 90.0:
				load("res://scenes/effects/burn_status.gd").apply(o, 3.0)
	if RunState.now("shock_venom") and me.has_method("stun") and me.state != me.State.STUNNED:
		me.stun(0.6 + 0.4 * RunState.base_n("storm_daze"))


func _process(delta: float) -> void:
	_t += delta
	var me := get_parent() as Node2D
	if me == null or _dead(me):
		if me and stacks > 0:
			_on_death(me)
		_clear()
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_clear()
		return
	# Overload: stunned enemies tick twice as fast
	var speed := 2.0 if (RunState.now("overload") and me.get("state") != null and me.state == me.State.STUNNED) else 1.0
	_tick -= delta * speed
	if _tick <= 0.0:
		_tick = TICK
		var dmg: int = 1 + stacks / 4 + RunState.base_n("venom_potency")
		# standing in a Venom rune: poison hurts double
		if load("res://scenes/effects/venom_zone.gd").boosted(self, me.global_position):
			dmg *= 2
		if me.has_method("dot_damage"):
			me.dot_damage(dmg, GREEN)
			RunState.add_dmg("Poison", dmg)
	queue_redraw()


## Plague: a poisoned enemy died, the poison jumps to 2 nearby
func _on_death(me: Node2D) -> void:
	if _death_done or not RunState.now("plague"):
		return
	_death_done = true
	var lvl := me.get_parent()
	var near: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == me or _dead(e):
			continue
		var d: float = me.global_position.distance_to(e.global_position)
		if d <= SPREAD_RANGE:
			near.append([d, e])
	near.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(2, near.size()):
		PoisonGlob.throw(lvl, me.global_position + Vector2(0, -20), near[i][1], maxi(stacks / 2, 2))


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
	var w := 7.0 if max_stacks <= MAX_STACKS else 5.0
	var x0 := -(max_stacks * w) / 2.0
	for i in max_stacks:
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
