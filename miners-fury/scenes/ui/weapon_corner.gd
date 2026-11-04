extends Control
## Bottom-right weapons (HUD layout A):
##   [other weapon]  [weapon in hand]  (ult ring)
## The in-hand box is bigger and gold. Q badge between them refills while the
## swap cools down. The ring fills while the ultimate cools down, shows the
## seconds left, then glows with a big R when it's ready.

const GameState = preload("res://scenes/core/game_state.gd")
const HudArt = preload("res://scenes/ui/hud_art.gd")

const OTHER := 60.0
const HAND := 72.0
const RING_R := 46.0
const RING_W := 8.0
const GAP := 14.0
const DARK := Color(0.08, 0.06, 0.08)
const GOLD := Color(1.0, 0.84, 0.42)
const W := OTHER + GAP + HAND + GAP + RING_R * 2.0
const H := RING_R * 2.0 + 22.0

var _t: float = 0.0
var _flash: float = 0.0
var _used_flash: float = 0.0
var _last_k: float = -1.0
var _q_ready_flash: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)


func refresh() -> void:
	_flash = 0.3
	_last_k = -1.0


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	var real := minf(delta / maxf(Engine.time_scale, 0.001), 0.05)
	_t += real
	_flash = maxf(_flash - real, 0.0)
	_used_flash = maxf(_used_flash - real, 0.0)
	_q_ready_flash = maxf(_q_ready_flash - real, 0.0)
	var p := _player()
	if p and p.has_method("ult_charge"):
		var k: float = p.ult_charge()
		if _last_k >= 0.999 and k < 0.5 and k >= 0.0:
			_used_flash = 0.35
		_last_k = k
	queue_redraw()


