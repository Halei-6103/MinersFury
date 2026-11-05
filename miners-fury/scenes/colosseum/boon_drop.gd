extends Node2D
## Colosseum material boons. Every 3 rounds you pick 1 of 3 (boon_picker.gd);
## this file holds the rules (what can be offered, what giving one does) and a
## walk-over pickup version if a drop on the floor is ever wanted again.
##   BoonDrop.spawn(level, at, "wolf_pelt")

const GameState = preload("res://scenes/core/game_state.gd")
const RunState = preload("res://scenes/colosseum/run_state.gd")
const RunData = preload("res://scenes/colosseum/run_data.gd")
const Juice = preload("res://scenes/effects/juice.gd")
const Sfx = preload("res://scenes/audio/sfx.gd")

const PICK_R := 34.0

var id: String = ""
var _t: float = 0.0
var _icon: TextureRect
var _taken: bool = false


static func spawn(level: Node, at: Vector2, mat: String) -> Node2D:
	var d = load("res://scenes/colosseum/boon_drop.gd").new()
	d.id = mat
	level.add_child(d)
	d.global_position = at
	return d


## materials that can be offered: found on the maps, not maxed out yet
static func eligible() -> Array:
	var opts: Array = []
	for mat in RunData.BOONS:
		if not GameState.found(mat):
			continue
		if int(RunState.boons.get(mat, 0)) >= int(RunData.BOONS[mat].max):
			continue
		if mat == "bat_wing" and _reach_maxed():
			continue
		opts.append(mat)
	return opts


## up to n different materials to choose from
static func choices(n: int = 3) -> Array:
	var opts := eligible()
	opts.shuffle()
	return opts.slice(0, n)


## give a material's boon to the player (the pick screen calls this)
static func give(p: Node, id: String) -> void:
	RunState.add_boon(id)
	if id == "slime_goo" and p:
		if p.health < p.max_health:
			p.heal(1)
		else:
			RunState.saved_heal += 1
	if p and p.has_method("apply_run"):
		p.apply_run()


static func _reach_maxed() -> bool:
	var most := 0.0
	for w in GameState.slots:
		if w != "":
			most = maxf(most, float(GameState.WEAPONS.get(w, {}).get("reach", 44.0)))
	return 8.0 * RunState.boon("bat_wing") >= most


func _ready() -> void:
	z_index = 3
	var info: Dictionary = GameState.ITEMS.get(id, {})
	var tex: Texture2D = load(info.get("icon", "res://icon.svg"))
	var frames := int(info.get("frames", 1))
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(0, 0, tex.get_width() / frames, tex.get_height())
	var spr := Sprite2D.new()
	spr.name = "Icon"
	spr.texture = a
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(2, 2)
	spr.position = Vector2(0, -26)
	add_child(spr)
	Juice.shockwave(self, global_position, 14.0)


func _process(delta: float) -> void:
	_t += delta
	var spr = get_node_or_null("Icon")
	if spr:
		spr.position.y = -26.0 + sin(_t * 3.0) * 4.0
	if _taken:
		return
	var p = get_tree().get_first_node_in_group("player")
	if p and p.state != p.State.DEAD:
		var off: Vector2 = p.global_position - global_position
		if Vector2(off.x, off.y * 2.0).length() < PICK_R:
			_take(p)
	queue_redraw()


func _take(p: Node) -> void:
	_taken = true
	give(p, id)
	var info: Dictionary = RunData.BOONS[id]
	var tier := int(GameState.lifetime.get(id, 0)) >= RunData.TIER_AT
	Juice.damage_number(get_parent(), global_position + Vector2(0, -70), "%s: %s%s" % [info.name, info.desc, "  (x1.5)" if tier else ""], GameState.ITEMS[id].color, 18)
	Sfx.play(self, "hit", global_position, -8.0, 0.05, 1.6)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.12)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


## a soft glow under it so it reads as a pickup
func _draw() -> void:
	var k := 0.6 + 0.4 * sin(_t * 4.0)
	var c: Color = GameState.ITEMS.get(id, {}).get("color", Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 22.0, Color(c.r, c.g, c.b, 0.18 * k))
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 28, Color(c.r, c.g, c.b, 0.6 * k), 2.0)
	draw_set_transform(Vector2.ZERO)
