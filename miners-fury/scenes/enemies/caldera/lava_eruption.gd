extends Node2D
## Black Knight's slam: the ground cracks, glows, then lava bursts up
## (fire pack v1 pillar + v9 burst by Fellor). Step off the glowing circle.
##   LavaEruption.erupt(level, at, warn_seconds, damage)
## Runs on every player's screen; each copy only burns its own player.

const FxSprite = preload("res://scenes/effects/fx_sprite.gd")
const Juice = preload("res://scenes/effects/juice.gd")
const Sfx = preload("res://scenes/audio/sfx.gd")

const RADIUS := 38.0        # flat radius that burns
const BURN_TIME := 0.35     # the pillar hurts for this long after it bursts
const ART_SCALE := 2.0

var warn: float = 0.9
var damage: int = 1
var _t: float = 0.0
var _up: bool = false
var _hit: bool = false


static func erupt(level: Node, at: Vector2, warn_s: float = 0.9, dmg: int = 1) -> Node2D:
	var e = load("res://scenes/enemies/caldera/lava_eruption.gd").new()
	e.warn = warn_s
	e.damage = dmg
	var floor_layer = level.get_node_or_null("Entities")
	(floor_layer if floor_layer else level).add_child(e)
	e.global_position = at
	return e


func _ready() -> void:
	z_index = 1


func _process(delta: float) -> void:
	_t += delta
	if not _up and _t >= warn:
		_up = true
		FxSprite.spawn(get_parent(), "lava_pillar", global_position + Vector2(0, 4), {"scale": ART_SCALE, "z": 0})
		FxSprite.spawn(get_parent(), "lava_burst", global_position + Vector2(0, -18), {"scale": ART_SCALE * 0.5, "z": 31})
		Sfx.play(self, "fire_impact", global_position, -6.0, 0.1)
		Juice.shockwave(self, global_position, 18.0)
	if _up and not _hit and _t < warn + BURN_TIME:
		var p = get_tree().get_first_node_in_group("player")
		if p and p.state != p.State.DEAD:
			var off: Vector2 = p.global_position - global_position
			if Vector2(off.x, off.y * 2.0).length() < RADIUS:
				if not (p.has_method("is_untargetable") and p.is_untargetable()):
					_hit = true
					p.take_damage(damage, global_position, null)
	if _t > warn + 1.2:
		queue_free()
	queue_redraw()


## the warning: a glowing crack that fills in before it bursts
func _draw() -> void:
	if _up:
		var fade := clampf(1.0 - (_t - warn) / 1.0, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
		draw_circle(Vector2.ZERO, RADIUS, Color(0.25, 0.06, 0.03, 0.45 * fade))
		draw_set_transform(Vector2.ZERO)
		return
	var k := clampf(_t / warn, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.9, 0.25, 0.05, 0.12 + 0.18 * k))
	draw_circle(Vector2.ZERO, RADIUS * k, Color(1.0, 0.55, 0.1, 0.35))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color(1.0, 0.7, 0.2, 0.5 + 0.5 * k), 2.0)
	draw_set_transform(Vector2.ZERO)
