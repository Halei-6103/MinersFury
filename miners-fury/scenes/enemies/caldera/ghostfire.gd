extends "res://scenes/enemies/melee/melee_enemy.gd"
## Ghostfire (Ember Caldera): a burning skull that floats at a distance and
## spits a beam of fire. Before it fires, a thin red line shows where the beam
## will go, then it locks in. Step off the line.
## Spawn: instantiate melee_enemy.tscn, set_script(this), kind = "ghostfire".

const GhostBeam = preload("res://scenes/enemies/caldera/ghost_beam.gd")
const NetG = preload("res://scenes/core/net.gd")

const KEEP_AWAY := 190.0
const BEAM_LEN := 230.0
const AIM_TIME := 0.7       # red line shows this long before it fires
const FIRE_FRAME := 3

enum Mode { DRIFT, AIM, FIRE }

var mode: Mode = Mode.DRIFT
var _shot_cd: float = 1.5
var _aim_t: float = 0.0
var _aim_dir := Vector2.RIGHT
var _fired: bool = false
var _orbit: float = 1.0


func _ready() -> void:
	super._ready()
	display_name = "Ghostfire"
	_orbit = 1.0 if randf() < 0.5 else -1.0
	_shot_cd = randf_range(1.2, 2.4)


func _physics_process(delta: float) -> void:
	if net_remote:
		_remote_tick(delta)
		return
	_t += delta
	_bar_timer = maxf(_bar_timer - delta, 0.0)
	match state:
		State.SPAWNING:
			velocity = Vector2.ZERO
		State.HURT, State.STUNNED:
			mode = Mode.DRIFT
			velocity = knockback
			knockback = knockback.move_toward(Vector2.ZERO, 1100.0 * delta)
			if state == State.STUNNED:
				stun_timer -= delta
				if stun_timer <= 0.0:
					_end_stun()
		State.DEAD:
			velocity = velocity.move_toward(Vector2.ZERO, (500.0 if _airborne else 2400.0) * delta)
		_:
			_brain(delta)
	move_and_slide()
	if state == State.DEAD and _airborne and get_slide_collision_count() > 0:
		_airborne = false
		velocity = Vector2.ZERO
	queue_redraw()


## where the beam comes out (the skull's mouth)
func _mouth() -> Vector2:
	return global_position + Vector2(0, hurtbox.position.y * 0.5)


func _brain(delta: float) -> void:
	var p := _player()
	if p == null or (p.has_method("is_untargetable") and p.is_untargetable()):
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		_play("idle")
		mode = Mode.DRIFT
		return
	var to_p := p.global_position - global_position
	var flat := Vector2(to_p.x, to_p.y * 2.0)
	match mode:
		Mode.DRIFT:
			_face(to_p.x)
			# hover at a distance, circling you
			var radial := flat.normalized() * clampf((flat.length() - KEEP_AWAY) / 80.0, -1.0, 1.0)
			var tangent := Vector2(-flat.y, flat.x).normalized() * _orbit * 0.5
			var mv: Vector2 = (radial + tangent + _separation()).normalized() * cfg.speed
			velocity = velocity.move_toward(Vector2(mv.x, mv.y * 0.5), 400.0 * delta)
			_play("idle")
			_shot_cd -= delta
			if _shot_cd <= 0.0 and to_p.length() < BEAM_LEN + 40.0:
				mode = Mode.AIM
				_aim_t = AIM_TIME
				_fired = false
				sprite.play("attack2")
				sprite.pause()
				sprite.frame = 0
		Mode.AIM:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			_face(to_p.x)
			# tracks you until the last moment, then locks
			if _aim_t > 0.2:
				# aim along the ground, feet to feet. The beam is drawn at mouth
				# height, but the hit check runs on the ground line, same as the dodge
				_aim_dir = (p.global_position - global_position).normalized()
			_aim_t -= delta
			sprite.position.x = randf_range(-1.0, 1.0)
			if _aim_t <= 0.0:
				sprite.position.x = 0.0
				mode = Mode.FIRE
				sprite.play("attack2")
		Mode.FIRE:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			if not _fired and sprite.frame >= FIRE_FRAME:
				_fired = true
				_fire()


func _fire() -> void:
	var from: Vector2 = global_position + _aim_dir * 10.0 * cfg.scale
	var h: float = -hurtbox.position.y * 0.5 + 6.0
	GhostBeam.fire(get_parent(), from, _aim_dir, cfg.damage, BEAM_LEN, h)
	var net := NetG.get_node_in(get_tree())
	net.fx_call("ghost_beam", [str(get_tree().current_scene.get_path_to(get_parent())), from, _aim_dir, cfg.damage, BEAM_LEN, h])


func _on_animation_finished() -> void:
	if state == State.DEAD or state == State.SPAWNING:
		super._on_animation_finished()
		return
	if state == State.HURT:
		super._on_animation_finished()
		return
	if sprite.animation == "attack2" and mode == Mode.FIRE:
		mode = Mode.DRIFT
		_shot_cd = cfg.cooldown + randf_range(0.0, 0.8)
		_play("idle")


func stun(duration: float) -> void:
	super.stun(duration)
	mode = Mode.DRIFT
	_shot_cd = maxf(_shot_cd, 1.0)


func _end_stun() -> void:
	paralyzed = false
	state = State.CHASE
	sprite.modulate = Color.WHITE
	_play("idle")


func _draw() -> void:
	super._draw()
	# the warning line where the beam will go
	if mode == Mode.AIM and state != State.DEAD:
		var a := 0.35 + 0.4 * (1.0 - _aim_t / AIM_TIME)
		var h: float = hurtbox.position.y * 0.5 - 6.0
		var from: Vector2 = Vector2(0, h) + _aim_dir * 10.0 * cfg.scale
		draw_line(from, from + _aim_dir * BEAM_LEN, Color(1.0, 0.25, 0.1, a), 2.0)
