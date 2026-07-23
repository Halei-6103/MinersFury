extends CharacterBody2D

@export var speed: float = 120.0
@export var roll_speed: float = 400.0
@export var roll_duration: float = 0.18
@export var roll_cooldown: float = 0.6
@export var acceleration: float = 800.0
@export var friction: float = 900.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

enum State { MOVE, ROLL }
var state: State = State.MOVE

var last_direction: Vector2 = Vector2.DOWN
var roll_direction: Vector2 = Vector2.ZERO
var roll_timer: float = 0.0
var roll_cooldown_timer: float = 0.0
var can_roll: bool = true

func _physics_process(delta: float) -> void:
	roll_cooldown_timer = max(roll_cooldown_timer - delta, 0.0)
	if roll_cooldown_timer <= 0.0:
		can_roll = true

	match state:
		State.MOVE:
			_handle_move(delta)
		State.ROLL:
			_handle_roll(delta)

	move_and_slide()
	_update_animation()

func _handle_move(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	).normalized()

	if input_dir != Vector2.ZERO:
		last_direction = input_dir
		velocity = velocity.move_toward(input_dir * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	if Input.is_action_just_pressed("dodge") and can_roll:
		_start_roll(input_dir)

func _start_roll(input_dir: Vector2) -> void:
	state = State.ROLL
	roll_timer = roll_duration
	can_roll = false
	roll_cooldown_timer = roll_cooldown
	# roll in whatever direction is currently held, fallback to last faced direction if standing still
	roll_direction = input_dir if input_dir != Vector2.ZERO else last_direction
	velocity = roll_direction * roll_speed

func _handle_roll(delta: float) -> void:
	roll_timer -= delta
	if roll_timer <= 0.0:
		state = State.MOVE
		velocity = velocity.limit_length(speed)

func _update_animation() -> void:
	var anim_prefix := "down"
	if abs(last_direction.x) > abs(last_direction.y):
		anim_prefix = "right" if last_direction.x > 0 else "left"
	else:
		anim_prefix = "down" if last_direction.y > 0 else "up"

	if state == State.ROLL:
		animated_sprite.play("roll_" + anim_prefix)
	elif velocity.length() > 10.0:
		animated_sprite.play("walk_" + anim_prefix)
	else:
		animated_sprite.play("idle_" + anim_prefix)
