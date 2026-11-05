extends Node2D
## Flame Blade ultimate: a fire tornado that spins up next to you and runs out in
## a straight line toward where you aimed. Everything it passes through takes a
## hit, gets set on fire, and is dragged a little along with it.
##   FireTornado.launch(level, from, flat_dir, distance)
## In co-op your teammates get a copy with remote = true: looks the same, hits nothing.
##
## Combos:
##   TOXIC TORNADO: runs through a Venom rune -> turns green. Poisons AND burns,
##     and blasts enemies away. An already-poisoned enemy maxes out on the spot
##     and the poison jumps to the 4 closest enemies.
##   DETONATE: land a Storm thunderclap on it -> it blows up. Big damage, burn,
##     stun, and electricity crackling on the ground after.

const FxSprite = preload("res://scenes/effects/fx_sprite.gd")
const Juice = preload("res://scenes/effects/juice.gd")
const BurnStatus = preload("res://scenes/effects/burn_status.gd")
const PoisonStatus = preload("res://scenes/effects/poison_status.gd")
const LightningBolt = preload("res://scenes/effects/lightning_bolt.gd")
const Sfx = preload("res://scenes/audio/sfx.gd")

const SPEED := 300.0          # flat floor units per second
const SPIN_UP := 0.35         # seconds it spins in place before it takes off
const HIT_R := 46.0           # flat radius
const DAMAGE := 2
const BURN := 4.0
const ART_SCALE := 1.7
## detonation (thunderclap on it)
const BOOM_R := 125.0
const BOOM_DAMAGE := 6
const BOOM_BURN := 5.0
const BOOM_STUN := 2.0
const SPARKS_LIFE := 3.0

var dir := Vector2.RIGHT      # flat (floor) direction
var distance: float = 420.0
var remote: bool = false
var toxic: bool = false
## Colosseum crystals: Firestorm (big), Exploding Tornado (boom_end), Scorched Path
var big: bool = false
var boom_end: bool = false
var scorch: bool = false
var _scorch_at: float = 0.0
const RunState = preload("res://scenes/colosseum/run_state.gd")
const FirePatch = preload("res://scenes/colosseum/fire_patch.gd")
var _t: float = 0.0
var _travelled: float = 0.0
var _hit: Array = []
var _spr: AnimatedSprite2D
var _phase: String = "coming"


static func launch(level: Node, from: Vector2, flat_dir: Vector2, dist: float, is_remote: bool = false, opts: Dictionary = {}) -> Node2D:
	var t = load("res://scenes/effects/fire_tornado.gd").new()
	t.dir = flat_dir.normalized() if flat_dir.length() > 0.01 else Vector2.RIGHT
	t.distance = dist
	t.remote = is_remote
	t.big = bool(opts.get("big", false))
	t.boom_end = bool(opts.get("boom_end", false))
	t.scorch = bool(opts.get("scorch", false))
	t.toxic = bool(opts.get("toxic", false))
	var ents = level.get_node_or_null("Entities")
	t.position = from
	(ents if ents else level).add_child(t)
	t.global_position = from
	return t


func _ready() -> void:
	add_to_group("fire_tornado")
	_spr = AnimatedSprite2D.new()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2.ONE * ART_SCALE * (1.6 if big else 1.0)
	add_child(_spr)
	_spr.animation_finished.connect(_on_anim_done)
	_play("tornado_coming", false)
	# the big WHOOSH, then it crackles while it runs
	Sfx.play(self, "flame_wall", global_position, 0.0, 0.04)
	Sfx.loop(self, "flame_hum", -6.0)
	Juice.shake(self, 0.45)
	Juice.shockwave(self, global_position, 26.0)


func _play(fx: String, loop: bool) -> void:
	_spr.sprite_frames = FxSprite.frames_for(fx, loop)
	_spr.offset = FxSprite.anchor_offset(fx)
	_spr.play("default")


func _on_anim_done() -> void:
	match _phase:
		"coming":
			_phase = "run"
			_play("toxic_tornado_idle" if toxic else "tornado_idle", true)
		"fade":
			queue_free()


## a thunderclap can only set it off while it's still spinning
func can_detonate() -> bool:
	return _phase != "fade" and _phase != "boom"


