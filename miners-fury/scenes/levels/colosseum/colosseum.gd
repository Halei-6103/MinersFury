extends "res://scenes/levels/shared/arena.gd"
## The Colosseum: endless rounds. Keeps going until you drop.
## Every round: more monsters, and they take more hits to kill.
## Monster damage NEVER goes up. Every 5th round has bosses:
##   rounds 5, 15, 25...  one boss       rounds 10, 20...  two bosses
##   round 30 and up: one extra boss on every boss round
## When you die you get a card with how far you got.
## Tune the numbers in the TUNING block below.

const UIK = preload("res://scenes/ui/ui_kit.gd")
const FxSprite = preload("res://scenes/effects/fx_sprite.gd")
const PufferBoss = preload("res://scenes/enemies/pufferfish/puffer_boss.gd")
const Sfx = preload("res://scenes/audio/sfx.gd")

# ---------------------------------------------------------------- TUNING
## monster health: +10% per round (round 10 = 1.9x, round 20 = 2.9x)
const HP_PER_ROUND := 0.10
## boss health grows slower since they start big (+7% per round after 5)
const BOSS_HP_PER_ROUND := 0.07
## how many monsters: 3 + 0.8 per round (round 10 = 11, round 20 = 19)
const BASE_COUNT := 3
const COUNT_PER_ROUND := 0.8
const MAX_COUNT := 32
## never more than this many alive at once (the rest wait their turn)
const MAX_ALIVE := 10
const BOSSES := ["werebear", "necromancer", "fire_cultist"]
const BOSS_TITLES := {"werebear": "WEREBEAR", "necromancer": "NECROMANCER", "pufferfish": "PUFFERFISH", "fire_cultist": "FIRE CULTIST"}
## [kind, first round it shows up, base weight, extra weight per round]
const POOL := [
	["slime", 1, 3.0, 0.0],
	["skeleton", 1, 3.0, 0.0],
	["bat", 1, 2.0, 0.0],
	["werewolf", 3, 2.0, 0.05],
	["orc", 3, 2.0, 0.05],
	["armored_skeleton", 6, 1.0, 0.1],
	["greatsword_skeleton", 9, 0.5, 0.08],
	["twisted_cultist", 5, 1.5, 0.05],
	["assassin_cultist", 7, 1.0, 0.06],
	["big_cultist", 11, 0.5, 0.06],
]
const SUBS := ["Fresh Meat", "The Crowd Wants More", "Warm Up", "No Mercy", "Blood on the Sand",
	"Hold the Line", "They Keep Coming", "Thumbs Down", "Glory or Death", "Feed the Lions",
	"Show Them Steel", "The Long Night"]
## arena floor size (the walkable ellipse is a bit smaller)
const FLOOR_R := 900.0
const GATES := [Vector2(512, -350), Vector2(-512, -350)]

var round_no: int = 0
var kills: int = 0
var bosses_slain: int = 0
var _run_time: float = 0.0
var _boss_round: bool = false
var _bars: Array = []
var _dead: bool = false
## co-op: who's down right now (peer id -> true). Whole team down = wipe
var _down: Dictionary = {}
var _down_me: bool = false


func _ready() -> void:
	level_id = "colosseum"
	cfg = {"boss": "", "boss_title": "", "shard": ""}
	rounds = []
	TransferBoard.place_player(self)
	Music.ensure(self)
	GameUI.ensure(self)
	# the base class's single bar isn't used, we stack one per boss
	_boss_bar = BossBar.new()
	_boss_bar.visible = false
	$UI.add_child(_boss_bar)
	var p := _player()
	if p:
		p.hold_on_death = true
		if _coop():
			p.died.connect(func() -> void: _net().host_call("_net_down", [true]))
			p.health_changed.connect(func(h: int, _m: int) -> void:
				if h > 0 and _down_me:
					_down_me = false
					_net().host_call("_net_down", [false]))
			p.died.connect(func() -> void: _down_me = true)
		else:
			p.died.connect(_on_player_died)
	_light_braziers()
	_hide_board_art()
	round_info.text = ""
	# co-op: the host runs the rounds, clients mirror them
	if _net_client():
		return
	await get_tree().create_timer(1.2, false).timeout
	_next_round()


func _coop() -> bool:
	return Net.online(get_tree())


