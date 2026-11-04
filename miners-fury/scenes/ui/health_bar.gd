extends Control
## Bottom-left health + dash, styled like the HUD mockup:
##   a dashed yellow box with a flat red health fill inside,
##   and under it one small bar per dash charge (solid blue when ready,
##   dashed blue outline when empty).
## Lost health drains away as a light trail; last hit point pulses; trying to
## dash with nothing left blinks the bars red; a bar flashes when it refills.

const HudArt = preload("res://scenes/ui/hud_art.gd")

const BAR_W := 200.0
const BAR_H := 24.0
const PAD := 4.0
const PILL_W := 44.0
const PILL_H := 8.0
const PILL_GAP := 6.0
const TRAIL := Color(1.0, 0.86, 0.72)

var player: Node = null

var _shown_hp: float = -1.0
var _last_hp: int = -1
var _hold: float = 0.0
var _deny: float = 0.0
var _ready_flash: Array = []
var _last_charge: float = -1.0
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(BAR_W, BAR_H + 6 + PILL_H)
	size = custom_minimum_size


## called by the player when you try to dash with no charge
func deny_dash() -> void:
	_deny = 0.35


func _process(delta: float) -> void:
	var real := minf(delta / maxf(Engine.time_scale, 0.001), 0.05)
	_t += real
	if player == null:
		return
	var hp: int = player.health
	if _shown_hp < 0.0 or hp > _last_hp:
		_shown_hp = hp
	elif hp < _last_hp:
		_hold = 0.45
	_last_hp = hp
	if _hold > 0.0:
		_hold -= real
	else:
		_shown_hp = move_toward(_shown_hp, hp, real * 4.0)
	_deny = maxf(_deny - real, 0.0)
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


func _draw() -> void:
	if player == null:
		return
	var hp: int = player.health
	var mx := float(maxi(player.max_health, 1))
	var box := Rect2(0, 0, BAR_W, BAR_H)
	HudArt.panel(self, box)
	var inner := box.grow(-PAD)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * clampf(_shown_hp / mx, 0, 1), inner.size.y)), TRAIL)
	var fill := HudArt.RED
	if hp == 1:
		fill = fill.lerp(Color(1, 0.55, 0.55), 0.5 + 0.5 * sin(_t * 9.0))
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * clampf(hp / mx, 0, 1), inner.size.y)), fill)

	var dmax := maxi(int(player.dash_max), 1)
	var charge: float = player.dash_charge
	for i in dmax:
		var r := Rect2(i * (PILL_W + PILL_GAP), BAR_H + 6, PILL_W, PILL_H)
		if _deny > 0.0 and int(_t * 20.0) % 2 == 0:
			draw_rect(r, Color(0.85, 0.2, 0.25))
			continue
		var k := clampf(charge - i, 0.0, 1.0)
		if k >= 1.0:
			draw_rect(r, HudArt.BLUE)
		else:
			if k > 0.0:
				draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), HudArt.BLUE.darkened(0.35))
			HudArt.dashed_rect(self, r, HudArt.BLUE, 2.0, 5.0)
		if i < _ready_flash.size() and _ready_flash[i] > 0.0:
			draw_rect(r, Color(1, 1, 1, _ready_flash[i] / 0.2))
