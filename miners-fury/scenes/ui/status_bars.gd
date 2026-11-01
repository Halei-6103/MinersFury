extends Control
## Connected health + dash bar, drawn as chunky pixel art (every "art pixel"
## is a PIXEL x PIXEL square on screen so it matches the sprites).
##
##   ___
##  /   \________________________________
## |  <3   HEALTH  |       |       |      |   red, thick, curved cap on the left
## |________________________________DASH__|   blue, thin, fused underneath
##
## Reads the player every frame: health / max_health, dash_charge / dash_max.

@export var pixel: int = 3
## art-pixel width of the whole bar
@export var bar_width: int = 96

# art-pixel layout
const CAP_W := 20          # width of the raised curved cap
const CAP_RISE := 7        # how much taller the cap is
const HP_TOP := 9          # top row of the health channel (after the cap)
const HP_BOTTOM := 16      # first row below the health channel
const DASH_TOP := 17
const DASH_BOTTOM := 20

const OUTLINE := Color(0.09, 0.06, 0.08)
const HP_BASE := Color(0.82, 0.16, 0.2)
const HP_HI := Color(1.0, 0.45, 0.42)
const HP_LO := Color(0.55, 0.07, 0.14)
const HP_EMPTY := Color(0.2, 0.11, 0.14)
const DRAIN := Color(1.0, 0.86, 0.72)
const DASH_BASE := Color(0.24, 0.62, 0.92)
const DASH_HI := Color(0.62, 0.88, 1.0)
const DASH_LO := Color(0.12, 0.38, 0.68)
const DASH_EMPTY := Color(0.1, 0.14, 0.22)
const DASH_CHARGING := Color(0.2, 0.42, 0.62)

var player: Node = null

var _shown_hp: float = -1.0      # the pale "drain" trail
var _drain_hold: float = 0.0
var _last_hp: int = -1
var _shake: float = 0.0
var _deny: float = 0.0
var _ready_flash: Array = []     # per dash charge, seconds left of the "ready" flash
var _last_charge: float = -1.0
var _t: float = 0.0


var _slots: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2((bar_width + 2) * pixel, (DASH_BOTTOM + 2) * pixel)
	# weapon slots sit just above the bar
	_slots = load("res://scenes/ui/weapon_slots.gd").new()
	_slots.position = Vector2(0, -56)
	add_child(_slots)


## the player calls this when the weapon changes
func set_weapons() -> void:
	if _slots:
		_slots.refresh()


## called by the player when you try to dash with no charge
func deny_dash() -> void:
	_deny = 0.35


func _process(delta: float) -> void:
	var real := minf(delta / maxf(Engine.time_scale, 0.001), 0.05)
	_t += real
	if player == null:
		return
	var hp: int = player.health
	var max_hp: int = max(player.max_health, 1)
	if _shown_hp < 0.0:
		_shown_hp = hp
		_last_hp = hp
	if hp < _last_hp:
		_drain_hold = 0.45
		_shake = 0.3
	elif hp > _last_hp:
		_shown_hp = hp
	_last_hp = hp
	if _drain_hold > 0.0:
		_drain_hold -= real
	else:
		_shown_hp = move_toward(_shown_hp, hp, real * 4.0)
	_shake = maxf(_shake - real, 0.0)
	_deny = maxf(_deny - real, 0.0)

	# flash a dash charge the moment it finishes refilling
	var charge: float = player.dash_charge
	var dmax: int = int(player.dash_max)
	if _ready_flash.size() != dmax:
		_ready_flash.resize(dmax)
		_ready_flash.fill(0.0)
	if _last_charge >= 0.0 and floor(charge) > floor(_last_charge):
		var idx := int(floor(charge)) - 1
		if idx >= 0 and idx < dmax:
			_ready_flash[idx] = 0.2
	_last_charge = charge
	for i in _ready_flash.size():
		_ready_flash[i] = maxf(_ready_flash[i] - real, 0.0)
	queue_redraw()


func _cap_top(x: int) -> int:
	# smooth curve from the raised cap down into the bar, like the sketch
	if x >= CAP_W:
		return HP_TOP
	var f := float(x) / CAP_W
	f = f * f * (3.0 - 2.0 * f)
	if x == 0:
		return HP_TOP - CAP_RISE + 1   # round off the top-left corner
	return HP_TOP - CAP_RISE + int(round(CAP_RISE * f))


func _px(x: int, y: int, w: int, h: int, c: Color, off: Vector2) -> void:
	draw_rect(Rect2(off + Vector2(x * pixel, y * pixel), Vector2(w * pixel, h * pixel)), c)


