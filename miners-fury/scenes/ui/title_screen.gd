extends Control
## Boot title screen. PLAY drops you into camp; NEW GAME wipes the save first.

const Music = preload("res://scenes/audio/music.gd")
const GameState = preload("res://scenes/core/game_state.gd")
const GameUI = preload("res://scenes/ui/game_ui.gd")
const UI = preload("res://scenes/ui/ui_kit.gd")
const Net = preload("res://scenes/core/net.gd")

const HUB := "res://scenes/levels/hub/hub.tscn"
const BG := "res://assets/ui/title_bg.jpg"

var _confirm_new: bool = false
var _options: Control = null
var _coop: Control = null
var _coop_list: VBoxContainer
var _coop_status: Label
var _coop_start: Button
var _coop_code: HBoxContainer
var _coop_code_label: Label


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

	_build_stamp()

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

	var coop := UI.button("CO-OP", true, UI.GOOD, 20)
	coop.custom_minimum_size = Vector2(260, 44)
	coop.pressed.connect(_toggle_coop)
	menu.add_child(coop)

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

	GameUI.add_settings_controls(v)

	var back := UI.button("BACK", true, UI.EDGE, 16)
	back.pressed.connect(_toggle_options)
	v.add_child(back)


# ---------------------------------------------------------------- co-op lobby

func _toggle_coop() -> void:
	var net = Net.get_node_in(get_tree())
	if _coop:
		_coop.queue_free()
		_coop = null
		if not net.in_game:
			net.leave()
		return
	var center := UI.overlay(self, 0.55)
	_coop = center.get_parent()
	_coop.add_to_group("modal")
	var p := UI.panel(UI.GOOD, 460.0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UI.label("CO-OP  (up to 4)", 26, UI.GOOD))

	var name_row := HBoxContainer.new()
	var nl := UI.label("Your name", 15)
	nl.custom_minimum_size.x = 100
	name_row.add_child(nl)
	var name_box := LineEdit.new()
	name_box.text = str(GameState.settings.get("player_name", net.my_name)) if GameState.settings.has("player_name") else net.my_name
	name_box.max_length = 16
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_box)
	v.add_child(name_row)

	# --- Steam: the real way to play with friends
	var steam := UI.section("PLAY WITH FRIENDS (STEAM)")
	var host := UI.button("HOST A GAME", net.steam_ok, UI.GOOD, 17)
	steam.add_child(host)
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)
	var code_box := LineEdit.new()
	code_box.placeholder_text = "Friend's code"
	code_box.max_length = 8
	code_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_box.editable = net.steam_ok
	code_row.add_child(code_box)
	var join_code := UI.button("JOIN", net.steam_ok, UI.EDGE, 17)
	code_row.add_child(join_code)
	steam.add_child(code_row)
	# shown once you're hosting
	_coop_code = HBoxContainer.new()
	_coop_code.add_theme_constant_override("separation", 8)
	_coop_code.visible = false
	_coop_code_label = UI.label("", 26, UI.GOLD)
	_coop_code.add_child(_coop_code_label)
	_coop_code.add_child(UI.spacer())
	var copy := UI.button("COPY", true, UI.EDGE, 14)
	copy.pressed.connect(func() -> void: DisplayServer.clipboard_set(net.join_code))
	_coop_code.add_child(copy)
	var invite := UI.button("INVITE", true, UI.GOOD, 14)
	invite.pressed.connect(func() -> void: net.invite_friends())
	_coop_code.add_child(invite)
	steam.add_child(_coop_code)
	if not net.steam_ok:
		steam.add_child(UI.label(net.steam_error, 13, UI.BAD))
	v.add_child(steam)

	# --- local: testing with several windows on one PC (or same Wi-Fi)
	var local := UI.section("LOCAL TEST (same PC or Wi-Fi)")
	var local_row := HBoxContainer.new()
	local_row.add_theme_constant_override("separation", 8)
	var host_local := UI.button("HOST", true, Color(0.6, 0.75, 0.6), 14)
	local_row.add_child(host_local)
	var addr := LineEdit.new()
	addr.placeholder_text = "Address (blank = this PC)"
	addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	local_row.add_child(addr)
	var join := UI.button("JOIN", true, Color(0.6, 0.7, 0.85), 14)
	local_row.add_child(join)
	local.add_child(local_row)
	v.add_child(local)

	var players := UI.section("PLAYERS")
	_coop_list = VBoxContainer.new()
	players.add_child(_coop_list)
	v.add_child(players)

	_coop_status = UI.label("Host a game, or join a friend's.", 14, UI.DIM)
	_coop_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(_coop_status)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	_coop_start = UI.button("START", false, UI.GOLD, 18)
	_coop_start.visible = false
	_coop_start.pressed.connect(func() -> void: net.start_game(HUB))
	bottom.add_child(_coop_start)
	bottom.add_child(UI.spacer())
	var back := UI.button("BACK", true, Color(0.6, 0.6, 0.65), 15)
	back.pressed.connect(_toggle_coop)
	bottom.add_child(back)
	v.add_child(bottom)

	var set_name := func() -> void:
		net.my_name = name_box.text.strip_edges() if name_box.text.strip_edges() != "" else "Miner"
	host.pressed.connect(func() -> void:
		set_name.call()
		net.host_steam())
	join_code.pressed.connect(func() -> void:
		set_name.call()
		net.join_steam_code(code_box.text))
	code_box.text_submitted.connect(func(_t: String) -> void:
		set_name.call()
		net.join_steam_code(code_box.text))
	host_local.pressed.connect(func() -> void:
		set_name.call()
		net.host())
	join.pressed.connect(func() -> void:
		set_name.call()
		net.join(addr.text))
	if not net.roster_changed.is_connected(_refresh_coop):
		net.roster_changed.connect(_refresh_coop)
		net.status.connect(func(t: String) -> void:
			if is_instance_valid(_coop_status):
				_coop_status.text = t)
	_refresh_coop()


func _refresh_coop() -> void:
	if _coop == null or not is_instance_valid(_coop_list):
		return
	for c in _coop_list.get_children():
		c.queue_free()
	var net = Net.get_node_in(get_tree())
	var ids: Array = net.roster.keys()
	ids.sort()
	for id in ids:
		var tag := "  (host)" if id == 1 else ""
		var me := "  (you)" if id == multiplayer.get_unique_id() else ""
		_coop_list.add_child(UI.label("%s%s%s" % [net.player_name(id), tag, me], 16, UI.GOLD if id == 1 else Color.WHITE))
	if ids.is_empty():
		_coop_list.add_child(UI.label("Nobody yet", 14, UI.DIM))
	var hosting: bool = Net.online(get_tree()) and multiplayer.is_server()
	_coop_code.visible = net.join_code != ""
	_coop_code_label.text = "CODE: %s" % net.join_code
	_coop_start.visible = hosting
	_coop_start.disabled = not hosting


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if _coop:
			get_viewport().set_input_as_handled()
			_toggle_coop()
			return
		if _options:
			get_viewport().set_input_as_handled()
			_toggle_options()


## bottom-right corner: a short code for this exact build (a fingerprint of the
## game files). Co-op needs everyone on the same build, so if joining fails,
## compare these. Same code = same version.
func _build_stamp() -> void:
	var txt := "build " + Net.build_id()
	var l := UI.label(txt, 11, UI.DIM)
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.offset_left = -220
	l.offset_top = -24
	l.offset_right = -10
	l.offset_bottom = -6
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child.call_deferred(l)
