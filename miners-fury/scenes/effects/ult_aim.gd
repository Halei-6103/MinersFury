extends Node2D
## While you hold R: a ring showing how far your ultimate can reach, and a
## marker where it will land (your cursor, pulled back inside the ring).

var color: Color = Color(0.3, 0.95, 1.0)
var max_range: float = 260.0
## size of the effect at the target (iso radius)
var target_radius: float = 90.0
var center := Vector2.ZERO
var target := Vector2.ZERO
var _t: float = 0.0


func _ready() -> void:
	top_level = true
	z_index = 2


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	global_position = Vector2.ZERO
	var k := 0.5 + 0.5 * sin(_t * 8.0)
	# reach ring around you
	draw_set_transform(center, 0.0, Vector2(1, 0.5))
	draw_arc(Vector2.ZERO, max_range, 0.0, TAU, 72, Color(0, 0, 0, 0.35), 5.0)
	draw_arc(Vector2.ZERO, max_range, 0.0, TAU, 72, Color(color.r, color.g, color.b, 0.45), 2.0)
	# where it lands
	draw_set_transform(target, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, target_radius, Color(color.r, color.g, color.b, 0.12 + 0.06 * k))
	draw_arc(Vector2.ZERO, target_radius, 0.0, TAU, 48, Color(0, 0, 0, 0.5), 5.0)
	draw_arc(Vector2.ZERO, target_radius, 0.0, TAU, 48, Color(color.r, color.g, color.b, 0.9), 2.0)
	draw_set_transform(Vector2.ZERO)
	draw_line(target + Vector2(-8, 0), target + Vector2(8, 0), Color.WHITE, 2.0)
	draw_line(target + Vector2(0, -5), target + Vector2(0, 5), Color.WHITE, 2.0)
