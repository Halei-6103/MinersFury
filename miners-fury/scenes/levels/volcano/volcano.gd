extends "res://scenes/levels/shared/arena.gd"
## Ember Caldera: cultists and bats on a volcano, the Fire Cultist is the boss.
## All the round logic is in shared/arena.gd (edit LEVELS there).

const FxSprite = preload("res://scenes/effects/fx_sprite.gd")


func _init() -> void:
	level_id = "volcano"


func _ready() -> void:
	super._ready()
	# light the braziers by the cult's altar
	for n in $Entities.get_children():
		if n.name.begins_with("Brazier"):
			var f := AnimatedSprite2D.new()
			f.sprite_frames = FxSprite.frames_for("brazier_fire", true)
			f.offset = FxSprite.anchor_offset("brazier_fire")
			f.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			f.position = Vector2(0, -44)
			f.scale = Vector2(0.8, 0.8)
			n.add_child(f)
			f.play("default")
			f.frame = randi() % 12
