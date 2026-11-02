extends "res://scenes/enemies/melee/melee_enemy.gd"
## Weapon Proficiency trial boss: the Pufferfish.
## It floats around you and spits water balls. Every so often it puffs up
## (spiky, hurts to touch) and casts Tetrodotoxin AT you: poison rune under
## your feet, thunderclap, two paralysis waves out the sides.
## If a wave paralyzes you, it follows up: one spiky body-slam while you're
## frozen ("geh!"). Below half health it spits three at a time and ults more often.
## Spawn: instantiate melee_enemy.tscn, set_script(this), kind = "pufferfish".

const WaterBall = preload("res://scenes/enemies/pufferfish/water_ball.gd")
const PufferUlt = preload("res://scenes/enemies/pufferfish/puffer_ult.gd")
const NetC = preload("res://scenes/core/net.gd")

enum Mode { SWIM, SPIT, ULT, LUNGE }

## how far it likes to stay from you (flat floor units)
const KEEP_AWAY := 250.0
const SPIT_FRAME := 4
const FIRST_ULT := 6.0
const ULT_EVERY := 13.0
const ULT_EVERY_ANGRY := 9.0
const SPIKE_R := 62.0
## the follow-up slam after it paralyzes you
const LUNGE_TELL := 0.3
const LUNGE_SPEED := 620.0
const LUNGE_HIT_R := 58.0
## drop sound files here and they play (wav / ogg / mp3), e.g. geh.ogg, gurgle.ogg
const SFX_DIR := "res://assets/audio/sfx/pufferfish/"

var mode: Mode = Mode.SWIM
var _mode_t: float = 2.0
var _shots: int = 0
var _spat: bool = false
var _gap: float = 0.0
var _ult_cd: float = FIRST_ULT
var _ult_t: float = 0.0
var _ult_cast: bool = false
var _thresholds: Array = [0.66, 0.33]
var _orbit: float = 1.0
var _back: bool = false
var _spike_cd: float = 0.0
var puffed: bool = false
var _lunge_t: float = 0.0
var _lunge_hit: bool = false
var _lunged: bool = false
var _lunge_target: Node2D = null


func _ready() -> void:
	super._ready()
	display_name = "Pufferfish"
	_orbit = 1.0 if randf() < 0.5 else -1.0


func _angry() -> bool:
	return health <= max_health / 2


func _fa(base: String) -> String:
	var b := "back_" + base
	if _back and sprite.sprite_frames.has_animation(b):
		return b
	return base


func _look(to_p: Vector2) -> void:
	_back = to_p.y < -12.0
	_face(to_p.x)


func _physics_process(delta: float) -> void:
	if net_remote:
		_remote_tick(delta)
		return
	_t += delta
	_bar_timer = maxf(_bar_timer - delta, 0.0)
	_spike_cd = maxf(_spike_cd - delta, 0.0)
	match state:
		State.SPAWNING:
			velocity = Vector2.ZERO
		State.HURT, State.STUNNED:
			velocity = knockback
			knockback = knockback.move_toward(Vector2.ZERO, 1100.0 * delta)
			if state == State.STUNNED:
				stun_timer -= delta
				if stun_timer <= 0.0:
					_end_stun()
		State.DEAD:
			velocity = velocity.move_toward(Vector2.ZERO, 2400.0 * delta)
		_:
			_brain(delta)
	if puffed:
		_spikes()
	# a fish floats: gentle bob on the sprite
	if state != State.DEAD:
		sprite.position.y = -(cfg.foot_y - 50.0) * cfg.scale + sin(_t * 3.0) * 3.0
	move_and_slide()
	queue_redraw()


