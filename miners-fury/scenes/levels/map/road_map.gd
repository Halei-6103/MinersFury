extends Node2D
## Road map. Click a circle to go there. Lines show the order.
##   grey  = haven't played it yet
##   red   = locked (clear the one before it first)
##   green = cleared (Colosseum: once you've had a go)
## Esc goes back to camp.

const GameState = preload("res://scenes/core/game_state.gd")
const Music = preload("res://scenes/audio/music.gd")
const GameUI = preload("res://scenes/ui/game_ui.gd")
const UI = preload("res://scenes/ui/ui_kit.gd")

const CAMP_SCENE := "res://scenes/levels/hub/hub.tscn"
const STOPS := [
	{"id": "camp", "pos": Vector2(300, 524)},
	{"id": "forest", "pos": Vector2(636, 336)},
	{"id": "wasteland", "pos": Vector2(992, 452)},
	{"id": "colosseum", "pos": Vector2(1120, 192)},
	{"id": "trial", "pos": Vector2(578, 628)},
]
## which stops are joined by a line
const LINKS := [[0, 1], [1, 2], [2, 3], [0, 4]]
## the Weapon Proficiency trial (not part of the main road): opens once you own
## both blades, and you can replay it as often as you like after beating it
const TRIAL := {"id": "trial", "name": "Pufferfish Trial", "boss": "Pufferfish",
	"scene": "res://scenes/levels/trial/trial.tscn", "trial": true}
const RADIUS := 28.0

const GREY := Color(0.62, 0.63, 0.66)
const RED := Color(0.9, 0.26, 0.24)
const GREEN := Color(0.35, 0.88, 0.42)
const CAMP_COL := Color(1.0, 0.82, 0.32)
const OUTLINE := Color(0.08, 0.06, 0.08)

var _hover: int = -1
var _pop: Array = []     # hover grow per node
var _shake: Array = []   # "nope" wiggle on locked nodes
var _t: float = 0.0
var _leaving: bool = false
var _tip: PanelContainer
var _tip_box: VBoxContainer


func _ready() -> void:
	for i in STOPS.size():
		_pop.append(0.0)
		_shake.append(0.0)
	Music.ensure(self)
	GameUI.ensure(self)
	GameState.ensure_loaded()
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/sprites/map/road_map.png")
	bg.centered = false
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.z_index = -1
	add_child(bg)
	_build_ui()
	var flash := ColorRect.new()
	flash.color = Color(0.7, 0.95, 1.0, 1.0)
	flash.size = Vector2(4000, 4000)
	flash.position = Vector2(-1000, -1000)
	flash.z_index = 100
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.5)
	tw.tween_callback(flash.queue_free)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := UI.label("ROAD MAP", 30)
	title.position = Vector2(28, 20)
	layer.add_child(title)
	var hint := UI.label("Click a circle to go there      Esc  back to camp", 14, UI.DIM)
	hint.position = Vector2(30, 62)
	layer.add_child(hint)
	# legend
	var leg := UI.panel(UI.EDGE)
	leg.position = Vector2(24, 600)
	layer.add_child(leg)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 2)
	leg.add_child(lv)
	for row in [[GREY, "Not played yet"], [RED, "Locked"], [GREEN, "Cleared"]]:
		var h := HBoxContainer.new()
		var dot := ColorRect.new()
		dot.color = row[0]
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(dot)
		h.add_child(UI.label("  " + row[1], 13))
		lv.add_child(h)
	# hover card
	_tip = UI.panel(UI.EDGE, 300.0)
	_tip.visible = false
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_tip)
	_tip_box = VBoxContainer.new()
	_tip_box.add_theme_constant_override("separation", 3)
	_tip.add_child(_tip_box)


func _map_info(id: String) -> Dictionary:
	if id == "trial":
		return TRIAL
	for m in GameState.MAPS:
		if m.id == id:
			return m
	return {}


func _status(i: int) -> String:
	var id: String = STOPS[i].id
	if id == "camp":
		return "camp"
	if id == "trial":
		if not (GameState.owns("storm_blade") and GameState.owns("venom_blade")):
			return "locked"
		return "done" if GameState.has_mastery("tetrodotoxin") else "open"
	if not GameState.is_unlocked(id):
		return "locked"
	return "done" if GameState.is_played(id) else "open"


