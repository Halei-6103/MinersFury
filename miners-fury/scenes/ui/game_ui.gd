extends CanvasLayer
## Always-on UI that lives on the tree root (like the music):
##   Esc  -> pause menu (resume, volume, return to camp, quit)
##   Tab  -> inventory (materials, shards, blueprints, weapons -> pick your two hands)
## Levels call  GameUI.ensure(self)  in _ready().
## Any menu a level opens itself should add_to_group("modal") so Esc closes
## that menu instead of opening the pause menu.

const GameState = preload("res://scenes/core/game_state.gd")
const UI = preload("res://scenes/ui/ui_kit.gd")
const Net = preload("res://scenes/core/net.gd")

const CAMP := "res://scenes/levels/hub/hub.tscn"
const MAP := "res://scenes/levels/map/road_map.tscn"
const TRIAL := "res://scenes/levels/trial/trial.tscn"

var _menu: Control = null
var _kind: String = ""
var _confirm_reset: bool = false
## weapon proficiency popup (shows in camp / on the road map once you own both blades)
var _note: Control = null
var _scene_id: int = 0
var _note_wait: float = -1.0
## tutorial tips (scenes/ui/tips.gd)
var _tips: Control = null
var _tip_check: float = 1.0


static func ensure(node: Node) -> void:
	ensure_buses()
	if node == null or not node.is_inside_tree():
		return
	var root := node.get_tree().root
	if root.get_node_or_null("GameUI"):
		return
	var ui = load("res://scenes/ui/game_ui.gd").new()
	ui.name = "GameUI"
	root.add_child.call_deferred(ui)


## Music + SFX volume buses (made at runtime so no bus layout file is needed)
static func ensure_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	GameState.ensure_loaded()
	apply_volume()
	# only set the window mode once, when the game starts. Doing it on every
	# scene load kicked people out of fullscreen whenever they changed maps
	if not _display_applied:
		_display_applied = true
		apply_display()


static var _display_applied: bool = false


## F11 or Alt+Enter: flip fullscreen and remember it
static func toggle_fullscreen() -> void:
	if OS.has_feature("web"):
		return
	var now_full := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	GameState.settings["fullscreen"] = not now_full
	apply_display()
	GameState.save()


static func apply_volume() -> void:
	for bus in ["Music", "SFX"]:
		var i := AudioServer.get_bus_index(bus)
		if i == -1:
			continue
		var v: float = GameState.settings.get(bus.to_lower(), 0.7)
		AudioServer.set_bus_mute(i, v <= 0.01)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


static func apply_display() -> void:
	if OS.has_feature("web"):
		return
	var full: bool = bool(GameState.settings.get("fullscreen", false))
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)


## SOUND sliders + fullscreen toggle, shared by pause + title options
static func add_settings_controls(parent: VBoxContainer) -> void:
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
			apply_volume())
		s.drag_ended.connect(func(_c: bool) -> void: GameState.save())
		row.add_child(s)
		row.add_child(pct)
		sound.add_child(row)
	parent.add_child(sound)

	if OS.has_feature("web"):
		return
	var display := UI.section("DISPLAY")
	var on: bool = bool(GameState.settings.get("fullscreen", false))
	var fs := UI.button("FULLSCREEN: ON" if on else "FULLSCREEN: OFF", true, UI.EDGE, 16)
	fs.pressed.connect(func() -> void:
		var next: bool = not bool(GameState.settings.get("fullscreen", false))
		GameState.settings["fullscreen"] = next
		fs.text = "FULLSCREEN: ON" if next else "FULLSCREEN: OFF"
		apply_display()
		GameState.save())
	display.add_child(fs)
	parent.add_child(display)


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_actions()
	# hidden recording tools (Shift+2). Lives on the root so hiding the UI can't hide it
	if get_tree().root.get_node_or_null("TrailerMode") == null:
		var tm = load("res://scenes/ui/trailer_mode.gd").new()
		tm.name = "TrailerMode"
		get_tree().root.add_child.call_deferred(tm)


func _process(delta: float) -> void:
	# tutorial tips: look for new ones twice a second (not while a menu is open)
	if _tips == null:
		_tips = load("res://scenes/ui/tips.gd").new()
		_tips.name = "Tips"
		add_child(_tips)
	_tip_check -= delta
	if _tip_check <= 0.0:
		_tip_check = 0.5
		if _menu == null and get_tree().get_nodes_in_group("modal").is_empty():
			_tips.check()
	var cs := get_tree().current_scene
	var id := cs.get_instance_id() if cs else 0
	if id != _scene_id:
		_scene_id = id
		if _note and is_instance_valid(_note):
			_note.queue_free()
		_note = null
		# give the scene a moment to fade in before popping up
		_note_wait = 1.4 if cs and (cs.scene_file_path == CAMP or cs.scene_file_path == MAP) else -1.0
	if _note_wait > 0.0 and not get_tree().paused:
		_note_wait -= delta
		if _note_wait <= 0.0 and GameState.can_try_tetrodotoxin():
			_show_proficiency()


