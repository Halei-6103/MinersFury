extends RefCounted
## One Colosseum run, for YOU (each player in co-op has their own). Wiped when a
## run starts; nothing here is saved. Only does anything while `active`.
##   const RunState = preload("res://scenes/colosseum/run_state.gd")
##   RunState.now("wildfire")   # does the weapon in your hand have it?

const RunData = preload("res://scenes/colosseum/run_data.gd")
const GameState = preload("res://scenes/core/game_state.gd")

static var active: bool = false
## the weapon in your hand right now (player.set_weapon keeps it up to date)
static var cur: String = ""
## per weapon: {"att": [ids], "base": {id: n}, "splash": {el: n}, "ult": id, "infused": el}
static var mods: Dictionary = {}
static var rerolls: int = 0
## material drops picked up: {material: n}
static var boons: Dictionary = {}
## Slime Goo heals saved for when you get hurt
static var saved_heal: int = 0
## live numbers for the Tab page and the death card
static var stats: Dictionary = {}
## Overcharge: hits since the last strike
static var hit_count: int = 0


static func reset() -> void:
	active = true
	mods = {}
	rerolls = 0
	boons = {}
	saved_heal = 0
	hit_count = 0
	stats = {"dmg_weapon": {}, "dmg_source": {}, "hurt_by": {}, "hits_taken": 0,
		"parries": 0, "dodges": 0, "kills": 0}


static func m(w: String) -> Dictionary:
	if not mods.has(w):
		mods[w] = {"att": [], "base": {}, "splash": {}, "ult": "", "infused": ""}
	return mods[w]


## the weapon's element for this run (a plain weapon can be infused)
static func element(w: String) -> String:
	var el := RunData.weapon_element(w)
	if el == "" and active:
		el = String(m(w).infused)
	return el


## does the weapon in your hand have this attunement?
static func now(id: String) -> bool:
	return active and cur != "" and id in m(cur).att


static func base_n(id: String) -> int:
	if not active or cur == "":
		return 0
	return int(m(cur).base.get(id, 0))


static func splash_chance(el: String) -> float:
	if not active or cur == "":
		return 0.0
	return int(m(cur).splash.get(el, 0)) * float(RunData.SPLASH[el].chance)


static func ult_mode() -> String:
	if not active or cur == "":
		return ""
	return String(m(cur).ult)


## material drop stacks, 1.5x once you've collected 25 of it over all your play
static func boon(id: String) -> float:
	if not active:
		return 0.0
	var n := float(boons.get(id, 0))
	if n > 0.0 and int(GameState.lifetime.get(id, 0)) >= RunData.TIER_AT:
		n *= RunData.TIER_MULT
	return n


static func add_boon(id: String) -> void:
	boons[id] = int(boons.get(id, 0)) + 1


# ---------------------------------------------------------------- stats

static func add_dmg(source: String, n: int) -> void:
	if not active or n <= 0:
		return
	var w := cur if cur != "" else "?"
	stats.dmg_weapon[w] = int(stats.dmg_weapon.get(w, 0)) + n
	stats.dmg_source[source] = int(stats.dmg_source.get(source, 0)) + n


static func add_hurt(by: String, n: int) -> void:
	if not active:
		return
	stats.hits_taken = int(stats.hits_taken) + 1
	stats.hurt_by[by] = int(stats.hurt_by.get(by, 0)) + n


static func bump(key: String) -> void:
	if active:
		stats[key] = int(stats.get(key, 0)) + 1


## biggest entry of a {name: n} dictionary -> [name, n]
static func top(d: Dictionary) -> Array:
	var best := ["", 0]
	for k in d:
		if int(d[k]) > int(best[1]):
			best = [k, int(d[k])]
	return best


# ---------------------------------------------------------------- crystal rolls

## the attunements this crystal could give a weapon (minus what it already has)
static func pool_for(w: String, el: String) -> Array:
	var wel := element(w)
	var has_ult := float(_ult_cd_total(w)) > 0.0
	var mm := m(w)
	var out: Array = []
	var src: Array
	if wel == "":
		src = RunData.PLAIN[el]
	elif wel == el:
		src = RunData.PURE[el]
	else:
		src = RunData.HYBRID[wel][el]
	for id in src:
		if id in mm.att:
			continue
		if id in RunData.ULTS and (mm.ult != "" or not has_ult):
			continue
		if id in RunData.NEEDS_ULT and not has_ult:
			continue
		# a plain weapon's hit upgrades only work once it has the element
		if wel == "" and not String(id).begins_with("infuse_") and mm.infused != el:
			continue
		if String(id).begins_with("infuse_") and mm.infused != "":
			continue
		out.append(id)
	return out


static func roll_two(pool: Array) -> Array:
	var p := pool.duplicate()
	p.shuffle()
	return p.slice(0, 2)


static func _ult_cd_total(w: String) -> int:
	return 1 if String(GameState.WEAPONS.get(w, {}).get("effect", "none")) in ["storm", "venom", "flame"] else 0


## take an attunement into a weapon
static func take(w: String, id: String) -> void:
	var mm := m(w)
	if String(id).begins_with("infuse_"):
		mm.infused = String(id).trim_prefix("infuse_")
	mm.att.append(id)
	if id in RunData.ULTS:
		mm.ult = id


## take a base crystal: matching element = the stat, otherwise the splash
static func take_base(w: String, el: String, id: String) -> void:
	var mm := m(w)
	if element(w) == el:
		mm.base[id] = int(mm.base.get(id, 0)) + 1
	else:
		mm.splash[el] = int(mm.splash.get(el, 0)) + 1
