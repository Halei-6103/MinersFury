extends RefCounted
## Everything you own, kept between maps and saved to disk.
## Use from anywhere:
##   const GameState = preload("res://scenes/core/game_state.gd")
##   GameState.add_item("bone", 2)
##   GameState.count("storm_crystal")
##   GameState.equipped()           -> weapon in your active hand
## Saves to user://save.json (on Windows: %APPDATA%/Godot/app_userdata/Miners Fury/).
##
## The loop:
##   bosses drop SHARDS  -> telecom sends them to Earth -> BLUEPRINT comes back
##   mobs drop MATERIALS -> crafting station + blueprint -> WEAPON
##   two weapon slots, Q swaps

const SAVE_PATH := "user://save.json"
const ICONS := "res://assets/sprites/items/"

## everything you can carry. type: "shard" (boss drop) or "material" (mob drop)
const ITEMS := {
	"storm_crystal": {
		"name": "Storm Shard", "type": "shard",
		"desc": "Torn from the Werebear. Crackles with trapped lightning.",
		"icon": ICONS + "storm_crystal.png", "frames": 6, "color": Color(0.3, 0.95, 1.0),
	},
	"tomb_crystal": {
		"name": "Tomb Shard", "type": "shard",
		"desc": "The Necromancer's heart. Cold, green, and humming with rot.",
		"icon": ICONS + "tomb_crystal.png", "frames": 6, "color": Color(0.55, 1.0, 0.35),
	},
	"wolf_pelt": {
		"name": "Wolf Pelt", "type": "material", "desc": "Thick, coarse fur from a werewolf.",
		"icon": ICONS + "wolf_pelt.png", "frames": 1, "color": Color(0.75, 0.6, 0.45),
	},
	"orc_tusk": {
		"name": "Orc Tusk", "type": "material", "desc": "Yellowed and sharp. Makes a good grip.",
		"icon": ICONS + "orc_tusk.png", "frames": 1, "color": Color(0.95, 0.9, 0.7),
	},
	"bat_wing": {
		"name": "Bat Wing", "type": "material", "desc": "Leathery. Light as paper.",
		"icon": ICONS + "bat_wing.png", "frames": 1, "color": Color(0.7, 0.55, 0.85),
	},
	"slime_goo": {
		"name": "Slime Goo", "type": "material", "desc": "Sticky, a little toxic. Don't lick it.",
		"icon": ICONS + "slime_goo.png", "frames": 1, "color": Color(0.5, 0.9, 0.35),
	},
	"bone": {
		"name": "Bone", "type": "material", "desc": "Old skeleton bone. Surprisingly sturdy.",
		"icon": ICONS + "bone.png", "frames": 1, "color": Color(0.95, 0.92, 0.82),
	},
}

## blueprints Earth sends down. "shard" = what you have to send up for it
const BLUEPRINTS := {
	"storm_blade": {
		"name": "Storm Blade Blueprint", "shard": "storm_crystal",
		"icon": ICONS + "blueprint.png", "frames": 12, "color": Color(0.55, 0.85, 1.0),
	},
	"venom_blade": {
		"name": "Venom Blade Blueprint", "shard": "tomb_crystal",
		"icon": ICONS + "blueprint_venom.png", "frames": 12, "color": Color(0.6, 1.0, 0.45),
	},
}

## weapons. "effect" is what the player does on hit. "recipe" = crafting cost
const WEAPONS := {
	"iron_sword": {
		"name": "Iron Sword", "effect": "none",
		"desc": "Old faithful. Gets the job done.",
		"swing_fx": "res://assets/sprites/player/swing_fx_frames.tres",
		"body": "res://assets/sprites/player/swordsman_frames.tres",
		"color": Color(0.85, 0.85, 0.9),
	},
	"storm_blade": {
		"name": "Storm Blade", "effect": "storm",
		"desc": "Hits chain lightning to 2 nearby enemies.\nR (ultimate): call down a thunderclap that stuns.",
		"swing_fx": "res://assets/sprites/player/storm_fx_frames.tres",
		"body": "res://assets/sprites/player/storm_swordsman_frames.tres",
		"color": Color(0.3, 0.95, 1.0),
		"recipe": {"blueprint": "storm_blade", "items": {"wolf_pelt": 3, "orc_tusk": 2}},
	},
	"venom_blade": {
		"name": "Venom Blade", "effect": "venom",
		"desc": "Hits stack poison (up to 5). At 5 it jumps to the 2 closest enemies.\nR (ultimate): poison rune for 5s. Stacks keep growing, poison hurts double.",
		"swing_fx": "res://assets/sprites/player/venom_fx_frames.tres",
		"body": "res://assets/sprites/player/venom_swordsman_frames.tres",
		"color": Color(0.55, 1.0, 0.35),
		"recipe": {"blueprint": "venom_blade", "items": {"bone": 5, "slime_goo": 3, "bat_wing": 2}},
	},
}

