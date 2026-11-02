extends Node2D
## Round-based fight for a map (demo mode). 5 rounds, the last one has the boss.
## The boss drops the map's shard. Clearing round 5 unlocks the next map.
## Each map's script just sets `level_id`; everything else lives in LEVELS.

const TransferBoard = preload("res://scenes/levels/shared/transfer_board.gd")
const Music = preload("res://scenes/audio/music.gd")
const Juice = preload("res://scenes/effects/juice.gd")
const BatScene = preload("res://scenes/enemies/bat/bat.tscn")
const MeleeScene = preload("res://scenes/enemies/melee/melee_enemy.tscn")
const BossBar = preload("res://scenes/ui/boss_bar.gd")
const Pickup = preload("res://scenes/items/pickup.gd")
const GameState = preload("res://scenes/core/game_state.gd")
const GameUI = preload("res://scenes/ui/game_ui.gd")
const Net = preload("res://scenes/core/net.gd")

## each round: a subtitle and a list of [monster, count]
const LEVELS := {
	"forest": {
		"boss": "werebear", "boss_title": "WEREBEAR", "shard": "storm_crystal",
		"rounds": [
			{"sub": "Something in the Trees", "spawns": [["slime", 3], ["bat", 2]]},
			{"sub": "Wolves", "spawns": [["werewolf", 3]]},
			{"sub": "Orc Hunters", "spawns": [["orc", 2], ["werewolf", 2]]},
			{"sub": "The Pack", "spawns": [["werewolf", 3], ["orc", 1], ["bat", 2]]},
			{"sub": "BOSS: Werebear", "spawns": [["werebear", 1], ["werewolf", 2]]},
		],
	},
	"wasteland": {
		"boss": "necromancer", "boss_title": "NECROMANCER", "shard": "tomb_crystal",
		"rounds": [
			{"sub": "The Dead Walk", "spawns": [["skeleton", 4]]},
			{"sub": "Bats & Slimes", "spawns": [["bat", 3], ["slime", 3]]},
			{"sub": "Iron Bones", "spawns": [["armored_skeleton", 2], ["skeleton", 3]]},
			{"sub": "The Greatsword", "spawns": [["greatsword_skeleton", 1], ["armored_skeleton", 2], ["slime", 2], ["bat", 2]]},
			{"sub": "BOSS: Necromancer", "spawns": [["necromancer", 1], ["skeleton", 2]]},
		],
	},
}
## seconds of breathing room between rounds
const BREAK_TIME := 3.5
## hearts restored when you clear a round
const HEAL_BETWEEN := 1
## playable diamond (iso square) half sizes, matches the wall
const HW := 900.0
const HH := 450.0

var level_id: String = "wasteland"
var cfg: Dictionary
var rounds: Array
var round_index: int = -1
var _spawning: bool = false
var _finished: bool = false
## true from "round clear" until the next round starts, so two monsters
## dying on the same frame (chain lightning!) can't clear the round twice
var _clearing: bool = false
var _boss_bar: Control

@onready var round_info: Label = $UI/RoundInfo
@onready var monsters: Node2D = $Entities/Monsters


func _ready() -> void:
	cfg = LEVELS[level_id]
	rounds = cfg.rounds
	TransferBoard.place_player(self)
	Music.ensure(self)
	GameUI.ensure(self)
	_boss_bar = BossBar.new()
	_boss_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_bar.offset_bottom = 90
	_boss_bar.visible = false
	$UI.add_child(_boss_bar)
	round_info.text = ""
	# co-op: only the host runs the rounds; everyone else just mirrors them
	if _net_client():
		return
	await get_tree().create_timer(1.2, false).timeout
	_next_round()


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


func _alive() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.state != e.State.DEAD:
			n += 1
	return n


func _update_info() -> void:
	if round_index < 0 or _finished:
		return
	round_info.text = "ROUND %d / %d     Enemies: %d" % [round_index + 1, rounds.size(), _alive()]
	_net().scene_call("_set_round_info", [round_info.text])


func _next_round() -> void:
	_clearing = false
	if round_index >= rounds.size() - 1:
		return
	round_index += 1
	var r: Dictionary = rounds[round_index]
	var boss_round := round_index == rounds.size() - 1
	_banner("ROUND %d" % (round_index + 1), r.sub, Color(1, 0.4, 0.3) if boss_round else Color(1, 0.85, 0.3))
	await get_tree().create_timer(1.1, false).timeout
	_spawning = true
	var queue: Array = []
	for entry in r.spawns:
		for i in entry[1]:
			queue.append(entry[0])
	queue.shuffle()
	# boss shows up first so the bar is there
	var boss: String = cfg.boss
	queue.sort_custom(func(a, b): return a == boss and b != boss)
	for kind in queue:
		_spawn(kind)
		_update_info()
		await get_tree().create_timer(0.35, false).timeout
	_spawning = false
	_update_info()


func _spawn(kind: String) -> void:
	var e: Node2D
	if kind == "bat":
		e = BatScene.instantiate()
	else:
		e = MeleeScene.instantiate()
		e.kind = kind
	e.position = _spawn_point(kind == cfg.boss)
	monsters.add_child(e)
	e.died.connect(_on_enemy_died)
	if kind == "bat":
		Juice.shockwave(self, e.global_position, 16.0)
	if kind == cfg.boss:
		_boss_bar.boss = e
		_boss_bar.title = cfg.boss_title
		_boss_bar.visible = true
		Juice.shake(self, 0.8)
		e.died.connect(_drop_boss_loot.bind(e))