func _brain(delta: float) -> void:
	var p := _player()
	if p == null:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		_play(_fa("idle"))
		return
	var to_p := p.global_position - global_position
	var flat := Vector2(to_p.x, to_p.y * 2.0)
	_ult_cd -= delta
	match mode:
		Mode.SWIM:
			_look(to_p)
			# circle you at a distance, drifting in and out
			var radial := flat.normalized() * clampf((flat.length() - KEEP_AWAY) / 90.0, -1.0, 1.0)
			var tangent := Vector2(-flat.y, flat.x).normalized() * _orbit * 0.7
			var mv: Vector2 = (radial + tangent + _separation()).normalized() * cfg.speed
			velocity = velocity.move_toward(Vector2(mv.x, mv.y * 0.5), 400.0 * delta)
			_play(_fa("walk"))
			_mode_t -= delta
			var hp_frac := float(health) / float(max_health)
			var crossed: bool = not _thresholds.is_empty() and hp_frac <= _thresholds[0]
			if (_ult_cd <= 0.0 or crossed) and flat.length() < 600.0:
				if crossed:
					_thresholds.pop_front()
				_start_ult()
			elif _mode_t <= 0.0:
				mode = Mode.SPIT
				_shots = 3 if not _angry() else 4
				_start_spit(to_p)
		Mode.SPIT:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			if _gap > 0.0:
				_gap -= delta
				if _gap <= 0.0:
					_start_spit(to_p)
				return
			if not _spat and sprite.frame >= SPIT_FRAME:
				_spat = true
				_spit(p)
		Mode.ULT:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			_ult_t += delta
			if not _ult_cast and _ult_t >= 0.55:
				_ult_cast = true
				PufferUlt.cast(get_tree().current_scene, p.global_position, global_position)
				NetC.get_node_in(get_tree()).fx_call("puffer_ult", [p.global_position, global_position])
				Juice.damage_number(get_parent(), global_position + Vector2(0, -110), "!!", Color(0.6, 1.0, 0.75), 30)
			# a wave got someone: don't waste it
			if _ult_cast and not _lunged:
				var frozen := _frozen_player()
				if frozen:
					_lunge_target = frozen
					_start_lunge()
					return
			if _ult_t >= 0.55 + PufferUlt.WARN + 0.9:
				puffed = false
				_play(_fa("deflate"))
				mode = Mode.SWIM
				_mode_t = 1.6
				_ult_cd = ULT_EVERY_ANGRY if _angry() else ULT_EVERY


		Mode.LUNGE:
			# go after whoever got frozen (co-op: maybe not the closest one)
			var lt: Node2D = _lunge_target if is_instance_valid(_lunge_target) else p
			_lunge(delta, lt, lt.global_position - global_position)


func _start_lunge() -> void:
	mode = Mode.LUNGE
	_lunged = true
	_lunge_t = 0.0
	_lunge_hit = false
	velocity = Vector2.ZERO
	# wind-up: shiver + flash so it reads as "here it comes"
	sprite.modulate = Color(2.2, 2.2, 2.0)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, LUNGE_TELL)


func _lunge(delta: float, p: Node2D, to_p: Vector2) -> void:
	_lunge_t += delta
	if _lunge_t < LUNGE_TELL:
		velocity = Vector2.ZERO
		sprite.position.x = randf_range(-2.0, 2.0)
		return
	sprite.position.x = 0.0
	if not _lunge_hit:
		_look(to_p)
		velocity = to_p.normalized() * LUNGE_SPEED
		var flat := Vector2(to_p.x, to_p.y * 2.0)
		if flat.length() < LUNGE_HIT_R:
			_lunge_hit = true
			_lunge_t = LUNGE_TELL
			# the wave's hit gave you i-frames; this slam is the guaranteed punish
			if p.get("puppet") == true:
				NetC.get_node_in(get_tree()).player_hit(p.net_id, 1, global_position, self, true)
			else:
				p.invincible_timer = 0.0
				p.take_damage(1, global_position, self)
			net_geh()
			NetC.get_node_in(get_tree()).fx_call("puffer_geh", [net_eid])
			Juice.shake(self, 0.7, to_p)
			Juice.hit_stop(self, 0.08)
			velocity = -to_p.normalized() * 340.0
		elif _lunge_t > LUNGE_TELL + 1.0:
			_lunge_hit = true   # missed (you got away): give up
			_lunge_t = LUNGE_TELL
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		if _lunge_t > LUNGE_TELL + 0.5:
			puffed = false
			_play(_fa("deflate"))
			mode = Mode.SWIM
			_mode_t = 1.6
			_ult_cd = ULT_EVERY_ANGRY if _angry() else ULT_EVERY


