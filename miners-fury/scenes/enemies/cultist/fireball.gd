extends Node2D
## Fire Cultist fireball (from the cultist pack). Flies straight, bursts on
## whatever it hits or when it runs out. Block it, parry it or roll through it.
##   Fireball.shoot(parent, from, dir_on_screen, damage)
## Runs on every player's screen; each copy only hits its own player.

const FxSprite = preload("res://scenes/effects/fx_sprite.gd")
const Juice = preload("res://scenes/effects/juice.gd")
const Sfx = preload("res://scenes/audio/sfx.gd")

const SPEED := 340.0
const RANGE := 760.0
const HIT_R := 30.0
const ART_SCALE := 2.0

var dir := Vector2.RIGHT
var damage: int = 1
var height: float = 40.0
var _travelled: float = 0.0
var _spr: AnimatedSprite2D
var _done: bool = false


static func shoot(parent: Node, from: Vector2, d: Vector2, dmg: int = 1, h: float = 40.0) -> Node2D:
	var b = load("res://scenes/enemies/cultist/fireball.gd").new()
	b.dir = d.normalized()
	b.damage = dmg
	b.height = h
	parent.add_child(b)
	b.global_position = from
	return b


func _ready() -> void:
	z_index = 30
	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = FxSprite.frames_for("cult_fireball", true)
	_spr.offset = FxSprite.anchor_offset("cult_fireball")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2.ONE * ART_SCALE
	_spr.rotation = dir.angle()
	_spr.position = Vector2(0, -height)
	add_child(_spr)
	_spr.play("default")
	Sfx.play(self, "fireball", global_position, -4.0)


func _process(delta: float) -> void:
	if _done:
		return
	var step := SPEED * minf(delta, 0.05)
	global_position += dir * step
	_travelled += step
	var p = get_tree().get_first_node_in_group("player")
	if p and p.state != p.State.DEAD:
		var off: Vector2 = p.global_position - global_position
		if Vector2(off.x, off.y * 2.0).length() < HIT_R:
			if not (p.has_method("is_untargetable") and p.is_untargetable()):
				p.take_damage(damage, global_position - dir * 20.0, null)
				_burst()
				return
	if _travelled > RANGE:
		_burst()
	queue_redraw()


func _burst() -> void:
	_done = true
	_spr.visible = false
	FxSprite.spawn(get_parent(), "cult_fire_impact", global_position + Vector2(0, -height), {"scale": ART_SCALE * 1.2, "z": 31})
	Sfx.play(self, "fire_impact", global_position, -5.0)
	Juice.shockwave(self, global_position, 14.0)
	queue_free()


## glow on the floor under it so you can read where it is
func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.45, 0.1, 0.25))
	draw_set_transform(Vector2.ZERO)
