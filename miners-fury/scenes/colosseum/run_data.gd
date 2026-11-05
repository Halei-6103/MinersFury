extends RefCounted
## Everything the Colosseum run can give you. Names and text only; what each one
## actually does lives where it happens (player.gd, burn/poison status, the ults).
##   const RunData = preload("res://scenes/colosseum/run_data.gd")
##
## Elements: "fire", "storm", "venom". A weapon's element comes from its "effect"
## in GameState.WEAPONS ("flame" counts as "fire").

const ELEMENTS := ["fire", "storm", "venom"]
const EL_NAME := {"fire": "Fire", "storm": "Storm", "venom": "Venom"}
const EL_COLOR := {
	"fire": Color(1.0, 0.55, 0.2),
	"storm": Color(0.45, 0.85, 1.0),
	"venom": Color(0.55, 1.0, 0.35),
}
## pack effect strips used as the crystal art (fire pack v1, effect pack 2, poison pack)
const EL_FX := {"fire": "brazier_fire", "storm": "chain_strike", "venom": "poison_pop"}

# ---------------------------------------------------------------- base crystals (rounds 5, 15, 25...)
## pick 1 of 2 from the element's pool. They stack.
const BASE := {
	"fire": ["fire_hot", "fire_long", "fire_tail", "charge"],
	"storm": ["storm_volt", "storm_arc", "storm_daze", "charge"],
	"venom": ["venom_potency", "venom_quick", "venom_rune", "charge"],
}
const BASE_INFO := {
	"fire_hot": {"name": "Hotter", "desc": "Burn does +1 damage each tick."},
	"fire_long": {"name": "Long Burn", "desc": "Burn lasts 1.5s longer."},
	"fire_tail": {"name": "Tailwind", "desc": "Your tornado travels 25% further."},
	"storm_volt": {"name": "Voltage", "desc": "Chain lightning does +1 damage."},
	"storm_arc": {"name": "Long Arc", "desc": "Chains jump 30 further between enemies."},
	"storm_daze": {"name": "Daze", "desc": "Your stuns last 0.4s longer."},
	"venom_potency": {"name": "Potency", "desc": "Poison ticks do +1 damage."},
	"venom_quick": {"name": "Quick Stacks", "desc": "25% chance a hit adds 2 poison stacks."},
	"venom_rune": {"name": "Lingering Rune", "desc": "Your rune lasts 1.5s longer."},
	"charge": {"name": "Charge", "desc": "Your ultimate charges 15% faster."},
}
## a base crystal in a weapon of another element (or a plain one): a chance per hit
const SPLASH := {
	"fire": {"chance": 0.20, "desc": "+20% chance your hits set enemies on fire."},
	"storm": {"chance": 0.15, "desc": "+15% chance your hits chain lightning to 1 enemy."},
	"venom": {"chance": 0.20, "desc": "+20% chance your hits add a poison stack."},
}

# ---------------------------------------------------------------- attunement crystals (rounds 10, 20, 30...)
## matching weapon: its element's pure pool. Other element: the hybrid pool.
## Plain weapons (no element) get infused instead, see PLAIN.
const PURE := {
	"fire": ["twin_tornado", "firestorm", "wildfire", "scorched_path"],
	"storm": ["forked", "double_clap", "static", "overcharge"],
	"venom": ["deep_wounds", "plague", "corrode", "big_rune"],
}
## HYBRID[weapon element][crystal element]
const HYBRID := {
	"fire": {
		"storm": ["arc_flame", "boom_tornado", "ignition", "heat_lightning"],
		"venom": ["toxic_smoke", "toxic_tornado", "fumes", "fever"],
	},
	"storm": {
		"fire": ["searing_bolts", "boom_clap", "overheat", "hot_wire"],
		"venom": ["neurotoxin", "tetro_clap", "conductive", "toxic_thunder"],
	},
	"venom": {
		"fire": ["boiling_blood", "tornado_rune", "fever_rune", "flashpoint"],
		"storm": ["shock_venom", "tetro_rune", "live_wire", "overload"],
	},
}
## a plain weapon (Iron Sword, Leather Whip): soak up the element for good, or take
## one of its upgrades that work on hits (needs the element on the weapon first)
const PLAIN := {
	"fire": ["infuse_fire", "wildfire"],
	"storm": ["infuse_storm", "forked", "static", "overcharge"],
	"venom": ["infuse_venom", "deep_wounds", "plague", "corrode"],
}
## turns your ultimate into something else. One per weapon.
const ULTS := ["boom_tornado", "toxic_tornado", "boom_clap", "tetro_clap", "tornado_rune", "tetro_rune"]
## only make sense on a weapon that has an ultimate
const NEEDS_ULT := ["twin_tornado", "firestorm", "scorched_path", "double_clap", "big_rune",
	"toxic_thunder", "fever_rune"]

