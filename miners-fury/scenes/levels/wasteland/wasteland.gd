extends Node2D
## The sandy wasteland, first combat zone. Bats roost out here.

const TransferBoard = preload("res://scenes/levels/shared/transfer_board.gd")
const Music = preload("res://scenes/audio/music.gd")
const Juice = preload("res://scenes/effects/juice.gd")

var _was_clear := false

@onready var bats_left_label: Label = $UI/BatsLeft


func _ready() -> void:
	TransferBoard.place_player(self)
	Music.ensure(self)
	for bat in get_tree().get_nodes_in_group("enemy"):
		bat.died.connect(_update_count)
	_update_count()


func _update_count() -> void:
	# deferred so the bat that just died is already out of the count
	await get_tree().process_frame
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.state != e.State.DEAD:
			alive += 1
	bats_left_label.text = "Bats left: %d" % alive if alive > 0 else "Area clear!"
	if alive == 0 and not _was_clear:
		_was_clear = true
		_finale()


## last kill: heavy slow-mo, camera pushes in, giant banner slams onto the screen
func _finale() -> void:
	Juice.slow_mo(self, 1.6, 0.12)
	var cam = get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("set_base_zoom"):
		var tw := create_tween()
		tw.set_ignore_time_scale(true)
		tw.tween_method(cam.set_base_zoom, Vector2.ONE, Vector2(1.6, 1.6), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(1.0)
		tw.tween_method(cam.set_base_zoom, Vector2(1.6, 1.6), Vector2.ONE, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	bats_left_label.modulate = Color(1, 0.9, 0.4)

	var banner := Label.new()
	banner.text = "AREA CLEAR"
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.offset_left = -400
	banner.offset_right = 400
	banner.offset_top = -160
	banner.offset_bottom = -60
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 72)
	banner.add_theme_constant_override("outline_size", 18)
	banner.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.05))
	banner.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(banner)
	banner.pivot_offset = Vector2(400, 50)
	banner.scale = Vector2(3.0, 3.0)
	banner.modulate.a = 0.0
	var bt := banner.create_tween()
	bt.set_ignore_time_scale(true)
	bt.tween_interval(0.25)
	bt.tween_property(banner, "modulate:a", 1.0, 0.05)
	bt.parallel().tween_property(banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bt.tween_callback(func():
		Juice.shake(self, 0.8)
		Juice.impact_flash(self, 0.5, Color(1, 0.9, 0.5)))
	bt.tween_interval(2.2)
	bt.tween_property(banner, "modulate:a", 0.0, 0.6)
	bt.tween_callback(banner.queue_free)
