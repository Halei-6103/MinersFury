extends Sprite2D
## Put on a tall prop's sprite (trees, big statues). When a player or a monster
## walks behind it, it fades out so you can still see them.
## Visual only, every player's game does it on its own.

const FADED := 0.4
const SPEED := 6.0
## don't bother checking things further than this from the prop
const NEAR := 260.0

var _rect: Rect2


func _ready() -> void:
	_rect = get_rect()
	# the bottom few pixels are the trunk/base you can't stand behind
	_rect.size.y -= 6.0


func _process(delta: float) -> void:
	var behind := false
	var foot := global_position.y
	for group in ["players_all", "enemy"]:
		for n in get_tree().get_nodes_in_group(group):
			if not (n is Node2D) or not n.visible:
				continue
			var p: Vector2 = n.global_position
			if p.y >= foot or absf(p.x - global_position.x) > NEAR or foot - p.y > NEAR * 2.0:
				continue
			# their middle (a bit above the feet) inside the art?
			var local: Vector2 = to_local(p + Vector2(0, -20))
			if _rect.has_point(local):
				behind = true
				break
		if behind:
			break
	var want := FADED if behind else 1.0
	if not is_equal_approx(modulate.a, want):
		modulate.a = move_toward(modulate.a, want, SPEED * delta)
