extends Node2D
## Venom Blade ultimate: a poison summoning rune on the ground for 5 seconds.
## Enemies standing in it gain a poison stack every PULSE seconds, and poison
## ticks hurt double while they're inside.
##   VenomZone.place(level, ground_pos)

const FxSprite = preload("res://scenes/effects/fx_sprite.gd")
const PoisonStatus = preload("res://scenes/effects/poison_status.gd")
const Juice = preload("res://scenes/effects/juice.gd")

const LIFE := 5.0
## ground radius (iso ellipse: full width = 2x this, height = this)
const RADIUS := 90.0
const PULSE := 0.6
const ART_SCALE := 1.5

var _t: float = 0.0
var _pulse: float = 0.0
var _rune: AnimatedSprite2D
var _ending: bool = false


static func place(parent: Node, at: Vector2) -> Node2D:
	var z = load("res://scenes/effects/venom_zone.gd").new()
	# lives on the floor layer: under every character, over the ground art
	var ground = parent.get_tree().current_scene.get_node_or_null("Ground")
	(ground if ground else parent).add_child(z)
	z.global_position = at
	return z


## used by poison ticks: is this spot inside a live rune?
static func boosted(node: Node, pos: Vector2) -> bool:
	for z in node.get_tree().get_nodes_in_group("venom_zone"):
		if z.contains(pos):
			return true
	return false


## the Toxic Storm combo burns the rune out
func consume() -> void:
	if _ending:
		return
	_ending = true
	_play("venom_zone_end", false)


func contains(pos: Vector2) -> bool:
	if _ending:
		return false
	var off := pos - global_position
	return Vector2(off.x, off.y * 2.0).length() <= RADIUS


func _ready() -> void:
	add_to_group("venom_zone")
	_rune = AnimatedSprite2D.new()
	_rune.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rune.scale = Vector2.ONE * ART_SCALE
	add_child(_rune)
	_rune.animation_finished.connect(_on_anim_done)
	_play("venom_zone_start", false)
	Juice.shake(self, 0.35)


func _play(fx: String, loop: bool) -> void:
	_rune.sprite_frames = FxSprite.frames_for(fx, loop)
	_rune.offset = FxSprite.anchor_offset(fx)
	_rune.play("default")


func _on_anim_done() -> void:
	if _ending:
		queue_free()
	else:
		_play("venom_zone_idle", true)


func _process(delta: float) -> void:
	_t += delta
	if _ending:
		return
	if _t >= LIFE:
		_ending = true
		_play("venom_zone_end", false)
		return
	_pulse -= delta
	if _pulse <= 0.0:
		_pulse = PULSE
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.get("state") != null and e.state == e.State.DEAD:
				continue
			if contains(e.global_position):
				PoisonStatus.apply(e, 1)
	queue_redraw()


func _draw() -> void:
	if _ending:
		return
	# faint fill so you can see exactly where it bites
	var k := 0.5 + 0.5 * sin(_t * 5.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.35, 0.8, 0.2, 0.08 + 0.05 * k))
	draw_set_transform(Vector2.ZERO)
