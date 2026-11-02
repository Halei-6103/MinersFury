extends "res://scenes/levels/shared/arena.gd"
## Weapon Proficiency trial: you vs the Pufferfish on a giant clam in the sea.
## No other monsters. It casts Tetrodotoxin at you. Beat it and you learn the
## combo (Venom rune + Storm thunderclap). Lose and you can retry right away.

const UIK = preload("res://scenes/ui/ui_kit.gd")
const PufferBoss = preload("res://scenes/enemies/pufferfish/puffer_boss.gd")
const Sfx = preload("res://scenes/audio/sfx.gd")
const SELF := "res://scenes/levels/trial/trial.tscn"
const CAMP := "res://scenes/levels/hub/hub.tscn"
const MAP := "res://scenes/levels/map/road_map.tscn"

var _boss: Node2D
var _over: bool = false


func _ready() -> void:
	level_id = "trial"
	cfg = {"boss": "pufferfish", "boss_title": "PUFFERFISH", "shard": ""}
	rounds = []
	TransferBoard.place_player(self)
	Music.ensure(self)
	GameUI.ensure(self)
	var attempt := int(Engine.get_meta("trial_attempt", 0)) + 1
	Engine.set_meta("trial_attempt", attempt)
	_boss_bar = BossBar.new()
	_boss_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_boss_bar.offset_bottom = 90
	_boss_bar.visible = false
	$UI.add_child(_boss_bar)
	var p := _player()
	if p:
		p.hold_on_death = true
		p.died.connect(_lose)
	round_info.text = "WEAPON PROFICIENCY     Attempt %d" % attempt
	await get_tree().create_timer(0.6, false).timeout
	_banner("PROFICIENCY TRIAL", "The Pufferfish knows your secret", Color(0.6, 1.0, 0.75), 1.8, 0.9)
	await get_tree().create_timer(2.2, false).timeout
	_spawn_boss()


func _spawn_boss() -> void:
	var e = MeleeScene.instantiate()
	e.set_script(PufferBoss)
	e.kind = "pufferfish"
	e.position = Vector2(0, -150)
	monsters.add_child(e)
	_boss = e
	e.died.connect(_win)
	_boss_bar.boss = e
	_boss_bar.title = "PUFFERFISH"
	_boss_bar.visible = true
	Juice.shake(self, 0.7)
	Juice.shockwave(self, e.global_position, 30.0)
	# superhero landing. The impact is right at the start of the sound, so wait
	# for the fish to finish dropping (~0.3s) and slam it in on touchdown
	var at: Vector2 = e.global_position
	get_tree().create_timer(0.28, false).timeout.connect(func() -> void:
		Sfx.play(self, "boss_landing", at, 0.0, 0.02))


func _on_enemy_died() -> void:
	pass


# ---------------------------------------------------------------- win

func _win() -> void:
	if _over:
		return
	_over = true
	GameState.add_mastery("tetrodotoxin")
	Engine.set_meta("trial_attempt", 0)
	round_info.text = ""
	Juice.slow_mo(self, 1.4, 0.15)
	await get_tree().create_timer(0.3, true, false, true).timeout
	Juice.impact_flash(self, 0.5, Color(0.6, 1.0, 0.75))
	_banner("PROFICIENCY UNLOCKED", "TETRODOTOXIN", Color(0.6, 1.0, 0.75), 2.4, 1.1)
	await get_tree().create_timer(3.2, true, false, true).timeout
	_boss_bar.visible = false
	var v := _card(Color(0.6, 1.0, 0.75))
	_title(v, "TETRODOTOXIN", 38, Color(0.6, 1.0, 0.75))
	_line(v, "You can now combine your two ultimates.", 16, Color.WHITE)
	var how := UIK.section("HOW TO CAST IT")
	how.add_child(UIK.label("1.  Venom Blade: hold R, drop a poison rune", 15))
	how.add_child(UIK.label("2.  Q to swap to the Storm Blade", 15))
	how.add_child(UIK.label("3.  Hold R, land the thunderclap ON the rune", 15))
	how.add_child(UIK.label("Two waves fly out the sides of the rune.\nAnything they touch is paralyzed and takes 30% more damage.", 13, UIK.DIM))
	v.add_child(how)
	_buttons(v, [["BACK TO CAMP", UIK.GOLD, CAMP, "Start"], ["ROAD MAP", UIK.EDGE, MAP, ""]])


# ---------------------------------------------------------------- lose

func _lose() -> void:
	if _over:
		return
	_over = true
	round_info.text = ""
	Juice.slow_mo(self, 1.0, 0.25)
	await get_tree().create_timer(1.6, true, false, true).timeout
	_boss_bar.visible = false
	get_tree().paused = true
	var v := _card(UIK.BAD)
	_title(v, "THE PUFFERFISH WINS", 32, UIK.BAD)
	if _boss and is_instance_valid(_boss):
		_line(v, "It had %d%% health left." % int(100.0 * _boss.health / _boss.max_health), 15, UIK.DIM)
	var tip := UIK.section("TIP")
	tip.add_child(UIK.label("When it puffs up, watch the glowing lines on the floor.\nStep off them (toward it or away) or roll through the wave.", 14))
	v.add_child(tip)
	_buttons(v, [["TRY AGAIN", UIK.GOOD, SELF, "Start"], ["BACK TO CAMP", UIK.GOLD, CAMP, "Start"]])


# ---------------------------------------------------------------- card bits

func _card(edge: Color) -> VBoxContainer:
	get_tree().paused = true
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var center := UIK.overlay(layer, 0.6)
	center.get_parent().add_to_group("modal")
	var panel := UIK.panel(edge, 480.0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	panel.pivot_offset = Vector2(240, 180)
	panel.scale = Vector2(0.6, 0.6)
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return v


func _title(v: VBoxContainer, text: String, size: int, color: Color) -> void:
	var l := UIK.label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)


func _line(v: VBoxContainer, text: String, size: int, color: Color) -> void:
	var l := UIK.label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)


func _buttons(v: VBoxContainer, list: Array) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	for b in list:
		var btn := UIK.button(b[0], true, b[1], 17)
		btn.pressed.connect(_leave.bind(b[2], b[3]))
		row.add_child(btn)
	v.add_child(row)


func _leave(scene: String, spawn: String) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if spawn != "":
		Engine.set_meta("arrival_spawn", spawn)
	get_tree().change_scene_to_file(scene)
