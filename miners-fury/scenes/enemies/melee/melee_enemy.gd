extends CharacterBody2D
## Ground monster that walks up, telegraphs, and swings. One script for every
## walker in the pack; set `kind` before adding it to the tree.
##
## Difficulty vs a bat (3 HP, 1 dmg):
##   slime     4 HP, 1 dmg  slow, hops at you, light
##   skeleton  5 HP, 1 dmg  readable sword swing, great parry practice
##   orc       8 HP, 2 dmg  slow heavy chop, doesn't flinch mid-swing
##   werebear 30 HP, 2 dmg  boss: big, fast claws, never flinches, parry to open it up
##   werewolf  6 HP, 1 dmg  fast, pounces, double slash
##   armored skeleton  9 HP, 1 dmg  shrugs off hits mid-swing
##   greatsword skeleton 12 HP, 2 dmg  slow huge swings, parry bait
##   necromancer 40 HP  boss: scythe up close, drops green bolts on you, raises skeletons
##
## "drops": [[item_id, chance], ...] spawn as pickups when it dies.

signal died

const Juice = preload("res://scenes/effects/juice.gd")
const FxSprite = preload("res://scenes/effects/fx_sprite.gd")

const KINDS := {
	"slime": {
		"frames": "res://assets/sprites/enemies/slime/slime_frames.tres",
		"hp": 4, "damage": 1, "speed": 55.0, "scale": 2.0,
		"attack_range": 46.0, "reach": 30.0, "windup": 0.4, "cooldown": 1.7,
		"attacks": ["attack1"], "hits": {"attack1": [[3, 4]]}, "lunge": 230.0,
		"knock_resist": 0.0, "armored_attacks": false, "boss": false, "launch": true,
		"ichor": Color(0.32, 0.7, 0.22), "foot_y": 57.0, "body_y": 50.0, "radius": 12.0,
		"drops": [["slime_goo", 0.9]],
	},
	"skeleton": {
		"frames": "res://assets/sprites/enemies/skeleton/skeleton_frames.tres",
		"hp": 5, "damage": 1, "speed": 72.0, "scale": 2.0,
		"attack_range": 52.0, "reach": 36.0, "windup": 0.45, "cooldown": 1.5,
		"attacks": ["attack1"], "hits": {"attack1": [[3, 4]]}, "lunge": 110.0,
		"knock_resist": 0.15, "armored_attacks": false, "boss": false, "launch": true,
		"ichor": Color(0.86, 0.83, 0.72), "foot_y": 58.0, "body_y": 49.0, "radius": 12.0,
		"drops": [["bone", 1.0]],
	},
	"orc": {
		"frames": "res://assets/sprites/enemies/orc/orc_frames.tres",
		"hp": 8, "damage": 2, "speed": 58.0, "scale": 2.2,
		"attack_range": 56.0, "reach": 40.0, "windup": 0.6, "cooldown": 1.9,
		"attacks": ["attack1", "attack2"], "hits": {"attack1": [[3, 4]], "attack2": [[3, 4]]}, "lunge": 80.0,
		"knock_resist": 0.55, "armored_attacks": true, "boss": false, "launch": false,
		"ichor": Color(0.55, 0.08, 0.1), "foot_y": 58.0, "body_y": 49.0, "radius": 14.0,
		"drops": [["orc_tusk", 1.0]],
	},
	"werebear": {
		"frames": "res://assets/sprites/enemies/werebear/werebear_frames.tres",
		"hp": 30, "damage": 2, "speed": 80.0, "scale": 3.0,
		"attack_range": 78.0, "reach": 56.0, "windup": 0.55, "cooldown": 1.3,
		"attacks": ["attack1", "attack2"], "hits": {"attack1": [[5, 6]], "attack2": [[4, 5], [9, 10]]}, "lunge": 140.0,
		"knock_resist": 0.9, "armored_attacks": true, "boss": true, "launch": false,
		"ichor": Color(0.45, 0.08, 0.1), "foot_y": 58.0, "body_y": 48.0, "radius": 20.0,
		"drops": [["wolf_pelt", 1.0], ["wolf_pelt", 1.0]],
	},
	"werewolf": {
		"frames": "res://assets/sprites/enemies/werewolf/werewolf_frames.tres",
		"hp": 6, "damage": 1, "speed": 105.0, "scale": 2.2,
		"attack_range": 62.0, "reach": 40.0, "windup": 0.38, "cooldown": 1.25,
		"attacks": ["attack1", "attack2"], "hits": {"attack1": [[5, 6]], "attack2": [[8, 9], [11, 12]]}, "lunge": 250.0,
		"knock_resist": 0.2, "armored_attacks": false, "boss": false, "launch": true,
		"ichor": Color(0.5, 0.1, 0.1), "foot_y": 58.0, "body_y": 50.0, "radius": 13.0,
		"drops": [["wolf_pelt", 1.0]],
	},
	"armored_skeleton": {
		"frames": "res://assets/sprites/enemies/armored_skeleton/armored_skeleton_frames.tres",
		"hp": 9, "damage": 1, "speed": 62.0, "scale": 2.2,
		"attack_range": 56.0, "reach": 40.0, "windup": 0.5, "cooldown": 1.7,
		"attacks": ["attack1"], "hits": {"attack1": [[4, 5]]}, "lunge": 120.0,
		"knock_resist": 0.5, "armored_attacks": true, "boss": false, "launch": false,
		"ichor": Color(0.8, 0.78, 0.7), "foot_y": 58.0, "body_y": 47.0, "radius": 13.0,
		"drops": [["bone", 1.0], ["bone", 0.5]],
	},
	"greatsword_skeleton": {
		"frames": "res://assets/sprites/enemies/greatsword_skeleton/greatsword_skeleton_frames.tres",
		"hp": 12, "damage": 2, "speed": 52.0, "scale": 2.4,
		"attack_range": 72.0, "reach": 56.0, "windup": 0.7, "cooldown": 2.0,
		"attacks": ["attack1", "attack2"], "hits": {"attack1": [[4, 6]], "attack2": [[6, 9]]}, "lunge": 90.0,
		"knock_resist": 0.7, "armored_attacks": true, "boss": false, "launch": false,
		"ichor": Color(0.8, 0.78, 0.7), "foot_y": 58.0, "body_y": 47.0, "radius": 15.0,
		"drops": [["bone", 1.0], ["bone", 1.0]],
	},
	"necromancer": {
		"frames": "res://assets/sprites/enemies/necromancer/necromancer_frames.tres",
		"hp": 40, "damage": 2, "speed": 62.0, "scale": 2.6,
		"attack_range": 80.0, "reach": 60.0, "windup": 0.5, "cooldown": 1.4,
		"attacks": ["attack1"], "hits": {"attack1": [[5, 7]]}, "lunge": 60.0,
		"knock_resist": 0.9, "armored_attacks": true, "boss": true, "launch": false,
		"ichor": Color(0.3, 0.55, 0.2), "foot_y": 58.0, "body_y": 44.0, "radius": 16.0,
		"caster": true,
	},
	# the proficiency trial boss. Its own brain lives in pufferfish/puffer_boss.gd
	"pufferfish": {
		"frames": "res://assets/sprites/enemies/pufferfish/pufferfish_frames.tres",
		"hp": 55, "damage": 1, "speed": 80.0, "scale": 3.0,
		"attack_range": 0.0, "reach": 30.0, "windup": 0.5, "cooldown": 1.0,
		"attacks": ["attack1"], "hits": {"attack1": []}, "lunge": 0.0,
		"knock_resist": 0.9, "armored_attacks": true, "boss": true, "launch": false,
		"ichor": Color(0.35, 0.65, 0.9), "foot_y": 67.0, "body_y": 52.0, "radius": 22.0,
	},
}