## maps on the road map, in order. Each one unlocks after the one before it is cleared.
const MAPS := [
	{"id": "forest", "name": "Mossback Woods", "scene": "res://scenes/levels/forest/forest.tscn", "boss": "Werebear"},
	{"id": "wasteland", "name": "Bone Wastes", "scene": "res://scenes/levels/wasteland/wasteland.tscn", "boss": "Necromancer"},
	{"id": "colosseum", "name": "The Colosseum", "scene": "res://scenes/levels/colosseum/colosseum.tscn", "boss": "Everything", "endless": true},
]

static var inventory: Dictionary = {}
static var blueprints: Array = []
static var weapons: Array = ["iron_sword"]
## two hands: Q swaps between them. "" = empty slot
static var slots: Array = ["iron_sword", ""]
static var active_slot: int = 0
static var cleared: Array = []
static var settings: Dictionary = {"music": 0.6, "sfx": 0.8, "fullscreen": false}
## Colosseum records: highest round reached and most kills in one run
## weapon proficiencies you've earned (e.g. "tetrodotoxin" = Venom rune + Storm clap combo)
static var masteries: Array = []
## tutorial tips you've already seen (scenes/ui/tips.gd)
static var tips_seen: Array = []
static var best_round: int = 0
static var best_kills: int = 0
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
			if ITEMS.has(k):
				inventory[k] = int(inv[k])
	blueprints = Array(data.get("blueprints", [])).filter(func(b): return BLUEPRINTS.has(b))
	weapons = Array(data.get("weapons", ["iron_sword"])).filter(func(w): return WEAPONS.has(w))
	if not weapons.has("iron_sword"):
		weapons.push_front("iron_sword")
	var s = data.get("slots", null)
	if typeof(s) == TYPE_ARRAY and s.size() == 2:
		slots = [str(s[0]), str(s[1])]
	else:
		# older saves had one "equipped" weapon
		slots = [str(data.get("equipped", "iron_sword")), ""]
	for i in 2:
		if slots[i] != "" and not weapons.has(slots[i]):
			slots[i] = ""
	if slots[0] == "" and slots[1] == "":
		slots[0] = "iron_sword"
	active_slot = clampi(int(data.get("active_slot", 0)), 0, 1)
	if slots[active_slot] == "":
		active_slot = 1 - active_slot
	cleared = Array(data.get("cleared", []))
	masteries = Array(data.get("masteries", []))
	tips_seen = Array(data.get("tips_seen", []))
	best_round = int(data.get("best_round", 0))
	best_kills = int(data.get("best_kills", 0))
	var st = data.get("settings", {})
	if typeof(st) == TYPE_DICTIONARY:
		for k in st:
			if not settings.has(k):
				continue
			if typeof(settings[k]) == TYPE_BOOL:
				settings[k] = bool(st[k])
			else:
				settings[k] = float(st[k])


static func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"inventory": inventory,
		"blueprints": blueprints,
		"weapons": weapons,
		"slots": slots,
		"active_slot": active_slot,
		"cleared": cleared,
		"masteries": masteries,
		"tips_seen": tips_seen,
		"best_round": best_round,
		"best_kills": best_kills,
		"settings": settings,
	}, "\t"))


## wipe the run (keeps your volume settings)
static func reset() -> void:
	inventory = {}
	blueprints = []
	weapons = ["iron_sword"]
	slots = ["iron_sword", ""]
	active_slot = 0
	cleared = []
	best_round = 0
	best_kills = 0
	masteries = []
	tips_seen = []
	_loaded = true
	save()


# ---------------------------------------------------------------- items

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


