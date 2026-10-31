extends Node2D
## Chunky pop-up number that jumps out, hangs, then drops and fades.
## Spawn through Juice.damage_number(...).

var text: String = "1"
var color: Color = Color(1, 0.9, 0.3)
var size: int = 18
var drift: float = 1.0      # which side it hops toward

var _t: float = 0.0
var _start: Vector2
const LIFE := 0.8


func _ready() -> void:
	z_index = 40
	_start = position
	scale = Vector2(2.2, 2.2)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	if _t > LIFE:
		queue_free()
		return
	# little hop arc
	var p := _t / LIFE
	position = _start + Vector2(drift * 26.0 * p, -60.0 * sin(min(p * 1.6, 1.0) * PI * 0.5) + 30.0 * p * p)
	modulate.a = 1.0 if p < 0.65 else 1.0 - (p - 0.65) / 0.35
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(-w / 2.0, size * 0.35)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0.08, 0.02, 0.06))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
