extends Node2D
## Loot on the ground. Pops out, bounces, bobs, then gets pulled into you
## when you walk close. Spawn with Pickup.drop(parent, pos, "item"/"blueprint", id).

const GameState = preload("res://scenes/core/game_state.gd")
const Juice = preload("res://scenes/effects/juice.gd")

## "item" or "blueprint"
var kind: String = "item"
var id: String = "storm_crystal"
## how close you need to be before it flies to you
var magnet_radius: float = 90.0
var sprite_scale: float = 1.5

const GRAVITY := 900.0
const SETTLE_TIME := 0.7      # can't be grabbed while it's still flying out
const COLLECT_DIST := 22.0

var _vel := Vector2.ZERO      # ground-plane velocity
var _h: float = 0.0           # height above the ground
var _vh: float = 0.0
var _t: float = 0.0
var _bounces: int = 0
var _pulling: bool = false
var _pull_speed: float = 0.0
var _color := Color(0.5, 0.8, 1.0)
var _sprite: AnimatedSprite2D


static func drop(parent: Node, pos: Vector2, kind_: String, id_: String, toss_dir: Vector2 = Vector2.ZERO) -> Node2D:
	var p = load("res://scenes/items/pickup.gd").new()
	p.kind = kind_
	p.id = id_
	if toss_dir == Vector2.ZERO:
		toss_dir = Vector2.RIGHT.rotated(randf() * TAU)
	p._vel = toss_dir.normalized() * randf_range(40.0, 70.0) * Vector2(1.0, 0.5)
	p._vh = randf_range(330.0, 400.0)
	parent.add_child(p)
	p.global_position = pos
	return p


func _ready() -> void:
	add_to_group("pickup")
	var info: Dictionary = GameState.ITEMS.get(id, {}) if kind == "item" else GameState.BLUEPRINTS.get(id, {})
	_color = info.get("color", _color)
	var tex: Texture2D = load(info.get("icon", "res://assets/sprites/items/storm_crystal.png"))
	var n: int = info.get("frames", 1)
	var fw := tex.get_width() / n
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 11.0 if kind == "item" else 12.0)
	sf.set_animation_loop("default", true)
	for i in n:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * fw, 0, fw, tex.get_height())
		sf.add_frame("default", a)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = sf
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * sprite_scale
	# feet on the ground point
	_sprite.offset = Vector2(0, -tex.get_height() * 0.5 + 3)
	add_child(_sprite)
	_sprite.play()


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	_t += delta
	var p := _player()

	if _pulling and p:
		var target := p.global_position
		_pull_speed = minf(_pull_speed + 1600.0 * delta, 900.0)
		global_position = global_position.move_toward(target, _pull_speed * delta)
		_h = lerpf(_h, 18.0, 10.0 * delta)
		if global_position.distance_to(target) < COLLECT_DIST:
			_collect(p)
			return
	elif _h > 0.0 or _vh > 0.0:
		# flying out / bouncing
		_vh -= GRAVITY * delta
		_h += _vh * delta
		global_position += _vel * delta
		if _h <= 0.0:
			_h = 0.0
			_bounces += 1
			if _bounces < 3:
				_vh = absf(_vh) * 0.38
				_vel *= 0.5
			else:
				_vh = 0.0
				_vel = Vector2.ZERO
	else:
		# resting: gentle bob
		_h = 3.0 + sin(_t * 3.2) * 3.0
		if p and _t > SETTLE_TIME and global_position.distance_to(p.global_position) < magnet_radius:
			_pulling = true

	_sprite.position.y = -_h
	queue_redraw()


## after a fight: everything left flies to you
func pull_now() -> void:
	magnet_radius = 99999.0
	_t = maxf(_t, SETTLE_TIME)
	_pulling = true


func _collect(p: Node2D) -> void:
	if kind == "blueprint":
		GameState.add_blueprint(id)
	else:
		GameState.add_item(id)
	var label := "+ " + GameState.display_name(id)
	Juice.damage_number(p.get_parent(), p.global_position + Vector2(0, -70), label, _color.lightened(0.2), 20)
	if kind == "blueprint":
		Juice.damage_number(p.get_parent(), p.global_position + Vector2(0, -100), "Take it to the Telecom", Color(1, 1, 1), 14)
	Juice.zoom_punch(self, 0.04)
	queue_free()


func _draw() -> void:
	# soft shadow + glow on the ground
	var k := clampf(1.0 - _h / 80.0, 0.4, 1.0)
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 22.0 * k, Color(_color.r, _color.g, _color.b, 0.10 + 0.08 * pulse))
	draw_circle(Vector2.ZERO, 11.0 * k, Color(0, 0, 0, 0.3 * k))
	draw_set_transform(Vector2.ZERO)