func _process(delta: float) -> void:
	_t += delta
	if _phase == "fade" or _phase == "boom":
		return
	if _t > SPIN_UP:
		var step := SPEED * (0.65 if big else 1.0) * delta * clampf((_t - SPIN_UP) / 0.25, 0.2, 1.0)
		_travelled += step
		global_position += Vector2(dir.x, dir.y * 0.5) * step
		# Scorched Path: a burning patch every so often
		if scorch and not remote and _travelled - _scorch_at > 44.0:
			_scorch_at = _travelled
			FirePatch.drop(get_parent(), global_position)
		if _travelled >= distance:
			# Exploding Tornado crystal: goes up at the end of its run
			if boom_end and not remote:
				detonate(true)
				return
			_phase = "fade"
			Sfx.stop_loop(self)
			_play("toxic_tornado_fade" if toxic else "tornado_fade", false)
			return
		# Firestorm: drags enemies in
		if big and not remote:
			_pull(delta)
	if not toxic:
		_check_rune()
	if not remote:
		_burn_things()
	queue_redraw()


# ---------------------------------------------------------------- toxic tornado

## ran into a Venom rune (yours or a teammate's): soak it up and turn green.
## Every copy checks on its own, so everyone sees it turn at the same spot
func _check_rune() -> void:
	for z in get_tree().get_nodes_in_group("venom_zone"):
		if z.contains(global_position):
			z.consume()
			_go_toxic()
			return


func _go_toxic() -> void:
	toxic = true
	_hit.clear()   # it gets a second go at everyone
	if _phase == "run":
		_play("toxic_tornado_idle", true)
	_spr.modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.4)
	Sfx.play(self, "venom_slam", global_position, -2.0, 0.05)
	FxSprite.spawn(get_parent(), "poison_burst", global_position, {"scale": 2.5, "z": 32})
	Juice.damage_number(get_parent(), global_position + Vector2(0, -120), "TOXIC TORNADO!", Color(0.55, 1.0, 0.35), 28)
	Juice.shake(self, 0.5)


func _burn_things() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e in _hit or not is_instance_valid(e):
			continue
		if e.get("state") != null and e.state == e.State.DEAD:
			continue
		var off: Vector2 = e.global_position - global_position
		if Vector2(off.x, off.y * 2.0).length() > HIT_R * (1.6 if big else 1.0):
			continue
		_hit.append(e)
		RunState.add_dmg("Tornado", DAMAGE)
		if toxic:
			# poisoned already? max it out and spread it to 4. Otherwise poison it
			var poison = e.get_node_or_null("Poison")
			if poison and poison.stacks > 0:
				poison.toxic_burst(4)
			else:
				PoisonStatus.apply(e, 3)
			BurnStatus.apply(e, BURN)
			# blasted away from the tornado
			e.take_damage(DAMAGE, global_position, 1.7)
			FxSprite.spawn(get_parent(), "poison_pop", e.global_position + Vector2(0, -20), {"scale": 2.0, "z": 35})
			Juice.damage_number(get_parent(), e.global_position + Vector2(0, -50), str(DAMAGE), Color(0.6, 1.0, 0.4), 24)
		else:
			# shoved from behind the tornado, so it drags them along the line
			var behind := global_position - Vector2(dir.x, dir.y * 0.5) * 30.0
			e.take_damage(DAMAGE, behind, 0.9)
			BurnStatus.apply(e, BURN)
			FxSprite.spawn(get_parent(), "knight_fireball_end", e.global_position + Vector2(0, -20), {"scale": 0.85, "z": 35})
			Juice.damage_number(get_parent(), e.global_position + Vector2(0, -50), str(DAMAGE), Color(1.0, 0.6, 0.2), 24)


# ---------------------------------------------------------------- detonation