@export var kind: String = "skeleton"
## the big "PARRY NOW" flash fires this many seconds before the hit lands
const TELL_LEAD := 0.35
@export var display_name: String = ""

enum State { SPAWNING, CHASE, WINDUP, ATTACK, HURT, STUNNED, DEAD, CAST }

const Pickup = preload("res://scenes/items/pickup.gd")
const LightningBolt = preload("res://scenes/effects/lightning_bolt.gd")

## Toxic Storm combo (poison rune + thunderclap): frozen solid, takes 30% more damage
var paralyzed: bool = false
var _dmg_carry: float = 0.0
const NecroBolt = preload("res://scenes/enemies/melee/necro_bolt.gd")

## raised by a Necromancer: climbs out of the ground, drops less loot
var summoned: bool = false
var no_drops: bool = false
var _minions: Array = []
var _cast_cd: float = 2.5
var _summon_cd: float = 1.5
var _cast_anim: String = ""
var _cast_fired: bool = false
var state: State = State.SPAWNING

var cfg: Dictionary
var health: int
var max_health: int
var ichor_color: Color
var cooldown: float = 0.5
var knockback: Vector2 = Vector2.ZERO
var attack_dir: Vector2 = Vector2.RIGHT
var windup_timer: float = 0.0
var stun_timer: float = 0.0
var _anim: String = ""
var _strike: int = -1
var _hit_strike: int = -1
var _bar_timer: float = 0.0
var _t: float = 0.0
var _airborne: bool = false
var _tell_at: float = 0.0       # seconds after the wind-up starts
var _tell_clock: float = 0.0
var _told: bool = true
var _tell_fx: float = 0.0       # drawing timer for the flash

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_area: Area2D = $AttackArea


