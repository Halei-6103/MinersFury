extends RefCounted
## Everything you own, kept between maps and saved to disk.
## Use from anywhere:
##   const GameState = preload("res://scenes/core/game_state.gd")
##   GameState.add_item("storm_crystal")
##   GameState.count("storm_crystal")
##   GameState.equipped            -> "iron_sword" / "storm_blade"
## Saves to user://save.json (on Windows: %APPDATA%/Godot/app_userdata/<project>/).

const SAVE_PATH := "user://save.json"

## loot you can carry
const ITEMS := {
	"storm_crystal": {
		"name": "Storm Crystal",
		"desc": "Hums with trapped lightning. Earth wants these.",
		"icon": "res://assets/sprites/items/storm_crystal.png",
		"frames": 6, "color": Color(0.45, 0.8, 1.0),
	},
}

## blueprints Earth can send down
const BLUEPRINTS := {
	"storm_blade": {
		"name": "Storm Blade Blueprint",
		"desc": "Schematic for an electric sword.",
		"icon": "res://assets/sprites/items/blueprint.png",
		"frames": 12, "color": Color(0.55, 0.75, 1.0),
	},
}

## weapons. "recipe" = what the telecom needs to fabricate it
const WEAPONS := {
	"iron_sword": {
		"name": "Iron Sword",
		"desc": "Old faithful. Gets the job done.",
	},
	"storm_blade": {
		"name": "Storm Blade",
		"desc": "Hits chain lightning to nearby enemies.\nCombo finisher sets off a thunderclap that stuns.",
		"recipe": {"blueprint": "storm_blade", "items": {"storm_crystal": 1}},
	},
}

static var inventory: Dictionary = {}
static var blueprints: Array = []
static var weapons: Array = ["iron_sword"]
static var equipped: String = "iron_sword"
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	inventory = {}
	var inv = data.get("inventory", {})
	if typeof(inv) == TYPE_DICTIONARY:
		for k in inv:
			inventory[k] = int(inv[k])
	blueprints = Array(data.get("blueprints", []))
	weapons = Array(data.get("weapons", ["iron_sword"]))
	if not weapons.has("iron_sword"):
		weapons.push_front("iron_sword")
	equipped = str(data.get("equipped", "iron_sword"))
	if not weapons.has(equipped):
		equipped = "iron_sword"


static func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"inventory": inventory,
		"blueprints": blueprints,
		"weapons": weapons,
		"equipped": equipped,
	}, "\t"))


## wipe everything (handy while testing)
static func reset() -> void:
	inventory = {}
	blueprints = []
	weapons = ["iron_sword"]
	equipped = "iron_sword"
	_loaded = true
	save()


static func count(id: String) -> int:
	ensure_loaded()
	return int(inventory.get(id, 0))


static func add_item(id: String, n: int = 1) -> void:
	ensure_loaded()
	inventory[id] = count(id) + n
	save()


static func remove_item(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	inventory[id] = count(id) - n
	if inventory[id] <= 0:
		inventory.erase(id)
	save()
	return true


static func has_blueprint(id: String) -> bool:
	ensure_loaded()
	return blueprints.has(id)


static func add_blueprint(id: String) -> void:
	ensure_loaded()
	if not blueprints.has(id):
		blueprints.append(id)
	save()


static func owns(weapon: String) -> bool:
	ensure_loaded()
	return weapons.has(weapon)


## true once you'd never need this blueprint again (have it, or already built the weapon)
static func knows(blueprint: String) -> bool:
	return has_blueprint(blueprint) or owns(blueprint)


static func can_fabricate(weapon: String) -> bool:
	if owns(weapon):
		return false
	var r: Dictionary = WEAPONS[weapon].get("recipe", {})
	if r.is_empty():
		return false
	if r.has("blueprint") and not has_blueprint(r.blueprint):
		return false
	for id in r.get("items", {}):
		if count(id) < int(r.items[id]):
			return false
	return true


static func fabricate(weapon: String) -> bool:
	if not can_fabricate(weapon):
		return false
	var r: Dictionary = WEAPONS[weapon].recipe
	for id in r.get("items", {}):
		inventory[id] = count(id) - int(r.items[id])
		if inventory[id] <= 0:
			inventory.erase(id)
	weapons.append(weapon)
	save()
	return true


static func equip(weapon: String) -> void:
	ensure_loaded()
	if weapons.has(weapon):
		equipped = weapon
		save()


## display name for any id (item, blueprint or weapon)
static func display_name(id: String) -> String:
	if ITEMS.has(id):
		return ITEMS[id].name
	if BLUEPRINTS.has(id):
		return BLUEPRINTS[id].name
	if WEAPONS.has(id):
		return WEAPONS[id].name
	return id
