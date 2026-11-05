extends Node2D

@export var distance_from_player: float = 40.0
@export var arrow_size: float = 8.0
@export var arrow_color: Color = Color(1.0, 0.96, 0.78)        # light cream, easy to spot on dirt
@export var outline_color: Color = Color(0.1, 0.08, 0.08, 0.9)  # dark edge so it reads on light ground too
@export var line_width: float = 1.5
@export var deadzone_radius: float = 15.0  # ignore mouse input inside this range
## the arrow next to the player. Off now that the mouse is a + (it still tracks
## your aim: swings and ultimates read last_direction)
@export var show_arrow: bool = false

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
	if not show_arrow:
		return
	var tip = Vector2(arrow_size, 0)
	var left = Vector2(-arrow_size * 0.6, -arrow_size * 0.6)
	var right = Vector2(-arrow_size * 0.6, arrow_size * 0.6)
	var pts = PackedVector2Array([tip, left, right])

	draw_colored_polygon(pts, arrow_color)
	draw_polyline(PackedVector2Array([tip, left, right, tip]), outline_color, line_width)
