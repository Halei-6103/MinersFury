extends Node2D
## A wall of fire across the floor. Glowing lines warn
## you first, then the flames burst up and burn anyone standing in them.
##   FlameWall.raise(level, center, flat_side, length)
## Runs on every player's screen; each copy only burns its own player, so you
## dodge what you see (same idea as the pufferfish waves).

const FxSprite = preload("res://scenes/effects/fx_sprite.gd")
const Juice = preload("res://scenes/effects/juice.gd")
const Sfx = preload("res://scenes/audio/sfx.gd")

const WARN := 1.1
const LIFE := 3.2           # how long the flames stay up after they erupt
const HALF_W := 22.0        # flat half thickness of the wall
const ART_SCALE := 1.15
const SPACING := 24.0       # screen px between flame pieces (they overlap into one band)
const HIT_EVERY := 0.6

var side := Vector2.RIGHT   # flat direction the wall runs along
var length: float = 360.0
var _t: float = 0.0
var _up: bool = false
var _ending: bool = false
var _hit_cd: float = 0.0
var _pieces: Array = []


static func raise(level: Node, center: Vector2, flat_side: Vector2, len: float = 360.0) -> Node2D:
	var w = load("res://scenes/effects/flame_wall.gd").new()
	w.side = flat_side.normalized() if flat_side.length() > 0.01 else Vector2.RIGHT
	w.length = len
	var ents = level.get_node_or_null("Entities")
	w.position = center
	(ents if ents else level).add_child(w)
	w.global_position = center
	return w


func _ready() -> void:
	y_sort_enabled = true
	Sfx.play(self, "fireball", global_position, -8.0, 0.05, 0.7)


func _screen(flat: Vector2) -> Vector2:
	return Vector2(flat.x, flat.y * 0.5)


func _erupt() -> void:
	_up = true
	var along := _screen(side * length)
	var n := maxi(int(along.length() / SPACING), 2)
	# the end caps only look right on a wall that runs mostly sideways on screen
	var caps: bool = absf(along.x) > absf(along.y) * 1.6
	for i in n + 1:
		var part := "m"
		if caps and i == 0:
			part = "l"
		elif caps and i == n:
			part = "r"
		var s := AnimatedSprite2D.new()
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2.ONE * ART_SCALE * randf_range(0.9, 1.1)
		# the caps face the right way when the wall runs right-to-left on screen
		s.flip_h = along.x < 0.0 if caps else randf() < 0.5
		s.position = -along * 0.5 + along * (float(i) / n) + Vector2(randf_range(-3, 3), randf_range(-2, 2))
		s.speed_scale = randf_range(0.85, 1.15)
		add_child(s)
		_pieces.append([s, part])
		_play(s, "flamewall_%s_coming" % part, false)
		s.animation_finished.connect(_piece_done.bind(s, part))
	Sfx.play(self, "flame_wall", global_position, -3.0, 0.05, 1.15)
	Juice.shake(self, 0.5)


func _play(s: AnimatedSprite2D, fx: String, loop: bool) -> void:
	s.sprite_frames = FxSprite.frames_for(fx, loop)
	s.offset = FxSprite.anchor_offset(fx)
	if s.flip_h:
		s.offset.x = -s.offset.x
	s.play("default")


func _piece_done(s: AnimatedSprite2D, part: String) -> void:
	if _ending:
		s.queue_free()
	else:
		_play(s, "flamewall_%s_idle" % part, true)


func _process(delta: float) -> void:
	_t += delta
	if not _up and _t >= WARN:
		_erupt()
	if _up and not _ending:
		_hit_cd -= delta
		_burn_player()
		if _t >= WARN + LIFE:
			_ending = true
			for p in _pieces:
				if is_instance_valid(p[0]):
					_play(p[0], "flamewall_%s_fade" % p[1], false)
			get_tree().create_timer(0.8, false).timeout.connect(queue_free)
	queue_redraw()


## only YOUR player: teammates' games check theirs
func _burn_player() -> void:
	if _hit_cd > 0.0:
		return
	var p = get_tree().get_first_node_in_group("player")
	if p == null or p.state == p.State.DEAD:
		return
	if p.has_method("is_untargetable") and p.is_untargetable():
		return
	var off: Vector2 = p.global_position - global_position
	var flat := Vector2(off.x, off.y * 2.0)
	var along := flat.dot(side)
	var across := absf(flat.dot(Vector2(-side.y, side.x)))
	if absf(along) <= length * 0.5 + 10.0 and across <= HALF_W:
		_hit_cd = HIT_EVERY
		p.take_damage(1, global_position + _screen(side * along), null)


## the warning: a glowing band filling in as the spell charges
func _draw() -> void:
	if _up:
		return
	var k := clampf(_t / WARN, 0.0, 1.0)
	var blink := 0.55 + 0.45 * sin(_t * (10.0 + 22.0 * k))
	var a := (0.2 + 0.45 * k) * blink
	var half := _screen(side * length * 0.5)
	var nrm := _screen(Vector2(-side.y, side.x) * HALF_W)
	var band := PackedVector2Array([-half + nrm, half + nrm, half - nrm, -half - nrm])
	draw_colored_polygon(band, Color(1.0, 0.45, 0.1, a * 0.4))
	draw_line(-half + nrm, half + nrm, Color(1.0, 0.7, 0.3, a), 2.0)
	draw_line(-half - nrm, half - nrm, Color(1.0, 0.7, 0.3, a), 2.0)
	draw_line(-half * k, half * k, Color(1.0, 0.85, 0.5, a + 0.2), 3.0)
