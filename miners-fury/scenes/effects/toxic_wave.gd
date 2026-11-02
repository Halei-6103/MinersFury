extends Node2D
## Tetrodotoxin: one electric wave flying out of the poison rune in a straight
## line. Anything it passes through gets paralyzed. The combo fires two of these,
## out both sides of the rune, perpendicular to where you're standing.
##   ToxicWave.fire(parent, rune_pos, dir_on_screen, distance, paralysis_time)

const FxSprite = preload("res://scenes/effects/fx_sprite.gd")
const LightningBolt = preload("res://scenes/effects/lightning_bolt.gd")
const Juice = preload("res://scenes/effects/juice.gd")

## ground units per second (measured on the flat floor, like the aim ring)
const SPEED := 620.0
## how wide the wave is: the bolt art is ~140px across at 2x, enemies this
## close to the wave's path get hit
const HALF_WIDTH := 66.0
## drop a rolling bolt every this many units, so the wave reads as one wide front
const STEP := 40.0
const ART_SCALE := 2.2

var start := Vector2.ZERO
var dir := Vector2.RIGHT          # flat-floor direction (iso undone)
var distance: float = 260.0
var paralysis: float = 4.0
## "enemy" when you cast it, "player" when the pufferfish casts it at you
var target_group: String = "enemy"
## co-op: teammate's wave on your screen (looks the same, doesn't paralyze)
var remote: bool = false
var _travelled: float = 0.0
var _hit: Array = []
var _head: AnimatedSprite2D
var _trail: Array = []            # recent head positions (screen)
var _done: bool = false
var _fade: float = 0.0
var _next_drop: float = 0.0


static func fire(parent: Node, at: Vector2, flat_dir: Vector2, dist: float, para: float, group: String = "enemy", is_remote: bool = false) -> void:
	var w = load("res://scenes/effects/toxic_wave.gd").new()
	w.target_group = group
	w.remote = is_remote
	w.start = at
	w.dir = flat_dir.normalized()
	w.distance = dist
	w.paralysis = para
	parent.add_child(w)


static func to_screen(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y * 0.5)


func _ready() -> void:
	top_level = true
	z_index = 34
	global_position = start
	_head = AnimatedSprite2D.new()
	_head.sprite_frames = FxSprite.frames_for("lightning_wave", true)
	_head.offset = FxSprite.anchor_offset("lightning_wave")
	_head.position = Vector2(0, -16)
	_head.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_head.scale = Vector2.ONE * ART_SCALE
	# the bolt art lies across a -45 deg line and its animation rolls toward
	# +45 deg: turn it so it rolls along our path with the bolt as a wide front
	_head.rotation = _art_rotation()
	add_child(_head)
	_head.play("default")


func _process(delta: float) -> void:
	var real := minf(delta / maxf(Engine.time_scale, 0.001), 0.05)
	if _done:
		_fade += real
		if _fade > 0.35:
			queue_free()
		queue_redraw()
		return
	_travelled = minf(_travelled + SPEED * real, distance)
	global_position = start + to_screen(dir * _travelled)
	# rolling bolts left behind along the path, each plays the pack's sweep
	while _next_drop <= _travelled:
		FxSprite.spawn(get_parent(), "lightning_wave_full", start + to_screen(dir * _next_drop) + Vector2(0, -16),
			{"rotation": _art_rotation(), "scale": ART_SCALE, "z": 33})
		_next_drop += STEP
	_trail.push_front(global_position)
	if _trail.size() > 10:
		_trail.pop_back()
	_check_hits()
	if _travelled >= distance:
		_done = true
		_head.visible = false
	queue_redraw()


## anyone between the rune and the head, within the wave's thickness
func _check_hits() -> void:
	if remote:
		return
	for e in get_tree().get_nodes_in_group(target_group):
		if e in _hit or (e.get("state") != null and e.state == e.State.DEAD) or not e.has_method("paralyze"):
			continue
		var rel: Vector2 = e.global_position - start
		var flat := Vector2(rel.x, rel.y * 2.0)
		var along := flat.dot(dir)
		if along < -HALF_WIDTH or along > _travelled:
			continue
		var side := absf(flat.cross(dir))
		if side > HALF_WIDTH:
			continue
		# rolling through it dodges it
		if e.has_method("is_untargetable") and e.is_untargetable():
			continue
		_hit.append(e)
		if target_group == "player":
			e.take_damage(1, start, null)
		e.paralyze(paralysis)
		var hb = e.get_node_or_null("Hurtbox")
		var p: Vector2 = hb.global_position if hb else e.global_position
		LightningBolt.zap(get_parent(), global_position + Vector2(0, -14), p, 0.8, 0.22)
		Juice.shake(self, 0.2)


func _art_rotation() -> float:
	return to_screen(dir).angle() - PI / 4.0


func _draw() -> void:
	pass