const ATT := {
	# fire
	"twin_tornado": {"name": "Twin Tornado", "desc": "Your ultimate sends out two tornados in a V."},
	"firestorm": {"name": "Firestorm", "desc": "One huge, slower tornado that pulls enemies in."},
	"wildfire": {"name": "Wildfire", "desc": "When a burning enemy dies, the fire jumps to anyone nearby."},
	"scorched_path": {"name": "Scorched Path", "desc": "Your tornado leaves a burning trail on the ground."},
	# storm
	"forked": {"name": "Forked Lightning", "desc": "Chains hit 2 more enemies."},
	"double_clap": {"name": "Double Clap", "desc": "Your thunderclap hits twice, the second one wider."},
	"static": {"name": "Static", "desc": "Stunned enemies take +1 damage from your hits."},
	"overcharge": {"name": "Overcharge", "desc": "Every 5th hit calls a lightning strike from the sky."},
	# venom
	"deep_wounds": {"name": "Deep Wounds", "desc": "Poison stacks to 8 instead of 5."},
	"plague": {"name": "Plague", "desc": "When a poisoned enemy dies, the poison jumps to 2 nearby."},
	"corrode": {"name": "Corrode", "desc": "Poisoned enemies take +1 damage from your hits."},
	"big_rune": {"name": "Big Rune", "desc": "Your rune is 40% wider and lasts 2s longer."},
	# fire weapon + storm
	"arc_flame": {"name": "Arc Flame", "desc": "Burn hops to 2 nearby enemies."},
	"boom_tornado": {"name": "Exploding Tornado", "desc": "ULTIMATE: your tornado blows up at the end."},
	"ignition": {"name": "Ignition", "desc": "Lightning hitting a burning enemy makes a small explosion."},
	"heat_lightning": {"name": "Heat Lightning", "desc": "Burning enemies get struck by lightning when their burn runs out."},
	# fire weapon + venom
	"toxic_smoke": {"name": "Toxic Smoke", "desc": "Burning enemies also get poisoned."},
	"toxic_tornado": {"name": "Toxic Tornado", "desc": "ULTIMATE: your tornado is toxic from the start."},
	"fumes": {"name": "Fumes", "desc": "Burning enemies leave a poison cloud when they die."},
	"fever": {"name": "Fever", "desc": "Poisoned enemies burn twice as long."},
	# storm weapon + fire
	"searing_bolts": {"name": "Searing Bolts", "desc": "Chain lightning sets enemies on fire."},
	"boom_clap": {"name": "Exploding Tornado", "desc": "ULTIMATE: your thunderclap drops a fire tornado that blows up."},
	"overheat": {"name": "Overheat", "desc": "Enemies you stun catch fire."},
	"hot_wire": {"name": "Hot Wire", "desc": "Chains jump further between burning enemies."},
	# storm weapon + venom
	"neurotoxin": {"name": "Neurotoxin", "desc": "Each chain hit adds a poison stack."},
	"tetro_clap": {"name": "Tetrodotoxin", "desc": "ULTIMATE: your thunderclap leaves the paralysis combo behind."},
	"conductive": {"name": "Conductive", "desc": "Poisoned enemies take +1 lightning damage."},
	"toxic_thunder": {"name": "Toxic Thunder", "desc": "Your thunderclap leaves a poison rune."},
	# venom weapon + fire
	"boiling_blood": {"name": "Boiling Blood", "desc": "Reaching full stacks makes them burst into flame."},
	"tornado_rune": {"name": "Toxic Tornado", "desc": "ULTIMATE: your rune spits out a toxic tornado."},
	"fever_rune": {"name": "Fever Rune", "desc": "Your rune burns as well as poisons."},
	"flashpoint": {"name": "Flashpoint", "desc": "When poison jumps, it sets the new targets on fire too."},
	# venom weapon + storm
	"shock_venom": {"name": "Shock Venom", "desc": "Reaching full stacks gives a quick stun."},
	"tetro_rune": {"name": "Tetrodotoxin", "desc": "ULTIMATE: your rune becomes the paralysis combo."},
	"live_wire": {"name": "Live Wire", "desc": "Poison jumps travel as lightning and zap what they hit."},
	"overload": {"name": "Overload", "desc": "Stunned enemies take poison twice as fast."},
	# plain weapons
	"infuse_fire": {"name": "Fire Infusion", "desc": "This weapon sets enemies on fire, like a Flame weapon (no ultimate)."},
	"infuse_storm": {"name": "Storm Infusion", "desc": "This weapon chains lightning, like a Storm weapon (no ultimate)."},
	"infuse_venom": {"name": "Venom Infusion", "desc": "This weapon stacks poison, like a Venom weapon (no ultimate)."},
}

# ---------------------------------------------------------------- material drops (every 3 rounds)
## a material you've found on the maps drops in the arena; walk over it. "max" =
## stops dropping after that many. Collect 25 of it over all your play: 1.5x as strong.
const BOONS := {
	"wolf_pelt": {"name": "Wolf Pelt", "desc": "+8% move speed", "max": 6},
	"orc_tusk": {"name": "Orc Tusk", "desc": "+0.5 damage on every hit", "max": 8},
	"bat_wing": {"name": "Bat Wing", "desc": "+8 reach (up to double)", "max": 99},
	"hellbat_wing": {"name": "Hellbat Wing", "desc": "Dashes recharge 12% faster", "max": 5},
	"slime_goo": {"name": "Slime Goo", "desc": "Heal 1 (saved for later if you're full)", "max": 99},
	"bone": {"name": "Bone", "desc": "Bigger parry window", "max": 4},
	"lava_goo": {"name": "Lava Goo", "desc": "Enemies that hit you catch fire", "max": 5},
	"charred_skull": {"name": "Charred Skull", "desc": "Parries fire a homing skull", "max": 3},
}
const TIER_AT := 25
const TIER_MULT := 1.5


static func weapon_element(w: String) -> String:
	var eff := String(load("res://scenes/core/game_state.gd").WEAPONS.get(w, {}).get("effect", "none"))
	return "fire" if eff == "flame" else (eff if eff in ["storm", "venom"] else "")


static func att_name(id: String) -> String:
	return String(ATT.get(id, BASE_INFO.get(id, {"name": id})).name)


static func att_desc(id: String) -> String:
	return String(ATT.get(id, BASE_INFO.get(id, {"desc": ""})).desc)
