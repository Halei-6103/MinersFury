extends RefCounted
## Game feel helpers. Use from anywhere:
##   const Juice = preload("res://scenes/effects/juice.gd")
##   Juice.hit_stop(self, 0.12)            freeze frame
##   Juice.shake(self, 0.5, hit_dir)       screen shake + camera kick
##   Juice.zoom_punch(self, 0.08)          quick zoom in and back
##   Juice.impact_flash(self, 0.3)         one-frame white screen flash
##   Juice.spark(parent, pos, dir, big)    exit burst out the back of a hit
##   Juice.splat(self, pos, dir, count)    ichor splats on the ground
##   Juice.shockwave(self, pos, size)      ring on the ground
##   Juice.slash(parent, pos, dir, ...)    crescent sword arc
##   Juice.damage_number(parent, pos, ...) pop-up number
##   Juice.death_puff(parent, pos)         dust puff

const HitSpark = preload("res://scenes/effects/hit_spark.gd")
const Watcher = preload("res://scenes/effects/hit_stop_watcher.gd")
const SlashArc = preload("res://scenes/effects/slash_arc.gd")
const DamageNumber = preload("res://scenes/effects/damage_number.gd")
const GroundFx = preload("res://scenes/effects/ground_fx.gd")
const FxSprite = preload("res://scenes/effects/fx_sprite.gd")


## Freeze-frame: the whole game nearly stops for `duration` real seconds.
## Overlapping calls extend it. Always recovers on the real clock.
static func hit_stop(node: Node, duration: float, time_scale: float = 0.02) -> void:
	var w = _watcher(node)
	if w:
		w.freeze(duration, time_scale)


## Slow motion for big moments. A hit stop on top of it freezes first, then slow-mo resumes.
static func slow_mo(node: Node, duration: float, time_scale: float = 0.25) -> void:
	var w = _watcher(node)
	if w:
		w.slow(duration, time_scale)


static func _watcher(node: Node):
	if node == null or not node.is_inside_tree():
		return null
	var root := node.get_tree().root
	var w = root.get_node_or_null("JuiceHitStop")
	if w == null:
		w = Watcher.new()
		w.name = "JuiceHitStop"
		root.add_child(w)
	return w


static func _camera(node: Node):
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group("camera")


## Screen shake (amount 0..1, stacks). kick_dir punches the camera that way too.
static func shake(node: Node, amount: float, kick_dir: Vector2 = Vector2.ZERO) -> void:
	var cam = _camera(node)
	if cam:
		cam.add_trauma(amount)
		if kick_dir != Vector2.ZERO:
			cam.kick(kick_dir.normalized() * amount * 16.0)


static func zoom_punch(node: Node, amount: float) -> void:
	var cam = _camera(node)
	if cam:
		cam.zoom_punch(amount)


## Full-screen white flash for a couple of real frames (anime impact frame).
static func impact_flash(node: Node, strength: float = 0.35, color: Color = Color(1, 1, 1)) -> void:
	if node == null or not node.is_inside_tree():
		return
	var scene := node.get_tree().current_scene
	if scene == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 90
	scene.add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(color.r, color.g, color.b, strength)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	var tw := layer.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_interval(0.05)
	tw.tween_property(rect, "color:a", 0.0, 0.12)
	tw.tween_callback(layer.queue_free)


## Exit burst: sparks + ichor blasting out the back of whatever got hit.
## dir = direction the hit traveled (attacker -> target).
static func spark(parent: Node, pos: Vector2, dir: Vector2, big: bool = false, ichor: Color = Color(0.5, 0.06, 0.32)) -> void:
	if parent == null:
		return
	var s = HitSpark.new()
	s.dir = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	s.big = big
	s.ichor_color = ichor
	parent.add_child(s)
	s.global_position = pos


static func _ground(node: Node) -> Node:
	var scene := node.get_tree().current_scene
	if scene:
		var g = scene.get_node_or_null("Ground")
		if g:
			return g
	return node.get_parent()


## Ichor splats that land on the floor behind the hit and stay for a while.
static func splat(node: Node, ground_pos: Vector2, dir: Vector2, count: int = 3, color: Color = Color(0.42, 0.05, 0.26)) -> void:
	if node == null or not node.is_inside_tree():
		return
	var ground := _ground(node)
	dir = dir.normalized()
	for i in count:
		var g = GroundFx.new()
		g.kind = "splat"
		g.color = color.darkened(randf_range(0.0, 0.25))
		g.radius = randf_range(4.0, 9.0) * (1.4 if i == 0 else 1.0)
		var dist := randf_range(18.0, 70.0) * (0.5 + i * 0.35)
		var side := dir.orthogonal() * randf_range(-12.0, 12.0)
		var at := ground_pos + dir * dist + side
		# lands after the droplets "fly" there
		g.delay = 0.04 + dist / 900.0
		ground.add_child(g)
		g.global_position = at


static func shockwave(node: Node, ground_pos: Vector2, size: float = 22.0) -> void:
	if node == null or not node.is_inside_tree():
		return
	var g = GroundFx.new()
	g.kind = "shockwave"
	g.radius = size
	var ground := _ground(node)
	ground.add_child(g)
	g.global_position = ground_pos
	g.z_index = 5


static func slash(parent: Node, pos: Vector2, dir: Vector2, big: bool = false, flip: bool = false) -> void:
	if parent == null:
		return
	var s = SlashArc.new()
	s.dir = dir.normalized()
	s.flip = flip
	if big:
		s.radius = 54.0
		s.thickness = 24.0
		s.sweep = 3.2
		s.color = Color(1, 0.92, 0.6)
	parent.add_child(s)
	s.global_position = pos


static func damage_number(parent: Node, pos: Vector2, text: String, color: Color = Color(1, 0.9, 0.3), size: int = 18) -> void:
	if parent == null:
		return
	var n = DamageNumber.new()
	n.text = text
	n.color = color
	n.size = size
	n.drift = -1.0 if randf() < 0.5 else 1.0
	parent.add_child(n)
	n.global_position = pos


## Dust cloud when something dies (effect pack 3).
static func death_puff(parent: Node, pos: Vector2, _scrap_color: Color = Color(0.25, 0.2, 0.32)) -> void:
	if parent == null:
		return
	FxSprite.spawn(parent, "death_puff", pos, {"z": 25, "flip_h": randf() < 0.5})
