extends Node2D

@export var distance_from_player: float = 40.0
@export var arrow_size: float = 8.0
@export var arrow_color: Color = Color(0.6, 0.6, 0.6)
@export var line_width: float = 1.5
@export var deadzone_radius: float = 15.0  # ignore mouse input inside this range

var last_direction: Vector2 = Vector2.RIGHT

func _process(_delta):
	var mouse_pos = get_global_mouse_position()
	var to_mouse = mouse_pos - get_parent().global_position

	if to_mouse.length() > deadzone_radius:
		last_direction = to_mouse.normalized()

	global_position = get_parent().global_position + last_direction * distance_from_player
	rotation = last_direction.angle()

	queue_redraw()

func _draw():
	var tip = Vector2(arrow_size, 0)
	var left = Vector2(-arrow_size * 0.6, -arrow_size * 0.6)
	var right = Vector2(-arrow_size * 0.6, arrow_size * 0.6)

	draw_line(tip, left, arrow_color, line_width)
	draw_line(left, right, arrow_color, line_width)
	draw_line(right, tip, arrow_color, line_width)