func _draw() -> void:
	var p := _player()
	var font := get_theme_default_font()
	var active: int = GameState.active_slot
	var w_in: String = GameState.slots[active]
	var w_out: String = GameState.slots[1 - active]
	var base_y := RING_R * 2.0   # boxes and ring share a bottom line

	# ---- other weapon
	var ro := Rect2(0, base_y - OTHER, OTHER, OTHER)
	_box(ro, Color(0.12, 0.1, 0.12, 0.8), Color(0.54, 0.5, 0.53), 2.0)
	_icon(w_out, ro.get_center(), 2.0, true)
	_label(Vector2(ro.get_center().x, base_y + 16), str(2 - active), Color(0.75, 0.72, 0.74))

	# ---- weapon in hand
	var rh := Rect2(OTHER + GAP, base_y - HAND, HAND, HAND)
	var edge := GOLD
	if _flash > 0.0:
		edge = edge.lerp(Color.WHITE, _flash / 0.3)
	_box(rh, Color(0.16, 0.12, 0.15, 0.92), edge, 3.0)
	_icon(w_in, rh.get_center(), 2.6, false)
	_label(Vector2(rh.get_center().x, base_y + 16), str(active + 1), Color.WHITE)

	# ---- Q badge between them (swap cooldown)
	var q := 1.0
	if p and p.has_method("swap_charge"):
		q = clampf(p.swap_charge(), 0.0, 1.0)
	var qc := Vector2(OTHER + GAP * 0.5, base_y - OTHER * 0.5)
	if q < 1.0:
		_q_ready_flash = 0.3
		_badge(qc, "Q", Color(0.3, 0.3, 0.34), Color(0.75, 0.75, 0.8), q)
	else:
		var c := Color(0.12, 0.1, 0.12)
		if _q_ready_flash > 0.0:
			c = c.lerp(Color.WHITE, _q_ready_flash / 0.3 * 0.7)
		_badge(qc, "Q", c, Color.WHITE)

	# ---- ult ring
	var cc := Vector2(OTHER + GAP + HAND + GAP + RING_R, RING_R)
	var k := -1.0
	if p and p.has_method("ult_charge"):
		k = p.ult_charge()
	var col: Color = GameState.WEAPONS[w_in].color if GameState.WEAPONS.has(w_in) else Color(0.8, 0.8, 0.85)
	var ready := k >= 1.0
	if ready:
		draw_circle(cc, RING_R + 7.0, Color(col, 0.18 + 0.12 * sin(_t * 6.0)))
	draw_circle(cc, RING_R + 2.0, DARK)
	draw_circle(cc, RING_R, Color(0.23, 0.18, 0.21, 0.9))
	if k > 0.0:
		var rc := col if ready else col.darkened(0.25)
		if ready:
			rc = col.lerp(Color.WHITE, 0.2 + 0.2 * sin(_t * 8.0))
		draw_arc(cc, RING_R - RING_W * 0.5, -PI / 2.0, -PI / 2.0 + TAU * k, 64, rc, RING_W, true)
	if _used_flash > 0.0:
		draw_arc(cc, RING_R - RING_W * 0.5, 0.0, TAU, 64, Color(1, 1, 1, _used_flash / 0.35), RING_W, true)
	draw_circle(cc, RING_R - RING_W, Color(0.14, 0.11, 0.13, 0.95))
	var txt := "-"
	var tc := Color(0.55, 0.52, 0.55)
	var fs := 20
	if ready:
		txt = "R"
		tc = GOLD.lerp(Color.WHITE, 0.3 * maxf(sin(_t * 8.0), 0.0))
		fs = 30
	elif k >= 0.0 and p:
		txt = str(ceili(p._ult_cd.get(p.weapon, 0.0)))
		tc = Color(0.85, 0.83, 0.85)
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(font, cc + Vector2(-tw * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, DARK)
	draw_string(font, cc + Vector2(-tw * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
	_label(Vector2(cc.x, base_y + 16), "ULT  R" if k >= 0.0 else "no ult", Color(0.75, 0.72, 0.74))


func _box(r: Rect2, bg: Color, edge: Color, wdt: float) -> void:
	draw_rect(r.grow(2.0), DARK)
	draw_rect(r, bg)
	draw_rect(r, edge, false, wdt)


func _label(at: Vector2, text: String, c: Color) -> void:
	var font := get_theme_default_font()
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string_outline(font, at - Vector2(tw * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, DARK)
	draw_string(font, at - Vector2(tw * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)


func _badge(at: Vector2, letter: String, bg: Color, fg: Color, fill: float = 1.0) -> void:
	var sz := 18.0
	var r := Rect2(at - Vector2(sz, sz) * 0.5, Vector2(sz, sz))
	draw_rect(r.grow(2.0), DARK)
	draw_rect(r, bg)
	if fill < 1.0:
		draw_rect(Rect2(r.position + Vector2(0, sz * (1.0 - fill)), Vector2(sz, sz * fill)), Color(0.55, 0.75, 1.0, 0.7))
	draw_rect(r, fg, false, 1.5)
	var font := get_theme_default_font()
	var tw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, at + Vector2(-tw * 0.5, 4.5), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, fg)


## a weapon's icon: your art if there is some (weapon_<id>.png), else a pixel sword
func _icon(w: String, at: Vector2, px: float, dim: bool) -> void:
	if w == "" or not GameState.WEAPONS.has(w):
		return
	var art := HudArt.get_art("weapon_" + w)
	if art:
		var sz := art.get_size() * px
		draw_texture_rect(art, Rect2(at - sz * 0.5, sz), false, Color(0.55, 0.55, 0.58) if dim else Color.WHITE)
		return
	var c: Color = GameState.WEAPONS[w].color
	if dim:
		c = c.darkened(0.45)
	for k in range(-5, 7):
		var q := at + Vector2(k, -k) * px
		draw_rect(Rect2(q - Vector2(px, px), Vector2(px * 2, px * 2)), DARK)
	for k in range(-2, 7):
		var q := at + Vector2(k, -k) * px
		draw_rect(Rect2(q - Vector2(px * 0.5, px * 0.5), Vector2(px, px)), c.lightened(0.3) if k > 4 else c)
	for k in range(-2, 3):
		var q := at + Vector2(-3 + k, 3 + k) * px
		draw_rect(Rect2(q - Vector2(px * 0.5, px * 0.5), Vector2(px, px)), Color(0.75, 0.6, 0.3))
	for k in range(-5, -3):
		var q := at + Vector2(k, -k) * px
		draw_rect(Rect2(q - Vector2(px * 0.5, px * 0.5), Vector2(px, px)), Color(0.45, 0.3, 0.2))
