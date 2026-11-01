extends "res://scenes/enemies/melee/melee_enemy.gd"
## Weapon Proficiency trial boss: the Pufferfish.
## It floats around you and spits water balls. Every so often it puffs up
## (spiky, hurts to touch) and casts Tetrodotoxin AT you: poison rune under
## your feet, thunderclap, two paralysis waves out the sides.
## Below half health it spits three at a time and ults more often.
## Spawn: instantiate melee_enemy.tscn, set_script(this), kind = "pufferfish".

const WaterBall = preload("res://scenes/enemies/pufferfish/water_ball.gd")
const PufferUlt = preload("res://scenes/enemies/pufferfish/puffer_ult.gd")

enum Mode { SWIM, SPIT, ULT }

## how far it likes to stay from you (flat floor units)
const KEEP_AWAY := 250.0
const SPIT_FRAME := 4
const FIRST_ULT := 6.0
const ULT_EVERY := 13.0
const ULT_EVERY_ANGRY := 9.0
const SPIKE_R := 62.0

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
				Juice.damage_number(get_parent(), global_position + Vector2(0, -110), "!!", Color(0.6, 1.0, 0.75), 30)
			if _ult_t >= 0.55 + PufferUlt.WARN + 0.9:
				puffed = false
				_play(_fa("deflate"))
				mode = Mode.SWIM
				_mode_t = 1.6
				_ult_cd = ULT_EVERY_ANGRY if _angry() else ULT_EVERY


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
	for d in dirs:
		WaterBall.shoot(get_parent(), global_position + d * 26.0, d, cfg.damage, mouth_h)
	Juice.shake(self, 0.2)


func _start_ult() -> void:
	mode = Mode.ULT
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
