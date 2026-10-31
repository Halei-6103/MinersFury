extends Node
## Lives on the scene tree root and owns Engine.time_scale.
## Two layers: a hard FREEZE (hit stop) on top of a softer SLOW-MO.
## Freeze wins while it's active, then slow-mo takes over, then back to normal.
## Runs on the real clock so it always recovers, even across scene changes.

var freeze_until_ms: int = 0
var freeze_scale: float = 0.02
var slow_until_ms: int = 0
var slow_scale: float = 0.25


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func freeze(duration: float, scale: float) -> void:
	var end := Time.get_ticks_msec() + int(duration * 1000.0)
	if end > freeze_until_ms:
		freeze_until_ms = end
	freeze_scale = scale
	_apply()


func slow(duration: float, scale: float) -> void:
	var end := Time.get_ticks_msec() + int(duration * 1000.0)
	if end > slow_until_ms:
		slow_until_ms = end
	slow_scale = scale
	_apply()


func _process(_delta: float) -> void:
	_apply()


func _apply() -> void:
	var now := Time.get_ticks_msec()
	var target := 1.0
	if now < freeze_until_ms:
		target = freeze_scale
	elif now < slow_until_ms:
		target = slow_scale
	if Engine.time_scale != target:
		Engine.time_scale = target
