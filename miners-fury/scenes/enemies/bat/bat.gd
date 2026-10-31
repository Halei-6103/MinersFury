extends CharacterBody2D
## Bat: drifts around its roost, chases you when you get close,
## then winds up and dive-bites. Flies over rocks, but can't leave the map.

signal died

const Juice = preload("res://scenes/effects/juice.gd")

@export var max_health: int = 3
@export var speed: float = 75.0
@export var detect_range: float = 230.0
@export var give_up_range: float = 380.0
@export var attack_range: float = 80.0
@export var lunge_speed: float = 280.0
@export var attack_cooldown: float = 1.8
## seconds the bat hangs in the air telegraphing before it dives
@export var windup_time: float = 0.3
@export var damage: int = 1
@export var wander_radius: float = 70.0
## how hard a normal hit shoves the bat back
@export var hit_knockback: float = 430.0
## killing blow launches the corpse this fast (home run)
@export var launch_speed: float = 640.0

enum State { IDLE, CHASE, ATTACK, HURT, DEAD }
var state: State = State.IDLE

var health: int
var home: Vector2
var wander_target: Vector2
var wander_timer: float = 0.0
var cooldown: float = 0.0
var lunge_dir: Vector2 = Vector2.ZERO
var hit_this_attack: bool = false
var knockback: Vector2 = Vector2.ZERO
var windup_timer: float = 0.0
var _airborne: bool = false
var _ghost_timer: float = 0.0
var _ghost_mat := CanvasItemMaterial.new()

# attack1 frames where the bat is actually diving
const LUNGE_FRAMES := [2, 3, 4]

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var bite_area: Area2D = $BiteArea

func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	home = global_position
	wander_target = home
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("fly")
	sprite.frame = randi() % 6  # so a group of bats don't flap in sync

func _physics_process(delta: float) -> void:
	cooldown = max(cooldown - delta, 0.0)
	var player := _get_player()
	var to_player := Vector2.ZERO
	var dist := INF
	# phased out (dodging) = the bat can't see you for a moment
	var hidden: bool = player != null and player.has_method("is_untargetable") and player.is_untargetable()
	if player:
		to_player = player.global_position - global_position
		dist = to_player.length()

	match state:
		State.IDLE:
			_wander(delta)
			if dist < detect_range and not hidden:
				state = State.CHASE
		State.CHASE:
			if dist > give_up_range:
				state = State.IDLE
			elif hidden:
				# lost you: hover in place, confused
				velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
			else:
				# swoop in on a slight curve so they don't beeline
				var dir := to_player.normalized().rotated(sin(Time.get_ticks_msec() / 300.0) * 0.35)
				velocity = velocity.move_toward(dir * speed, 400.0 * delta)
				if dist < attack_range and cooldown <= 0.0:
					_start_attack(to_player)
		State.ATTACK:
			if windup_timer > 0.0:
				# hang in the air and shake a little so you can see the dive coming
				windup_timer -= delta
				velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
				sprite.position.x = randf_range(-1.5, 1.5)
				if windup_timer <= 0.0:
					sprite.position.x = 0.0
					if player and not hidden:
						lunge_dir = to_player.normalized()  # aim at where you are now
					sprite.flip_h = lunge_dir.x < 0.0
					sprite.play("attack1")
			elif sprite.frame in LUNGE_FRAMES:
				velocity = lunge_dir * lunge_speed
				_try_bite()
			else:
				velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		State.HURT:
			velocity = knockback
			knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)
		State.DEAD:
			if _airborne:
				# flying corpse: slows a bit, leaves a streak behind it
				velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
				_ghost_timer -= delta
				if _ghost_timer <= 0.0:
					_ghost_timer = 0.03
					_spawn_ghost()
			else:
				velocity = velocity.move_toward(Vector2.ZERO, 2400.0 * delta)

	if state != State.DEAD and abs(velocity.x) > 5.0:
		sprite.flip_h = velocity.x < 0.0
	move_and_slide()

