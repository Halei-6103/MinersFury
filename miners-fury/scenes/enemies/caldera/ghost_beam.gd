extends Node2D
## Ghostfire beam (Zerie pack 02). A straight line of fire out of the skull's mouth.
##   GhostBeam.fire(parent, from, dir_on_screen, damage, length)
## Runs on every player's screen; each copy only burns its own player.

const FxSprite = preload("res://scenes/effects/fx_sprite.gd")
const Sfx = preload("res://scenes/audio/sfx.gd")

const HIT_TIME := 0.25      # the beam hurts for this long
const HALF_W := 14.0        # flat half thickness that hits

var dir := Vector2.RIGHT
var damage: int = 1
var length: float = 220.0
var height: float = 30.0
var _t: float = 0.0
var _hit: bool = false


static func fire(parent: Node, from: Vector2, d: Vector2, dmg: int = 1, len: float = 220.0, h: float = 30.0) -> Node2D:
	var b = load("res://scenes/enemies/caldera/ghost_beam.gd").new()
	b.dir = d.normalized()
	b.damage = dmg
	b.length = len
	b.height = h
	parent.add_child(b)
	b.global_position = from
	b._show()
	return b


## (after it has its position: _ready runs before global_position is set)
func _show() -> void:
	# the art is 100px long: stretch it to the beam's length
	FxSprite.spawn(get_parent(), "ghost_beam", global_position + Vector2(0, -height), {
		"rotation": dir.angle(), "scale": length / 98.0, "z": 31, "speed": 0.6})
	Sfx.play(self, "fireball", global_position, -8.0, 0.1, 1.5)


func _process(delta: float) -> void:
	_t += delta
	if not _hit and _t < HIT_TIME:
		var p = get_tree().get_first_node_in_group("player")
		if p and p.state != p.State.DEAD and not (p.has_method("is_untargetable") and p.is_untargetable()):
			# distance from the player to the beam line, measured flat
			var off: Vector2 = p.global_position - global_position
			var along := off.dot(dir)
			if along > 0.0 and along < length:
				var side: Vector2 = off - dir * along
				if Vector2(side.x, side.y * 2.0).length() < HALF_W * 2.0:
					_hit = true
					p.take_damage(damage, global_position, null)
	if _t > HIT_TIME + 0.1:
		queue_free()