func _ready() -> void:
	cfg = KINDS.get(kind, KINDS["skeleton"])
	add_to_group("enemy")
	max_health = cfg.hp
	health = max_health
	ichor_color = cfg.ichor
	if display_name == "":
		display_name = kind.capitalize()
	var s: float = cfg.scale
	sprite.sprite_frames = load(cfg.frames)
	sprite.scale = Vector2(s, s)
	# feet (baked shadow) sit on the node's position
	sprite.position = Vector2(0, -(cfg.foot_y - 50.0) * s)
	var body_h: float = (cfg.foot_y - cfg.body_y) * s
	($Body.shape as CircleShape2D).radius = cfg.radius
	hurtbox.position = Vector2(0, -body_h)
	(hurtbox.get_node("Shape").shape as CircleShape2D).radius = cfg.radius + 6.0 * s / 2.0
	(attack_area.get_node("Shape").shape as CircleShape2D).radius = cfg.reach * 0.75
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_check_hits)
	_spawn_in()


func _spawn_in() -> void:
	state = State.SPAWNING
	if summoned and sprite.sprite_frames.has_animation("summon"):
		# claw out of the ground (the animation ends -> CHASE)
		sprite.play("summon")
		return
	sprite.play("idle")
	modulate = Color(1, 1, 1, 0)
	sprite.position.y -= 30.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(sprite, "position:y", sprite.position.y + 30.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		state = State.CHASE
		Juice.shockwave(self, global_position, 18.0 * cfg.scale / 2.0))


func _player() -> Node2D:
	var p = get_tree().get_first_node_in_group("player")
	if p == null or p.state == p.State.DEAD:
		return null
	return p


