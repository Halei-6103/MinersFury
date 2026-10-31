extends Node2D
## The camp hub. Wires up the stations (telecom, seed shop, farm).
## The telecom opens the uplink menu (cargo, fabricate, armory).
## Other stations still show the simple info panel for now.

const TransferBoard = preload("res://scenes/levels/shared/transfer_board.gd")
const Music = preload("res://scenes/audio/music.gd")
const GameState = preload("res://scenes/core/game_state.gd")
const Juice = preload("res://scenes/effects/juice.gd")
const LightningBolt = preload("res://scenes/effects/lightning_bolt.gd")

@onready var info_panel: PanelContainer = $UI/InfoPanel
@onready var info_title: Label = $UI/InfoPanel/Margin/VBox/Title
@onready var info_body: Label = $UI/InfoPanel/Margin/VBox/Body

var _open_station: Area2D = null
var _uplink: Control = null
var _busy: bool = false   # fabricate cinematic running

const C_BG := Color(0.07, 0.09, 0.16, 0.96)
const C_EDGE := Color(0.35, 0.7, 1.0)
const C_DIM := Color(0.6, 0.68, 0.8)
const C_GOOD := Color(0.55, 1.0, 0.6)
const C_BAD := Color(1.0, 0.45, 0.4)
const C_GOLD := Color(1.0, 0.85, 0.3)


func _ready() -> void:
	info_panel.visible = false
	GameState.ensure_loaded()
	for station in get_tree().get_nodes_in_group("hub_station"):
		if station.station_id == "transfer":
			continue  # the transfer board handles itself
		station.interacted.connect(_on_station_interacted)
		station.player_left.connect(_on_station_left)
	TransferBoard.place_player(self)
	Music.ensure(self)


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


func _on_station_interacted(station: Area2D) -> void:
	if _busy:
		return
	if _open_station == station:
		_close_panel()
		return
	_close_panel()
	_open_station = station
	if station.station_id == "telecom":
		_open_uplink()
		return
	info_title.text = station.station_name
	info_body.text = station.description
	info_panel.visible = true


func _on_station_left(station: Area2D) -> void:
	if _open_station == station:
		_close_panel()


func _close_panel() -> void:
	_open_station = null
	info_panel.visible = false
	if _uplink:
		_uplink.queue_free()
		_uplink = null
		_lock_player(false)


func _unhandled_input(event: InputEvent) -> void:
	if _uplink and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_panel()


## stop the player swinging/walking while a menu is up
func _lock_player(on: bool) -> void:
	var p := _player()
	if p == null:
		return
	p.set_physics_process(not on)
	if on:
		p.velocity = Vector2.ZERO
		p.animated_sprite.play("idle")


# ---------------------------------------------------------------- uplink menu

func _style(bg: Color, edge: Color, w: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(w)
	s.set_content_margin_all(12)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 6
	return s


func _label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0.05))
	return l


func _icon(path: String, frames: int, k: float = 2.0) -> TextureRect:
	var tex: Texture2D = load(path)
	var a := AtlasTexture.new()
	a.atlas = tex
	var fw := tex.get_width() / frames
	a.region = Rect2(0, 0, fw, tex.get_height())
	var r := TextureRect.new()
	r.texture = a
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.custom_minimum_size = Vector2(fw, tex.get_height()) * k
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return r


func _button(text: String, enabled: bool, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", _style(color.darkened(0.6), color, 2))
	b.add_theme_stylebox_override("hover", _style(color.darkened(0.4), color.lightened(0.3), 2))
	b.add_theme_stylebox_override("pressed", _style(color.darkened(0.2), Color.WHITE, 2))
	b.add_theme_stylebox_override("disabled", _style(Color(0.12, 0.12, 0.16), Color(0.3, 0.3, 0.35), 2))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.5))
	return b