func _color(i: int) -> Color:
	match _status(i):
		"camp": return CAMP_COL
		"locked": return RED
		"done": return GREEN
	return GREY


func _process(delta: float) -> void:
	_t += delta
	var mp := get_global_mouse_position()
	var h := -1
	if not _leaving:
		for i in STOPS.size():
			if mp.distance_to(STOPS[i].pos) < RADIUS + 8:
				h = i
	if h != _hover:
		_hover = h
		_fill_tip()
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if h >= 0 else Input.CURSOR_ARROW)
	for i in STOPS.size():
		_pop[i] = move_toward(_pop[i], 1.0 if i == _hover else 0.0, delta * 8.0)
		_shake[i] = maxf(_shake[i] - delta, 0.0)
	if _hover >= 0:
		var p: Vector2 = STOPS[_hover].pos
		var at := p + Vector2(RADIUS + 18, -40)
		if at.x + _tip.size.x > 1260:
			at.x = p.x - RADIUS - 18 - _tip.size.x
		at.y = clampf(at.y, 10, 710 - _tip.size.y)
		_tip.position = at
	queue_redraw()


func _fill_tip() -> void:
	for c in _tip_box.get_children():
		c.queue_free()
	_tip.visible = _hover >= 0
	_tip.size = Vector2.ZERO
	if _hover < 0:
		return
	var id: String = STOPS[_hover].id
	var st := _status(_hover)
	if id == "camp":
		_tip_box.add_child(UI.label("CAMP", 22, CAMP_COL))
		_tip_box.add_child(UI.label("Telecom, crafting station, your tent.", 13, UI.DIM))
		_tip_box.add_child(UI.label("Click to go back", 14))
		return
	var m := _map_info(id)
	_tip_box.add_child(UI.label(m.name.to_upper(), 22, _color(_hover)))
	if m.get("trial", false):
		_tip_box.add_child(UI.label("Weapon Proficiency. Just you and the fish.", 14))
		_tip_box.add_child(UI.label("Beat it to learn Tetrodotoxin\n(Venom rune + Storm thunderclap).", 13, UI.DIM))
	elif m.get("endless", false):
		_tip_box.add_child(UI.label("Endless rounds. Bosses every 5.", 14))
		_tip_box.add_child(UI.label("How long can you last?", 13, UI.DIM))
		if GameState.best_round > 0:
			_tip_box.add_child(UI.label("Best: round %d   (%d kills)" % [GameState.best_round, GameState.best_kills], 14, UI.GOLD))
	else:
		_tip_box.add_child(UI.label("Boss: " + m.boss, 14))
		if id == "forest":
			_tip_box.add_child(UI.label("Drops: Wolf Pelt, Orc Tusk, Slime Goo,\nBat Wing. Boss: Storm Shard", 12, UI.DIM))
		elif id == "wasteland":
			_tip_box.add_child(UI.label("Drops: Bone, Slime Goo, Bat Wing.\nBoss: Tomb Shard", 12, UI.DIM))
	match st:
		"locked" when m.get("trial", false):
			_tip_box.add_child(UI.label("LOCKED: craft the Storm Blade\nand the Venom Blade first", 14, RED))
		"locked":
			_tip_box.add_child(UI.label("LOCKED: clear %s first" % _map_info(STOPS[_hover - 1].id).get("name", "the last area"), 14, RED))
		"done":
			var again := "CLEARED. Click to fight again"
			if m.get("endless", false):
				again = "Click to fight"
			elif m.get("trial", false):
				again = "MASTERED. Click to replay"
			_tip_box.add_child(UI.label(again, 14, GREEN))
		_:
			_tip_box.add_child(UI.label("Click to fight", 14))


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_go(0)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _hover >= 0:
		if _status(_hover) == "locked":
			_shake[_hover] = 0.35
			_say(STOPS[_hover].pos, "Locked")
		else:
			_go(_hover)


func _say(at: Vector2, text: String) -> void:
	var l := UI.label(text, 18, RED)
	l.position = at + Vector2(-30, -70)
	l.z_index = 50
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 30, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	tw.tween_callback(l.queue_free)


