extends Node2D
## Storm Blade finisher: a bolt from the sky (effect pack 2) and an electric
## dome blast on the ground (effect pack 1). Visual only, the player does the damage.

const FxSprite = preload("res://scenes/effects/fx_sprite.gd")

var radius: float = 100.0


func _ready() -> void:
	# wait a beat so whoever spawned us has set our position
	_fire.call_deferred()


func _fire() -> void:
	var p := global_position
	var parent := get_parent()
	FxSprite.spawn(parent, "storm_strike", p, {"z": 40})
	# the dome's blast is ~210px wide at 1x, which matches the 100px hit radius
	FxSprite.spawn(parent, "storm_dome", p, {"z": 20, "speed": 1.3})
	queue_free()
