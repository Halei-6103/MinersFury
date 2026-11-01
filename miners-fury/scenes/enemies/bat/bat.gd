extends CharacterBody2D
## Bat: drifts around its roost, chases you when you get close,
## then winds up and dive-bites. Flies over rocks, but can't leave the map.

signal died

const Juice = preload("res://scenes/effects/juice.gd")
const Pickup = preload("res://scenes/items/pickup.gd")
const LightningBolt = preload("res://scenes/effects/lightning_bolt.gd")
## Toxic Storm combo: frozen, takes 30% more damage
var paralyzed: bool = false
var _dmg_carry: float = 0.0

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

enum State { IDLE, CHASE, ATTACK, HURT, STUNNED, DEAD }
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
var stun_timer: float = 0.0
## the big "PARRY NOW" flash fires this many seconds before the dive connects
const TELL_LEAD := 0.35
var _tell_at: float = 0.0
var _tell_clock: float = 0.0
var _told: bool = true
var _tell_fx: float = 0.0
var ichor_color: Color = Color(0.5, 0.06, 0.32)
var _t: float = 0.0
var _airborne: bool = false
var _flight_tween: Tween
var _spin_tween: Tween
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
		State.STUNNED:
			# knocked out of the air, flopping on the ground
			velocity = knockback
			knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)
			stun_timer -= delta
			if stun_timer <= 0.0:
				paralyzed = false
				state = State.CHASE
				cooldown = 0.6
				sprite.modulate = Color.WHITE
				var up := create_tween()
				up.tween_property(sprite, "position:y", -18.0, 0.2).set_ease(Tween.EASE_OUT)
				sprite.play("fly")
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
	_check_wall_hits()

## the map edge is a wall: knocked bats bounce off it, launched corpses SLAM into it
func _check_wall_hits() -> void:
	if get_slide_collision_count() == 0:
		return
	var n := get_slide_collision(0).get_normal()
	if state == State.DEAD and _airborne:
		_wall_slam(n)
	elif state == State.HURT and knockback.length() > 150.0:
		knockback = knockback.bounce(n) * 0.45
		velocity = knockback
		Juice.shake(self, 0.25)
		Juice.death_puff(get_parent(), global_position - n * 10.0, Color(0.55, 0.45, 0.35))

func _wall_slam(n: Vector2) -> void:
	_airborne = false
	velocity = velocity.bounce(n) * 0.25
	if _flight_tween:
		_flight_tween.kill()
	if _spin_tween:
		_spin_tween.kill()
	Juice.shake(self, 0.6, -n)
	Juice.spark(get_parent(), sprite.global_position - n * 6.0, -n, false, Color(0.55, 0.45, 0.35))
	# smack, then drop straight down at the foot of the wall
	sprite.scale = Vector2(1.3, 2.6) if absf(n.x) > absf(n.y) else Vector2(2.7, 1.3)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(2, 2), 0.15)
	tw.parallel().tween_property(sprite, "position:y", -6.0, 0.16).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(sprite, "rotation", 0.0, 0.16)
	tw.tween_callback(_land)

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
	var fps: float = maxf(sprite.sprite_frames.get_animation_speed("attack1"), 1.0)
	# the bite lands partway through the dive: account for the distance it has to fly
	var fly: float = maxf(to_player.length() - 30.0, 0.0) / lunge_speed
	_tell_at = maxf(windup_time + LUNGE_FRAMES[0] / fps + fly - TELL_LEAD, 0.0)
	_tell_clock = 0.0
	_told = false

func _try_bite() -> void:
	if hit_this_attack:
		return
	for body in bite_area.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			hit_this_attack = true
			body.take_damage(damage, global_position, self)
			velocity = -lunge_dir * 120.0  # bounce off after biting
			return

## knock_scale: combo starters nudge (keeps the bat in reach), finishers launch
func take_damage(amount: int, from_position: Vector2, knock_scale: float = 1.0) -> void:
	if state == State.DEAD:
		return
	if state == State.STUNNED:
		if paralyzed:
			var f := amount * 1.3 + _dmg_carry
			amount = int(floor(f))
			_dmg_carry = f - amount
		else:
			amount *= 2   # stunned = open for punishment
	health -= amount
	sprite.position.x = 0.0
	knockback = (global_position - from_position).normalized() * hit_knockback * knock_scale
	_flash()
	if health <= 0:
		_die()
		return
	if state == State.STUNNED:
		knockback *= 0.4
		return
	state = State.HURT
	sprite.play("hurt")

## poison ticks: hurts without knocking it around
func dot_damage(amount: int, color: Color = Color(0.55, 1.0, 0.35)) -> void:
	if state == State.DEAD:
		return
	health -= amount
	Juice.damage_number(get_parent(), global_position + Vector2(0, -50), str(amount), color, 16)
	if health <= 0:
		knockback = Vector2.RIGHT if randf() < 0.5 else Vector2.LEFT
		_die()

