extends RefCounted
## Sound effects.
##   const Sfx = preload("res://scenes/audio/sfx.gd")
##   Sfx.play(self, "storm_zap")             at this node's spot
##   Sfx.play(self, "hit", hit_pos, -4.0)    somewhere else, 4 dB quieter
##   Sfx.play(self, "swing", null, 0.0, 0.03, 0.8)   lower pitch (also longer)
##   Sfx.loop(self, "storm_hum", -16.0)      a looping sound stuck to a node
## Picks a random variant if there are several (hit_1.wav, hit_2.wav ...),
## wobbles the pitch a little so repeats never sound copy-pasted, and plays
## on the "SFX" bus so the Effects volume slider controls it.
## Sounds positioned in the world get quieter with distance (matters in co-op).

const DIRS := ["res://assets/audio/sfx/blades/", "res://assets/audio/sfx/bosses/", "res://assets/audio/sfx/footsteps/", "res://assets/audio/sfx/"]
const EXTS := ["wav", "ogg", "mp3"]

static var _variants: Dictionary = {}


static func _find(sound: String) -> Array:
	if _variants.has(sound):
		return _variants[sound]
	var found: Array = []
	for d in DIRS:
		for ext in EXTS:
			var plain: String = d + sound + "." + ext
			if ResourceLoader.exists(plain):
				# a file with the exact name wins: numbered variants are ignored
				_variants[sound] = [plain]
				return [plain]
			for i in range(1, 9):
				var v: String = "%s%s_%d.%s" % [d, sound, i, ext]
				if ResourceLoader.exists(v):
					found.append(v)
		if not found.is_empty():
			break
	_variants[sound] = found
	return found


static func _bus() -> String:
	return "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"


static func play(node: Node, sound: String, at = null, volume_db: float = 0.0, pitch_wobble: float = 0.08, pitch: float = 1.0) -> void:
	if node == null or not node.is_inside_tree():
		return
	var list := _find(sound)
	if list.is_empty():
		return
	var a := AudioStreamPlayer2D.new()
	a.stream = load(list[randi() % list.size()])
	a.bus = _bus()
	a.volume_db = volume_db
	a.pitch_scale = pitch * randf_range(1.0 - pitch_wobble, 1.0 + pitch_wobble)
	a.max_distance = 1400.0
	var parent: Node = node.get_tree().current_scene if node.get_tree().current_scene else node
	parent.add_child(a)
	if at is Vector2:
		a.global_position = at
	elif node is Node2D:
		a.global_position = (node as Node2D).global_position
	a.finished.connect(a.queue_free)
	a.play()


## a looping sound that follows `node` (replaces any loop it already had)
static func loop(node: Node2D, sound: String, volume_db: float = -14.0) -> void:
	stop_loop(node)
	var list := _find(sound)
	if list.is_empty():
		return
	var stream = load(list[0])
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	elif "loop" in stream:
		stream.loop = true
	var a := AudioStreamPlayer2D.new()
	a.name = "SfxLoop"
	a.stream = stream
	a.bus = _bus()
	a.volume_db = volume_db
	a.max_distance = 900.0
	node.add_child(a)
	a.play()


static func stop_loop(node: Node) -> void:
	var old := node.get_node_or_null("SfxLoop")
	if old:
		old.name = "SfxLoopOld"
		old.queue_free()