## the arena is built from the Pixel Crawler desert pack: the exit is the stairs in
## the middle of the north wall, so the transfer board only keeps its "[E] Leave" zone
func _hide_board_art() -> void:
	var b := get_node_or_null("Entities/TransferBoard")
	if b == null:
		return
	for n in ["Pad", "Cabinet", "Glow"]:
		var c = b.get_node_or_null(n)
		if c:
			c.visible = false
	var body = b.get_node_or_null("Cabinet/CabinetBody")
	if body:
		body.collision_layer = 0
		body.collision_mask = 0


func _light_braziers() -> void:
	for n in $Entities.get_children():
		if n.name.begins_with("Brazier"):
			var f := AnimatedSprite2D.new()
			f.sprite_frames = FxSprite.frames_for("brazier_fire", true)
			f.offset = FxSprite.anchor_offset("brazier_fire")
			f.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			f.position = Vector2(0, -44)
			f.scale = Vector2(0.8, 0.8)
			n.add_child(f)
			f.play("default")
			f.frame = randi() % 12


func _process(delta: float) -> void:
	if not _dead and round_no > 0:
		_run_time += delta
	# count every kill, summoned skeletons included
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.has_meta("col_tracked"):
			e.set_meta("col_tracked", true)
			e.died.connect(_on_kill.bind(e))
			e.died.connect(_on_enemy_died)


func _on_kill(e: Node) -> void:
	if _dead:
		return
	kills += 1
	var c = e.get("cfg")
	if typeof(c) == TYPE_DICTIONARY and c.get("boss", false):
		bosses_slain += 1
	_update_info()


func _update_info() -> void:
	if round_no <= 0 or _dead:
		return
	round_info.text = "ROUND %d     Kills: %d     Enemies: %d" % [round_no, kills, _alive()]
	_net().scene_call("_set_round_info", [round_info.text])


# ---------------------------------------------------------------- rounds

static func boss_count(r: int) -> int:
	if r % 5 != 0:
		return 0
	var n := 1 if r % 10 == 5 else 2
	if r >= 30:
		n += 1
	if r >= 60:
		n += 1
	return n


static func monster_count(r: int) -> int:
	return mini(BASE_COUNT + int(r * COUNT_PER_ROUND), MAX_COUNT)


static func hp_mult(r: int, boss: bool) -> float:
	if boss:
		return 1.0 + BOSS_HP_PER_ROUND * maxf(r - 5, 0)
	return 1.0 + HP_PER_ROUND * (r - 1)


func _pick_kind() -> String:
	var total := 0.0
	var opts: Array = []
	for row in POOL:
		if round_no >= row[1]:
			var w: float = row[2] + row[3] * (round_no - row[1])
			opts.append([row[0], w])
			total += w
	var roll := randf() * total
	for o in opts:
		roll -= o[1]
		if roll <= 0.0:
			return o[0]
	return opts[0][0]


func _next_round() -> void:
	_clearing = false
	if _dead:
		return
	round_no += 1
	var nb := boss_count(round_no)
	_boss_round = nb > 0
	var sub: String = SUBS[(round_no - 1) % SUBS.size()]
	var color := Color(1, 0.85, 0.3)
	var queue: Array = []
	if nb > 0:
		var pool: Array = BOSSES.duplicate()
		# round 30+: the pufferfish can show up as a colosseum boss too
		if round_no >= 30:
			pool.append("pufferfish")
		var picks: Array = []
		for i in nb:
			picks.append(pool[(i + round_no / 5) % pool.size()])
		for b in picks:
			queue.append(b)
		match nb:
			1: sub = "BOSS: " + BOSS_TITLES[picks[0]].capitalize()
			2: sub = "DOUBLE BOSS"
			3: sub = "TRIPLE BOSS"
			_: sub = "%d BOSSES. GOOD LUCK" % nb
		color = Color(1, 0.4, 0.3)
	var n := monster_count(round_no)
	if nb > 0:
		n = n / 2
	var extra: Array = []
	for i in n:
		extra.append(_pick_kind())
	extra.shuffle()
	queue.append_array(extra)
	_banner("ROUND %d" % round_no, sub, color)
	await get_tree().create_timer(1.1, false).timeout
	_spawning = true
	_update_info()
	for kind in queue:
		# don't flood the sand: wait until there's room
		while _alive() >= MAX_ALIVE and not _dead:
			await get_tree().create_timer(0.3, false).timeout
		if _dead:
			return
		_spawn(kind)
		_update_info()
		await get_tree().create_timer(0.35 if not BOSS_TITLES.has(kind) else 0.8, false).timeout
	_spawning = false
	_update_info()
	_on_enemy_died()