## "WEAPON PROFICIENCY" card sliding in from the right, with a START button
func _show_proficiency() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_note = holder
	var p := UI.panel(Color(0.6, 1.0, 0.75), 330.0)
	p.position = Vector2(-350, 96)
	holder.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(UI.label("!", 22, UI.GOLD))
	head.add_child(UI.label("  WEAPON PROFICIENCY", 18, Color(0.6, 1.0, 0.75)))
	v.add_child(head)
	var body := UI.label("Your Storm Blade and Venom Blade hum\nwhen they're near each other.\n\nSomething out at sea wants to test you.", 14)
	v.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var go := UI.button("START", true, UI.GOOD, 16)
	go.pressed.connect(func() -> void:
		holder.queue_free()
		_note = null
		Engine.set_meta("trial_attempt", 0)
		Net.change_scene(get_tree(), TRIAL, "Start"))
	row.add_child(go)
	var later := UI.button("LATER", true, Color(0.6, 0.6, 0.65), 14)
	later.pressed.connect(func() -> void:
		var tw2 := holder.create_tween()
		tw2.tween_property(p, "position:x", 40.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw2.tween_callback(holder.queue_free)
		_note = null)
	row.add_child(later)
	v.add_child(row)
	# slide in + a little bounce
	p.position.x = 40.0
	var tw := p.create_tween()
	tw.tween_property(p, "position:x", -350.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ensure_actions() -> void:
	if not InputMap.has_action("inventory"):
		InputMap.add_action("inventory")
		for k in [KEY_TAB, KEY_I]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event("inventory", ev)
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_ESCAPE
		InputMap.action_add_event("pause", ev)


func _no_player() -> bool:
	return get_tree().get_first_node_in_group("player") == null


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed)):
		get_viewport().set_input_as_handled()
		toggle_fullscreen()
		return
	if event.is_action_pressed("pause"):
		if _menu:
			get_viewport().set_input_as_handled()
			close()
		elif get_tree().get_nodes_in_group("modal").is_empty() and not _no_player():
			get_viewport().set_input_as_handled()
			open_pause()
	elif event.is_action_pressed("inventory"):
		if _menu and _kind == "inventory":
			get_viewport().set_input_as_handled()
			close()
		elif _menu == null and get_tree().get_nodes_in_group("modal").is_empty() and not _no_player():
			get_viewport().set_input_as_handled()
			open_inventory()


func close() -> void:
	if _menu:
		_menu.queue_free()
		_menu = null
	_kind = ""
	_confirm_reset = false
	get_tree().paused = false


