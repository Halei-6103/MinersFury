extends Control
## The in-game HUD (layout "A" from the HUD canvas, with D's boss bar + round
## info). Lives on the player's HUD layer; the player talks to it through
## `player`, set_weapons() and deny_dash().
##   Top left:     teammates (co-op): portrait, name, health bar, DOWN
##   Top centre:   boss bar (the level adds it, boss_bar.gd)
##   Top right:    round info (the level's RoundInfo label, moved here)
##   Bottom left:  health bar + dash pills (health_bar.gd)
##   Bottom right: weapon in hand inside the ult ring, other weapon tucked
##                 beside it, Q to swap (weapon_ring.gd, the D layout)
## Your own art: see hud_art.gd for the file names it looks for.

const HudArt = preload("res://scenes/ui/hud_art.gd")

var player: Node = null:
	set(v):
		player = v
		if _bar:
			_bar.player = v

var _bar: Control
var _weapons: Control
var _team: Control
var _round_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# everything on the HUD uses the same font
	theme = Theme.new()
	theme.default_font = HudArt.font()
	_bar = load("res://scenes/ui/health_bar.gd").new()
	_bar.name = "HealthBar"
	add_child(_bar)
	_weapons = load("res://scenes/ui/weapon_ring.gd").new()
	_weapons.name = "Weapons"
	_weapons.mirror = true
	add_child(_weapons)
	_team = load("res://scenes/ui/team_frames.gd").new()
	_team.name = "TeamFrames"
	add_child(_team)
	_team.position = Vector2(16, 16)
	_team.size = Vector2(240, 200)
	_bar.player = player
	_layout()


func _layout() -> void:
	var s := size if size.x > 0 else get_viewport_rect().size
	_bar.position = Vector2(18, s.y - 18 - _bar.size.y)
	_weapons.position = Vector2(s.x - 16 - _weapons.size.x, s.y - 12 - _weapons.size.y)


## the player calls this when the weapon changes
func set_weapons() -> void:
	if _weapons:
		_weapons.refresh()


## called by the player when you try to dash with no charge
func deny_dash() -> void:
	if _bar:
		_bar.deny_dash()


func _process(_delta: float) -> void:
	_layout()
	_move_round_info()
	queue_redraw()


## the round info, drawn like the mockup: a dashed box, big first line,
## small lines under it (the level's own label is kept but made invisible)
func _draw() -> void:
	if _round_label == null or not is_instance_valid(_round_label) or not _round_label.visible:
		return
	var lines := _round_label.text.strip_edges().split("\n")
	if lines.is_empty() or lines[0] == "":
		return
	var tint: Color = _round_label.modulate
	var big := HudArt.font(true)
	var small := HudArt.font(false)
	var w := big.get_string_size(lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	for k in range(1, lines.size()):
		w = maxf(w, small.get_string_size(lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
	var h := 30.0 + 14.0 * (lines.size() - 1)
	var r := Rect2(size.x - 16.0 - (w + 28.0), 14.0, w + 28.0, h)
	HudArt.panel(self, r)
	var cx := r.get_center().x
	HudArt.text_c(self, Vector2(cx, r.position.y + 21), lines[0], 17, HudArt.TEXT * tint)
	for k in range(1, lines.size()):
		HudArt.text_c(self, Vector2(cx, r.position.y + 21 + 14.0 * k), lines[k], 11, HudArt.TEXT * tint, false)


## every level has a UI/RoundInfo label; the HUD draws its text top-right
func _move_round_info() -> void:
	var cs := get_tree().current_scene
	if cs == null:
		return
	var l := cs.get_node_or_null("UI/RoundInfo") as Label
	if l == null or l == _round_label:
		return
	_round_label = l
	# the HUD draws it (see _draw); the label just holds the text
	l.self_modulate = Color(1, 1, 1, 0)