func _spawn(kind: String) -> void:
	var boss: bool = BOSS_TITLES.has(kind)
	var e: Node2D
	if kind == "bat":
		e = BatScene.instantiate()
	elif kind == "pufferfish" or kind == "fire_cultist":
		# same trick as the trial: melee scene + its own brain, BEFORE add_child
		e = MeleeScene.instantiate()
		e.set_script(PufferBoss if kind == "pufferfish" else load(BOSS_SCRIPTS[kind]))
		e.kind = kind
	else:
		e = MeleeScene.instantiate()
		e.kind = kind
	e.position = _spawn_point(boss)
	monsters.add_child(e)
	# tougher, never hits harder
	var m := hp_mult(round_no, boss)
	e.max_health = maxi(int(round(e.max_health * m)), 1)
	e.health = e.max_health
	Juice.shockwave(self, e.global_position, 30.0 if boss else 16.0)
	if boss:
		_add_boss_bar(e, BOSS_TITLES[kind])
		Juice.shake(self, 0.8)
	if kind == "pufferfish":
		_puffer_landing(e)


func _puffer_landing(e: Node2D) -> void:
	var at: Vector2 = e.global_position
	get_tree().create_timer(0.28, false).timeout.connect(func() -> void:
		Sfx.play(self, "boss_landing", at, 0.0, 0.02))


func _add_boss_bar(e: Node, title: String) -> void:
	var bar := BossBar.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.boss = e
	bar.title = title
	$UI.add_child(bar)
	_bars.append(bar)
	_stack_bars()
	e.died.connect(func() -> void:
		await get_tree().create_timer(1.2, false).timeout
		_bars.erase(bar)
		if is_instance_valid(bar):
			bar.queue_free()
		_stack_bars())


func _stack_bars() -> void:
	for i in _bars.size():
		var b: Control = _bars[i]
		b.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		b.offset_top = i * 64
		b.offset_bottom = i * 64 + 90


## monsters walk out of the gate farthest from you. Bosses come from the middle back.
func _spawn_point(boss: bool) -> Vector2:
	var p := _player()
	var me := p.global_position if p else Vector2.ZERO
	if boss:
		var v := Vector2(randf_range(-260, 260), randf_range(-240, -120))
		if v.distance_to(me) < 300:
			v = Vector2(-signf(me.x) * 420 if me.x != 0 else 420, -150)
		return v
	if randf() < 0.6:
		var g: Vector2 = GATES[0] if GATES[0].distance_to(me) > GATES[1].distance_to(me) else GATES[1]
		return g + Vector2(randf_range(-50, 50), randf_range(-20, 30))
	for i in 40:
		var v := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * FLOOR_R * 0.75
		v.y *= 0.5
		if Vector2(v.x, v.y * 2).length() > FLOOR_R * 0.75:
			continue
		if v.distance_to(me) > 280:
			return v
	return GATES[0]


func _on_enemy_died() -> void:
	if _net_client():
		return
	await get_tree().process_frame
	_update_info()
	if _spawning or _dead or _clearing or round_no <= 0 or _alive() > 0:
		return
	_round_clear()


func _round_clear() -> void:
	_clearing = true
	var p := _player()
	var full := _boss_round
	var heal: int = (p.max_health - p.health) if (p and full) else HEAL_BETWEEN
	_banner("ROUND %d CLEAR" % round_no, "Full heal!" if full else "+%d heart" % HEAL_BETWEEN, Color(0.6, 1, 0.6), 1.4, 0.8)
	if p and p.health < p.max_health and heal > 0:
		p.heal(heal)
		Juice.damage_number(p.get_parent(), p.global_position + Vector2(0, -50), "+%d" % heal, Color(0.5, 1, 0.5), 26)
	_pull_loot(1.2)
	# teammates get the same heal (a full heal on boss rounds) and their loot pulled in
	_net().scene_call("_net_heal", [999 if full else HEAL_BETWEEN])
	_net().scene_call("_pull_loot", [1.2])
	await get_tree().create_timer(BREAK_TIME, false).timeout
	_next_round()


# ---------------------------------------------------------------- death card / team wipe

## host: someone went down (or got back up). Whole team down = everyone loses
func _net_down(peer: int, is_down: bool) -> void:
	if _dead:
		return
	if is_down:
		_down[peer] = true
	else:
		_down.erase(peer)
	if _down.size() >= _net().player_count():
		var survived := maxi(round_no - 1, 0)
		_net().scene_call("_team_wipe", [survived, round_no, kills, bosses_slain, _run_time])
		_team_wipe(survived, round_no, kills, bosses_slain, _run_time)


