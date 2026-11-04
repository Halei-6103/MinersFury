extends Control
## Tutorial tips. Little cards that pop up the first time something matters
## (first fight, first shard, first blueprint...), once each, saved in your save.
## Never pauses the game (co-op safe). One at a time; extras wait their turn.
## The pause menu's HOW TO PLAY page lists every tip (Tips.ORDER + Tips.TIPS).
## GameUI owns one of these and calls check() a couple of times a second.

const GameState = preload("res://scenes/core/game_state.gd")
const UI = preload("res://scenes/ui/ui_kit.gd")

const CAMP := "res://scenes/levels/hub/hub.tscn"
const MAP := "res://scenes/levels/map/road_map.tscn"
const FIGHT_MAPS := ["forest", "wasteland", "colosseum", "trial", "volcano"]
## how long a tip stays if you don't click "Got it"
const STAY := 16.0

## shown in this order on the HOW TO PLAY page
const ORDER := ["camp", "road_map", "fight", "materials", "shard", "blueprint", "weapon", "ultimate", "combo"]
const TIPS := {
	"camp": {
		"title": "Welcome to camp",
		"text": "This is home base. Walk onto the transfer board and press E to open the road map, then pick where to fight.",
	},
	"road_map": {
		"title": "The road map",
		"text": "Click a circle to go there.\nGrey = not played, red = locked, green = cleared.\nClear a map to unlock the next one.",
	},
	"fight": {
		"title": "Fighting",
		"text": "Click to attack. Click again during a swing to combo.\nRight click blocks. Block just before a hit lands to PARRY.\nSpace dodges.",
	},
	"materials": {
		"title": "Monster drops",
		"text": "Monsters drop materials like pelts, tusks and bones. They go straight into your bag.\nPress Tab to see what you have.",
	},
	"shard": {
		"title": "You got a shard!",
		"text": "Bosses drop shards. Bring it to the Telecom in camp and press E.\nEarth trades it for a weapon blueprint.",
	},
	"blueprint": {
		"title": "Blueprint unlocked",
		"text": "Go to the Crafting Station in camp.\nBlueprint + the right materials = a new weapon.\nShort on materials? Fight more monsters.",
	},
	"weapon": {
		"title": "Two hands",
		"text": "You hold two weapons. Press 1 or 2 to pick one, or Q to flip between them.\nSwapping has a short cooldown. Tab lets you choose what goes in each hand.",
	},
	"ultimate": {
		"title": "Ultimates",
		"text": "Elemental weapons have an ultimate.\nHold R to aim, let go to cast.\nThe bar under your weapon fills up when it's ready again.",
	},
	"combo": {
		"title": "Combos",
		"text": "Some ultimates react with each other. Learn how in a Weapon Proficiency trial.\nA notification shows up in camp when you're ready for one.",
		"guide_only": true,
	},
}

var _queue: Array = []
var _card: Control = null
var _left: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func seen(id: String) -> bool:
	GameState.ensure_loaded()
	return GameState.tips_seen.has(id)


## which tips have just become relevant (called a couple of times a second)
func check() -> void:
	var tree := get_tree()
	var cs := tree.current_scene
	if cs == null or tree.get_first_node_in_group("player") == null and cs.scene_file_path != MAP:
		return
	var path: String = cs.scene_file_path
	var want := {
		"camp": path == CAMP,
		"road_map": path == MAP,
		"fight": FIGHT_MAPS.any(func(m): return path.contains("/" + m + "/")),
		"materials": not GameState.items_of_type("material").is_empty(),
		"shard": not GameState.items_of_type("shard").is_empty(),
		"blueprint": not GameState.blueprints.is_empty(),
		"weapon": GameState.weapons.size() >= 2,
		"ultimate": GameState.weapons.any(func(w): return GameState.WEAPONS[w].get("effect", "none") != "none"),
	}
	for id in ORDER:
		if want.get(id, false) and not seen(id) and not _queue.has(id):
			_queue.append(id)
	if _card == null and not _queue.is_empty():
		_show(_queue.pop_front())


func _process(delta: float) -> void:
	if _card:
		_left -= delta
		if _left <= 0.0:
			_dismiss()


func _show(id: String) -> void:
	var tip: Dictionary = TIPS[id]
	GameState.tips_seen.append(id)
	GameState.save()
	var p := UI.panel(UI.GOLD, 340.0)
	p.position = Vector2(20, 190)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(UI.label("TIP", 13, UI.DIM))
	head.add_child(UI.spacer())
	head.add_child(UI.label("Esc > How to play", 11, UI.DIM))
	v.add_child(head)
	v.add_child(UI.label(tip.title, 20, UI.GOLD))
	var body := UI.label(tip.text, 14)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.custom_minimum_size.x = 300
	v.add_child(body)
	var ok := UI.button("Got it", true, UI.GOLD, 14)
	ok.pressed.connect(_dismiss)
	var row := HBoxContainer.new()
	row.add_child(UI.spacer())
	row.add_child(ok)
	v.add_child(row)
	_card = p
	_left = STAY
	# slide in from the left
	p.position.x = -380
	p.create_tween().tween_property(p, "position:x", 20.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _dismiss() -> void:
	if _card == null:
		return
	var c := _card
	_card = null
	var tw := c.create_tween()
	tw.tween_property(c, "position:x", -380.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(c.queue_free)


## the HOW TO PLAY page (built into a VBox the pause menu gives us)
static func build_guide(v: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for id in ORDER:
		var tip: Dictionary = TIPS[id]
		var card := UI.card()
		var cv := VBoxContainer.new()
		card.add_child(cv)
		cv.add_child(UI.label(tip.title, 17, UI.GOLD))
		var body := UI.label(tip.text, 14)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD
		body.custom_minimum_size.x = 640
		cv.add_child(body)
		list.add_child(card)
