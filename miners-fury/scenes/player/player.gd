extends CharacterBody2D

@export var speed: float = 200.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0

var current_state: String = "idle"

func _physics_process(delta: float) -> void:
	var input_vector := Vector2.ZERO
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	input_vector = input_vector.normalized()

	if input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(input_vector * speed, acceleration * delta)
		current_state = "move"
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		current_state = "idle"

	move_and_slide()