## everyone runs this (host + clients via scene_call)
func _team_wipe(survived: int, died_on: int, kill_count: int, bosses: int, run_t: float) -> void:
	if _dead:
		return
	_dead = true
	_spawning = false
	round_no = died_on
	kills = kill_count
	bosses_slain = bosses
	_run_time = run_t
	for b in _bars:
		if is_instance_valid(b):
			b.queue_free()
	_bars.clear()
	round_info.text = ""
	var best_before := GameState.best_round
	var new_best := GameState.record_run(died_on, kill_count)
	Juice.slow_mo(self, 1.2, 0.2)
	await get_tree().create_timer(1.8, true, false, true).timeout
	_show_card(survived, best_before, new_best, true)


func _on_player_died() -> void:
	if _dead or _coop():
		return
	_dead = true
	_spawning = false
	for b in _bars:
		if is_instance_valid(b):
			b.queue_free()
	_bars.clear()
	round_info.text = ""
	var survived := maxi(round_no - 1, 0)
	var best_before := GameState.best_round
	var new_best := GameState.record_run(round_no, kills)
	Juice.slow_mo(self, 1.2, 0.2)
	await get_tree().create_timer(1.8, true, false, true).timeout
	_show_card(survived, best_before, new_best, false)


func _show_card(survived: int, best_before: int, new_best: bool, team_wipe: bool = false) -> void:
	# pausing the tree in co-op kills networking
	if not _coop():
		get_tree().paused = true
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var center := UIK.overlay(layer, 0.6)
	center.get_parent().add_to_group("modal")
	var panel := UIK.panel(Color(1, 0.4, 0.3), 460.0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := UIK.label("THE TEAM WAS WIPED" if team_wipe else "YOU FELL", 40 if team_wipe else 44, UIK.BAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := UIK.label("The crowd goes wild", 15, UIK.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	if new_best:
		var nb := UIK.label("NEW BEST!", 22, UIK.GOLD)
		nb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nb)
	var stats := UIK.section("YOUR RUN")
	var mins := int(_run_time) / 60
	var secs := int(_run_time) % 60
	for row in [
		["Rounds survived", str(survived)],
		["Died on round", str(round_no)],
		["Monsters killed", str(kills)],
		["Bosses slain", str(bosses_slain)],
		["Time", "%d:%02d" % [mins, secs]],
		["Best round", str(maxi(best_before, round_no))],
	]:
		var h := HBoxContainer.new()
		h.add_child(UIK.label(row[0], 17))
		h.add_child(UIK.spacer())
		h.add_child(UIK.label(row[1], 19, UIK.GOLD))
		stats.add_child(h)
	v.add_child(stats)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	var again := UIK.button("FIGHT AGAIN", true, UIK.GOOD, 17)
	again.pressed.connect(_leave.bind("res://scenes/levels/colosseum/colosseum.tscn", "Start"))
	btns.add_child(again)
	var map := UIK.button("ROAD MAP", true, UIK.EDGE, 17)
	map.pressed.connect(_leave.bind("res://scenes/levels/map/road_map.tscn", ""))
	btns.add_child(map)
	var camp := UIK.button("CAMP", true, UIK.GOLD, 17)
	camp.pressed.connect(_leave.bind("res://scenes/levels/hub/hub.tscn", "Start"))
	btns.add_child(camp)
	v.add_child(btns)
	if _net_client():
		var note := UIK.label("The host picks where the team goes next.", 13, UIK.DIM)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(note)
	panel.pivot_offset = Vector2(230, 200)
	panel.scale = Vector2(0.6, 0.6)
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _leave(scene: String, spawn: String) -> void:
	if _coop():
		Net.change_scene(get_tree(), scene, spawn)
		return
	get_tree().paused = false
	Engine.time_scale = 1.0
	if spawn != "":
		Engine.set_meta("arrival_spawn", spawn)
	get_tree().change_scene_to_file(scene)


## a monster copy showed up on this client: bosses get their bar
func net_enemy_spawned(e: Node) -> void:
	var k := str(e.get("kind"))
	if BOSS_TITLES.has(k) and e.get("summoned") != true:
		_add_boss_bar(e, BOSS_TITLES[k])
	if k == "pufferfish":
		_puffer_landing(e)
