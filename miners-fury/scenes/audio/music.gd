extends AudioStreamPlayer
## Background music. One player lives on the scene tree root, so the song keeps
## going (no restart) when you warp between the camp and the wasteland.
## Levels call:  Music.ensure(self)
##   const Music = preload("res://scenes/audio/music.gd")

const TRACK := "res://assets/audio/music/cool_beans_man.mp3"
## background music level. Raise toward 0 if still too soft.
const VOLUME_DB := -12.0
const FADE_IN := 2.5
## where to jump back to the start, per song (seconds). The song file has a long
## silent tail; this trims the quiet gap between loops. Not listed = loop at the
## song's real end.
##   cool_beans_man: music stops at ~75s, file is ~95s long -> restart at 85s (10s gap)
const LOOP_AT := {"cool_beans_man.mp3": 85.0}

var _loop_at: float = 0.0


static func ensure(node: Node) -> void:
	if node == null or not node.is_inside_tree():
		return
	var root := node.get_tree().root
	if root.get_node_or_null("BackgroundMusic"):
		return
	var player = load("res://scenes/audio/music.gd").new()
	player.name = "BackgroundMusic"
	root.add_child.call_deferred(player)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var song = load(TRACK)
	if song == null:
		push_warning("Background music not found at " + TRACK)
		queue_free()
		return
	if "loop" in song:
		song.loop = true
	stream = song
	_loop_at = float(LOOP_AT.get(TRACK.get_file(), 0.0))
	# volume slider in the pause menu controls the "Music" bus
	load("res://scenes/ui/game_ui.gd").ensure_buses()
	bus = "Music"
	# fade in gently instead of blasting on
	volume_db = -60.0
	play()
	var tw := create_tween()
	tw.tween_property(self, "volume_db", VOLUME_DB, FADE_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# safety net: if looping isn't supported by the stream, restart it when it ends
	finished.connect(play)


func _process(_delta: float) -> void:
	if _loop_at > 0.0 and playing and get_playback_position() >= _loop_at:
		play(0.0)