## hit by a Storm thunderclap. deal = this player's game does the damage
## (the one who clapped). Everyone else just sees it go up.
func detonate(deal: bool) -> void:
	if not can_detonate():
		return
	_phase = "boom"
	Sfx.stop_loop(self)
	_spr.visible = false
	var at := global_position
	var lvl := get_parent()
	FxSprite.spawn(lvl, "fire_boom", at + Vector2(0, 6), {"scale": 3.2, "z": 40})
	Sfx.play(self, "fire_explosion", at, 2.0, 0.03)
	Juice.impact_flash(self, 0.55, Color(1.0, 0.75, 0.4))
	Juice.shake(self, 1.0)
	Juice.hit_stop(self, 0.12)
	Juice.zoom_punch(self, 0.12)
	Juice.shockwave(self, at, 60.0)
	Juice.damage_number(lvl, at + Vector2(0, -150), "DETONATE!", Color(1.0, 0.8, 0.3), 34)
	# electricity left crackling on the ground
	var sparks := Sparks.new()
	sparks.position = at
	lvl.add_child(sparks)
	sparks.global_position = at
	if deal:
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e) or (e.get("state") != null and e.state == e.State.DEAD):
				continue
			var off: Vector2 = e.global_position - at
			if Vector2(off.x, off.y * 2.0).length() > BOOM_R:
				continue
			e.take_damage(BOOM_DAMAGE, at, 1.5)
			RunState.add_dmg("Explosions", BOOM_DAMAGE)
			BurnStatus.apply(e, BOOM_BURN)
			if e.get("state") != null and e.state != e.State.DEAD and e.has_method("stun"):
				e.stun(BOOM_STUN)
			LightningBolt.zap(lvl, at + Vector2(0, -30), e.global_position + Vector2(0, -20), 0.9, 0.25)
			Juice.damage_number(lvl, e.global_position + Vector2(0, -56), str(BOOM_DAMAGE) + "!", Color(1.0, 0.7, 0.25), 32)
	get_tree().create_timer(0.1, false).timeout.connect(queue_free)


func _pull(delta: float) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or (e.get("state") != null and e.state == e.State.DEAD):
			continue
		var c = e.get("cfg")
		if typeof(c) == TYPE_DICTIONARY and c.get("boss", false):
			continue
		var off: Vector2 = global_position - e.global_position
		var flat := Vector2(off.x, off.y * 2.0)
		if flat.length() < HIT_R * 3.5 and flat.length() > 6.0:
			e.global_position += off.normalized() * 70.0 * delta


## a warm glow on the floor under it (green when toxic)
func _draw() -> void:
	if _phase == "fade" or _phase == "boom":
		return
	var k := clampf(_t / SPIN_UP, 0.0, 1.0)
	var c1 := Color(0.5, 1.0, 0.3, 0.22) if toxic else Color(1.0, 0.45, 0.1, 0.22)
	var c2 := Color(0.75, 1.0, 0.5, 0.25) if toxic else Color(1.0, 0.75, 0.3, 0.25)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 34.0 * k, c1)
	draw_circle(Vector2.ZERO, 20.0 * k, c2)
	draw_set_transform(Vector2.ZERO)


## little lightning crackles left on the ground after a detonation (visual only)
class Sparks extends Node2D:
	const LB = preload("res://scenes/effects/lightning_bolt.gd")
	var _t: float = 0.0
	var _bolts: Array = []    # [points, life, max_life]
	var _spawn: float = 0.0

	func _ready() -> void:
		z_index = 5

	func _process(delta: float) -> void:
		_t += delta
		var left: float = 3.0 - _t
		if left <= 0.0 and _bolts.is_empty():
			queue_free()
			return
		_spawn -= delta
		if left > 0.0 and _spawn <= 0.0:
			# busy at first, thinning out
			_spawn = lerpf(0.015, 0.12, clampf(_t / 3.0, 0.0, 1.0))
			var a := Vector2.from_angle(randf() * TAU) * randf_range(10.0, 110.0)
			a.y *= 0.5
			var b := a + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 26.0) * Vector2(1, 0.6)
			var life := randf_range(0.06, 0.14)
			_bolts.append([LB.zigzag(a, b, 3.0, 5.0), life, life])
		for bo in _bolts:
			bo[1] -= delta
		_bolts = _bolts.filter(func(bo): return bo[1] > 0.0)
		queue_redraw()

	func _draw() -> void:
		for bo in _bolts:
			LB.draw_bolt(self, bo[0], bo[1] / bo[2], 0.9)
