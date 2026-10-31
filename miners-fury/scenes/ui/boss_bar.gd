extends Control
## Big pixel-art boss health bar, top-center. Same style as the player's bar.

@export var pixel: int = 3
@export var bar_width: int = 140

var boss: Node = null
var title: String = "BOSS"
var _shown: float = -1.0
var _hold: float = 0.0
var _t: float = 0.0

const OUTLINE := Color(0.09, 0.06, 0.08)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var real := minf(delta / maxf(Engine.time_scale, 0.001), 0.05)
	_t += real
	if boss == null or not is_instance_valid(boss):
		return
	var hp: float = maxf(boss.health, 0)
	if _shown < 0.0:
		_shown = hp
	if hp < _shown and _hold <= 0.0:
		_hold = 0.4
	_hold -= real
	if _hold <= 0.0:
		_shown = move_toward(_shown, hp, real * 12.0)
	queue_redraw()


func _draw() -> void:
	if boss == null or not is_instance_valid(boss):
		return
	var font := ThemeDB.fallback_font
	var W := bar_width
	var x0 := (size.x - (W + 2) * pixel) / 2.0
	var y0 := 26.0
	var p := pixel
	var hp: float = maxf(boss.health, 0)
	var mx: float = maxf(boss.max_health, 1)
	var fill := int(round(W * hp / mx))
	var trail := int(round(W * _shown / mx))
	var stunned: bool = boss.get("state") != null and boss.state == boss.State.STUNNED
	# title
	var ts := 22
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
	draw_string_outline(font, Vector2(size.x / 2.0 - tw / 2.0, y0 - 6), title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, 8, OUTLINE)
	draw_string(font, Vector2(size.x / 2.0 - tw / 2.0, y0 - 6), title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(1, 0.85, 0.4))
	# frame
	draw_rect(Rect2(x0, y0, (W + 2) * p, 8 * p), OUTLINE)
	for x in W:
		var c: Color
		if x < fill:
			c = Color(0.85, 0.2, 0.15) if not stunned else Color(0.95, 0.75, 0.25)
		elif x < trail:
			c = Color(1, 0.86, 0.72)
		else:
			c = Color(0.2, 0.11, 0.14)
		draw_rect(Rect2(x0 + (x + 1) * p, y0 + p, p, 6 * p), c)
		if x < fill:
			draw_rect(Rect2(x0 + (x + 1) * p, y0 + p, p, p), Color(1, 0.5, 0.45) if not stunned else Color(1, 0.95, 0.6))
			draw_rect(Rect2(x0 + (x + 1) * p, y0 + 6 * p, p, p), Color(0.5, 0.06, 0.08))
	if stunned:
		var s := "STUNNED"
		var sw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var a := 0.6 + 0.4 * sin(_t * 12.0)
		draw_string_outline(font, Vector2(size.x / 2.0 - sw / 2.0, y0 + 8 * p + 16), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 6, Color(OUTLINE, a))
		draw_string(font, Vector2(size.x / 2.0 - sw / 2.0, y0 + 8 * p + 16), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.9, 0.3, a))