## parried! knocked out of the air and dazed
## Toxic Storm: drops out of the air, locked up
func paralyze(duration: float) -> void:
	if state == State.DEAD:
		return
	stun(duration)
	paralyzed = true
	knockback = Vector2.ZERO
	sprite.play("fly")
	sprite.pause()
	sprite.modulate = Color(0.7, 1.0, 0.85)

func stun(duration: float) -> void:
	if state == State.DEAD:
		return
	paralyzed = false
	state = State.STUNNED
	stun_timer = duration
	windup_timer = 0.0
	sprite.position.x = 0.0
	sprite.play("hurt")
	sprite.pause()
	sprite.frame = 1
	sprite.modulate = Color(0.85, 0.85, 1.2)
	knockback = -lunge_dir * 260.0
	var drop := create_tween()
	drop.tween_property(sprite, "position:y", -6.0, 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

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
	sprite.self_modulate = Color.WHITE
	if randf() < 0.7:
		Pickup.drop(get_parent(), global_position, "item", "bat_wing")
	var dir := knockback.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	velocity = dir * launch_speed
	_airborne = true
	_ghost_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.play("hurt")
	sprite.pause()
	var spin := TAU * 3.0 * (1.0 if dir.x >= 0.0 else -1.0)
	# keep the arc under the wall line: low arc if the wall is close in that direction
	var apex := -78.0
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * 400.0, 4)
	var hit := space.intersect_ray(q)
	if hit:
		var dist: float = global_position.distance_to(hit.position)
		apex = -clampf(dist * 0.2, 12.0, 64.0)
	_flight_tween = create_tween()
	_flight_tween.tween_property(sprite, "position:y", apex, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flight_tween.tween_property(sprite, "position:y", -6.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flight_tween.tween_callback(_land)
	# spin the whole flight
	_spin_tween = create_tween()
	_spin_tween.tween_property(sprite, "rotation", spin, 0.46).from(0.0)
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


func _process(delta: float) -> void:
	_t += delta
	_tell_fx = maxf(_tell_fx - delta, 0.0)
	if not _told and state == State.ATTACK:
		_tell_clock += delta
		if _tell_clock >= _tell_at:
			_told = true
			_tell_fx = 0.28
			sprite.modulate = Color(5, 5, 4)
			var tw := create_tween()
			tw.tween_property(sprite, "modulate", Color.WHITE, 0.16)
	elif state != State.ATTACK:
		_told = true
	queue_redraw()


func _draw() -> void:
	if _tell_fx > 0.0:
		_draw_tell()
	if state != State.STUNNED:
		return
	if paralyzed:
		for i in 3:
			var a := Vector2(randf_range(-12, 12), randf_range(-24, 0))
			var b := a + Vector2.from_angle(randf() * TAU) * randf_range(6, 12)
			LightningBolt.draw_bolt(self, LightningBolt.zigzag(a, b, 2.5, 4.0), 0.9, 0.45)
		return
	for i in 3:
		var a := _t * 6.0 + TAU * i / 3.0
		var p := Vector2(cos(a) * 12.0, -30.0 + sin(a) * 4.0)
		draw_rect(Rect2(p - Vector2(1, 3), Vector2(2, 6)), Color(1, 0.92, 0.3))
		draw_rect(Rect2(p - Vector2(3, 1), Vector2(6, 2)), Color(1, 0.92, 0.3))
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1))


## big gold glint + ring: block now!
func _draw_tell() -> void:
	var p := 1.0 - _tell_fx / 0.28
	var a := 1.0 - p
	var body := Vector2(0, sprite.position.y)
	var r := 14.0 + p * 30.0
	draw_arc(body, r, 0.0, TAU, 28, Color(0.1, 0.05, 0.05, a * 0.8), 6.0)
	draw_arc(body, r, 0.0, TAU, 28, Color(1.0, 0.85, 0.25, a), 3.0)
	var g := 12.0 + 8.0 * sin(p * PI)
	var c := Vector2(0, sprite.position.y - 26.0)
	for pass_ in 2:
		var w := 3.0 if pass_ == 0 else 0.0
		var col := Color(0.1, 0.05, 0.05, a) if pass_ == 0 else Color(1.0, 0.9, 0.3, a)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -g - w), c + Vector2(g * 0.22 + w, 0), c + Vector2(0, g + w), c + Vector2(-g * 0.22 - w, 0)]), col)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-g - w, 0), c + Vector2(0, g * 0.22 + w), c + Vector2(g + w, 0), c + Vector2(0, -g * 0.22 - w)]), col)
	draw_circle(c, 3.0, Color(1, 1, 1, a))
