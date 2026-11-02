extends Node2D
## The camp hub.
##   Telecom          send boss shards to Earth -> blueprints come back
##   Crafting station blueprint + mob materials -> weapon
##   Transfer board   opens the road map
## Other stations (seed shop, greenhouse) still show the simple info panel.
## The crafting station is built here in code so your hub.tscn edits stay untouched.

const TransferBoard = preload("res://scenes/levels/shared/transfer_board.gd")
const Music = preload("res://scenes/audio/music.gd")
const GameState = preload("res://scenes/core/game_state.gd")
const GameUI = preload("res://scenes/ui/game_ui.gd")
const UI = preload("res://scenes/ui/ui_kit.gd")
const Juice = preload("res://scenes/effects/juice.gd")
const LightningBolt = preload("res://scenes/effects/lightning_bolt.gd")
const FxSprite = preload("res://scenes/effects/fx_sprite.gd")
const Station = preload("res://scenes/levels/hub/station.gd")
const Sfx = preload("res://scenes/audio/sfx.gd")

const ROAD_MAP := "res://scenes/levels/map/road_map.tscn"
## where the crafting station stands in camp (move it here if it's in the way)
const CRAFT_POS := Vector2(262, -14)
const CRAFT_ANCHOR := Vector2(42, 62)

@onready var info_panel: PanelContainer = $UI/InfoPanel
@onready var info_title: Label = $UI/InfoPanel/Margin/VBox/Title
@onready var info_body: Label = $UI/InfoPanel/Margin/VBox/Body

var _open_station: Area2D = null
var _menu: Control = null
var _busy: bool = false   # a cinematic is running
var _craft_node: Node2D


func _ready() -> void:
	info_panel.visible = false
	GameState.ensure_loaded()
	Engine.set_meta("map_stop", 0)
	_build_craft_station()
	for station in get_tree().get_nodes_in_group("hub_station"):
		if station.station_id == "transfer":
			continue  # the transfer board handles itself
		if not station.interacted.is_connected(_on_station_interacted):
			station.interacted.connect(_on_station_interacted)
			station.player_left.connect(_on_station_left)
	_point_board_at_map()
	TransferBoard.place_player(self)
	Music.ensure(self)
	GameUI.ensure(self)


## the transfer board now opens the road map instead of going straight to a map
func _point_board_at_map() -> void:
	for b in get_tree().get_nodes_in_group("hub_station"):
		if b.station_id == "transfer":
			var board = b.get_parent()
			board.target_scene = ROAD_MAP
			board.label = "Road Map"
			b.station_name = "Road Map"
			if b.prompt:
				b.prompt.text = "[E] Road Map"


func _build_craft_station() -> void:
	var root := Node2D.new()
	root.name = "CraftingStation"
	root.position = CRAFT_POS
	var tex: Texture2D = load("res://assets/sprites/hub/craft_station.png")
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.offset = tex.get_size() / 2.0 - CRAFT_ANCHOR
	root.add_child(spr)
	var body := StaticBody2D.new()
	var shape := CollisionPolygon2D.new()
	shape.polygon = PackedVector2Array([Vector2(-30, -6), Vector2(14, -26), Vector2(48, -10), Vector2(4, 12)])
	body.add_child(shape)
	root.add_child(body)
	var area: Area2D = Station.new()
	area.station_id = "craft"
	area.station_name = "Crafting Station"
	area.prompt_path = NodePath("Prompt")
	var zone := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 62.0
	zone.shape = c
	area.add_child(zone)
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.z_index = 20
	prompt.position = Vector2(-80, -84)
	prompt.size = Vector2(160, 18)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.add_theme_constant_override("outline_size", 4)
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	area.add_child(prompt)
	root.add_child(area)
	$Entities.add_child(root)
	_craft_node = root


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
	match station.station_id:
		"telecom":
			_open_uplink()
		"craft":
			_open_crafting()
		_:
			info_title.text = station.station_name
			info_body.text = station.description
			info_panel.visible = true


func _on_station_left(station: Area2D) -> void:
	if _open_station == station:
		_close_panel()


func _close_panel() -> void:
	_open_station = null
	info_panel.visible = false
	if _menu:
		_menu.queue_free()
		_menu = null
		_lock_player(false)


func _unhandled_input(event: InputEvent) -> void:
	if _menu and event.is_action_pressed("ui_cancel"):
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