## the "GEH!" sound + popup (the host sends it to everyone's copy too)
func net_geh() -> void:
	_sfx("geh")
	Juice.damage_number(get_parent(), global_position + Vector2(0, -110), "GEH!", Color(1, 0.85, 0.5), 30)


## any player frozen by a wave right now (nearest first)
func _frozen_player() -> Node2D:
	var best: Node2D = null
	var bd := INF
	for q in get_tree().get_nodes_in_group("players_all"):
		if q.get("_paralysis") == null or q._paralysis <= 0.3 or q.state == q.State.DEAD:
			continue
		var d: float = global_position.distance_to(q.global_position)
		if d < bd:
			bd = d
			best = q
	return best


## plays SFX_DIR/<name>.(ogg|wav|mp3) if you've added one, with a little pitch wobble
func _sfx(name: String) -> void:
	for ext in ["ogg", "wav", "mp3"]:
		var path: String = SFX_DIR + name + "." + ext
		if ResourceLoader.exists(path):
			var a := AudioStreamPlayer2D.new()
			a.stream = load(path)
			a.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
			a.pitch_scale = randf_range(0.92, 1.1)
			get_parent().add_child(a)
			a.global_position = global_position
			a.play()
			a.finished.connect(a.queue_free)
			return


func _start_spit(to_p: Vector2) -> void:
	_look(to_p)
	_spat = false
	sprite.play(_fa("attack1"))


func _spit(p: Node2D) -> void:
	var s: float = cfg.scale
	var mouth_h: float = (cfg.foot_y - 55.0) * s
	var aim: Vector2 = p.global_position - global_position
	var dirs: Array = [aim.normalized()]
	if _angry():
		dirs = [aim.normalized().rotated(-0.32), aim.normalized(), aim.normalized().rotated(0.32)]
	var net := NetC.get_node_in(get_tree())
	var parent_path := str(get_tree().current_scene.get_path_to(get_parent()))
	for d in dirs:
		WaterBall.shoot(get_parent(), global_position + d * 26.0, d, cfg.damage, mouth_h)
		net.fx_call("water_ball", [parent_path, global_position + d * 26.0, d, cfg.damage, mouth_h])
	Juice.shake(self, 0.2)


func _start_ult() -> void:
	mode = Mode.ULT
	_lunged = false
	_ult_t = 0.0
	_ult_cast = false
	puffed = true
	sprite.play(_fa("puff"))
	Juice.shockwave(self, global_position, 34.0)
	Juice.shake(self, 0.5)


## spiky while puffed: touching it hurts (parry it and it's stunned)
func _spikes() -> void:
	var p := _player()
	if p == null or _spike_cd > 0.0:
		return
	var off := p.global_position - global_position
	if Vector2(off.x, off.y * 2.0).length() < SPIKE_R:
		_spike_cd = 1.0
		p.take_damage(1, global_position, self)


func _on_animation_finished() -> void:
	if state == State.DEAD:
		super._on_animation_finished()
		return
	var a := String(sprite.animation)
	if a.ends_with("attack1") and mode == Mode.SPIT:
		_shots -= 1
		if _shots > 0:
			_gap = 0.35 if not _angry() else 0.22
			_play(_fa("idle"))
		else:
			mode = Mode.SWIM
			_mode_t = 2.4 if not _angry() else 1.6
	elif a.ends_with("puff") and puffed:
		_play(_fa("puffed"))
	elif a.ends_with("deflate"):
		_play(_fa("walk"))


## parried or clapped: drop whatever it was doing
func stun(duration: float) -> void:
	super.stun(duration)
	if state == State.STUNNED and mode == Mode.SPIT:
		mode = Mode.SWIM
		_mode_t = 1.2


func _end_stun() -> void:
	paralyzed = false
	state = State.CHASE
	sprite.modulate = Color.WHITE
	if mode == Mode.ULT and puffed:
		_play(_fa("puffed"))
	else:
		_play(_fa("walk"))


func _die(dir: Vector2, knock_scale: float) -> void:
	puffed = false
	super._die(dir, knock_scale)
