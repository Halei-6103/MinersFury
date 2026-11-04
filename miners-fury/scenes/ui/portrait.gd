extends Control
## Bottom-left portrait: your character's idle frame (with the weapon look you
## have on), zoomed into a framed square.

const BOX := 56.0
const DARK := Color(0.08, 0.06, 0.08)
const GOLD := Color(1.0, 0.84, 0.42)

var player: Node = null
var _tex: Texture2D = null
var _src: Rect2 = Rect2()
var _anim_key: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(BOX, BOX)
	size = Vector2(BOX, BOX)


func refresh() -> void:
	_anim_key = ""


func _process(_delta: float) -> void:
	if player == null:
		return
	var sf: SpriteFrames = player.animated_sprite.sprite_frames
	var key := str(sf.get_instance_id())
	if key != _anim_key:
		_anim_key = key
		_tex = null
		if sf.has_animation("idle") and sf.get_frame_count("idle") > 0:
			_tex = sf.get_frame_texture("idle", 0)
			# crop to the character itself so it fills the frame
			var img := _tex.get_image()
			if img:
				var used := img.get_used_rect()
				var side := maxf(used.size.x, used.size.y) + 6.0
				_src = Rect2(Vector2(used.get_center()) - Vector2(side, side) * 0.5, Vector2(side, side))
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(BOX, BOX))
	draw_rect(r.grow(2.0), DARK)
	draw_rect(r, Color(0.16, 0.12, 0.15, 0.9))
	if _tex:
		draw_texture_rect_region(_tex, r.grow(-4.0), _src)
	var hurt: bool = player != null and player.health <= 1
	draw_rect(r, GOLD if not hurt else Color(1, 0.4, 0.4), false, 2.0)