func _physics_process(delta: float) -> void:
	_t += delta
	cooldown = maxf(cooldown - delta, 0.0)
	_tell_fx = maxf(_tell_fx - delta, 0.0)
	if not _told and (state == State.WINDUP or state == State.ATTACK):
		_tell_clock += delta
		if _tell_clock >= _tell_at:
			_big_tell()
	_bar_timer = maxf(_bar_timer - delta, 0.0)
	var p := _player()
	var to_p := Vector2.ZERO
	if p:
		to_p = p.global_position - global_position
	var hidden: bool = p != null and p.has_method("is_untargetable") and p.is_untargetable()

	match state:
		State.SPAWNING:
			velocity = Vector2.ZERO
		State.CHASE:
			if p == null or hidden:
				velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
				_play("idle")
			elif cfg.get("caster", false) and _try_cast(to_p, delta):
				pass
			else:
				var dir := (to_p.normalized() + _separation() * 0.8).normalized()
				velocity = velocity.move_toward(dir * cfg.speed, 900.0 * delta)
				_play("walk")
				_face(to_p.x)
				if to_p.length() < cfg.attack_range and cooldown <= 0.0:
					_start_windup(to_p)
		State.WINDUP:
			velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
			windup_timer -= delta
			# telegraph: shake and flash so you can read the swing (and time a parry)
			sprite.position.x = randf_range(-1.5, 1.5)
			if _tell_fx <= 0.0:
				var blink := int(windup_timer * 16.0) % 2 == 0
				sprite.modulate = Color(1.6, 1.3, 1.3) if blink else Color.WHITE
			if windup_timer <= 0.0:
				_start_attack(to_p)
		State.ATTACK:
			var w = _window_now()
			if w >= 0:
				velocity = attack_dir * cfg.lunge
			else:
				velocity = velocity.move_toward(Vector2.ZERO, 1400.0 * delta)
			_check_hits()
		State.HURT:
			velocity = knockback
			knockback = knockback.move_toward(Vector2.ZERO, 1100.0 * delta)
		State.STUNNED:
			velocity = knockback
			knockback = knockback.move_toward(Vector2.ZERO, 1100.0 * delta)
			stun_timer -= delta
			if stun_timer <= 0.0:
				_end_stun()
		State.DEAD:
			velocity = velocity.move_toward(Vector2.ZERO, (500.0 if _airborne else 2400.0) * delta)
		State.CAST:
			velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
			if p:
				_face(to_p.x)
			if not _cast_fired and sprite.frame >= 5:
				_cast_fired = true
				if _cast_anim == "summon":
					_raise_dead()
				else:
					_drop_bolts(p)
	move_and_slide()
	if state == State.DEAD and _airborne and get_slide_collision_count() > 0:
		_airborne = false
		velocity = Vector2.ZERO
	queue_redraw()


## keep monsters from stacking into one blob
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self:
			continue
		var d: Vector2 = global_position - e.global_position
		var l := d.length()
		if l > 0.1 and l < 40.0:
			push += d / l * (1.0 - l / 40.0)
	return push


func _face(dx: float) -> void:
	if absf(dx) > 2.0:
		sprite.flip_h = dx < 0.0


func _play(a: String) -> void:
	if sprite.animation != a or not sprite.is_playing():
		sprite.play(a)


func _start_windup(to_p: Vector2) -> void:
	state = State.WINDUP
	windup_timer = cfg.windup
	_anim = cfg.attacks[randi() % cfg.attacks.size()]
	attack_dir = to_p.normalized()
	# schedule the bold tell so it always lands TELL_LEAD before the first hit
	var fps: float = maxf(sprite.sprite_frames.get_animation_speed(_anim), 1.0)
	var first_hit: int = cfg.hits[_anim][0][0]
	_tell_at = maxf(cfg.windup + first_hit / fps - TELL_LEAD, 0.0)
	_tell_clock = 0.0
	_told = false
	_face(to_p.x)
	sprite.play(_anim)
	sprite.pause()
	sprite.frame = 0


func _start_attack(to_p: Vector2) -> void:
	state = State.ATTACK
	sprite.position.x = 0.0
	sprite.modulate = Color.WHITE
	if to_p != Vector2.ZERO:
		attack_dir = to_p.normalized()   # last-second aim
	_face(attack_dir.x)
	attack_area.position = attack_dir * cfg.reach * 0.75 + Vector2(0, hurtbox.position.y * 0.5)
	_strike = -1
	_hit_strike = -1
	sprite.play(_anim)


func _window_now() -> int:
	if state != State.ATTACK:
		return -1
	var windows: Array = cfg.hits.get(String(sprite.animation), [])
	for i in windows.size():
		if sprite.frame >= windows[i][0] and sprite.frame <= windows[i][1]:
			return i
	return -1


func _check_hits() -> void:
	var w := _window_now()
	if w >= 0 and w != _strike:
		_strike = w
		_swipe_fx(w)
	if w < 0 or w == _hit_strike:
		return
	for b in attack_area.get_overlapping_bodies():
		if b.is_in_group("player") and b.has_method("take_damage"):
			_hit_strike = w
			b.take_damage(cfg.damage, global_position, self)
			return