func _section(title: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(_label(title, 15, C_EDGE))
	return v


func _open_uplink() -> void:
	_lock_player(true)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(root)
	_uplink = root

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(C_BG, C_EDGE, 3))
	panel.custom_minimum_size = Vector2(720, 0)
	center.add_child(panel)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 14)
	panel.add_child(main)

	var head := HBoxContainer.new()
	head.add_child(_label("TELECOM UPLINK", 26, Color.WHITE))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var status := _label("EARTH LINK: ONLINE", 13, C_GOOD)
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(status)
	main.add_child(head)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	main.add_child(cols)

	# --- cargo
	var cargo := _section("CARGO")
	cargo.custom_minimum_size.x = 220
	var any := false
	for id in GameState.ITEMS:
		var n := GameState.count(id)
		if n <= 0:
			continue
		any = true
		var row := HBoxContainer.new()
		row.add_child(_icon(GameState.ITEMS[id].icon, GameState.ITEMS[id].frames, 1.2))
		row.add_child(_label("%s  x%d" % [GameState.ITEMS[id].name, n], 15))
		cargo.add_child(row)
	for id in GameState.blueprints:
		any = true
		var row := HBoxContainer.new()
		row.add_child(_icon(GameState.BLUEPRINTS[id].icon, GameState.BLUEPRINTS[id].frames, 1.5))
		row.add_child(_label(GameState.BLUEPRINTS[id].name, 15, Color(0.7, 0.85, 1.0)))
		cargo.add_child(row)
	if not any:
		var e := _label("Nothing yet.\nGo hunt in the wasteland.", 14, C_DIM)
		cargo.add_child(e)
	cols.add_child(cargo)

	# --- fabricate + armory
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 18)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)

	var fab := _section("FABRICATE")
	var shown := 0
	for w in GameState.WEAPONS:
		var r: Dictionary = GameState.WEAPONS[w].get("recipe", {})
		if r.is_empty():
			continue
		# only show weapons you've found the blueprint for (or already built)
		if not GameState.knows(r.get("blueprint", w)):
			continue
		shown += 1
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(Color(0.1, 0.14, 0.24), Color(0.25, 0.45, 0.75), 2))
		var v := VBoxContainer.new()
		card.add_child(v)
		v.add_child(_label(GameState.WEAPONS[w].name, 20, C_GOLD))
		v.add_child(_label(GameState.WEAPONS[w].desc, 13, C_DIM))
		if GameState.owns(w):
			v.add_child(_label("Built", 14, C_GOOD))
		else:
			var has_bp := GameState.has_blueprint(r.blueprint)
			v.add_child(_label(("[x] " if has_bp else "[ ] ") + "Blueprint", 14, C_GOOD if has_bp else C_BAD))
			for id in r.get("items", {}):
				var need := int(r.items[id])
				var have := GameState.count(id)
				v.add_child(_label("%s %s  %d/%d" % ["[x]" if have >= need else "[ ]", GameState.display_name(id), have, need], 14, C_GOOD if have >= need else C_BAD))
			var b := _button("SEND TO EARTH + FABRICATE", GameState.can_fabricate(w), Color(0.35, 0.7, 1.0))
			b.pressed.connect(_fabricate.bind(w))
			v.add_child(b)
		fab.add_child(card)
	if shown == 0:
		fab.add_child(_label("No blueprints yet.\nBig monsters carry the good stuff.", 14, C_DIM))
	right.add_child(fab)

	var arm := _section("ARMORY")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for w in GameState.weapons:
		var eq: bool = GameState.equipped == w
		var b := _button(GameState.WEAPONS[w].name + ("  (equipped)" if eq else ""), not eq, C_GOLD if w == "storm_blade" else Color(0.75, 0.75, 0.8))
		b.pressed.connect(_equip.bind(w))
		row.add_child(b)
	arm.add_child(row)
	right.add_child(arm)

	main.add_child(_label("[E] / [Esc] close", 12, C_DIM))

	# pop in
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)
	panel.scale = Vector2(0.92, 0.92)
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_uplink() -> void:
	var st := _open_station
	_close_panel()
	if st:
		_open_station = st
		_open_uplink()


