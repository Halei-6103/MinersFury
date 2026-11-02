extends Node2D
## The pufferfish casts YOUR combo at you: a poison rune drops where you stand,
## lines show where the waves will go, then a thunderclap sets it off and two
## Tetrodotoxin waves shoot out sideways. Get off the lines (or roll through).
##   PufferUlt.cast(level, rune_pos, caster_pos)

const FxSprite = preload("res://scenes/effects/fx_sprite.gd")
const Juice = preload("res://scenes/effects/juice.gd")
const ToxicWave = preload("res://scenes/effects/toxic_wave.gd")
const Thunderclap = preload("res://scenes/effects/thunderclap.gd")
const ParalysisWave = preload("res://scenes/effects/paralysis_wave.gd")
const Sfx = preload("res://scenes/audio/sfx.gd")

## seconds from the rune landing to the waves firing
const WARN := 1.6
const WAVE_DIST := 330.0
const PARALYSIS := 1.6
const CLAP_R := 70.0
const HALF_WIDTH := 66.0

var caster_pos := Vector2.ZERO
var _side := Vector2.RIGHT       # flat direction the waves travel (and its opposite)
var _t: float = 0.0
var _fired: bool = false
var _rune: AnimatedSprite2D


static func cast(level: Node, at: Vector2, from: Vector2) -> void:
	var u = load("res://scenes/enemies/pufferfish/puffer_ult.gd").new()
	u.caster_pos = from
	var ground = level.get_node_or_null("Ground")
	# know where we are BEFORE _ready runs (it spawns the rune art and sound there)
	u.position = at
	(ground if ground else level).add_child(u)
	u.global_position = at


func _ready() -> void:
	var to_rune: Vector2 = global_position - caster_pos
	var flat := Vector2(to_rune.x, to_rune.y * 2.0)
	if flat.length() < 1.0:
		flat = Vector2.DOWN
	_side = Vector2(-flat.y, flat.x).normalized()
	FxSprite.spawn(self, "venom_zone_start", global_position, {"scale": 1.4, "z": 0})
	# the poison rune slams down first (same sound as your Venom ult)
	Sfx.play(self, "venom_slam", global_position, 1.0, 0.05)
	_rune = AnimatedSprite2D.new()
	_rune.sprite_frames = FxSprite.frames_for("venom_zone_idle", true)
	_rune.offset = FxSprite.anchor_offset("venom_zone_idle")
	_rune.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rune.scale = Vector2(1.4, 1.4)
	_rune.visible = false
	add_child(_rune)
	get_tree().create_timer(0.45, false).timeout.connect(func() -> void:
		if is_instance_valid(_rune):
			_rune.visible = true
			_rune.play("default"))


func _process(delta: float) -> void:
	_t += delta
	if not _fired and _t >= WARN:
		_fire()
	if _fired and _t >= WARN + 0.9:
		queue_free()
	queue_redraw()


func _fire() -> void:
	_fired = true
	var level := get_tree().current_scene
	var at := global_position
	var tc = Thunderclap.new()
	tc.radius = CLAP_R
	level.add_child(tc)
	tc.global_position = at
	Sfx.play(self, "storm_ult", at, 1.0, 0.04)
	var title = ParalysisWave.new()
	level.add_child(title)
	title.global_position = at
	for s in [1.0, -1.0]:
		ToxicWave.fire(level, at, _side * s, WAVE_DIST, PARALYSIS, "player")
	# standing right in it: the thunderclap gets you too
	var p = get_tree().get_first_node_in_group("player")
	if p and p.state != p.State.DEAD:
		var off: Vector2 = p.global_position - at
		if Vector2(off.x, off.y * 2.0).length() < CLAP_R and not p.is_untargetable():
			p.take_damage(1, at, null)
	Juice.impact_flash(self, 0.3, Color(0.6, 1.0, 0.8))
	Juice.shake(self, 0.9)
	if is_instance_valid(_rune):
		_rune.queue_free()
	FxSprite.spawn(get_parent(), "venom_zone_end", global_position, {"scale": 1.4, "z": 0})


## the warning: where the waves will run, filling up as the timer runs out
func _draw() -> void:
	if _fired:
		return
	var k := clampf(_t / WARN, 0.0, 1.0)
	var blink := 0.55 + 0.45 * sin(_t * (10.0 + 20.0 * k))
	var a := (0.18 + 0.4 * k) * blink
	for s in [1.0, -1.0]:
		var d: Vector2 = _side * s
		var tip := Vector2(d.x, d.y * 0.5) * WAVE_DIST
		var nrm := Vector2(-d.y, d.x) * HALF_WIDTH
		var nrm_s := Vector2(nrm.x, nrm.y * 0.5)
		var band := PackedVector2Array([nrm_s, tip + nrm_s, tip - nrm_s, -nrm_s])
		draw_colored_polygon(band, Color(0.55, 1.0, 0.6, a * 0.35))
		draw_line(nrm_s, tip + nrm_s, Color(0.7, 1.0, 0.8, a), 2.0)
		draw_line(-nrm_s, tip - nrm_s, Color(0.7, 1.0, 0.8, a), 2.0)
		# how full the timer is, creeping out along the band
		draw_line(Vector2.ZERO, tip * k, Color(0.8, 1.0, 0.9, a + 0.2), 4.0)
	# shrinking ring = the clap is about to land
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
	draw_arc(Vector2.ZERO, CLAP_R + (1.0 - k) * 60.0, 0.0, TAU, 40, Color(0.6, 0.95, 1.0, 0.6 * blink), 3.0)
	draw_set_transform(Vector2.ZERO)
