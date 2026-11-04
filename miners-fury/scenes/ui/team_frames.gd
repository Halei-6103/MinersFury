extends Control
## Top-left teammate list (co-op only), styled like the HUD mockup:
##   dashed yellow box: [portrait] name
##                                 health bar      (faded + DOWN when down)

const HudArt = preload("res://scenes/ui/hud_art.gd")

const ROW_W := 190.0
const ROW_H := 36.0
const GAP := 6.0
const PORT := 28.0

var _t: float = 0.0
var _shown: Dictionary = {}   # teammate id -> health shown (drains down after a hit)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	for m in get_tree().get_nodes_in_group("remote_player"):
		var id := m.get_instance_id()
		var hp := float(m.health)
		var s: float = _shown.get(id, hp)
		_shown[id] = hp if hp > s else move_toward(s, hp, delta * 3.0)
	queue_redraw()


func _draw() -> void:
	var y := 0.0
	var i := 0
	for m in get_tree().get_nodes_in_group("remote_player"):
		if not is_instance_valid(m):
			continue
		var down: bool = m.state == m.State.DEAD
		var a := 0.5 if down else 1.0
		var tag = m.get_node_or_null("NameTag")
		var nm: String = tag.text if tag and tag.text != "" else "Player %d" % (i + 2)
		var row := Rect2(0, y, ROW_W, ROW_H)
		HudArt.panel(self, row, a)
		# portrait square: their initial (until there's portrait art)
		var pr := Rect2(4, y + 4, PORT, PORT)
		draw_rect(pr, Color(HudArt.YELLOW, a), false, 2.0)
		HudArt.text_c(self, pr.get_center() + Vector2(0, 4), nm.substr(0, 1).to_upper(), 11, Color(HudArt.TEXT, a))
		var tx := PORT + 12.0
		HudArt.text(self, Vector2(tx, y + 15), nm.left(16), 11, Color(HudArt.TEXT, a), false)
		var bar := Rect2(tx, y + 21, ROW_W - tx - 8, 8)
		if down:
			var flash := 0.6 + 0.4 * sin(_t * 6.0)
			HudArt.text(self, bar.position + Vector2(0, 8), "DOWN", 10, Color(1, 0.45, 0.45, flash))
		else:
			var mx := float(maxi(m.max_health, 1))
			var shown: float = _shown.get(m.get_instance_id(), float(m.health))
			draw_rect(bar, Color(0.2, 0.11, 0.14, 0.8))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(shown / mx, 0, 1), bar.size.y)), Color(1, 0.86, 0.72))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(m.health / mx, 0, 1), bar.size.y)), HudArt.RED)
		y += ROW_H + GAP
		i += 1
