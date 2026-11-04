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
const HudArt = preload("res://scenes/ui/hud_art.gd")


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
	# styled like the HUD mockup: name on top, flat red fill in a dashed box
	var bw := 420.0
	var bh := 22.0
	var box := Rect2((size.x - bw) / 2.0, 30.0, bw, bh)
	var hp: float = maxf(boss.health, 0)
	var mx: float = maxf(boss.max_health, 1)
	var stunned: bool = boss.get("state") != null and boss.state == boss.State.STUNNED
	HudArt.text_c(self, Vector2(size.x / 2.0, box.position.y - 7), _spaced(title), 14)
	HudArt.panel(self, box)
	var inner := box.grow(-4.0)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * clampf(_shown / mx, 0, 1), inner.size.y)), Color(1, 0.86, 0.72))
	var fill := HudArt.RED if not stunned else Color(0.95, 0.75, 0.25)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * clampf(hp / mx, 0, 1), inner.size.y)), fill)
	if stunned:
		var a := 0.6 + 0.4 * sin(_t * 12.0)
		HudArt.text_c(self, Vector2(size.x / 2.0, box.end.y + 16), "STUNNED", 12, Color(1, 0.9, 0.3, a))


## a little letter spacing, like the mockup's boss name
func _spaced(t: String) -> String:
	var out := ""
	for c in t.to_upper():
		out += c + (" " if c != " " else "")
	return out.strip_edges()