func _get_player() -> Node2D:
	var p = get_tree().get_first_node_in_group("player")
	if p and p.get("state") != null and p.state == p.State.DEAD:
		return null
	return p

func _wander(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0 or global_position.distance_to(wander_target) < 8.0:
		wander_timer = randf_range(1.5, 3.0)
		wander_target = home + Vector2(randf_range(-1, 1), randf_range(-0.5, 0.5)) * wander_radius
	var dir := (wander_target - global_position).normalized()
	velocity = velocity.move_toward(dir * speed * 0.4, 200.0 * delta)

func _start_attack(to_player: Vector2) -> void:
	state = State.ATTACK
	lunge_dir = to_player.normalized()
	hit_this_attack = false
	sprite.flip_h = lunge_dir.x < 0.0
	# wind up first (holds the first attack frame), then dive
	windup_timer = windup_time
	sprite.play("attack1")
	sprite.pause()
	sprite.frame = 0

func _try_bite() -> void:
	if hit_this_attack:
		return
	for body in bite_area.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage, global_position)
			hit_this_attack = true
			velocity = -lunge_dir * 120.0  # bounce off after biting
			return

## knock_scale: combo starters nudge (keeps the bat in reach), finishers launch
func take_damage(amount: int, from_position: Vector2, knock_scale: float = 1.0) -> void:
	if state == State.DEAD:
		return
	health -= amount
	sprite.position.x = 0.0
	knockback = (global_position - from_position).normalized() * hit_knockback * knock_scale
	_flash()
	if health <= 0:
		_die()
		return
	state = State.HURT
	sprite.play("hurt")

func _flash() -> void:
	sprite.modulate = Color(3, 3, 3)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	# squash flat then pop back
	sprite.scale = Vector2(2.7, 1.4)
	var sq := create_tween()
	sq.tween_property(sprite, "scale", Vector2(2, 2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## HOME RUN: the corpse gets launched, spins through the air, slams down
func _die() -> void:
	state = State.DEAD
	collision_layer = 0
	var dir := knockback.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	velocity = dir * launch_speed
	_airborne = true
	_ghost_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.play("hurt")
	sprite.pause()
	var spin := TAU * 3.0 * (1.0 if dir.x >= 0.0 else -1.0)
	var tw := create_tween()
	tw.tween_property(sprite, "position:y", -78.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position:y", -6.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_land)
	# spin the whole flight
	var spin_tw := create_tween()
	spin_tw.tween_property(sprite, "rotation", spin, 0.46).from(0.0)
	died.emit()

func _land() -> void:
	_airborne = false
	sprite.rotation = 0.0
	# bounce
	var tw := create_tween()
	tw.tween_property(sprite, "position:y", -16.0, 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position:y", -6.0, 0.08).set_ease(Tween.EASE_IN)
	sprite.scale = Vector2(2.8, 1.3)
	var sq := create_tween()
	sq.tween_property(sprite, "scale", Vector2(2, 2), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Juice.death_puff(get_parent(), global_position)
	Juice.shockwave(self, global_position, 26.0)
	Juice.splat(self, global_position, velocity if velocity != Vector2.ZERO else Vector2.RIGHT, 4)
	Juice.shake(self, 0.45)
	sprite.play("death")

func _spawn_ghost() -> void:
	var g := Sprite2D.new()
	g.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.flip_h = sprite.flip_h
	g.scale = sprite.scale
	g.rotation = sprite.rotation
	g.material = _ghost_mat
	g.modulate = Color(1, 0.55, 0.85, 0.55)
	get_parent().add_child(g)
	g.global_position = sprite.global_position
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.22)
	tw.tween_callback(g.queue_free)

func _on_animation_finished() -> void:
	match state:
		State.ATTACK:
			state = State.CHASE
			cooldown = attack_cooldown
			sprite.play("fly")
		State.HURT:
			state = State.CHASE
			cooldown = max(cooldown, 0.5)
			sprite.play("fly")
		State.DEAD:
			var tw := create_tween()
			tw.tween_interval(1.2)
			tw.tween_property(self, "modulate:a", 0.0, 0.6)
			tw.tween_callback(queue_free)
