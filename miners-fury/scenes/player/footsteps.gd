extends Node
## Footstep sounds for a player (you and teammates). Plays a step every
## STRIDE pixels walked, picking the sound from what's under their feet.
##
## Sounds (Kenney "Impact Sounds", CC0) live in res://assets/audio/sfx/footsteps/ as
##   step_grass_1.ogg ... step_grass_5.ogg
##   step_dirt_N, step_stone_N, step_sand_N
## (any number up to 8 each; a random one plays every step).
##
## The surface comes from the map's ground tile layers: the top-most layer
## with a tile under the feet wins, and SURFACES says what that layer is.

const Sfx = preload("res://scenes/audio/sfx.gd")

const STRIDE := 48.0
const VOLUME := -10.0
const VOLUME_TEAMMATE := -16.0
## evens out the surfaces (the grass steps are quieter than the rest)
const SURFACE_DB := {"grass": 4.0, "stone": -1.0, "dirt": -2.0, "sand": 0.0}

## tile sheet file -> surface, with per-layer exceptions ("sheet:Layer")
const SURFACES := {
	"garden_tiles.png:Paths": "stone",
	"garden_tiles.png": "grass",
	"floors_tiles.png": "dirt",
	"fairy_forest_tiles.png:Dirt": "dirt",
	"fairy_forest_tiles.png": "grass",
	"cemetery_floor.png": "grass",
	"forge_tiles.png": "stone",
	"Ground.png:Walls": "stone",
	"Ground.png": "sand",
	"Sand.png": "sand",
	"water_tiles.png": "sand",
}

var _p: Node2D
var _last: Vector2
var _walked: float = 0.0


func _ready() -> void:
	_p = get_parent()
	_last = _p.global_position


func _physics_process(_delta: float) -> void:
	if _p == null or not _p.is_inside_tree():
		return
	var pos := _p.global_position
	var moved := pos.distance_to(_last)
	_last = pos
	# big jumps are teleports (scene changes, co-op snaps), not walking
	if moved > 60.0:
		return
	var st = _p.get("state")
	# only while walking: not while rolling, dead, or being knocked about
	if st != null and st != _p.State.MOVE:
		_walked = 0.0
		return
	_walked += moved
	if _walked >= STRIDE:
		_walked = 0.0
		var surf := surface_at(pos)
		var vol: float = (VOLUME_TEAMMATE if _p.get("puppet") else VOLUME) + SURFACE_DB.get(surf, 0.0)
		Sfx.play(_p, "step_" + surf, pos, vol, 0.1)


## what the ground is at a world position
func surface_at(pos: Vector2) -> String:
	var cs := get_tree().current_scene
	if cs == null:
		return "grass"
	var ground := cs.get_node_or_null("Ground")
	if ground == null:
		return "grass"
	var layers := ground.get_children()
	layers.reverse()   # last child draws on top
	for l in layers:
		if not (l is TileMapLayer) or not l.visible or l.tile_set == null:
			continue
		var cell: Vector2i = l.local_to_map(l.to_local(pos))
		var sid: int = l.get_cell_source_id(cell)
		if sid == -1:
			continue
		var src = l.tile_set.get_source(sid)
		var sheet := ""
		if src is TileSetAtlasSource and src.texture:
			sheet = src.texture.resource_path.get_file()
		var key := sheet + ":" + String(l.name)
		if SURFACES.has(key):
			return SURFACES[key]
		if SURFACES.has(sheet):
			return SURFACES[sheet]
	return "grass"
