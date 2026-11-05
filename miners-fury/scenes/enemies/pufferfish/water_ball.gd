extends Node2D
## Pufferfish spit: the water ball from the VFX pack (Water v4).
##   WaterBall.shoot(parent, from, dir_on_screen, damage)
## Bursts out, flies straight, splashes on whatever it hits (or when it runs out).
## You can block it, parry it (it pops), or roll through it.

const FxSprite = preload("res://scenes/effects/fx_sprite.gd")
const Juice = preload("res://scenes/effects/juice.gd")

const SPEED := 330.0
const RANGE := 760.0
const HIT_R := 18.0
const ART_SCALE := 1.2

## what the Colosseum death card calls this
var hazard_name := "Pufferfish spit"
var dir := Vector2.RIGHT
var damage: int = 1
## how high off the floor the ball flies (art only, hits are checked on the floor)
var height: float = 30.0
var _travelled: float = 0.0
var _spr: AnimatedSprite2D
var _flying: bool = false
var _done: bool = false


static func shoot(parent: Node, from: Vector2, d: Vector2, dmg: int = 1, h: float = 30.0) -> Node2D:
	var b = load("res://scenes/enemies/pufferfish/water_ball.gd").new()
	b.dir = d.normalized()
	b.height = h
	b.damage = dmg
	parent.add_child(b)
	b.global_position = from
	return b


func _ready() -> void:
	z_index = 30
	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = FxSprite.frames_for("water_ball_start")
	_spr.offset = FxSprite.anchor_offset("water_ball_start")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2.ONE * ART_SCALE
	_spr.rotation = dir.angle()
	_spr.position = Vector2(0, -height)
	add_child(_spr)
	_spr.play("default")
	_spr.animation_finished.connect(_on_start_done)


func _on_start_done() -> void:
	if _done:
		return
	_flying = true
	_spr.sprite_frames = FxSprite.frames_for("water_ball_fly", true)
	_spr.play("default")


func _process(delta: float) -> void:
	if _done:
		return
	var real := minf(delta, 0.05)
	# it leaves slower while the burst plays, then gets going
	var step := SPEED * real * (1.0 if _flying else 0.55)
	global_position += dir * step
	_travelled += step
	var p = get_tree().get_first_node_in_group("player")
	if p and p.state != p.State.DEAD:
		var off: Vector2 = p.global_position - global_position
		if Vector2(off.x, off.y * 2.0).length() < HIT_R + 12.0:
			if not (p.has_method("is_untargetable") and p.is_untargetable()):
				p.take_damage(damage, global_position - dir * 20.0, self)
				_splash()
				return
	if _travelled > RANGE:
		_splash()


func _splash() -> void:
	_done = true
	_spr.visible = false
	FxSprite.spawn(get_parent(), "water_ball_end", global_position + Vector2(0, -height), {"scale": ART_SCALE * 0.9, "z": 31})
	Juice.shockwave(self, global_position, 14.0)
	queue_free()
