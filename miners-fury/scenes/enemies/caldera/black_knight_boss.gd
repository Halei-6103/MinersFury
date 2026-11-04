extends "res://scenes/enemies/melee/melee_enemy.gd"
## Ember Caldera boss: the Black Knight (Zerie pack 02, Black Knight_A).
##   attack1: spear thrusts up close (two hits, parry them).
##   attack2: a sweep, then a fireball off the spear tip (fire pack v2).
##            Uses it to reach you when you keep your distance.
##   attack3: leaps and slams. Spikes burst around it, then lava erupts under
##            you and in a ring around it (fire pack v1/v9). Watch the glowing circles.
## Below half health: fireballs come in threes and the slam sends a second wave.
## Spawn: instantiate melee_enemy.tscn, set_script(this), kind = "black_knight".

const KnightFireball = preload("res://scenes/enemies/caldera/knight_fireball.gd")
const LavaEruption = preload("res://scenes/enemies/caldera/lava_eruption.gd")
const NetK = preload("res://scenes/core/net.gd")
const SfxK = preload("res://scenes/audio/sfx.gd")

const FIREBALL_FRAME := 11
const SLAM_FRAME := 10
const FIRST_SLAM := 6.0
const SLAM_EVERY := 10.0
const SLAM_EVERY_ANGRY := 7.0
const FIRE_EVERY := 3.5

var _slam_cd: float = FIRST_SLAM
var _fire_cd: float = 2.5
var _fired: bool = false
var _slammed: bool = false


func _ready() -> void:
	super._ready()
	display_name = "Black Knight"
	sprite.frame_changed.connect(_on_knight_frame)


func _angry() -> bool:
	return health <= max_health / 2


func _physics_process(delta: float) -> void:
	if not net_remote and state != State.DEAD and state != State.SPAWNING:
		_slam_cd -= delta
		_fire_cd -= delta
		# out of spear range: throw fire at you instead of walking the whole way
		if state == State.CHASE and cooldown <= 0.0 and _fire_cd <= 0.0:
			var p := _player()
			if p and not (p.has_method("is_untargetable") and p.is_untargetable()):
				var to_p := p.global_position - global_position
				var d := Vector2(to_p.x, to_p.y * 2.0).length()
				if d > cfg.attack_range * 1.6 and d < 650.0:
					_start_windup(to_p)
	super._physics_process(delta)


func _pick_attack(to_p: Vector2) -> String:
	var d := Vector2(to_p.x, to_p.y * 2.0).length()
	if _slam_cd <= 0.0 and d < 320.0:
		_slam_cd = SLAM_EVERY_ANGRY if _angry() else SLAM_EVERY
		_big_warning()
		return "attack3"
	if d > cfg.attack_range * 1.6:
		_fire_cd = FIRE_EVERY * (0.7 if _angry() else 1.0)
		return "attack2"
	# up close: mostly thrusts, sometimes the sweep + point-blank fireball
	if _fire_cd <= 0.0 and randf() < 0.3:
		_fire_cd = FIRE_EVERY
		return "attack2"
	return "attack1"


func _start_attack(to_p: Vector2) -> void:
	_fired = false
	_slammed = false
	super._start_attack(to_p)


func _big_warning() -> void:
	sprite.modulate = Color(1.8, 1.2, 0.8)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.5)
	Juice.damage_number(get_parent(), global_position + Vector2(0, -150), "!!", Color(1.0, 0.55, 0.2), 30)


func _on_knight_frame() -> void:
	if net_remote or state != State.ATTACK:
		return
	if sprite.animation == "attack2" and not _fired and sprite.frame >= FIREBALL_FRAME:
		_fired = true
		_throw()
	elif sprite.animation == "attack3" and not _slammed and sprite.frame >= SLAM_FRAME:
		_slammed = true
		_slam()


## spear tip: in front of it, about chest high
func _tip() -> Vector2:
	var side := -1.0 if sprite.flip_h else 1.0
	return global_position + Vector2(side * 40.0 * cfg.scale, 0)


func _throw() -> void:
	var p := _player()
	var from := _tip()
	var aim := Vector2(-1.0 if sprite.flip_h else 1.0, 0.0)
	if p:
		aim = (p.global_position - from).normalized()
	var dirs: Array = [aim]
	if _angry():
		dirs = [aim.rotated(-0.28), aim, aim.rotated(0.28)]
	var h: float = 12.0 * cfg.scale
	var net := NetK.get_node_in(get_tree())
	var parent_path := str(get_tree().current_scene.get_path_to(get_parent()))
	for d in dirs:
		KnightFireball.shoot(get_parent(), from, d, cfg.damage, h)
		net.fx_call("knight_fireball", [parent_path, from, d, cfg.damage, h])
	Juice.shake(self, 0.2)


func _slam() -> void:
	Juice.shake(self, 0.9)
	Juice.shockwave(self, global_position, 40.0)
	SfxK.play(self, "boss_landing", global_position, 0.0, 0.02)
	var spots: Array = []
	# under every player
	for pl in get_tree().get_nodes_in_group("players_all"):
		if pl.state != pl.State.DEAD:
			spots.append([pl.global_position, 0.75])
	# a ring around the knight, just past the spikes
	var n := 8 if _angry() else 6
	var off := randf() * TAU
	for i in n:
		var a := off + TAU * i / n
		spots.append([global_position + Vector2(cos(a), sin(a) * 0.5) * 190.0, 0.55])
	_erupt(spots)
	if _angry():
		# second wave: where you ran to
		get_tree().create_timer(1.0, false).timeout.connect(func() -> void:
			if state == State.DEAD:
				return
			var again: Array = []
			for pl in get_tree().get_nodes_in_group("players_all"):
				if pl.state != pl.State.DEAD:
					again.append([pl.global_position, 0.7])
					var k := Vector2.from_angle(randf() * TAU)
					again.append([pl.global_position + Vector2(k.x, k.y * 0.5) * 90.0, 0.85])
			_erupt(again))


func _erupt(spots: Array) -> void:
	var net := NetK.get_node_in(get_tree())
	var level := get_tree().current_scene
	for s in spots:
		LavaEruption.erupt(level, s[0], s[1], cfg.damage)
		net.fx_call("lava_eruption", [s[0], s[1], cfg.damage])