## the Werebear's claws rip the air (effect pack 7), hit or miss
func _swipe_fx(strike: int) -> void:
	if kind != "werebear":
		return
	var at: Vector2 = global_position + attack_dir * cfg.reach * 0.45 + Vector2(0, -6)
	var left := attack_dir.x < 0.0
	if sprite.animation == "attack1":
		FxSprite.spawn(get_parent(), "claw_sweep", at, {"flip_h": left, "z": 30})
	else:
		# alternate sides on the double swipe
		FxSprite.spawn(get_parent(), "claw_burst", at, {"flip_h": left != (strike % 2 == 1), "z": 30})
	Juice.shake(self, 0.25)


## one big bold flash: block now!
func _big_tell() -> void:
	_told = true
	_tell_fx = 0.28
	sprite.modulate = Color(5, 5, 4)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.16)


func take_damage(amount: int, from_position: Vector2, knock_scale: float = 1.0) -> void:
	if state == State.DEAD or state == State.SPAWNING:
		return
	if state == State.STUNNED:
		if paralyzed:
			# +30%, carried over so small hits still add up
			var f := amount * 1.3 + _dmg_carry
			amount = int(floor(f))
			_dmg_carry = f - amount
		else:
			amount *= 2   # stunned = open for punishment
	health -= amount
	_bar_timer = 2.5
	var dir := (global_position - from_position).normalized()
	_flash()
	if health <= 0:
		_die(dir, knock_scale)
		return
	var resist: float = cfg.knock_resist
	var shove: Vector2 = dir * 380.0 * knock_scale * (1.0 - resist)
	if state == State.STUNNED:
		knockback = shove * 0.5
		return
	# heavy monsters keep swinging through your hits
	if cfg.armored_attacks and (state == State.WINDUP or state == State.ATTACK):
		return
	if cfg.boss:
		knockback = shove
		return
	knockback = shove
	_told = true
	state = State.HURT
	sprite.position.x = 0.0
	sprite.modulate = Color.WHITE
	sprite.play("hurt")


## poison ticks: hurts without interrupting what it's doing
func dot_damage(amount: int, color: Color = Color(0.55, 1.0, 0.35)) -> void:
	if state == State.DEAD or state == State.SPAWNING:
		return
	health -= amount
	_bar_timer = 2.5
	Juice.damage_number(get_parent(), global_position + Vector2(0, hurtbox.position.y * 2.0 - 6.0), str(amount), color, 16)
	if health <= 0:
		_die(Vector2.RIGHT if randf() < 0.5 else Vector2.LEFT, 0.6)


# ---------------------------------------------------------------- Necromancer spells

func _hp_low() -> bool:
	return health <= max_health / 2


func _alive_minions() -> int:
	_minions = _minions.filter(func(m): return is_instance_valid(m) and m.state != m.State.DEAD)
	return _minions.size()


## returns true if it started casting instead of walking
func _try_cast(to_p: Vector2, delta: float) -> bool:
	_cast_cd -= delta
	_summon_cd -= delta
	if _cast_cd > 0.0:
		return false
	var want := 3 if _hp_low() else 2
	if _summon_cd <= 0.0 and _alive_minions() < want:
		_start_cast("summon")
		return true
	# bolts when you're out of scythe range
	if to_p.length() > cfg.attack_range * 1.4:
		_start_cast("attack2")
		return true
	return false


func _start_cast(anim: String) -> void:
	state = State.CAST
	_cast_anim = anim
	_cast_fired = false
	sprite.play(anim)


func _drop_bolts(p: Node2D) -> void:
	if p == null:
		return
	var spots: Array = [p.global_position]
	if _hp_low():
		# enraged: a spread of three
		for i in 2:
			spots.append(p.global_position + Vector2.from_angle(randf() * TAU) * Vector2(1, 0.5) * randf_range(60, 100))
	for at in spots:
		NecroBolt.cast(get_parent(), at, cfg.damage)


