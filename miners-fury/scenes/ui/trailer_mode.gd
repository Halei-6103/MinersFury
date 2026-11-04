extends CanvasLayer
## Hidden trailer / recording tools. Shift+2 opens and closes the panel.
## Click the buttons (F1 to F7 also work if you have them):
##   Invincible, No cooldowns, pick a monster (< >) + Spawn, Hide UI, Speed, Kill all
## Spawned monsters appear a little way from you, toward your mouse.
## Hide UI hides everything including this panel: Shift+2 brings it back.
## Only affects your own game, never sent to teammates.
## GameUI adds one of these to the root, so it's there in every scene.

const MeleeScene = preload("res://scenes/enemies/melee/melee_enemy.tscn")
const BatScene = preload("res://scenes/enemies/bat/bat.tscn")
const UI = preload("res://scenes/ui/ui_kit.gd")

const MONSTERS := ["slime", "skeleton", "bat", "orc", "werewolf", "armored_skeleton", "greatsword_skeleton",
	"lava_slime", "hellbat", "ghostfire", "werebear", "necromancer", "black_knight", "pufferfish"]
const BRAINS := {
	"black_knight": "res://scenes/enemies/caldera/black_knight_boss.gd",
	"ghostfire": "res://scenes/enemies/caldera/ghostfire.gd",
	"pufferfish": "res://scenes/enemies/pufferfish/puffer_boss.gd",
}
const SPEEDS := [1.0, 0.5, 0.25]
## how far from you a spawned monster appears (toward the mouse)
const SPAWN_DIST := 170.0
const STUDIO := "res://scenes/levels/studio/studio.tscn"
const Net = preload("res://scenes/core/net.gd")

## kept across scenes
static var on: bool = false
static var god: bool = false
static var no_cd: bool = false
static var pick: int = 0
static var speed_i: int = 0
static var clean: bool = false

var _panel: PanelContainer
var _btn: Dictionary = {}
var _monster: Label
var _hidden: Array = []


func _ready() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = UI.panel(UI.GOLD, 260.0)
	_panel.position = Vector2(1000, 70)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)
	v.add_child(UI.label("TRAILER MODE", 18, UI.GOLD))
	v.add_child(UI.label("Shift+2 to close", 11, UI.DIM))
	_btn.god = _add(v, "", _toggle_god)
	_btn.cd = _add(v, "", _toggle_cd)
	# monster picker:  <  Black Knight  >
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var prev := UI.button("<", true, UI.EDGE, 15)
	prev.pressed.connect(func() -> void: _pick(-1))
	row.add_child(prev)
	_monster = UI.label("", 14)
	_monster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_monster.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_monster)
	var nxt := UI.button(">", true, UI.EDGE, 15)
	nxt.pressed.connect(func() -> void: _pick(1))
	row.add_child(nxt)
	v.add_child(row)
	_btn.spawn = _add(v, "SPAWN IT", _spawn_pick, UI.GOOD)
	_btn.speed = _add(v, "", _cycle_speed)
	_btn.kill = _add(v, "KILL ALL MONSTERS", _kill_all, UI.BAD)
	_btn.clean = _add(v, "HIDE UI (clean shots)", _toggle_clean)
	_btn.studio = _add(v, "GO TO TRAILER ARENA", _go_studio, UI.GOLD)
	_refresh()


func _add(v: VBoxContainer, text: String, cb: Callable, color: Color = UI.EDGE) -> Button:
	var b := UI.button(text, true, color, 14)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	v.add_child(b)
	return b


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if k == KEY_2 and event.shift_pressed:
		get_viewport().set_input_as_handled()
		if on and clean:
			# UI was hidden for a shot: bring it back instead of closing
			_toggle_clean()
			return
		on = not on
		if not on:
			_reset()
		_toast("TRAILER MODE ON" if on else "TRAILER MODE OFF")
		_refresh()
		return
	if not on:
		return
	match k:
		KEY_F1: _toggle_god()
		KEY_F2: _toggle_cd()
		KEY_F3: _pick(-1 if event.shift_pressed else 1)
		KEY_F4: _spawn_pick()
		KEY_F5: _toggle_clean()
		KEY_F6: _cycle_speed()
		KEY_F7: _kill_all()
		_: return
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- actions

func _toggle_god() -> void:
	god = not god
	_refresh()


func _toggle_cd() -> void:
	no_cd = not no_cd
	_refresh()


func _pick(step: int) -> void:
	pick = posmod(pick + step, MONSTERS.size())
	_refresh()


func _cycle_speed() -> void:
	speed_i = (speed_i + 1) % SPEEDS.size()
	Engine.time_scale = SPEEDS[speed_i]
	_refresh()