func _equip(w: String) -> void:
	GameState.equip(w)
	var p := _player()
	if p and p.has_method("set_weapon"):
		p.set_weapon(w)
		Juice.damage_number(p.get_parent(), p.global_position + Vector2(0, -70), GameState.WEAPONS[w].name + " equipped", C_GOLD, 18)
	_refresh_uplink()


# ---------------------------------------------------------------- fabricate

## crystal beams up to Earth, the new sword beams back down onto you
func _fabricate(w: String) -> void:
	if not GameState.fabricate(w):
		return
	var station := _open_station
	_close_panel()
	_busy = true
	_lock_player(true)
	var p := _player()
	var dish: Vector2 = station.get_parent().global_position + Vector2(0, -40) if station else Vector2.ZERO

	# 1. uplink: beam shoots into the sky from the telecom
	_beam(dish, Color(0.35, 0.7, 1.0), 0.9, 26.0)
	Juice.shake(self, 0.35)
	_float_text(dish + Vector2(0, -80), "TRANSMITTING...", Color(0.6, 0.85, 1.0))
	await get_tree().create_timer(1.3).timeout

	# 2. Earth answers: beam lands on the player
	var at: Vector2 = p.global_position if p else dish
	_float_text(at + Vector2(0, -150), "INCOMING", C_GOLD)
	await get_tree().create_timer(0.6).timeout
	_beam(at, Color(1.0, 0.9, 0.45), 0.8, 46.0)
	for i in 4:
		LightningBolt.zap(self, at + Vector2(randf_range(-60, 60), -340), at + Vector2(randf_range(-30, 30), randf_range(-10, 10)), 1.6, 0.3)
	Juice.shockwave(self, at, 40.0)
	Juice.impact_flash(self, 0.6, Color(1, 0.95, 0.7))
	Juice.shake(self, 0.9)
	Juice.zoom_punch(self, 0.12)
	GameState.equip(w)
	if p and p.has_method("set_weapon"):
		p.set_weapon(w)
	_acquired_banner(GameState.WEAPONS[w].name)
	await get_tree().create_timer(1.2).timeout
	_lock_player(false)
	_busy = false


func _beam(ground: Vector2, color: Color, life: float, width: float) -> void:
	var b := Node2D.new()
	b.z_index = 50
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	b.material = m
	add_child(b)
	b.global_position = ground
	var t := {"v": 0.0}
	b.draw.connect(func():
		var k: float = t.v
		var a := sin(k * PI)
		var w := width * (0.4 + 0.6 * a)
		b.draw_rect(Rect2(-w, -900, w * 2, 900), Color(color.r, color.g, color.b, 0.25 * a))
		b.draw_rect(Rect2(-w * 0.45, -900, w * 0.9, 900), Color(color.r, color.g, color.b, 0.6 * a))
		b.draw_rect(Rect2(-w * 0.15, -900, w * 0.3, 900), Color(1, 1, 1, 0.9 * a))
		b.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
		b.draw_circle(Vector2.ZERO, w * 1.6, Color(color.r, color.g, color.b, 0.5 * a))
		b.draw_set_transform(Vector2.ZERO))
	var tw := b.create_tween()
	tw.tween_method(func(v: float) -> void:
		t.v = v
		b.queue_redraw(), 0.0, 1.0, life)
	tw.tween_callback(b.queue_free)


func _float_text(pos: Vector2, text: String, color: Color) -> void:
	Juice.damage_number(self, pos, text, color, 20)


func _acquired_banner(weapon_name: String) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -420
	box.offset_right = 420
	box.offset_top = -200
	box.offset_bottom = -60
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a := _label("WEAPON ACQUIRED", 26, Color.WHITE)
	var b := _label(weapon_name.to_upper(), 60, C_GOLD)
	b.add_theme_constant_override("outline_size", 14)
	for l in [a, b]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	$UI.add_child(box)
	box.pivot_offset = Vector2(420, 70)
	box.scale = Vector2(2.2, 2.2)
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.06)
	tw.parallel().tween_property(box, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.0)
	tw.tween_property(box, "modulate:a", 0.0, 0.4)
	tw.tween_callback(box.queue_free)
