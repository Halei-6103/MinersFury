extends Camera2D
## Screen shake, camera kick and zoom punch. Runs on REAL time so it keeps
## shaking during freeze frames (that's what sells the impact).

@export var max_offset: Vector2 = Vector2(16, 11)
## how fast trauma fades per second
@export var decay: float = 2.2
## how fast a camera kick springs back
@export var kick_return: float = 14.0

var trauma: float = 0.0
var _kick: Vector2 = Vector2.ZERO
var _zoom_extra: float = 0.0
var _base_zoom: Vector2


func _ready() -> void:
	add_to_group("camera")
	_base_zoom = zoom


func add_trauma(amount: float) -> void:
	trauma = min(trauma + amount, 1.0)


func kick(v: Vector2) -> void:
	_kick += v


func zoom_punch(amount: float) -> void:
	_zoom_extra = max(_zoom_extra, amount)


## call this if you change the zoom on purpose (cutscenes etc.)
func set_base_zoom(z: Vector2) -> void:
	_base_zoom = z


func _process(delta: float) -> void:
	var real: float = delta / maxf(Engine.time_scale, 0.001)
	real = minf(real, 0.05)
	trauma = max(trauma - decay * real, 0.0)
	_kick = _kick.lerp(Vector2.ZERO, clamp(kick_return * real, 0.0, 1.0))
	_zoom_extra = lerpf(_zoom_extra, 0.0, clamp(10.0 * real, 0.0, 1.0))
	var s := trauma * trauma
	var shake := Vector2(
		randf_range(-1.0, 1.0) * max_offset.x * s,
		randf_range(-1.0, 1.0) * max_offset.y * s
	)
	# whole pixels so the pixel art doesn't swim
	offset = (shake + _kick).round()
	zoom = _base_zoom * (1.0 + _zoom_extra)
