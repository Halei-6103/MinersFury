extends CanvasLayer
## The crystal screen after a Colosseum boss round.
##   kind "base"   (rounds 5, 15, 25...): pick 1 of 2 boosts. Matching weapon gets
##                 the stat, any other weapon gets a splash chance of the element.
##   kind "attune" (rounds 10, 20, 30...): see the element and 2 attunements per
##                 weapon. Take one, reroll the crystal, reroll the attunements, or skip.
## Every option shows which hand it goes into. Skip is always there, and so is
## reroll (one shared pool for crystals and boons: spend them wisely).
##   CrystalPicker.open(level, "attune", on_done)

const UI = preload("res://scenes/ui/ui_kit.gd")
const GameState = preload("res://scenes/core/game_state.gd")
const RunState = preload("res://scenes/colosseum/run_state.gd")
const RunData = preload("res://scenes/colosseum/run_data.gd")
const FxSprite = preload("res://scenes/effects/fx_sprite.gd")
const Net = preload("res://scenes/core/net.gd")

var kind: String = "attune"
var el: String = "fire"
## weapon -> [ids] shown right now
var opts: Dictionary = {}
var on_done: Callable
var _root: Control
var _closed: bool = false


static func open(level: Node, k: String, done: Callable) -> Node:
	var p = load("res://scenes/colosseum/crystal_picker.gd").new()
	p.kind = k
	p.on_done = done
	p.el = RunData.ELEMENTS[randi() % 3]
	level.add_child(p)
	return p


func _weapons() -> Array:
	return GameState.slots.filter(func(w): return w != "")


func _ready() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal")
	if not Net.online(get_tree()):
		get_tree().paused = true
	_roll_options()
	_build()


func _roll_options() -> void:
	opts = {}
	for w in _weapons():
		if kind == "base":
			if RunState.element(w) == el:
				opts[w] = RunState.roll_two(RunData.BASE[el])
			else:
				opts[w] = ["splash"]
		else:
			opts[w] = RunState.roll_two(RunState.pool_for(w, el))


## same element, two new picks for each weapon (new ones first if there are any)
func _reroll_attunements() -> void:
	for w in _weapons():
		var pool := RunState.pool_for(w, el)
		var fresh: Array = pool.filter(func(id): return not (id in opts.get(w, [])))
		var pick := RunState.roll_two(fresh)
		if pick.size() < 2:
			for id in RunState.roll_two(pool):
				if pick.size() < 2 and not (id in pick):
					pick.append(id)
		opts[w] = pick