func _go(i: int) -> void:
	_leaving = true
	_tip.visible = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	var id: String = STOPS[i].id
	var scene: String = CAMP_SCENE
	var spawn := "FromWasteland"
	if id != "camp":
		scene = _map_info(id).scene
		spawn = "Start"
	if id == "trial":
		Engine.set_meta("trial_attempt", 0)
	var flash := ColorRect.new()
	flash.color = Color(0.7, 0.95, 1.0, 0.0)
	flash.size = Vector2(4000, 4000)
	flash.position = Vector2(-1000, -1000)
	flash.z_index = 100
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 1.0, 0.3)
	tw.tween_callback(func() -> void:
		Engine.set_meta("arrival_spawn", spawn)
		get_tree().change_scene_to_file(scene))


func _draw() -> void:
	# lines first so the circles sit on top
	for l in LINKS:
		var a: Vector2 = STOPS[l[0]].pos
		var b: Vector2 = STOPS[l[1]].pos
		var col := _color(l[1])
		if _status(l[1]) == "locked":
			col = col.darkened(0.35)
		draw_line(a, b, OUTLINE, 11.0)
		draw_line(a, b, col.darkened(0.25), 6.0)
		# little dashes running along the line toward the next stop
		var dir := (b - a).normalized()
		var length := a.distance_to(b)
		var off := fmod(_t * 40.0, 24.0)
		var s := RADIUS + off
		while s < length - RADIUS:
			draw_line(a + dir * s, a + dir * minf(s + 8.0, length - RADIUS), col.lightened(0.35), 2.0)
			s += 24.0
	var font := ThemeDB.fallback_font
	for i in STOPS.size():
		var id: String = STOPS[i].id
		var col := _color(i)
		var st := _status(i)
		var wig: float = sin(_t * 60.0) * 5.0 * (_shake[i] / 0.35)
		var p: Vector2 = STOPS[i].pos + Vector2(wig, 0)
		var r: float = RADIUS * (1.0 + 0.15 * _pop[i])
		# soft drop shadow, then the button
		draw_circle(p + Vector2(0, 5), r + 3, Color(0, 0, 0, 0.35))
		draw_circle(p, r + 4, OUTLINE)
		draw_circle(p, r, col.darkened(0.3))
		draw_circle(p + Vector2(-r * 0.15, -r * 0.18), r * 0.78, col)
		draw_arc(p, r - 2, PI * 1.05, PI * 1.6, 12, col.lightened(0.45), 3.0)
		if _pop[i] > 0.0:
			var ring := r + 8 + 3 * sin(_t * 6.0)
			draw_arc(p, ring, 0, TAU, 40, Color(col, 0.7 * _pop[i]), 3.0)
		# icon in the middle
		match st:
			"locked":
				draw_rect(Rect2(p + Vector2(-9, -3), Vector2(18, 14)), OUTLINE)
				draw_rect(Rect2(p + Vector2(-7, -1), Vector2(14, 10)), Color(0.95, 0.85, 0.6))
				draw_arc(p + Vector2(0, -4), 6.0, PI, TAU, 10, OUTLINE, 5.0)
				draw_arc(p + Vector2(0, -4), 6.0, PI, TAU, 10, Color(0.95, 0.95, 0.95), 2.0)
			"done":
				var pts := PackedVector2Array([p + Vector2(-10, 0), p + Vector2(-3, 8), p + Vector2(11, -8)])
				draw_polyline(pts, OUTLINE, 7.0)
				draw_polyline(pts, Color.WHITE, 3.5)
			"camp":
				draw_colored_polygon(PackedVector2Array([p + Vector2(-12, 9), p + Vector2(0, -10), p + Vector2(12, 9)]), OUTLINE)
				draw_colored_polygon(PackedVector2Array([p + Vector2(-9, 7), p + Vector2(0, -6), p + Vector2(9, 7)]), Color(1, 0.97, 0.88))
			_:
				# crossed swords: fight here
				for sgn in [-1.0, 1.0]:
					var a := p + Vector2(-9 * sgn, 9)
					var b := p + Vector2(9 * sgn, -9)
					draw_line(a, b, OUTLINE, 6.0)
					draw_line(a, b, Color.WHITE, 2.5)
		var name_txt: String = "Camp" if id == "camp" else _map_info(id).name
		var fs := 17
		var w := font.get_string_size(name_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var np: Vector2 = STOPS[i].pos + Vector2(-w / 2, RADIUS + 26)
		draw_string_outline(font, np, name_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 7, OUTLINE)
		draw_string(font, np, name_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col.lightened(0.2))
