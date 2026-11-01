extends Control
## Two weapon slots above the health bar. The bright one is in your hand,
## Q swaps. Little pixel swords tinted with each weapon's color.

const GameState = preload("res://scenes/core/game_state.gd")

const BOX := 34.0
const GAP := 26.0
var _flash: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(BOX * 2 + GAP, BOX + 14)


func refresh() -> void:
	_flash = 0.3
	queue_redraw()


func _process(delta: float) -> void:
	var real := minf(delta / maxf(Engine.time_scale, 0.001), 0.05)
	_t += real
	_flash = maxf(_flash - real, 0.0)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	for i in 2:
		var w: String = GameState.slots[i]
		var active: bool = i == GameState.active_slot
		var x := i * (BOX + GAP)
		var r := Rect2(x, 0, BOX, BOX)
		var edge := Color(1, 0.9, 0.5) if active else Color(0.4, 0.38, 0.42)
		if active and _flash > 0.0:
			edge = edge.lerp(Color.WHITE, _flash / 0.3)
		draw_rect(r.grow(2), Color(0.08, 0.06, 0.08, 0.9))
		draw_rect(r, Color(0.16, 0.14, 0.18, 0.92) if active else Color(0.12, 0.11, 0.13, 0.75))
		draw_rect(r, edge, false, 2.0)
		if w != "":
			var c: Color = GameState.WEAPONS[w].color
			if not active:
				c = c.darkened(0.45)
			_sword(r.get_center(), c)
		draw_string(font, Vector2(x + 3, BOX + 12), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.8, 0.8))
		if active:
			_draw_ult(x, w)
	# Q between the boxes
	var qx := BOX + GAP / 2.0
	draw_rect(Rect2(qx - 8, BOX / 2 - 8, 16, 16), Color(0.08, 0.06, 0.08, 0.9))
	draw_rect(Rect2(qx - 8, BOX / 2 - 8, 16, 16), Color(0.7, 0.7, 0.75), false, 1.0)
	draw_string(font, Vector2(qx - 4, BOX / 2 + 5), "Q", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


## R meter under the weapon in your hand: fills while the ultimate charges
func _draw_ult(x: float, w: String) -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p == null or not p.has_method("ult_charge"):
		return
	var k: float = p.ult_charge()
	if k < 0.0:
		return
	var c: Color = GameState.WEAPONS[w].color
	var bar := Rect2(x + 12, BOX + 4, BOX - 12, 6)
	draw_rect(bar.grow(1), Color(0.08, 0.06, 0.08, 0.9))
	draw_rect(bar, Color(0.18, 0.18, 0.22))
	var ready := k >= 1.0
	var fill := c if ready else c.darkened(0.4)
	if ready:
		fill = fill.lerp(Color.WHITE, 0.25 + 0.25 * sin(_t * 8.0))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), fill)
	draw_string(get_theme_default_font(), Vector2(x + BOX + 2, BOX + 11), "R", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE if ready else Color(0.6, 0.6, 0.65))


## a tiny diagonal pixel sword
func _sword(c: Vector2, col: Color) -> void:
	var px := 2.0
	var dark := Color(0.08, 0.06, 0.08)
	for k in range(-5, 7):
		var p := c + Vector2(k, -k) * px
		draw_rect(Rect2(p - Vector2(px, px), Vector2(px * 2, px * 2)), dark)
	for k in range(-2, 7):
		var p := c + Vector2(k, -k) * px
		draw_rect(Rect2(p - Vector2(px * 0.5, px * 0.5), Vector2(px, px)), col.lightened(0.3) if k > 4 else col)
	# guard + grip
	for k in range(-2, 3):
		var p := c + Vector2(-3 + k, -(-3) + k) * px + Vector2(0, 0)
		draw_rect(Rect2(p - Vector2(px * 0.5, px * 0.5), Vector2(px, px)), Color(0.75, 0.6, 0.3))
	for k in range(-5, -3):
		var p := c + Vector2(k, -k) * px
		draw_rect(Rect2(p - Vector2(px * 0.5, px * 0.5), Vector2(px, px)), Color(0.45, 0.3, 0.2))
