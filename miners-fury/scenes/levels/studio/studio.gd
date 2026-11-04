extends "res://scenes/levels/colosseum/colosseum.gd"
## Trailer Arena: the Colosseum with nothing in it. No rounds, no waves.
## For recording: open trailer mode (Shift+2) and spawn exactly what you want.
## Get here from the trailer mode panel. In co-op the host takes everyone along.
## You can't really die here: you get back up after a couple of seconds.

const TrailerMode = preload("res://scenes/ui/trailer_mode.gd")


func _ready() -> void:
	level_id = "studio"
	cfg = {"boss": "", "boss_title": "", "shard": ""}
	rounds = []
	TransferBoard.place_player(self)
	Music.ensure(self)
	GameUI.ensure(self)
	_boss_bar = BossBar.new()
	_boss_bar.visible = false
	$UI.add_child(_boss_bar)
	var p := _player()
	if p:
		p.hold_on_death = true
		if not _coop():
			p.died.connect(_get_up)
	_light_braziers()
	_hide_board_art()
	round_info.text = "TRAILER ARENA\nShift+2 for the tools"


## no rounds here, so nothing to count
func _on_enemy_died() -> void:
	pass


func _update_info() -> void:
	pass


## solo: back on your feet after 2 seconds (co-op uses the normal revive)
func _get_up() -> void:
	await get_tree().create_timer(2.0, false).timeout
	var p := _player()
	if p and p.has_method("coop_revive"):
		p.coop_revive(p.max_health)


## a client asked the host to spawn something (so everyone gets the same monster)
func trailer_spawn(_peer: int, kind: String, at: Vector2) -> void:
	TrailerMode.spawn_monster(get_tree(), kind, at)
