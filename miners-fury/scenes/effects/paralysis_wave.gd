extends Node2D
## "TETRODOTOXIN" title that slams in over the rune when the combo fires,
## plus a quick green-blue flash on the ground where the rune was.

const TEXT_LIFE := 1.4
var _t: float = 0.0


func _ready() -> void:
	z_index = 45


func _process(delta: float) -> void:
	_t += minf(delta / maxf(Engine.time_scale, 0.001), 0.05)
	if _t >= TEXT_LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	# ground flash
	if _t < 0.3:
		var a := 1.0 - _t / 0.3
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
		draw_circle(Vector2.ZERO, 40.0 + _t * 120.0, Color(0.55, 1.0, 0.5, 0.35 * a))
		draw_set_transform(Vector2.ZERO)
	# the name, slammed in big then settling
	var ta := clampf(1.0 - (_t - 0.9) / 0.5, 0.0, 1.0)
	var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - _t / 0.15)
	var font := ThemeDB.fallback_font
	var fs := int(34 * pop)
	var txt := "TETRODOTOXIN"
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(-w / 2.0, -95.0 - _t * 10.0)
	draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0.03, 0.1, 0.06, ta))
	draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.6, 1.0, 0.75, ta))