static func items_of_type(type: String) -> Array:
	ensure_loaded()
	var out: Array = []
	for id in ITEMS:
		if ITEMS[id].type == type and count(id) > 0:
			out.append(id)
	return out


# ---------------------------------------------------------------- blueprints (telecom)

static func has_blueprint(id: String) -> bool:
	ensure_loaded()
	return blueprints.has(id)


## blueprint you could ask Earth for right now (have the shard, don't have it yet)
static func can_uplink(bp: String) -> bool:
	return not has_blueprint(bp) and count(BLUEPRINTS[bp].shard) > 0


static func uplink(bp: String) -> bool:
	if not can_uplink(bp):
		return false
	remove_item(BLUEPRINTS[bp].shard)
	blueprints.append(bp)
	save()
	return true


# ---------------------------------------------------------------- weapons (crafting)

static func owns(weapon: String) -> bool:
	ensure_loaded()
	return weapons.has(weapon)


static func can_craft(weapon: String) -> bool:
	if owns(weapon):
		return false
	var r: Dictionary = WEAPONS[weapon].get("recipe", {})
	if r.is_empty() or not has_blueprint(r.blueprint):
		return false
	for id in r.get("items", {}):
		if count(id) < int(r.items[id]):
			return false
	return true


static func craft(weapon: String) -> bool:
	if not can_craft(weapon):
		return false
	var r: Dictionary = WEAPONS[weapon].recipe
	for id in r.get("items", {}):
		inventory[id] = count(id) - int(r.items[id])
		if inventory[id] <= 0:
			inventory.erase(id)
	weapons.append(weapon)
	# drop it straight into an empty hand
	if slots.has(""):
		slots[slots.find("")] = weapon
	save()
	return true


static func equipped() -> String:
	ensure_loaded()
	var w: String = slots[active_slot]
	return w if w != "" else "iron_sword"


## put a weapon in a hand (swaps hands if it's already in the other one)
static func set_slot(i: int, weapon: String) -> void:
	ensure_loaded()
	if weapon != "" and not owns(weapon):
		return
	var other := 1 - i
	if weapon != "" and slots[other] == weapon:
		slots[other] = slots[i]
	slots[i] = weapon
	if slots[0] == "" and slots[1] == "":
		slots[0] = "iron_sword"
	if slots[active_slot] == "":
		active_slot = 1 - active_slot
	save()


## Q: switch hands. Returns the new weapon, or "" if the other hand is empty.
static func swap() -> String:
	ensure_loaded()
	var other := 1 - active_slot
	if slots[other] == "":
		return ""
	active_slot = other
	save()
	return slots[active_slot]


# ---------------------------------------------------------------- maps

static func is_cleared(map_id: String) -> bool:
	ensure_loaded()
	return cleared.has(map_id)


static func mark_cleared(map_id: String) -> void:
	ensure_loaded()
	if not cleared.has(map_id):
		cleared.append(map_id)
	save()


static func is_unlocked(map_id: String) -> bool:
	for i in MAPS.size():
		if MAPS[i].id == map_id:
			return i == 0 or is_cleared(MAPS[i - 1].id)
	return false


# ---------------------------------------------------------------- proficiency

static func has_mastery(id: String) -> bool:
	ensure_loaded()
	return masteries.has(id)


static func add_mastery(id: String) -> void:
	ensure_loaded()
	if not masteries.has(id):
		masteries.append(id)
	save()


## the Tetrodotoxin trial opens up once you own both blades
static func can_try_tetrodotoxin() -> bool:
	return owns("storm_blade") and owns("venom_blade") and not has_mastery("tetrodotoxin")


## endless maps count as "done" once you've had a go
static func is_played(map_id: String) -> bool:
	if map_id == "colosseum":
		ensure_loaded()
		return best_round > 0
	return is_cleared(map_id)


## Colosseum: returns true if this run beat your best round
static func record_run(round_reached: int, kills: int) -> bool:
	ensure_loaded()
	var beat := round_reached > best_round
	best_round = maxi(best_round, round_reached)
	best_kills = maxi(best_kills, kills)
	save()
	return beat


static func display_name(id: String) -> String:
	if ITEMS.has(id):
		return ITEMS[id].name
	if BLUEPRINTS.has(id):
		return BLUEPRINTS[id].name
	if WEAPONS.has(id):
		return WEAPONS[id].name
	return id