func _draw() -> void:
	if player == null:
		return
	var off := Vector2(pixel, pixel)
	if _shake > 0.0:
		var k := _shake / 0.3
		off += Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * pixel * k
	if _deny > 0.0:
		off.x += round(sin(_t * 70.0) * 2.0) * pixel * (_deny / 0.35)

	var W := bar_width
	var hp: int = player.health
	var max_hp: int = max(player.max_health, 1)
	var hp_cols := int(round(float(W) * hp / max_hp))
	var drain_cols := int(round(float(W) * _shown_hp / max_hp))
	var low := hp <= 1 and hp > 0
	var pulse := (0.5 + 0.5 * sin(_t * 9.0)) if low else 0.0

	# ---- outline: one dark pixel around the whole fused shape
	for x in range(-1, W + 1):
		var cx := clampi(x, 0, W - 1)
		var top := _cap_top(cx)
		_px(x, top - 1, 1, DASH_BOTTOM - top + 2, OUTLINE, off)

	# ---- health channel, column by column (so the cap curve is pixel-exact)
	for x in W:
		var top := _cap_top(x)
		var h := HP_BOTTOM - top
		if x < hp_cols:
			var base := HP_BASE.lerp(Color(1, 0.5, 0.5), pulse * 0.6)
			_px(x, top, 1, h, base, off)
			_px(x, top, 1, 1, HP_HI, off)
			_px(x, HP_BOTTOM - 1, 1, 1, HP_LO, off)
		elif x < drain_cols:
			_px(x, top, 1, h, DRAIN, off)
		else:
			_px(x, top, 1, h, HP_EMPTY, off)
			_px(x, top, 1, 1, HP_EMPTY.darkened(0.3), off)
	# segment notches between hit points
	for i in range(1, max_hp):
		var nx := int(round(float(W) * i / max_hp))
		_px(nx, HP_TOP + 1, 1, HP_BOTTOM - HP_TOP - 1, Color(OUTLINE, 0.55), off)

	# little pixel heart in the cap
	var heart := ["0110110", "1111111", "1111111", "0111110", "0011100", "0001000"]
	var hx := 3
	var hy := HP_TOP - CAP_RISE + 2
	for yy in heart.size():
		for xx in heart[yy].length():
			if heart[yy][xx] == "1":
				var c := Color(1, 0.95, 0.92) if hp > 0 else Color(0.45, 0.4, 0.42)
				if yy == 1 and xx in [1, 2]:
					c = Color(1, 1, 1)
				_px(hx + xx, hy + yy, 1, 1, c, off)

	# divider between the two bars
	_px(0, HP_BOTTOM, W, 1, OUTLINE, off)

	# ---- dash channel
	var charge: float = player.dash_charge
	var dmax := maxf(player.dash_max, 1.0)
	var full_cols := int(floor(charge)) * W / int(dmax)
	var part_cols := int(round(float(W) * charge / dmax))
	var dh := DASH_BOTTOM - DASH_TOP
	for x in W:
		if _deny > 0.0 and int(_t * 20.0) % 2 == 0:
			_px(x, DASH_TOP, 1, dh, Color(0.85, 0.2, 0.25), off)
		elif x < full_cols:
			_px(x, DASH_TOP, 1, dh, DASH_BASE, off)
			_px(x, DASH_TOP, 1, 1, DASH_HI, off)
			_px(x, DASH_BOTTOM - 1, 1, 1, DASH_LO, off)
		elif x < part_cols:
			_px(x, DASH_TOP, 1, dh, DASH_CHARGING, off)
		else:
			_px(x, DASH_TOP, 1, dh, DASH_EMPTY, off)
	# shimmer running across the full part
	if full_cols > 0:
		var sx := int(fmod(_t * 60.0, W + 30)) - 15
		for k in 3:
			var x := sx + k
			if x >= 0 and x < full_cols:
				_px(x, DASH_TOP, 1, dh, Color(1, 1, 1, 0.55 - k * 0.15), off)
	# notches between dash charges + "ready" flash
	var n := int(dmax)
	for i in n:
		var a := i * W / n
		var b := (i + 1) * W / n
		if i < _ready_flash.size() and _ready_flash[i] > 0.0:
			_px(a, DASH_TOP, b - a, dh, Color(1, 1, 1, _ready_flash[i] / 0.2), off)
		if i > 0:
			_px(a, DASH_TOP, 1, dh, OUTLINE, off)
