extends CanvasLayer
## Every 3 rounds in the Colosseum: pick 1 of 3 material boons (or skip).
## Only materials you've found on the maps show up. Each material always gives
## the same boon, and they stack.
##   BoonPicker.open(level, on_done)

const UI = preload("res://scenes/ui/ui_kit.gd")
const GameState = preload("res://scenes/core/game_state.gd")
const RunState = preload("res://scenes/colosseum/run_state.gd")
const RunData = preload("res://scenes/colosseum/run_data.gd")
const BoonDrop = preload("res://scenes/colosseum/boon_drop.gd")
const Net = preload("res://scenes/core/net.gd")
const Juice = preload("res://scenes/effects/juice.gd")

var opts: Array = []
var on_done: Callable
var _closed: bool = false
var _root: Control


## returns null (and finishes right away) when there's nothing to offer
static func open(level: Node, done: Callable) -> Node:
	var list := BoonDrop.choices(3)
	if list.is_empty():
		if done.is_valid():
			done.call()
		return null
	var p = load("res://scenes/colosseum/boon_picker.gd").new()
	p.opts = list
	p.on_done = done
	level.add_child(p)
	return p


func _ready() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal")
	if not Net.online(get_tree()):
		get_tree().paused = true
	_build()


func _build() -> void:
	if _root:
		_root.queue_free()
	var center := UI.overlay(self, 0.55)
	_root = center.get_parent()
	var panel := UI.panel(UI.GOLD, 720.0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(UI.label("PICK A BOON", 26, UI.GOLD))
	head.add_child(UI.spacer())
	head.add_child(UI.label("Rerolls: %d" % RunState.rerolls, 16, UI.GOLD))
	v.add_child(head)
	v.add_child(UI.label("From materials you've found on the maps. They stack for the rest of the run.", 13, UI.DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	for id in opts:
		row.add_child(_card(String(id)))
	var bottom := HBoxContainer.new()
	# same rerolls as the crystals
	var rr := UI.button("REROLL", RunState.rerolls > 0, UI.GOLD, 15)
	rr.pressed.connect(_reroll)
	bottom.add_child(rr)
	bottom.add_child(UI.spacer())
	var skip := UI.button("SKIP", true, Color(0.6, 0.6, 0.65), 15)
	skip.pressed.connect(_close)
	bottom.add_child(skip)
	v.add_child(bottom)


func _card(id: String) -> Control:
	var item: Dictionary = GameState.ITEMS[id]
	var info: Dictionary = RunData.BOONS[id]
	var card := UI.card(item.color.darkened(0.4))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.add_child(UI.icon(item.icon, int(item.get("frames", 1)), 2.0))
	top.add_child(UI.label(info.name, 17, item.color))
	cv.add_child(top)
	var d := UI.label(info.desc, 14)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 190
	cv.add_child(d)
	var have := int(RunState.boons.get(id, 0))
	var tier := int(GameState.lifetime.get(id, 0)) >= RunData.TIER_AT
	var note := "Have: %d" % have
	if tier:
		note += "   (x1.5, collected 25)"
	cv.add_child(UI.label(note, 12, UI.DIM))
	var b := UI.button("TAKE", true, item.color, 15)
	b.pressed.connect(_take.bind(id))
	cv.add_child(b)
	return card


## three new ones (different from these if there are enough)
func _reroll() -> void:
	RunState.rerolls -= 1
	var all := BoonDrop.eligible()
	var fresh: Array = all.filter(func(m): return not (m in opts))
	fresh.shuffle()
	var pick: Array = fresh.slice(0, 3)
	all.shuffle()
	for m in all:
		if pick.size() >= 3:
			break
		if not (m in pick):
			pick.append(m)
	opts = pick
	_build()


func _take(id: String) -> void:
	var p = get_tree().get_first_node_in_group("player")
	BoonDrop.give(p, id)
	if p:
		Juice.damage_number(p.get_parent(), p.global_position + Vector2(0, -70), "%s: %s" % [RunData.BOONS[id].name, RunData.BOONS[id].desc], GameState.ITEMS[id].color, 18)
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
