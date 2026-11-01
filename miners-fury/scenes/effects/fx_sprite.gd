extends AnimatedSprite2D
## One-shot sprite effects cut from the effect packs (assets/sprites/fx/).
##   const FxSprite = preload("res://scenes/effects/fx_sprite.gd")
##   FxSprite.spawn(parent, "storm_strike", global_pos)
##   FxSprite.spawn(parent, "claw_burst", pos, {"rotation": a, "flip_h": true, "scale": 1.2})
## The anchor in FX is the pixel that lands on `pos` (feet of a strike, center of a burst).
## Add new strips here: name -> [frames, fps, anchor].

const FX := {
	"storm_strike": [8, 16, Vector2(98, 388)],
	"storm_dome": [12, 18, Vector2(128, 229)],
	"chain_strike": [8, 22, Vector2(24, 122)],
	"shield_start": [20, 40, Vector2(48, 60)],
	"shield_idle": [7, 12, Vector2(48, 60)],
	"shield_hit": [12, 24, Vector2(48, 60)],
	"shield_bubble": [14, 26, Vector2(58, 58)],
	"hit_impact": [8, 30, Vector2(51, 51)],
	"hit_heavy": [6, 26, Vector2(88, 66)],
	"death_puff": [9, 16, Vector2(59, 95)],
	"claw_burst": [7, 18, Vector2(80, 100)],
	"claw_sweep": [8, 18, Vector2(60, 130)],
	# VFX Collector pack (64x64, play at scale 2)
	"poison_pop": [12, 22, Vector2(32, 36)],
	"poison_burst": [12, 18, Vector2(32, 46)],
	"poison_aura": [12, 12, Vector2(32, 58)],
	"poison_cloud": [12, 18, Vector2(32, 46)],
	# Necromancer spell effects from the character pack (100x100)
	"necro_bolt": [6, 12, Vector2(50, 60)],
	"necro_circle": [7, 10, Vector2(52, 58)],
	# Venom Blade ultimate: poison rune on the ground (top-down poison pack, 128x128)
	"venom_zone_start": [9, 18, Vector2(64, 66)],
	"venom_zone_idle": [40, 14, Vector2(64, 66)],
	"venom_zone_end": [9, 18, Vector2(64, 66)],
	# Tetrodotoxin wave head (lightning pack v10, recentered, loops while it flies)
	"lightning_wave": [6, 20, Vector2(32, 32)],
	# the same bolt with its own sweep animation (rolls down-right across its canvas)
	"lightning_wave_full": [9, 24, Vector2(32, 32)],
	# Colosseum braziers (fire pack v1, loops)
	"brazier_fire": [12, 12, Vector2(32, 62)],
}

static var _cache: Dictionary = {}


## SpriteFrames for one strip ("default" animation), built once and shared
static func frames_for(fx_name: String, loop: bool = false) -> SpriteFrames:
	var key := fx_name + ("_loop" if loop else "")
	if _cache.has(key):
		return _cache[key]
	var d: Array = FX[fx_name]
	var tex: Texture2D = load("res://assets/sprites/fx/%s.png" % fx_name)
	var n: int = d[0]
	var fw := tex.get_width() / n
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", d[1])
	sf.set_animation_loop("default", loop)
	for i in n:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * fw, 0, fw, tex.get_height())
		sf.add_frame("default", a)
	_cache[key] = sf
	return sf


## offset so the anchor pixel sits on the node's origin
static func anchor_offset(fx_name: String) -> Vector2:
	var d: Array = FX[fx_name]
	var tex: Texture2D = load("res://assets/sprites/fx/%s.png" % fx_name)
	var size := Vector2(tex.get_width() / int(d[0]), tex.get_height())
	return size * 0.5 - d[2]


## opts: rotation, flip_h, scale (float), z (int), modulate (Color), speed (float)
static func spawn(parent: Node, fx_name: String, pos: Vector2, opts: Dictionary = {}) -> AnimatedSprite2D:
	if parent == null or not FX.has(fx_name):
		return null
	var s = load("res://scenes/effects/fx_sprite.gd").new()
	s.sprite_frames = frames_for(fx_name)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.offset = anchor_offset(fx_name)
	s.flip_h = opts.get("flip_h", false)
	if s.flip_h:
		s.offset.x = -s.offset.x
	s.rotation = opts.get("rotation", 0.0)
	s.scale = Vector2.ONE * float(opts.get("scale", 1.0))
	s.z_index = opts.get("z", 30)
	s.modulate = opts.get("modulate", Color.WHITE)
	s.speed_scale = opts.get("speed", 1.0)
	parent.add_child(s)
	s.global_position = pos
	s.animation_finished.connect(s.queue_free)
	s.play("default")
	return s
