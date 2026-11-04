extends Control
## Bottom-left weapon cluster (HUD layout D).
##   Big circle = the weapon in your hand. Its ring of yellow dashes is the
##   ultimate: the dashes light up clockwise while it cools down, glow + R when
##   it's ready (no glow, it stays still), flash when you use it.
##   Small circle = your other weapon. Its dashes light up while the swap
##   cools down; all lit = Q is ready.

const GameState = preload("res://scenes/core/game_state.gd")
const HudArt = preload("res://scenes/ui/hud_art.gd")

const BIG_L := Vector2(42, 54)   # centre of the big circle (left-handed layout)
const BIG_R := 42.0
const RING_W := 3.0
const SMALL_L := Vector2(102, 20) # centre of the small circle
const SMALL_R := 20.0
const DARK := Color(0.08, 0.06, 0.08)
const FACE := Color(0.14, 0.11, 0.13, 0.92)
const TRACK := Color(0.23, 0.18, 0.21, 0.9)
const GOLD := Color(1.0, 0.84, 0.42)

## true = ring on the right, other weapon tucked on its left (bottom-right corner)
var mirror: bool = false
var BIG := BIG_L
var SMALL := SMALL_L
var _t: float = 0.0
var _swap_anim: float = 0.0
var _used_flash: float = 0.0
var _last_k: float = -1.0
var _q_ready_flash: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(124, 112)
	size = custom_minimum_size
	if mirror:
		BIG = Vector2(size.x - BIG_L.x, BIG_L.y)
		SMALL = Vector2(size.x - SMALL_L.x, SMALL_L.y)


## weapon changed (swap / equip)
func refresh() -> void:
	_swap_anim = 0.22
	_last_k = -1.0


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	var real := minf(delta / maxf(Engine.time_scale, 0.001), 0.05)
	_t += real
	_swap_anim = maxf(_swap_anim - real, 0.0)
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
	var active: int = GameState.active_slot
	var w_in: String = GameState.slots[active]
	var w_out: String = GameState.slots[1 - active]
	var k := -1.0
	if p and p.has_method("ult_charge"):
		k = p.ult_charge()
	var col: Color = GameState.WEAPONS[w_in].color if GameState.WEAPONS.has(w_in) else Color(0.8, 0.8, 0.85)

	# while swapping, the two icons slide past each other
	var s := _swap_anim / 0.22
	var big_icon_at := BIG.lerp(SMALL, s)
	var small_icon_at := SMALL.lerp(BIG, s)

	# ---- big circle + ult ring: a ring of yellow dashes that light up one by
	# one, clockwise from the top, as the ultimate cools down
	var ready := k >= 1.0
	var Y := HudArt.YELLOW
	draw_circle(BIG, BIG_R - RING_W - 2.0, FACE)
	if k >= 0.0:
		HudArt.dashed_ring(self, BIG, BIG_R - RING_W * 0.5, Y, RING_W, 28, k, Color(Y, 0.2))
	else:
		# this weapon has no ultimate: just the faint outline
		HudArt.dashed_ring(self, BIG, BIG_R - RING_W * 0.5, Color(Y, 0.2), RING_W, 28)
	if _used_flash > 0.0:
		HudArt.dashed_ring(self, BIG, BIG_R - RING_W * 0.5, Color(1, 1, 1, _used_flash / 0.35), RING_W, 28)
	_icon(w_in, big_icon_at, 2.4, false)

	# R badge pops in when the ultimate is ready
	if ready:
		_badge(BIG + Vector2(0, BIG_R - 2), "R", GOLD, DARK)

	# ---- small circle: the other weapon. Its dashed ring lights up as the
	# swap cools down; all lit = you can press Q
	var q := 1.0
	if p and p.has_method("swap_charge"):
		q = clampf(p.swap_charge(), 0.0, 1.0)
	draw_circle(SMALL, SMALL_R, FACE)
	var sc := Y
	if q >= 1.0 and _q_ready_flash > 0.0:
		sc = Y.lerp(Color.WHITE, _q_ready_flash / 0.3)
	HudArt.dashed_ring(self, SMALL, SMALL_R - 1.0, sc, 2.0, 16, q, Color(Y, 0.2))
	_icon(w_out, small_icon_at, 1.3, true)

	var qc := SMALL + Vector2((SMALL_R - 4) if mirror else (-SMALL_R + 4), SMALL_R - 4)
	if q < 1.0:
		_q_ready_flash = 0.3
		_badge(qc, "Q", Color(0.12, 0.1, 0.12), Color(0.6, 0.58, 0.6))
	else:
		_badge(qc, "Q", Color(0.12, 0.1, 0.12), Color.WHITE)


## a weapon's icon: your art if there is some (weapon_<id>.png), else a pixel sword
func _icon(w: String, at: Vector2, px: float, dim: bool) -> void:
	if w == "" or not GameState.WEAPONS.has(w):
		return
	var art := HudArt.get_art("weapon_" + w)
	var tint := Color(0.55, 0.55, 0.58) if dim else Color.WHITE
	if art:
		var sz := art.get_size() * px
		draw_texture_rect(art, Rect2(at - sz * 0.5, sz), false, tint)
		return
	var c: Color = GameState.WEAPONS[w].color
	if dim:
		c = c.darkened(0.45)
	_sword(at, c, px)


func _badge(at: Vector2, letter: String, bg: Color, fg: Color, scale_k: float = 1.0) -> void:
	var sz := 18.0 * scale_k
	var r := Rect2(at - Vector2(sz, sz) * 0.5, Vector2(sz, sz))
	draw_rect(r, bg)
	HudArt.dashed_rect(self, r, HudArt.YELLOW if fg != Color(0.6, 0.58, 0.6) else Color(HudArt.YELLOW, 0.4), 1.5, 3.0)
	var font := HudArt.font()
	var fs := int(12 * scale_k)
	var tw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, at + Vector2(-tw * 0.5, fs * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)


## stand-in diagonal pixel sword until there's a weapon icon
func _sword(c: Vector2, col: Color, px: float) -> void:
	var dark := DARK
	for k in range(-5, 7):
		var p := c + Vector2(k, -k) * px
		draw_rect(Rect2(p - Vector2(px, px), Vector2(px * 2, px * 2)), dark)
	for k in range(-2, 7):
		var p := c + Vector2(k, -k) * px
		draw_rect(Rect2(p - Vector2(px * 0.5, px * 0.5), Vector2(px, px)), col.lightened(0.3) if k > 4 else col)
	for k in range(-2, 3):
		var p := c + Vector2(-3 + k, 3 + k) * px
		draw_rect(Rect2(p - Vector2(px * 0.5, px * 0.5), Vector2(px, px)), Color(0.75, 0.6, 0.3))
	for k in range(-5, -3):
		var p := c + Vector2(k, -k) * px
		draw_rect(Rect2(p - Vector2(px * 0.5, px * 0.5), Vector2(px, px)), Color(0.45, 0.3, 0.2))
