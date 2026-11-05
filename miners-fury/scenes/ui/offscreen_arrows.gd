extends Control
## Red arrows on the edge of the screen pointing at monsters you can't see
## (like Sephiria). Each one sits where the line from the middle of the screen
## to the monster crosses the edge, so it shows you which way to go. Closer
## monsters get bigger arrows; bosses get a big pulsing one.
## Lives on the GameUI layer, so every level with monsters gets it.

const RED := Color(1.0, 0.22, 0.2)
const EDGE_DARK := Color(0.12, 0.03, 0.03, 0.9)
## how far in from the screen edge the arrows sit
const INSET := 26.0
## size at the edge of the screen and far away (px)
const NEAR_SIZE := 13.0
const FAR_SIZE := 8.0
const FAR_DIST := 900.0

var _t: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	# the screen (this node sits on a CanvasLayer, so read the viewport directly)
	var view := vp.get_visible_rect()
	if view.size.x < 64.0 or view.size.y < 64.0:
		return
	var inner := view.grow(-INSET)
	var center := view.get_center()
	var xf := vp.get_canvas_transform()
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not (e is Node2D):
			continue
		if e.get("state") != null and e.state == e.State.DEAD:
			continue
		var hb = e.get_node_or_null("Hurtbox")
		var world: Vector2 = hb.global_position if hb else e.global_position
		var sp: Vector2 = xf * world
		if view.grow(-4.0).has_point(sp):
			continue
		var dir := (sp - center).normalized()
		var at := _edge_point(center, dir, inner)
		var boss := false
		var c = e.get("cfg")
		if typeof(c) == TYPE_DICTIONARY and c.get("boss", false):
			boss = true
		var d: float = (world - p.global_position).length()
		var k := clampf(1.0 - (d - 400.0) / FAR_DIST, 0.0, 1.0)
		var s := lerpf(FAR_SIZE, NEAR_SIZE, k)
		var col := RED
		if boss:
			s = 18.0 + 2.0 * sin(_t * 6.0)
			col = RED.lerp(Color(1.0, 0.6, 0.3), 0.5 + 0.5 * sin(_t * 6.0))
		else:
			col.a = lerpf(0.6, 1.0, k)
		_arrow(at, dir, s, col)


## where the ray from the middle of the screen leaves the inner box
func _edge_point(center: Vector2, dir: Vector2, box: Rect2) -> Vector2:
	var tx := INF
	var ty := INF
	if absf(dir.x) > 0.0001:
		tx = ((box.end.x if dir.x > 0.0 else box.position.x) - center.x) / dir.x
	if absf(dir.y) > 0.0001:
		ty = ((box.end.y if dir.y > 0.0 else box.position.y) - center.y) / dir.y
	return center + dir * minf(tx, ty)


func _arrow(at: Vector2, dir: Vector2, s: float, col: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	var tip := at + dir * s
	var back := at - dir * s * 0.6
	var pts := PackedVector2Array([tip, back + side * s * 0.8, back - side * s * 0.8])
	var out := PackedVector2Array([tip + dir * 2.0, back + side * (s * 0.8 + 2.4) - dir * 1.2, back - side * (s * 0.8 + 2.4) - dir * 1.2])
	draw_colored_polygon(out, EDGE_DARK)
	draw_colored_polygon(pts, col)