func _kill_all() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_method("take_damage") and e.get("state") != e.State.DEAD:
			e.take_damage(9999, e.global_position + Vector2(10, 0))


func _toggle_clean() -> void:
	clean = not clean
	_apply_clean()
	_refresh()
	if clean:
		_toast("UI hidden. Shift+2 to bring it back")


func _go_studio() -> void:
	# co-op: only the host can travel, and it brings everyone (Net says so if you're not)
	Net.change_scene(get_tree(), STUDIO, "Start")


func _spawn_pick() -> void:
	# a little way from you, toward the mouse (so you can aim where it lands)
	var at := Vector2.ZERO
	var p = get_tree().get_first_node_in_group("player")
	if p:
		var to: Vector2 = p.get_global_mouse_position() - p.global_position
		var flat := Vector2(to.x, to.y * 2.0)
		if flat.length() < 1.0:
			flat = Vector2.RIGHT
		flat = flat.normalized() * SPAWN_DIST
		at = p.global_position + Vector2(flat.x, flat.y * 0.5)
	var kind: String = MONSTERS[pick]
	# co-op: monsters belong to the host. A client asks the host to make it
	# (works in the Trailer Arena) so everyone fights the same one
	if Net.online(get_tree()) and not multiplayer.is_server():
		if get_tree().current_scene and get_tree().current_scene.has_method("trailer_spawn"):
			Net.get_node_in(get_tree()).host_call("trailer_spawn", [kind, at])
		else:
			_toast("In co-op only the host can spawn here")
		return
	spawn_monster(get_tree(), kind, at)


static func spawn_monster(tree: SceneTree, kind: String, at: Vector2) -> void:
	var cs := tree.current_scene
	if cs == null:
		return
	var parent: Node = cs.get_node_or_null("Entities/Monsters")
	if parent == null:
		parent = cs.get_node_or_null("Entities")
	if parent == null:
		parent = cs
	var e: Node2D
	if kind == "bat" or kind == "hellbat":
		e = BatScene.instantiate()
		e.kind = kind
	else:
		e = MeleeScene.instantiate()
		if BRAINS.has(kind):
			e.set_script(load(BRAINS[kind]))
		e.kind = kind
	e.position = at
	parent.add_child(e)
	e.global_position = at


# ---------------------------------------------------------------- every frame

func _process(_delta: float) -> void:
	_panel.visible = on and not clean
	if not on:
		return
	var p = get_tree().get_first_node_in_group("player")
	if p:
		p.set_meta("trailer_god", god)
		if no_cd:
			for w in p._ult_cd.keys():
				p._ult_cd[w] = 0.0
			p._swap_cd = 0.0
			p.dash_charge = p.dash_max
	# something (a hit-stop, a slow-mo kill) put time back to normal: keep our speed
	if speed_i != 0 and not get_tree().paused and Engine.time_scale >= 0.99:
		Engine.time_scale = SPEEDS[speed_i]
	# a new scene brought new UI with it: hide that too
	if clean:
		_apply_clean()


func _apply_clean() -> void:
	if clean:
		for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if n == self or not n.visible:
				continue
			n.visible = false
			_hidden.append(n)
		for p in get_tree().get_nodes_in_group("players_all"):
			for nm in ["NameTag", "FootHearts"]:
				var tag = p.get_node_or_null(nm)
				if tag and tag.visible:
					tag.visible = false
					_hidden.append(tag)
	else:
		for n in _hidden:
			if is_instance_valid(n):
				n.visible = true
		_hidden.clear()


func _reset() -> void:
	god = false
	no_cd = false
	speed_i = 0
	Engine.time_scale = 1.0
	if clean:
		clean = false
		_apply_clean()
	var p = get_tree().get_first_node_in_group("player")
	if p:
		p.set_meta("trailer_god", false)


func _refresh() -> void:
	if _btn.is_empty():
		return
	_btn.god.text = "INVINCIBLE: " + ("ON" if god else "OFF")
	_btn.cd.text = "NO COOLDOWNS: " + ("ON" if no_cd else "OFF")
	_btn.god.modulate = Color(0.6, 1, 0.6) if god else Color.WHITE
	_btn.cd.modulate = Color(0.6, 1, 0.6) if no_cd else Color.WHITE
	_monster.text = MONSTERS[pick].replace("_", " ").capitalize()
	_btn.speed.text = "SPEED: %d%%" % int(SPEEDS[speed_i] * 100)
	_btn.speed.modulate = Color(0.7, 0.85, 1) if speed_i != 0 else Color.WHITE


func _toast(text: String) -> void:
	var l := UI.label(text, 22, UI.GOLD)
	l.position = Vector2(440, 120)
	add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
