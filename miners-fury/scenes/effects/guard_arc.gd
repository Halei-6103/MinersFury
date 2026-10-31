extends Node2D
## Shield arc in front of the player while blocking. Bright gold during the
## perfect-block window, steady blue after. Flashes when it eats a hit.

var dir: Vector2 = Vector2.RIGHT
var perfect: bool = false
var radius: float = 30.0
var _flash: float = 0.0
var _flash_color: Color = Color.WHITE
var _t: float = 0.0


func hit_flash(c: Color) -> void:
	_flash = 0.2
	_flash_color = c


func _process(delta: float) -> void:
	var real := minf(delta / maxf(Engine.time_scale, 0.001), 0.05)
	_t += real
	_flash = maxf(_flash - real, 0.0)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var base := Color(1.0, 0.85, 0.35) if perfect else Color(0.45, 0.8, 1.0)
	if _flash > 0.0:
		base = base.lerp(_flash_color, _flash / 0.2)
	var a0 := dir.angle() - 1.05
	var a1 := dir.angle() + 1.05
	var pulse := 0.85 + 0.15 * sin(_t * 14.0)
	var r := radius * (1.12 if perfect else 1.0)
	# dark rim, then the bright band, then a thin white edge (reads on any ground)
	draw_arc(Vector2.ZERO, r, a0, a1, 18, Color(0.08, 0.04, 0.1, 0.8), 7.0)
	draw_arc(Vector2.ZERO, r, a0, a1, 18, Color(base.r, base.g, base.b, 0.85 * pulse), 4.0)
	draw_arc(Vector2.ZERO, r + 1.5, a0 + 0.1, a1 - 0.1, 18, Color(1, 1, 1, 0.9 * pulse), 1.0)
	# little rivets at the ends like a buckler edge
	for a in [a0, a1]:
		var p := Vector2.from_angle(a) * r
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(0.08, 0.04, 0.1))
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), base)
