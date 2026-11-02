extends "res://scenes/enemies/melee/melee_enemy.gd"
## Ember Caldera boss: the Fire Cultist.
## Keeps its distance and throws fireballs at you. Every so often it raises walls
## of fire across the floor (watch the glowing lines, step out or roll through).
## At 2/3 and 1/3 health it calls assassins out of the shadows.
## Below half health: fireballs come in threes and the walls come in pairs.
## Spawn: instantiate melee_enemy.tscn, set_script(this), kind = "fire_cultist".

const Fireball = preload("res://scenes/enemies/cultist/fireball.gd")
const FlameWall = preload("res://scenes/effects/flame_wall.gd")
const NetC = preload("res://scenes/core/net.gd")
const SfxC = preload("res://scenes/audio/sfx.gd")

enum Mode { DRIFT, VOLLEY, WALL }

const KEEP_AWAY := 240.0
const SHOT_FRAME := 5
const FIRST_WALL := 7.0
const WALL_EVERY := 11.0
const WALL_EVERY_ANGRY := 8.0
const WALL_LEN := 380.0

var mode: Mode = Mode.DRIFT
var _mode_t: float = 2.0
var _shots: int = 0
var _shot: bool = false
var _gap: float = 0.0
var _wall_cd: float = FIRST_WALL
var _thresholds: Array = [0.66, 0.33]
var _orbit: float = 1.0


func _ready() -> void:
	super._ready()
	display_name = "Fire Cultist"
	_orbit = 1.0 if randf() < 0.5 else -1.0


func _angry() -> bool:
	return health <= max_health / 2


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
	move_and_slide()
	queue_redraw()


func _brain(delta: float) -> void:
	var p := _player()
	if p == null:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		_play("idle")
		return
	var to_p := p.global_position - global_position
	var flat := Vector2(to_p.x, to_p.y * 2.0)
	_wall_cd -= delta
	# backup when hurt: call the assassins
	if not _thresholds.is_empty() and float(health) / max_health <= _thresholds[0]:
		_thresholds.pop_front()
		_call_assassins(p)
	match mode:
		Mode.DRIFT:
			_face(to_p.x)
			var radial := flat.normalized() * clampf((flat.length() - KEEP_AWAY) / 90.0, -1.0, 1.0)
			var tangent := Vector2(-flat.y, flat.x).normalized() * _orbit * 0.6
			var mv: Vector2 = (radial + tangent + _separation()).normalized() * cfg.speed
			velocity = velocity.move_toward(Vector2(mv.x, mv.y * 0.5), 400.0 * delta)
			_play("walk")
			_mode_t -= delta
			if _wall_cd <= 0.0 and flat.length() < 700.0:
				_start_wall()
			elif _mode_t <= 0.0:
				mode = Mode.VOLLEY
				_shots = 3 if not _angry() else 4
				_start_shot(to_p)
		Mode.VOLLEY:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			if _gap > 0.0:
				_gap -= delta
				if _gap <= 0.0:
					_start_shot(to_p)
				return
			if not _shot and sprite.frame >= SHOT_FRAME:
				_shot = true
				_throw(p)
		Mode.WALL:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			if not _shot and sprite.frame >= SHOT_FRAME:
				_shot = true
				_raise_walls(p)


func _start_shot(to_p: Vector2) -> void:
	_face(to_p.x)
	_shot = false
	sprite.play("attack1")


func _throw(p: Node2D) -> void:
	var s: float = cfg.scale
	var hand := Vector2(18.0 * (-1.0 if sprite.flip_h else 1.0), 0) * s
	var aim: Vector2 = (p.global_position - global_position).normalized()
	var dirs: Array = [aim]
	if _angry():
		dirs = [aim.rotated(-0.3), aim, aim.rotated(0.3)]
	var net := NetC.get_node_in(get_tree())
	var parent_path := str(get_tree().current_scene.get_path_to(get_parent()))
	for d in dirs:
		var from: Vector2 = global_position + hand.x * Vector2.RIGHT + d * 20.0
		Fireball.shoot(get_parent(), from, d, cfg.damage, 18.0 * s)
		net.fx_call("fireball", [parent_path, from, d, cfg.damage, 18.0 * s])
	Juice.shake(self, 0.15)


func _start_wall() -> void:
	mode = Mode.WALL
	_shot = false
	sprite.play("attack1")
	# bright flash on the hands: something big is coming
	sprite.modulate = Color(1.8, 1.3, 0.8)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.5)
	Juice.damage_number(get_parent(), global_position + Vector2(0, -110), "!!", Color(1.0, 0.6, 0.2), 30)


## a wall across your path. Angry: two of them, one each side of you
func _raise_walls(p: Node2D) -> void:
	var to_p := p.global_position - global_position
	var flat := Vector2(to_p.x, to_p.y * 2.0).normalized()
	var side := Vector2(-flat.y, flat.x)
	var spots: Array = []
	if _angry():
		for k in [-1.0, 1.0]:
			var off: Vector2 = flat * 85.0 * k
			spots.append(p.global_position + Vector2(off.x, off.y * 0.5))
	else:
		spots.append(p.global_position)
	var net := NetC.get_node_in(get_tree())
	for at in spots:
		FlameWall.raise(get_tree().current_scene, at, side, WALL_LEN)
		net.fx_call("flame_wall", [at, side, WALL_LEN])
	_wall_cd = WALL_EVERY_ANGRY if _angry() else WALL_EVERY


func _call_assassins(p: Node2D) -> void:
	var scene = load("res://scenes/enemies/melee/melee_enemy.tscn")
	var n := 2 if _thresholds.size() >= 1 else 3
	for i in n:
		var at: Vector2 = p.global_position + Vector2.from_angle(TAU * i / n + randf()) * Vector2(1, 0.5) * randf_range(120, 170)
		var m = scene.instantiate()
		m.kind = "assassin_cultist"
		m.summoned = true
		m.position = at
		get_parent().add_child(m)
		_minions.append(m)
	SfxC.play(self, "fireball", global_position, -2.0, 0.05, 0.6)
	Juice.damage_number(get_parent(), global_position + Vector2(0, -110), "RISE!", Color(1.0, 0.45, 0.35), 28)


func _on_animation_finished() -> void:
	if state == State.DEAD or state == State.SPAWNING:
		super._on_animation_finished()
		return
	if sprite.animation == "attack1":
		match mode:
			Mode.VOLLEY:
				_shots -= 1
				if _shots > 0:
					_gap = 0.25 if not _angry() else 0.15
					_play("idle")
				else:
					mode = Mode.DRIFT
					_mode_t = 2.2 if not _angry() else 1.5
			Mode.WALL:
				mode = Mode.DRIFT
				_mode_t = 1.4
	elif state == State.HURT:
		super._on_animation_finished()


## parried or clapped: drop whatever it was doing
func stun(duration: float) -> void:
	super.stun(duration)
	if state == State.STUNNED:
		mode = Mode.DRIFT
		_mode_t = 1.2


func _end_stun() -> void:
	paralyzed = false
	state = State.CHASE
	sprite.modulate = Color.WHITE
	_play("walk")