## somewhere on the ground, not right on top of you
func _spawn_point(far: bool) -> Vector2:
	var p := _player()
	var me := p.global_position if p else Vector2.ZERO
	var best := Vector2.ZERO
	for i in 40:
		var v := Vector2(randf_range(-1, 1) * HW, randf_range(-1, 1) * HH) * 0.75
		if absf(v.x) / HW + absf(v.y) / HH > 0.78:
			continue
		best = v
		if v.distance_to(me) > (380.0 if far else 260.0):
			return v
	return best


func _on_enemy_died() -> void:
	if _net_client():
		return
	await get_tree().process_frame
	_update_info()
	if _spawning or _finished or _clearing or _alive() > 0:
		return
	if round_index >= rounds.size() - 1:
		_finished = true
		_boss_bar.visible = false
		_finale()
		return
	_round_clear()


func _pull_loot(delay: float) -> void:
	await get_tree().create_timer(delay, false).timeout
	for loot in get_tree().get_nodes_in_group("pickup"):
		loot.pull_now()


func _round_clear() -> void:
	_clearing = true
	var p := _player()
	_banner("ROUND CLEAR", "+%d heart" % HEAL_BETWEEN if HEAL_BETWEEN > 0 else "", Color(0.6, 1, 0.6), 1.4, 0.8)
	if p and p.health < p.max_health and HEAL_BETWEEN > 0:
		p.heal(HEAL_BETWEEN)
		Juice.damage_number(p.get_parent(), p.global_position + Vector2(0, -50), "+%d" % HEAL_BETWEEN, Color(0.5, 1, 0.5), 26)
	_pull_loot(1.2)
	_net().scene_call("_net_heal", [HEAL_BETWEEN])
	_net().scene_call("_pull_loot", [1.2])
	await get_tree().create_timer(BREAK_TIME, false).timeout
	_next_round()


## the boss coughs up the map's shard
func _drop_boss_loot(boss: Node2D) -> void:
	var at := boss.global_position
	await get_tree().create_timer(0.5, false).timeout
	var p := _player()
	var away := (at - p.global_position).normalized() if p else Vector2.RIGHT
	Juice.shockwave(self, at, 26.0)
	Pickup.drop(monsters, at, "item", cfg.shard, away)


## big text slammed onto the screen. scale = how big, hold = seconds on screen
func _banner(text: String, sub: String, color: Color, hold: float = 1.6, scale_k: float = 1.0) -> void:
	_net().scene_call("_banner", [text, sub, color, hold, scale_k])
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -420
	box.offset_right = 420
	box.offset_top = -190
	box.offset_bottom = -40
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 2:
		var l := Label.new()
		l.text = text if i == 0 else sub
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", int((64 if i == 0 else 26) * scale_k))
		l.add_theme_constant_override("outline_size", 16 if i == 0 else 10)
		l.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.05))
		l.add_theme_color_override("font_color", color if i == 0 else Color(1, 1, 1))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if l.text != "":
			box.add_child(l)
	$UI.add_child(box)
	box.pivot_offset = Vector2(420, 75)
	box.scale = Vector2(2.4, 2.4)
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(box, "modulate:a", 1.0, 0.06)
	tw.parallel().tween_property(box, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): Juice.shake(self, 0.45))
	tw.tween_interval(hold)
	tw.tween_property(box, "modulate:a", 0.0, 0.4)
	tw.tween_callback(box.queue_free)


## won all 5: heavy slow-mo, camera pushes in, VICTORY
func _finale() -> void:
	_net().scene_call("_finale")
	var first_time := not GameState.is_cleared(level_id)
	GameState.mark_cleared(level_id)
	Juice.slow_mo(self, 1.6, 0.12)
	var cam = get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("set_base_zoom"):
		var tw := create_tween()
		tw.set_ignore_time_scale(true)
		tw.tween_method(cam.set_base_zoom, Vector2.ONE, Vector2(1.6, 1.6), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(1.0)
		tw.tween_method(cam.set_base_zoom, Vector2(1.6, 1.6), Vector2.ONE, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	round_info.text = "AREA CLEARED     Head back to camp on the transfer board"
	round_info.modulate = Color(1, 0.9, 0.4)
	await get_tree().create_timer(0.25, true, false, true).timeout
	Juice.impact_flash(self, 0.5, Color(1, 0.9, 0.5))
	_banner("VICTORY", "New area unlocked on the road map" if first_time else "The area is yours", Color(1, 0.85, 0.3), 2.6, 1.2)
	# anything you didn't grab flies to you
	_pull_loot(3.0)


# ---------------------------------------------------------------- co-op

func _net() -> Node:
	return Net.get_node_in(get_tree())


## true on a client in co-op (the host runs this level, we mirror it)
func _net_client() -> bool:
	return Net.online(get_tree()) and not multiplayer.is_server()


func _set_round_info(text: String) -> void:
	round_info.text = text


## the host cleared a round: heal yourself too
func _net_heal(n: int) -> void:
	var p := _player()
	if p and p.health < p.max_health and n > 0:
		var got: int = mini(n, p.max_health - p.health)
		p.heal(got)
		Juice.damage_number(p.get_parent(), p.global_position + Vector2(0, -50), "+%d" % got, Color(0.5, 1, 0.5), 26)


## a monster copy just showed up on this client: bosses get the big bar
func net_enemy_spawned(e: Node) -> void:
	var c = e.get("cfg")
	if typeof(c) == TYPE_DICTIONARY and c.get("boss", false):
		_boss_bar.boss = e
		_boss_bar.title = str(cfg.get("boss_title", "BOSS"))
		_boss_bar.visible = true