func _build() -> void:
	if _root:
		_root.queue_free()
	var center := UI.overlay(self, 0.55)
	_root = center.get_parent()
	var col: Color = RunData.EL_COLOR[el]
	var panel := UI.panel(col, 760.0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	# head: crystal art + element
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var fx: String = RunData.EL_FX[el]
	var tex: Texture2D = load("res://assets/sprites/fx/%s.png" % fx)
	head.add_child(UI.icon("res://assets/sprites/fx/%s.png" % fx, int(FxSprite.FX[fx][0]), 56.0 / tex.get_height()))
	var tv := VBoxContainer.new()
	tv.add_child(UI.label(("%s CRYSTAL" if kind == "attune" else "%s BASE CRYSTAL") % RunData.EL_NAME[el].to_upper(), 26, col))
	tv.add_child(UI.label("Pick one. It goes into that weapon and only works while you hold it." if kind == "attune"
		else "A small boost. Matching weapon: the stat. Other weapon: a chance to do %s on hit." % RunData.EL_NAME[el].to_lower(), 13, UI.DIM))
	head.add_child(tv)
	head.add_child(UI.spacer())
	head.add_child(UI.label("Rerolls: %d" % RunState.rerolls, 16, UI.GOLD))
	v.add_child(head)

	# one column per hand
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	v.add_child(cols)
	for w in _weapons():
		cols.add_child(_weapon_column(w))

	# buttons
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if kind == "attune":
		var rc := UI.button("REROLL CRYSTAL", RunState.rerolls > 0, UI.GOLD, 15)
		rc.pressed.connect(func() -> void:
			RunState.rerolls -= 1
			var others: Array = RunData.ELEMENTS.filter(func(e): return e != el)
			el = others[randi() % others.size()]
			_roll_options()
			_build())
		row.add_child(rc)
		var ra := UI.button("REROLL ATTUNEMENTS", RunState.rerolls > 0, UI.GOLD, 15)
		ra.pressed.connect(func() -> void:
			RunState.rerolls -= 1
			_reroll_attunements()
			_build())
		row.add_child(ra)
	else:
		# base crystal: one reroll button, a new element and new boosts
		var rb := UI.button("REROLL", RunState.rerolls > 0, UI.GOLD, 15)
		rb.pressed.connect(func() -> void:
			RunState.rerolls -= 1
			var others: Array = RunData.ELEMENTS.filter(func(e): return e != el)
			el = others[randi() % others.size()]
			_roll_options()
			_build())
		row.add_child(rb)
	row.add_child(UI.spacer())
	var skip := UI.button("SKIP", true, Color(0.6, 0.6, 0.65), 15)
	skip.pressed.connect(_close)
	row.add_child(skip)
	v.add_child(row)


func _weapon_column(w: String) -> Control:
	var info: Dictionary = GameState.WEAPONS[w]
	var card := UI.card(info.color.darkened(0.35))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)
	cv.add_child(UI.label(info.name, 19, info.color))
	var wel := RunState.element(w)
	var what := "Matching: pure upgrades" if wel == el else ("No element yet" if wel == "" else "Mixed: %s + %s" % [RunData.EL_NAME[wel], RunData.EL_NAME[el]])
	if kind == "base":
		what = "Matching: stat boost" if wel == el else "Splash chance"
	cv.add_child(UI.label(what, 13, UI.DIM))
	var have: Array = RunState.m(w).att
	if not have.is_empty():
		cv.add_child(UI.label("Has: " + ", ".join(have.map(func(id): return RunData.att_name(id))), 12, UI.DIM))
	var list: Array = opts.get(w, [])
	if list.is_empty():
		# nothing left in this pool: a base boost of the element instead
		cv.add_child(UI.label("Nothing new for this weapon.", 13, UI.DIM))
		var fb: String = RunData.BASE[el][randi() % 4]
		list = ["base:" + fb]
	for id in list:
		cv.add_child(_option(w, String(id)))
	return card


func _option(w: String, id: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var title := ""
	var desc := ""
	if id == "splash":
		title = "%s Splash" % RunData.EL_NAME[el]
		desc = RunData.SPLASH[el].desc
	elif id.begins_with("base:"):
		var b := id.trim_prefix("base:")
		title = RunData.BASE_INFO[b].name
		desc = RunData.BASE_INFO[b].desc
	elif kind == "base":
		title = RunData.BASE_INFO[id].name
		desc = RunData.BASE_INFO[id].desc
	else:
		title = RunData.att_name(id)
		desc = RunData.att_desc(id)
	var ult := id in RunData.ULTS
	var b := UI.button(title, true, Color(1.0, 0.75, 0.3) if ult else RunData.EL_COLOR[el], 16)
	b.pressed.connect(_choose.bind(w, id))
	box.add_child(b)
	var d := UI.label(desc, 13)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 300
	box.add_child(d)
	return box


func _choose(w: String, id: String) -> void:
	if kind == "base":
		RunState.take_base(w, el, id if id != "splash" else RunData.BASE[el][0])
	elif id.begins_with("base:"):
		var mm := RunState.m(w)
		var b := id.trim_prefix("base:")
		if RunState.element(w) == el:
			mm.base[b] = int(mm.base.get(b, 0)) + 1
		else:
			mm.splash[el] = int(mm.splash.get(el, 0)) + 1
	else:
		RunState.take(w, id)
	# the player re-reads its weapon (an infusion turns on the aura and hits)
	var p = get_tree().get_first_node_in_group("player")
	if p and p.has_method("set_weapon") and p.weapon == w:
		p.set_weapon(w)
	_close()


func _close() -> void:
	if _closed:
		return
	_closed = true
	if not Net.online(get_tree()):
		get_tree().paused = false
	if on_done.is_valid():
		on_done.call()
	queue_free()