## a centered menu panel; returns the content box
func _menu_box(title: String, status: String = "") -> VBoxContainer:
	_lock_player(true)
	var center := UI.overlay($UI, 0.25)
	_menu = center.get_parent()
	_menu.add_to_group("modal")
	var panel := UI.panel(UI.EDGE, 720.0)
	center.add_child(panel)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 14)
	panel.add_child(main)
	var head := HBoxContainer.new()
	head.add_child(UI.label(title, 26))
	head.add_child(UI.spacer())
	if status != "":
		var st := UI.label(status, 13, UI.GOOD)
		st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(st)
	main.add_child(head)
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)
	panel.scale = Vector2(0.92, 0.92)
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return main


func _reopen() -> void:
	var st := _open_station
	_close_panel()
	if st:
		_on_station_interacted(st)


# ---------------------------------------------------------------- telecom: shard -> blueprint

func _open_uplink() -> void:
	var main := _menu_box("TELECOM UPLINK", "EARTH LINK: ONLINE")
	main.add_child(UI.label("Send boss shards home. Earth studies them and beams down a blueprint.", 14, UI.DIM))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	main.add_child(cols)

	var cargo := UI.section("SHARDS IN CARGO")
	cargo.custom_minimum_size.x = 220
	var any := false
	for id in GameState.items_of_type("shard"):
		any = true
		cargo.add_child(UI.item_row(id, GameState.count(id), GameState.ITEMS[id]))
	if not any:
		cargo.add_child(UI.label("No shards.\nBosses drop them.", 14, UI.DIM))
	cols.add_child(cargo)

	var right := UI.section("BLUEPRINTS")
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var where := {"storm_crystal": "the Werebear in Mossback Woods", "tomb_crystal": "the Necromancer in the Bone Wastes", "fire_crystal": "the Fire Cultist in the Ember Caldera"}
	for bp in GameState.BLUEPRINTS:
		var info: Dictionary = GameState.BLUEPRINTS[bp]
		var card := UI.card()
		var v := VBoxContainer.new()
		card.add_child(v)
		var top := HBoxContainer.new()
		top.add_child(UI.icon(info.icon, info.frames, 1.4))
		top.add_child(UI.label(info.name, 18, UI.GOLD))
		v.add_child(top)
		var shard: String = info.shard
		if GameState.has_blueprint(bp):
			v.add_child(UI.label("Received. Build it at the crafting station.", 14, UI.GOOD))
		elif GameState.count(shard) > 0:
			var b := UI.button("SEND %s TO EARTH" % GameState.display_name(shard).to_upper(), true, UI.EDGE)
			b.pressed.connect(_send_shard.bind(bp))
			v.add_child(b)
		else:
			v.add_child(UI.label("Needs a %s (from %s)" % [GameState.display_name(shard), where.get(shard, "a boss")], 14, UI.BAD))
		right.add_child(card)
	main.add_child(UI.label("[E] / [Esc] close", 12, UI.DIM))


func _send_shard(bp: String) -> void:
	if not GameState.uplink(bp):
		return
	var station := _open_station
	_close_panel()
	_busy = true
	_lock_player(true)
	var dish: Vector2 = station.get_parent().global_position + Vector2(0, -40) if station else Vector2.ZERO
	var shard_col: Color = GameState.ITEMS[GameState.BLUEPRINTS[bp].shard].color
	# up it goes
	_beam(dish, shard_col, 0.9, 26.0)
	Juice.shake(self, 0.35)
	Juice.damage_number(self, dish + Vector2(0, -80), "TRANSMITTING...", shard_col.lightened(0.3), 20)
	await get_tree().create_timer(1.4).timeout
	# Earth answers: a blueprint beams down onto the dish
	_beam(dish, Color(0.75, 1.0, 1.0), 0.7, 34.0)
	FxSprite.spawn(self, "storm_strike", dish + Vector2(0, 40), {"z": 60})
	Juice.impact_flash(self, 0.4, Color(0.8, 1.0, 1.0))
	Juice.shake(self, 0.6)
	_big_banner("BLUEPRINT RECEIVED", GameState.BLUEPRINTS[bp].name.replace(" Blueprint", "").to_upper(), UI.GOLD)
	await get_tree().create_timer(1.2).timeout
	_lock_player(false)
	_busy = false


# ---------------------------------------------------------------- crafting: blueprint + materials -> weapon

