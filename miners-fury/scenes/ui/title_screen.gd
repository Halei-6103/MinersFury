extends Control
## Boot title screen. PLAY drops you into camp; NEW GAME wipes the save first.

const Music = preload("res://scenes/audio/music.gd")
const GameState = preload("res://scenes/core/game_state.gd")
const GameUI = preload("res://scenes/ui/game_ui.gd")
const UI = preload("res://scenes/ui/ui_kit.gd")

const HUB := "res://scenes/levels/hub/hub.tscn"
const BG := "res://assets/ui/title_bg.jpg"

var _confirm_new: bool = false
var _options: Control = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	GameState.ensure_loaded()
	GameUI.ensure(self)
	Music.ensure(self)
	_build()


func _build() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = load(BG)
	if tex:
		bg.texture = tex
	else:
		var fallback := ColorRect.new()
		fallback.color = Color(0.04, 0.05, 0.09)
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fallback)
	add_child(bg)

	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.03, 0.06, 0.42)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 64)
	root.add_theme_constant_override("margin_right", 64)
	root.add_theme_constant_override("margin_top", 72)
	root.add_theme_constant_override("margin_bottom", 48)
	add_child(root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	root.add_child(col)

	var brand := UI.label("MINERS FURY", 72, UI.GOLD)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_constant_override("outline_size", 10)
	col.add_child(brand)

	var tag := UI.label("Unleash your fury.", 18, UI.DIM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size.y = 40
	col.add_child(spacer)

	var menu_wrap := CenterContainer.new()
	col.add_child(menu_wrap)

	var panel := UI.panel(UI.EDGE, 320.0)
	menu_wrap.add_child(panel)

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	panel.add_child(menu)

	var play := UI.button("PLAY", true, UI.EDGE, 22)
	play.custom_minimum_size = Vector2(260, 48)
	play.pressed.connect(_play)
	menu.add_child(play)

	var fresh := UI.button("NEW GAME", true, UI.BAD, 18)
	fresh.custom_minimum_size = Vector2(260, 40)
	fresh.pressed.connect(_new_game.bind(fresh))
	menu.add_child(fresh)

	var opts := UI.button("OPTIONS", true, Color(0.55, 0.7, 0.9), 18)
	opts.custom_minimum_size = Vector2(260, 40)
	opts.pressed.connect(_toggle_options)
	menu.add_child(opts)

	if not OS.has_feature("web"):
		var quit := UI.button("QUIT", true, Color(0.7, 0.7, 0.75), 18)
		quit.custom_minimum_size = Vector2(260, 40)
		quit.pressed.connect(func() -> void: get_tree().quit())
		menu.add_child(quit)

	var foot := UI.label("WASD move · click attack · Esc pause in-game", 13, Color(0.55, 0.6, 0.7, 0.85))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(foot)

	brand.modulate.a = 0.0
	tag.modulate.a = 0.0
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(brand, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(tag, "modulate:a", 1.0, 0.7).set_delay(0.15)
	tw.tween_property(panel, "modulate:a", 1.0, 0.55).set_delay(0.35)


func _play() -> void:
	Engine.set_meta("arrival_spawn", "Start")
	get_tree().change_scene_to_file(HUB)


func _new_game(btn: Button) -> void:
	if not _confirm_new:
		_confirm_new = true
		btn.text = "WIPE SAVE? CLICK AGAIN"
		return
	GameState.reset()
	_play()


func _toggle_options() -> void:
	if _options:
		_options.queue_free()
		_options = null
		return
	var center := UI.overlay(self, 0.55)
	_options = center.get_parent()
	_options.add_to_group("modal")
	var p := UI.panel(UI.EDGE, 420.0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(UI.label("OPTIONS", 26))
	head.add_child(UI.spacer())
	v.add_child(head)

	var sound := UI.section("SOUND")
	for pair in [["Music", "music"], ["Effects", "sfx"]]:
		var row := HBoxContainer.new()
		var l := UI.label(pair[0], 15)
		l.custom_minimum_size.x = 90
		row.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = GameState.settings.get(pair[1], 0.7)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.focus_mode = Control.FOCUS_NONE
		var pct := UI.label("%d%%" % int(s.value * 100), 14, UI.DIM)
		pct.custom_minimum_size.x = 48
		s.value_changed.connect(func(val: float) -> void:
			GameState.settings[pair[1]] = val
			pct.text = "%d%%" % int(val * 100)
			GameUI.apply_volume())
		s.drag_ended.connect(func(_c: bool) -> void: GameState.save())
		row.add_child(s)
		row.add_child(pct)
		sound.add_child(row)
	v.add_child(sound)

	var back := UI.button("BACK", true, UI.EDGE, 16)
	back.pressed.connect(_toggle_options)
	v.add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if _options:
			get_viewport().set_input_as_handled()
			_toggle_options()