func _raise_dead() -> void:
	var scene = load("res://scenes/enemies/melee/melee_enemy.tscn")
	var n := 2
	for i in n:
		var at: Vector2 = global_position + Vector2.from_angle(TAU * i / n + randf_range(-0.6, 0.6)) * Vector2(1, 0.5) * randf_range(70, 110)
		var floor_layer = get_tree().current_scene.get_node_or_null("Ground")
		FxSprite.spawn(floor_layer if floor_layer else get_parent(), "necro_circle", at, {"scale": 2.0, "z": 0})
		var m = scene.instantiate()
		m.kind = "armored_skeleton" if _hp_low() and i == 0 else "skeleton"
		m.summoned = true
		m.position = at
		get_parent().add_child(m)
		_minions.append(m)
	Juice.shake(self, 0.3)


func _flash() -> void:
	var base := sprite.modulate
	sprite.modulate = Color(3, 3, 3)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE if state != State.STUNNED else Color(0.85, 0.85, 1.2), 0.15)
	var s: float = cfg.scale
	sprite.scale = Vector2(s * 1.3, s * 0.72)
	var sq := create_tween()
	sq.tween_property(sprite, "scale", Vector2(s, s), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## parried! dazed, can't act, takes double damage
func stun(duration: float) -> void:
	if state == State.DEAD or state == State.SPAWNING:
		return
	paralyzed = false
	state = State.STUNNED
	_told = true
	stun_timer = duration * (0.6 if cfg.boss else 1.0)
	sprite.position.x = 0.0
	sprite.play("hurt")
	sprite.pause()
	sprite.frame = 1
	sprite.modulate = Color(0.85, 0.85, 1.2)
	knockback = attack_dir * -220.0 * (1.0 - cfg.knock_resist * 0.5)


## Toxic Storm: nerves locked up. Can't move or act. Bosses shake it off in half the time.
func paralyze(duration: float) -> void:
	if state == State.DEAD or state == State.SPAWNING:
		return
	stun(duration)
	paralyzed = true
	stun_timer = duration * (0.5 if cfg.boss else 1.0)
	knockback = Vector2.ZERO
	# locked mid-stance, not the red "hurt" frame
	sprite.play("idle")
	sprite.pause()
	sprite.modulate = Color(0.7, 1.0, 0.85)


func _end_stun() -> void:
	paralyzed = false
	state = State.CHASE
	cooldown = 0.6
	sprite.modulate = Color.WHITE
	sprite.play("walk")


func _die(dir: Vector2, knock_scale: float) -> void:
	state = State.DEAD
	collision_layer = 0
	hurtbox.monitorable = false
	sprite.position.x = 0.0
	sprite.self_modulate = Color.WHITE
	_drop_loot()
	# the dead stop walking when their master falls
	for m in _minions:
		if is_instance_valid(m) and m.state != m.State.DEAD:
			m.no_drops = true
			m.take_damage(999, global_position)
	died.emit()
	if cfg.launch:
		# small monsters get sent flying
		_airborne = true
		velocity = dir * 560.0 * clampf(knock_scale, 0.6, 1.3)
		sprite.play("hurt")
		sprite.pause()
		var base_y := sprite.position.y
		var tw := create_tween()
		tw.tween_property(sprite, "position:y", base_y - 46.0, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(sprite, "position:y", base_y, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(sprite, "rotation", TAU * 2.0 * signf(dir.x if dir.x != 0.0 else 1.0), 0.2)
		tw.tween_callback(_land)
	else:
		# heavy ones crumple where they stand
		velocity = dir * 120.0
		sprite.play("death")
		Juice.shake(self, 0.9 if cfg.boss else 0.5)
		Juice.shockwave(self, global_position, 30.0 if cfg.boss else 22.0)
		Juice.death_puff(get_parent(), global_position, ichor_color.darkened(0.3))


func _drop_loot() -> void:
	if no_drops:
		return
	for d in cfg.get("drops", []):
		if randf() < float(d[1]) * (0.4 if summoned else 1.0):
			Pickup.drop(get_parent(), global_position, "item", d[0])


func _land() -> void:
	_airborne = false
	sprite.rotation = 0.0
	Juice.death_puff(get_parent(), global_position, ichor_color.darkened(0.3))
	Juice.shockwave(self, global_position, 20.0)
	Juice.splat(self, global_position, velocity if velocity != Vector2.ZERO else Vector2.RIGHT, 3, ichor_color.darkened(0.35))
	Juice.shake(self, 0.35)
	sprite.play("death")


func _on_animation_finished() -> void:
	match state:
		State.SPAWNING:
			if sprite.animation == "summon":
				state = State.CHASE
				Juice.shockwave(self, global_position, 16.0)
		State.CAST:
			state = State.CHASE
			_cast_cd = 1.6 if _hp_low() else 2.4
			if _cast_anim == "summon":
				_summon_cd = 8.0
		State.ATTACK:
			state = State.CHASE
			cooldown = cfg.cooldown
		State.HURT:
			state = State.CHASE
			cooldown = maxf(cooldown, 0.35)
		State.DEAD:
			var tw := create_tween()
			tw.tween_interval(1.2)
			tw.tween_property(self, "modulate:a", 0.0, 0.6)
			tw.tween_callback(queue_free)


func _draw() -> void:
	var top: float = hurtbox.position.y * 2.0 - 10.0
	if _tell_fx > 0.0:
		_draw_tell(Vector2(0, hurtbox.position.y), top - 6.0, cfg.scale / 2.0)
	# paralysis: green-blue current crawling over the body
	if state == State.STUNNED and paralyzed:
		var by := hurtbox.position.y
		for i in 3:
			var a: Vector2 = Vector2(randf_range(-16, 16), by + randf_range(-18, 14)) * cfg.scale / 2.0
			var b: Vector2 = a + Vector2.from_angle(randf() * TAU) * randf_range(8, 16)
			LightningBolt.draw_bolt(self, LightningBolt.zigzag(a, b, 3.0, 5.0), 0.9, 0.5)
		_star(Vector2(0, top), Color(0.6, 1.0, 0.4))
	# dizzy stars while stunned
	elif state == State.STUNNED:
		for i in 3:
			var a := _t * 6.0 + TAU * i / 3.0
			var p := Vector2(cos(a) * 14.0, top + sin(a) * 5.0)
			_star(p, Color(1, 0.92, 0.3))
	# small health bar over hurt monsters (boss uses the big bar instead)
	if not cfg.boss and state != State.DEAD and _bar_timer > 0.0 and health < max_health:
		var w := 30.0
		var y := top - 8.0
		var a2 := clampf(_bar_timer, 0.0, 1.0)
		draw_rect(Rect2(-w / 2 - 1, y - 1, w + 2, 5), Color(0.08, 0.05, 0.07, a2))
		draw_rect(Rect2(-w / 2, y, w, 3), Color(0.25, 0.12, 0.14, a2))
		draw_rect(Rect2(-w / 2, y, w * health / max_health, 3), Color(0.9, 0.25, 0.25, a2))


func _star(p: Vector2, c: Color) -> void:
	draw_rect(Rect2(p - Vector2(1, 3), Vector2(2, 6)), c)
	draw_rect(Rect2(p - Vector2(3, 1), Vector2(6, 2)), c)
	draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1))



## big gold glint over the head + a ring snapping out from the body
func _draw_tell(body: Vector2, head_y: float, k: float) -> void:
	var p := 1.0 - _tell_fx / 0.28          # 0 -> 1
	var a := 1.0 - p
	var r := (14.0 + p * 30.0) * k
	draw_arc(body, r, 0.0, TAU, 28, Color(0.1, 0.05, 0.05, a * 0.8), 6.0)
	draw_arc(body, r, 0.0, TAU, 28, Color(1.0, 0.85, 0.25, a), 3.0)
	var g := (12.0 + 8.0 * sin(p * PI)) * k
	var c := Vector2(0, head_y)
	var dark := Color(0.1, 0.05, 0.05, a)
	var gold := Color(1.0, 0.9, 0.3, a)
	for pass_ in 2:
		var w := 3.0 if pass_ == 0 else 0.0
		var col := dark if pass_ == 0 else gold
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -g - w), c + Vector2(g * 0.22 + w, 0), c + Vector2(0, g + w), c + Vector2(-g * 0.22 - w, 0)]), col)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-g - w, 0), c + Vector2(0, g * 0.22 + w), c + Vector2(g + w, 0), c + Vector2(0, -g * 0.22 - w)]), col)
	draw_circle(c, 3.0 * k, Color(1, 1, 1, a))