func _open_crafting() -> void:
	var main := _menu_box("CRAFTING STATION")
	main.add_child(UI.label("Blueprints from Earth + materials from monsters = new weapons.", 14, UI.DIM))
	var shown := 0
	for w in GameState.WEAPONS:
		var info: Dictionary = GameState.WEAPONS[w]
		var r: Dictionary = info.get("recipe", {})
		if r.is_empty():
			continue
		shown += 1
		var card := UI.card(info.color.darkened(0.35))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		card.add_child(v)
		var top := HBoxContainer.new()
		top.add_child(UI.label(info.name, 20, info.color))
		top.add_child(UI.spacer())
		if GameState.owns(w):
			top.add_child(UI.label("BUILT", 14, UI.GOOD))
		v.add_child(top)
		v.add_child(UI.label(info.desc, 13, UI.DIM))
		if not GameState.owns(w):
			var has_bp := GameState.has_blueprint(r.blueprint)
			var need := HBoxContainer.new()
			need.add_theme_constant_override("separation", 18)
			need.add_child(UI.label(("[x] " if has_bp else "[ ] ") + "Blueprint", 14, UI.GOOD if has_bp else UI.BAD))
			for id in r.items:
				var n := int(r.items[id])
				var have := GameState.count(id)
				var row := HBoxContainer.new()
				row.add_child(UI.icon(GameState.ITEMS[id].icon, 1, 1.2))
				row.add_child(UI.label("%s %d/%d" % [GameState.ITEMS[id].name, have, n], 14, UI.GOOD if have >= n else UI.BAD))
				need.add_child(row)
			v.add_child(need)
			if not has_bp:
				v.add_child(UI.label("Get the blueprint from the telecom first.", 13, UI.DIM))
			var b := UI.button("CRAFT", GameState.can_craft(w), info.color)
			b.pressed.connect(_craft.bind(w))
			v.add_child(b)
		main.add_child(card)
	if shown == 0:
		main.add_child(UI.label("Nothing to build yet.", 14, UI.DIM))
	main.add_child(UI.label("Swap what's in your hands from the inventory [Tab]. Q swaps in a fight.   [E] / [Esc] close", 12, UI.DIM))


func _craft(w: String) -> void:
	if not GameState.craft(w):
		return
	_close_panel()
	_busy = true
	_lock_player(true)
	var at: Vector2 = _craft_node.global_position + Vector2(4, -26)
	var col: Color = GameState.WEAPONS[w].color
	# hammer it out: three strikes, sparks, then the reveal
	for i in 3:
		Juice.shake(self, 0.3)
		Juice.spark(self, at + Vector2(randf_range(-6, 6), randf_range(-4, 4)), Vector2.UP.rotated(randf_range(-1, 1)), false, Color(1, 0.7, 0.3))
		Juice.damage_number(self, at + Vector2(0, -30), "CLANG", Color(1, 0.8, 0.5), 16)
		await get_tree().create_timer(0.35).timeout
	if GameState.WEAPONS[w].effect == "venom":
		FxSprite.spawn(self, "poison_burst", at + Vector2(0, 20), {"scale": 2.0, "z": 60})
	elif GameState.WEAPONS[w].effect == "flame":
		FxSprite.spawn(self, "cult_fire_impact", at + Vector2(0, -6), {"scale": 4.0, "z": 60})
		Sfx.play(self, "flame_wall", at, -4.0)
	else:
		FxSprite.spawn(self, "storm_strike", at + Vector2(0, 26), {"z": 60})
	Juice.impact_flash(self, 0.5, col.lightened(0.5))
	Juice.shake(self, 0.8)
	Juice.zoom_punch(self, 0.1)
	var p := _player()
	if p and p.has_method("set_weapon"):
		p.set_weapon(GameState.equipped())
	var hand := GameState.slots.find(w)
	_big_banner("WEAPON CRAFTED", GameState.WEAPONS[w].name.to_upper(), col, "In hand %d. Q to swap, Tab to manage." % (hand + 1) if hand >= 0 else "Equip it from the inventory (Tab)")
	await get_tree().create_timer(1.2).timeout
	_lock_player(false)
	_busy = false


# ---------------------------------------------------------------- effects

func _beam(ground: Vector2, color: Color, life: float, width: float) -> void:
	var b := Node2D.new()
	b.z_index = 50
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


func _big_banner(top_text: String, big: String, color: Color, sub: String = "") -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -420
	box.offset_right = 420
	box.offset_top = -210
	box.offset_bottom = -50
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a := UI.label(top_text, 26, Color.WHITE)
	var b := UI.label(big, 58, color)
	b.add_theme_constant_override("outline_size", 14)
	for l in [a, b]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	if sub != "":
		var c := UI.label(sub, 16, UI.DIM)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(c)
	$UI.add_child(box)
	box.pivot_offset = Vector2(420, 80)
	box.scale = Vector2(2.2, 2.2)
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.06)
	tw.parallel().tween_property(box, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.2)
	tw.tween_property(box, "modulate:a", 0.0, 0.4)
	tw.tween_callback(box.queue_free)