func _open(kind: String) -> VBoxContainer:
	if _menu:
		_menu.queue_free()
	_kind = kind
	# online the world keeps going: the menu just sits on top
	get_tree().paused = not Net.online(get_tree())
	var center := UI.overlay(self)
	_menu = center.get_parent()
	var p := UI.panel(UI.EDGE, 560.0 if kind == "pause" else 760.0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	return v


# ---------------------------------------------------------------- pause

func open_guide() -> void:
	var v := _open("guide")
	var head := HBoxContainer.new()
	head.add_child(UI.label("HOW TO PLAY", 28, UI.GOLD))
	head.add_child(UI.spacer())
	var back := UI.button("BACK", true, UI.EDGE, 14)
	back.pressed.connect(open_pause)
	head.add_child(back)
	v.add_child(head)
	load("res://scenes/ui/tips.gd").build_guide(v)


func open_pause() -> void:
	var v := _open("pause")
	var head := HBoxContainer.new()
	head.add_child(UI.label("PAUSED", 30))
	head.add_child(UI.spacer())
	v.add_child(head)

	var resume := UI.button("RESUME", true, UI.EDGE, 18)
	resume.pressed.connect(close)
	v.add_child(resume)
	var how := UI.button("HOW TO PLAY", true, UI.GOLD, 16)
	how.pressed.connect(open_guide)
	v.add_child(how)

	add_settings_controls(v)

	var keys := UI.section("CONTROLS")
	keys.add_child(UI.label("WASD move     Mouse aim     Left click attack (click again to combo)\nRight click block (just before a hit = PARRY)     Space dodge\nR (hold, aim, let go) weapon ultimate     Q / 1 / 2 swap weapon\nTab inventory     E interact     Esc pause", 13, UI.DIM))
	v.add_child(keys)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	var in_camp: bool = get_tree().current_scene and get_tree().current_scene.scene_file_path == CAMP
	if not in_camp:
		var camp := UI.button("RETURN TO CAMP", true, UI.GOLD)
		camp.pressed.connect(func() -> void:
			close()
			Net.change_scene(get_tree(), CAMP, "Start"))
		row2.add_child(camp)
	if Net.online(get_tree()):
		var leave := UI.button("LEAVE CO-OP", true, Color(0.9, 0.6, 0.4))
		leave.pressed.connect(func() -> void:
			close()
			Net.get_node_in(get_tree()).leave()
			get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn"))
		row2.add_child(leave)
	var reset := UI.button("NEW GAME", true, UI.BAD)
	reset.pressed.connect(func() -> void:
		if not _confirm_reset:
			_confirm_reset = true
			reset.text = "WIPE SAVE? CLICK AGAIN"
			return
		GameState.reset()
		close()
		Net.change_scene(get_tree(), CAMP, "Start"))
	row2.add_child(reset)
	row2.add_child(UI.spacer())
	if not OS.has_feature("web"):
		var quit := UI.button("QUIT GAME", true, Color(0.7, 0.7, 0.75))
		quit.pressed.connect(func() -> void: get_tree().quit())
		row2.add_child(quit)
	v.add_child(row2)


# ---------------------------------------------------------------- inventory

func open_inventory() -> void:
	var v := _open("inventory")
	var head := HBoxContainer.new()
	head.add_child(UI.label("INVENTORY", 28))
	head.add_child(UI.spacer())
	head.add_child(UI.label("[Tab] close", 13, UI.DIM))
	v.add_child(head)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	v.add_child(cols)

	# left: stuff you're carrying
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 16)
	left.custom_minimum_size.x = 250
	cols.add_child(left)
	var mats := UI.section("MATERIALS")
	var any := false
	for id in GameState.items_of_type("material"):
		any = true
		mats.add_child(UI.item_row(id, GameState.count(id), GameState.ITEMS[id]))
	if not any:
		mats.add_child(UI.label("Nothing yet. Monsters drop these.", 13, UI.DIM))
	left.add_child(mats)
	var shards := UI.section("SHARDS & BLUEPRINTS")
	any = false
	for id in GameState.items_of_type("shard"):
		any = true
		shards.add_child(UI.item_row(id, GameState.count(id), GameState.ITEMS[id]))
	for bp in GameState.blueprints:
		any = true
		shards.add_child(UI.item_row(bp, -1, GameState.BLUEPRINTS[bp], 1.3))
	if not any:
		shards.add_child(UI.label("Bosses drop shards.\nThe telecom trades them for blueprints.", 13, UI.DIM))
	left.add_child(shards)

	# right: weapons and which hand they're in
	var right := UI.section("WEAPONS")
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UI.label("Pick what goes in each hand. Q swaps hands in a fight.", 13, UI.DIM))
	for w in GameState.weapons:
		var info: Dictionary = GameState.WEAPONS[w]
		var card := UI.card(info.color.darkened(0.35))
		var cv := VBoxContainer.new()
		card.add_child(cv)
		var top := HBoxContainer.new()
		top.add_child(UI.label(info.name, 19, info.color))
		top.add_child(UI.spacer())
		var hand := GameState.slots.find(w)
		if hand >= 0:
			top.add_child(UI.label("IN HAND %d" % (hand + 1) + ("  (active)" if hand == GameState.active_slot else ""), 13, UI.GOOD))
		cv.add_child(top)
		cv.add_child(UI.label(info.desc, 13, UI.DIM))
		var btns := HBoxContainer.new()
		btns.add_theme_constant_override("separation", 8)
		for i in 2:
			var b := UI.button("Hand %d" % (i + 1), GameState.slots[i] != w, UI.EDGE, 14)
			b.pressed.connect(_put_in_hand.bind(i, w))
			btns.add_child(b)
		if hand >= 0 and GameState.slots[1 - hand] != "":
			var un := UI.button("Unequip", true, Color(0.6, 0.6, 0.65), 14)
			un.pressed.connect(_put_in_hand.bind(hand, ""))
			btns.add_child(un)
		cv.add_child(btns)
		right.add_child(card)
	if GameState.weapons.size() == 1:
		right.add_child(UI.label("Craft new weapons at the crafting station in camp.", 13, UI.DIM))


func _put_in_hand(i: int, w: String) -> void:
	GameState.set_slot(i, w)
	var p = get_tree().get_first_node_in_group("player")
	if p and p.has_method("set_weapon"):
		p.set_weapon(GameState.equipped())
	open_inventory()
