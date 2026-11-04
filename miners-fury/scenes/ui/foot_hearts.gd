extends Node2D
## Health squares (and dash dots) in the world, on every player.
##   You: under your feet.  Teammates: over their heads.
## Full and untouched: fades out after a couple of seconds so it stays out of
## the way. Any change brings it back. Last heart pulses and stays up.
## Lost hearts flash white for a moment.

const HudArt = preload("res://scenes/ui/hud_art.gd")

const PX := 1.6               # size of one "pixel" of a health square
const GAP := 3.0
const SHOW_FOR := 2.0
const FADE := 0.4
const HEART := ["0110110", "1111111", "1111111", "0111110", "0011100", "0001000"]
const RED := Color(0.85, 0.2, 0.25)
const DARK := Color(0.08, 0.05, 0.07)
const EDGE := Color(0.08, 0.05, 0.07, 0.4)   # the soft outline
const BLUE := Color(0.24, 0.56, 0.84)

var _p: Node = null
var _show: float = SHOW_FOR
var _last_hp: int = -1
var _last_dash: float = -1.0
var _flash: Dictionary = {}     # heart index -> seconds of white flash left
var _deny: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	_p = get_parent()
	z_index = 60
	z_as_relative = false


## you tried to dash with no charge: the dots blink red
func deny() -> void:
	_deny = 0.35
	_show = SHOW_FOR


func _process(delta: float) -> void:
	if _p == null:
		return
	var real := minf(delta / maxf(Engine.time_scale, 0.001), 0.05)
	_t += real
	var mine: bool = not _p.puppet
	position = Vector2(0, 24) if mine else Vector2(0, -84)
	var hp: int = _p.health
	if _last_hp >= 0 and hp != _last_hp:
		_show = SHOW_FOR
		for i in range(hp, _last_hp):
			_flash[i] = 0.3
	_last_hp = hp
	if mine:
		var d: float = _p.dash_charge
		if d < _p.dash_max or (_last_dash >= 0.0 and d != _last_dash):
			_show = SHOW_FOR
		_last_dash = d
	_show = maxf(_show - real, 0.0)
	_deny = maxf(_deny - real, 0.0)
	for k in _flash.keys():
		_flash[k] = _flash[k] - real
		if _flash[k] <= 0.0:
			_flash.erase(k)
	var down: bool = _p.state == _p.State.DEAD
	var want := 1.0
	if down:
		want = 0.0
	elif hp > 1 and _show <= 0.0:
		want = 0.0
	modulate.a = move_toward(modulate.a, want, real / FADE)
	visible = modulate.a > 0.01
	if visible:
		queue_redraw()


func _draw() -> void:
	var hp: int = _p.health
	var max_hp: int = maxi(_p.max_health, 1)
	var hw := 7.0 * PX
	var total := max_hp * hw + (max_hp - 1) * GAP
	var x0 := -total / 2.0
	var low := hp == 1
	var full_art := HudArt.get_art("heart_full")
	var empty_art := HudArt.get_art("heart_empty")
	for i in max_hp:
		var at := Vector2(x0 + i * (hw + GAP), 0)
		var filled := i < hp
		var grow := 1.0
		if low and filled:
			grow = 1.0 + 0.2 * (0.5 + 0.5 * sin(_t * 9.0))
		var tint := Color.WHITE
		if _flash.has(i):
			tint = Color(3, 3, 3)
		var art := full_art if filled else empty_art
		if art:
			var sz := art.get_size() * PX * grow
			draw_texture_rect(art, Rect2(at + Vector2(hw, 6 * PX) * 0.5 - sz * 0.5, sz), false, tint)
		else:
			_heart(at, filled, grow, _flash.has(i))
	if not _p.puppet:
		var dmax: int = int(_p.dash_max)
		var charge: float = _p.dash_charge
		var dot := 3.0 * PX
		var dw := dmax * dot + (dmax - 1) * 3.0
		for i in dmax:
			var c := Vector2(-dw / 2.0 + i * (dot + 3.0) + dot * 0.5, 6 * PX + 4.0 + dot * 0.5)
			var rad := dot * 0.5
			draw_circle(c, rad + 1.0, EDGE)
			if _deny > 0.0 and int(_t * 20.0) % 2 == 0:
				draw_circle(c, rad, Color(0.85, 0.2, 0.25))
			elif i < floor(charge):
				draw_circle(c, rad, BLUE)
			elif i < charge:
				var k: float = charge - floor(charge)
				draw_circle(c, rad, Color(0.15, 0.17, 0.22))
				draw_circle(c, rad * k, BLUE.darkened(0.3))
			else:
				draw_circle(c, rad, Color(0.15, 0.17, 0.22))


## health block: a plain square (filled = you have it, outline = lost)
func _heart(at: Vector2, filled: bool, grow: float, flash: bool) -> void:
	var sz := Vector2(7 * PX, 6 * PX) * grow
	var r := Rect2(at + Vector2(7 * PX, 6 * PX) * 0.5 - sz * 0.5, sz)
	draw_rect(r.grow(1.0), EDGE)
	if flash:
		draw_rect(r, Color.WHITE)
	elif filled:
		draw_rect(r, RED)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1.5)), RED.lightened(0.3))
	else:
		draw_rect(r, Color(0.2, 0.14, 0.17))
		draw_rect(r, RED.darkened(0.25), false, 1.5)
