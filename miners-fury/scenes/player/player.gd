extends CharacterBody2D

signal health_changed(health: int, max_health: int)
signal died

const Juice = preload("res://scenes/effects/juice.gd")
const GameState = preload("res://scenes/core/game_state.gd")
const LightningBolt = preload("res://scenes/effects/lightning_bolt.gd")
const Thunderclap = preload("res://scenes/effects/thunderclap.gd")
const FxSprite = preload("res://scenes/effects/fx_sprite.gd")
const StormAura = preload("res://scenes/effects/storm_aura.gd")
const PoisonStatus = preload("res://scenes/effects/poison_status.gd")

@export var speed: float = 216.0
@export var roll_speed: float = 400.0
@export var roll_duration: float = 0.18
## short gap between back-to-back dashes
@export var roll_cooldown: float = 0.2
## dash charges you can store, and how long one takes to refill
@export var dash_max: float = 2.0
@export var dash_recharge_time: float = 1.6
@export var acceleration: float = 1440.0
@export var friction: float = 1620.0
## how much you can still drift while swinging (0 = planted, 1 = full speed)
@export var attack_move_factor: float = 0.25

## how long a dodge makes you untargetable: no damage, and enemies lose track of you.
## Starts when the roll starts and lasts a bit past the roll itself.
@export var dodge_untargetable_time: float = 0.4

@export_group("Roll Effect")
## tint while phased out during a roll
@export var phase_color: Color = Color(0.55, 1.0, 1.0, 0.45)
## color of the afterimages left behind
@export var ghost_color: Color = Color(0.15, 0.6, 1.0, 0.6)
## seconds between afterimages (smaller = denser trail)
@export var ghost_interval: float = 0.045
## how long each afterimage takes to fade
@export var ghost_fade_time: float = 0.3

@export_group("Feel")
## press attack/dodge slightly early and it still happens when you're able to
@export var input_buffer_time: float = 0.18
## little step forward on each swing (pixels/sec burst)
@export var attack_lunge: float = 190.0
@export var finisher_lunge: float = 255.0
## freeze frames (seconds): normal hit / combo finisher / killing blow / getting hurt
@export var hit_stop_light: float = 0.09
@export var hit_stop_heavy: float = 0.15
@export var hit_stop_kill: float = 0.23
@export var hit_stop_hurt: float = 0.12
## how long the combo counter stays up without a hit
@export var combo_timeout: float = 2.5

@export_group("Block")
## hold right click to block hits from the front
@export var block_move_factor: float = 0.35
## block this long before a hit lands = PARRY (stuns the attacker)
@export var parry_window: float = 0.25
@export var parry_stun_time: float = 2.2
## how wide the guard covers, in degrees each side of your aim
@export var block_angle: float = 75.0

@export_group("Combat")
@export var max_health: int = 5
@export var sword_damage: int = 1
@export var invincible_time: float = 1.0
@export var knockback_strength: float = 260.0
## scene to go back to when you die
## Tetrodotoxin cast AT you (the pufferfish trial): can't move or act
var _paralysis: float = 0.0
## seconds before Q can swap weapons again (stops swap spam)
@export var swap_cooldown: float = 2.5
var _swap_cd: float = 0.0
var _swap_nag: float = 0.0
## set by the Colosseum: stay down when you die (it shows the run card)
var hold_on_death: bool = false
@export_file("*.tscn") var respawn_scene: String = "res://scenes/levels/hub/hub.tscn"

@export_group("Storm Blade")
## each hit jumps to this many more enemies nearby
@export var chain_count: int = 2
@export var chain_range: float = 110.0
@export var chain_damage: int = 1
@export_group("Ultimates (R)")
## hold R to aim, let go to cast. How far from you it can land
@export var ult_range: float = 260.0
## Storm Blade: thunderclap where you aim
@export var clap_radius: float = 100.0
@export var clap_damage: int = 3
@export var clap_stun: float = 1.2
@export var storm_ult_cooldown: float = 10.0
## Venom Blade: poison rune where you aim (lasts 5s)
@export var venom_ult_cooldown: float = 12.0
## COMBO "Tetrodotoxin": thunderclap on a poison rune (bosses get half)
@export var paralysis_time: float = 4.0
## swapping weapons (Q) cancels a swing; you can't swing again for this long
@export var swap_attack_delay: float = 0.25

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var aim_indicator: Node2D = $AimIndicator
@onready var sword_hitbox: Area2D = $SwordHitbox
@onready var swing_fx: AnimatedSprite2D = $SwingFX
@onready var hud = $HUD/StatusBars

enum State { MOVE, ROLL, ATTACK, HURT, DEAD, BLOCK }
var state: State = State.MOVE

var last_direction: Vector2 = Vector2.DOWN
var roll_direction: Vector2 = Vector2.ZERO
var roll_timer: float = 0.0
var roll_cooldown_timer: float = 0.0
var can_roll: bool = true
var dash_charge: float = 2.0

# the swordsman sprite is drawn facing right, we flip it for left
var facing_right: bool = true

# combo: attack1 (slash) -> click again during it -> attack2 (spin + stab finisher)
var combo_queued: bool = false
# which animation frames deal damage. Each [first, last] pair is one strike;
# an enemy can only be hit once per strike.
const HIT_WINDOWS := {
	"attack1": [[2, 4]],
	"attack2": [[2, 4], [6, 8], [11, 13]],
}
## how far in front of you (toward the aim marker) the sword reaches
@export var sword_reach: float = 44.0
## size of the separated sword swoosh (body is drawn at 2x)
@export var swing_fx_scale: float = 3.2
@export var finisher_fx_scale: float = 3.7
var _strike_index: int = -1
var _hit_this_strike: Array = []

var health: int
var invincible_timer: float = 0.0
var untargetable_timer: float = 0.0
var ghost_timer: float = 0.0
var _ghost_material := CanvasItemMaterial.new()
var knockback: Vector2 = Vector2.ZERO
var _buffered: String = ""
var _buffer_timer: float = 0.0
var _hurt_flash: TextureRect
var _guard: Node2D
var _block_time: float = 0.0
const GuardArc = preload("res://scenes/effects/guard_arc.gd")
var _combo_label: Label
var combo_count: int = 0
var _combo_timer: float = 0.0
## "iron_sword" or "storm_blade" (comes from the save, swapped at the telecom)
var weapon: String = "iron_sword"
var _iron_fx: SpriteFrames
var _aura: Node2D
var _clapped: bool = false
## after a weapon swap you can't swing for this long
var _attack_lock: float = 0.0
## seconds left before each weapon's ultimate is ready again
var _ult_cd: Dictionary = {}
var _aim_node: Node2D = null
const UltAim = preload("res://scenes/effects/ult_aim.gd")
const VenomZone = preload("res://scenes/effects/venom_zone.gd")
const ParalysisWave = preload("res://scenes/effects/paralysis_wave.gd")
const ToxicWave = preload("res://scenes/effects/toxic_wave.gd")
const Net = preload("res://scenes/core/net.gd")
const Sfx = preload("res://scenes/audio/sfx.gd")

# ---------------------------------------------------------------- co-op
## true = this is a teammate's character mirrored on your screen (no input,
## no camera, no HUD). It just shows whatever its owner sends.
var puppet: bool = false
## multiplayer peer id of whoever controls this character
var net_id: int = 1
var _net_target: Vector2 = Vector2.ZERO
var _net_has_target: bool = false
var _net_send_t: float = 0.0
var _net_last_anim: String = ""
var _net_last_frame: int = -1
const NET_SEND_RATE := 1.0 / 30.0

func _ready() -> void:
	if puppet:
		_puppet_ready()
		return
	add_to_group("player")
	add_to_group("players_all")
	health = max_health
	_ghost_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD  # afterimages glow
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.frame_changed.connect(_on_frame_changed)
	dash_charge = dash_max
	hud.player = self
	health_changed.emit(health, max_health)
	_build_hurt_flash()
	_build_combo_label()
	_ensure_block_action()
	_guard = GuardArc.new()
	_guard.position = Vector2(0, -10)
	_guard.z_index = 5
	_guard.visible = false
	add_child(_guard)
	Engine.time_scale = 1.0  # in case a scene change happened mid hit stop
	_iron_fx = swing_fx.sprite_frames
	GameState.ensure_loaded()
	_ensure_swap_action()
	_ensure_ult_action()
	set_weapon(GameState.equipped())
	if Net.online(get_tree()):
		# wait a frame: the level is still building its children right now
		Net.get_node_in(get_tree()).local_ready.call_deferred(self)

## swap swords: the swoosh, the crackle on the blade, and what hits do
func set_weapon(w: String) -> void:
	weapon = w
	var info: Dictionary = GameState.WEAPONS.get(w, GameState.WEAPONS["iron_sword"])
	var fx = load(info.get("swing_fx", "")) if info.has("swing_fx") else null
	swing_fx.sprite_frames = fx if fx else _iron_fx
	# the sword itself is recolored in every animation frame for each weapon
	var body = load(info.get("body", "")) if info.has("body") else null
	if body and animated_sprite.sprite_frames != body:
		var anim := animated_sprite.animation
		var frame := animated_sprite.frame
		var playing := animated_sprite.is_playing()
		animated_sprite.sprite_frames = body
		animated_sprite.animation = anim
		animated_sprite.frame = frame
		if playing:
			animated_sprite.play(anim)
	if _aura:
		_aura.queue_free()
		_aura = null
	# quiet hum of the blade in your hand
	match info.effect:
		"storm": Sfx.loop(self, "storm_hum", -24.0)
		"venom": Sfx.loop(self, "venom_hum", -29.0)
		_: Sfx.stop_loop(self)
	if info.effect == "storm" or info.effect == "venom":
		_aura = StormAura.new()
		_aura.venom = info.effect == "venom"
		add_child(_aura)
	if hud and hud.has_method("set_weapons"):
		hud.set_weapons()

# ---------------------------------------------------------------- ultimates (R)

func _ult_cooldown_for(w: String) -> float:
	match GameState.WEAPONS.get(w, {}).get("effect", "none"):
		"storm":
			return storm_ult_cooldown
		"venom":
			return venom_ult_cooldown
	return 0.0


## 0 = just used, 1 = ready (for the HUD). -1 = this weapon has no ultimate
func ult_charge() -> float:
	var total := _ult_cooldown_for(weapon)
	if total <= 0.0:
		return -1.0
	return 1.0 - clampf(_ult_cd.get(weapon, 0.0) / total, 0.0, 1.0)


func _ult_target() -> Vector2:
	var to := get_global_mouse_position() - global_position
	# the floor is iso: measure reach on an ellipse
	var flat := Vector2(to.x, to.y * 2.0)
	if flat.length() > ult_range:
		flat = flat.normalized() * ult_range
	return global_position + Vector2(flat.x, flat.y * 0.5)


func _handle_ultimate(delta: float) -> void:
	for w in _ult_cd.keys():
		_ult_cd[w] = maxf(_ult_cd[w] - delta, 0.0)
	var has_ult := _ult_cooldown_for(weapon) > 0.0
	if Input.is_action_just_pressed("ultimate"):
		if not has_ult:
			Juice.damage_number(get_parent(), global_position + Vector2(0, -70), "No ultimate on this weapon", Color(0.8, 0.8, 0.85), 14)
		elif _ult_cd.get(weapon, 0.0) > 0.0:
			Juice.damage_number(get_parent(), global_position + Vector2(0, -70), "Ultimate charging: %ds" % ceili(_ult_cd[weapon]), Color(0.8, 0.8, 0.85), 14)
		elif _aim_node == null:
			_aim_node = UltAim.new()
			_aim_node.color = GameState.WEAPONS[weapon].color
			_aim_node.max_range = ult_range
			_aim_node.target_radius = clap_radius if is_storm() else VenomZone.RADIUS
			get_parent().add_child(_aim_node)
	if _aim_node:
		_aim_node.center = global_position
		_aim_node.target = _ult_target()
		if state == State.DEAD:
			_cancel_aim()
		elif not Input.is_action_pressed("ultimate"):
			var at := _ult_target()
			_cancel_aim()
			_cast_ultimate(at)


func _cancel_aim() -> void:
	if _aim_node:
		_aim_node.queue_free()
		_aim_node = null


func _cast_ultimate(at: Vector2) -> void:
	if _ult_cd.get(weapon, 0.0) > 0.0:
		return
	_ult_cd[weapon] = _ult_cooldown_for(weapon)
	_face_mouse()
	if is_storm():
		_thunderclap(at)
	elif is_venom():
		VenomZone.place(get_parent(), at)
		Sfx.play(self, "venom_slam", at, 1.0, 0.05)
		Juice.impact_flash(self, 0.12, Color(0.6, 1.0, 0.45))
	if hud and hud.has_method("set_weapons"):
		hud.set_weapons()


func _ensure_ult_action() -> void:
	if InputMap.has_action("ultimate"):
		return
	InputMap.add_action("ultimate")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_R
	InputMap.action_add_event("ultimate", ev)


## Q: swap hands
func _ensure_swap_action() -> void:
	# Q flips hands, 1 / 2 pick a hand directly
	for pair in [["swap_weapon", KEY_Q], ["weapon_1", KEY_1], ["weapon_2", KEY_2]]:
		if InputMap.has_action(pair[0]):
			continue
		InputMap.add_action(pair[0])
		var ev := InputEventKey.new()
		ev.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0], ev)

## 0..1 for the HUD: 1 = you can swap, lower = still cooling down
func swap_charge() -> float:
	return 1.0 - _swap_cd / maxf(swap_cooldown, 0.01)

func _try_swap() -> void:
	if state == State.DEAD:
		return
	if _swap_cd > 0.0:
		# still cooling down: tell them once in a while, not on every key mash
		if _swap_nag <= 0.0:
			_swap_nag = 0.5
			Juice.damage_number(get_parent(), global_position + Vector2(0, -70), "Swap in %.1fs" % _swap_cd, Color(0.75, 0.75, 0.8), 14)
		return
	_cancel_aim()
	var was_attacking := state == State.ATTACK
	var w := GameState.swap()
	if w == "":
		Juice.damage_number(get_parent(), global_position + Vector2(0, -70), "Other hand is empty", Color(0.8, 0.8, 0.85), 14)
		return
	# swapping mid-swing cancels it, then a short beat before you can swing again
	if was_attacking:
		state = State.MOVE
		combo_queued = false
		_strike_index = -1
		_hit_this_strike.clear()
		swing_fx.visible = false
		animated_sprite.play("idle")
	_attack_lock = swap_attack_delay
	_swap_cd = swap_cooldown
	set_weapon(w)
	var c: Color = GameState.WEAPONS[w].color
	Juice.damage_number(get_parent(), global_position + Vector2(0, -74), GameState.WEAPONS[w].name, c, 18)
	animated_sprite.modulate = Color(c.r * 2.0, c.g * 2.0, c.b * 2.0)
	var tw := create_tween()
	tw.tween_property(animated_sprite, "modulate", Color.WHITE, 0.25)

## whoosh for the blade you're holding
func _swing_sound(heavy: bool = false) -> void:
	var sound := "swing"
	match weapon:
		"storm_blade": sound = "storm_swing"
		"venom_blade": sound = "venom_swing"
	if heavy:
		# the finisher: lower and louder, which also stretches it out longer
		Sfx.play(self, sound, null, 1.5, 0.03, 0.8)
	else:
		Sfx.play(self, sound, null, -2.0)


# ---------------------------------------------------------------- co-op sync

## a teammate's character on your screen: strip out everything that's "you"
func _puppet_ready() -> void:
	add_to_group("remote_player")
	add_to_group("players_all")
	$Camera2D.enabled = false
	$HUD.queue_free()
	hud = null
	aim_indicator.queue_free()
	sword_hitbox.monitoring = false
	collision_layer = 0
	collision_mask = 0
	_iron_fx = swing_fx.sprite_frames
	_net_target = position


## floating name over teammates (and over you, small, so you know which is you)
func show_name_tag(text: String) -> void:
	var l := get_node_or_null("NameTag") as Label
	if l == null:
		l = Label.new()
		l.name = "NameTag"
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_constant_override("outline_size", 5)
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.06))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(120, 16)
		l.position = Vector2(-60, -70)
		l.z_index = 50
		add_child(l)
	l.text = text
	l.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0) if puppet else Color(1, 0.9, 0.5))


## what everyone else needs to draw you (sent ~30 times a second)
func _net_send() -> void:
	var st := [
		position, String(animated_sprite.animation), animated_sprite.frame, animated_sprite.flip_h,
		animated_sprite.visible, animated_sprite.modulate, weapon,
		swing_fx.visible, String(swing_fx.animation), swing_fx.frame, swing_fx.flip_h, swing_fx.rotation,
		int(state), health, max_health,
	]
	rpc("_net_state", st)


@rpc("any_peer", "unreliable_ordered")
func _net_state(st: Array) -> void:
	if not puppet or multiplayer.get_remote_sender_id() != net_id or st.size() < 15:
		return
	_net_target = st[0]
	if not _net_has_target:
		position = _net_target
		_net_has_target = true
	var anim: String = st[1]
	if weapon != st[6]:
		set_weapon(st[6])
	if animated_sprite.sprite_frames.has_animation(anim) and animated_sprite.animation != anim:
		animated_sprite.animation = anim
	animated_sprite.pause()
	animated_sprite.frame = st[2]
	animated_sprite.flip_h = st[3]
	animated_sprite.visible = st[4]
	animated_sprite.modulate = st[5]
	# a teammate's cuts: you hear them too (frames arrive in jumps, so compare to the last one)
	if anim.begins_with("attack") and HIT_WINDOWS.has(anim):
		var last: int = _net_last_frame if anim == _net_last_anim else -1
		if st[2] != last:
			_cut_sound(anim, st[2], last)
	_net_last_anim = anim
	_net_last_frame = st[2]
	swing_fx.visible = st[7]
	if st[7]:
		var sa: String = st[8]
		if swing_fx.sprite_frames.has_animation(sa):
			swing_fx.animation = sa
		swing_fx.pause()
		swing_fx.frame = st[9]
		swing_fx.flip_h = st[10]
		swing_fx.rotation = st[11]
	state = st[12] as State
	health = st[13]
	max_health = st[14]


func _puppet_tick(delta: float) -> void:
	if not _net_has_target:
		return
	# glide toward the last position we heard about; snap if it's way off
	if position.distance_to(_net_target) > 300.0:
		position = _net_target
	else:
		position = position.lerp(_net_target, 1.0 - exp(-18.0 * delta))


func is_venom() -> bool:
	return weapon == "venom_blade"

func is_storm() -> bool:
	return weapon == "storm_blade"

## "12 HITS" counter on the right side of the screen
func _build_combo_label() -> void:
	_combo_label = Label.new()
	_combo_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_combo_label.offset_left = -260
	_combo_label.offset_right = -24
	_combo_label.offset_top = 90
	_combo_label.offset_bottom = 150
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_label.add_theme_font_size_override("font_size", 40)
	_combo_label.add_theme_constant_override("outline_size", 12)
	_combo_label.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.06))
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_label.visible = false
	$HUD.add_child(_combo_label)

func _bump_combo() -> void:
	combo_count += 1
	_combo_timer = combo_timeout
	if combo_count < 2:
		return
	_combo_label.visible = true
	_combo_label.modulate.a = 1.0
	_combo_label.text = "%d HITS" % combo_count
	# hotter colors as the combo climbs
	var heat: float = clamp((combo_count - 2) / 18.0, 0.0, 1.0)
	var col := Color(1, 0.95, 0.4).lerp(Color(1, 0.45, 0.1), clamp(heat * 2.0, 0.0, 1.0))
	if heat > 0.5:
		col = col.lerp(Color(1, 0.15, 0.55), (heat - 0.5) * 2.0)
	_combo_label.add_theme_color_override("font_color", col)
	_combo_label.pivot_offset = Vector2(_combo_label.size.x, _combo_label.size.y / 2.0)
	_combo_label.scale = Vector2(1.7, 1.7)
	_combo_label.rotation = randf_range(-0.12, 0.12)
	var tw := _combo_label.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_combo_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_combo_label, "rotation", 0.0, 0.22)

func _update_combo(delta: float) -> void:
	if combo_count == 0:
		return
	_combo_timer -= delta
	if _combo_timer <= 0.0:
		combo_count = 0
		var tw := _combo_label.create_tween()
		tw.tween_property(_combo_label, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func(): _combo_label.visible = false)

## red glow around the screen edges when you take a hit
func _build_hurt_flash() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.8, 0.0, 0.05, 0.0))
	grad.set_color(1, Color(0.85, 0.0, 0.05, 0.6))
	grad.add_point(0.72, Color(0.85, 0.0, 0.05, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.15, 0.5)
	tex.width = 256
	tex.height = 256
	_hurt_flash = TextureRect.new()
	_hurt_flash.texture = tex
	_hurt_flash.stretch_mode = TextureRect.STRETCH_SCALE
	_hurt_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt_flash.modulate.a = 0.0
	$HUD.add_child(_hurt_flash)
	$HUD.move_child(_hurt_flash, 0)

## remember a press for a moment so early inputs aren't eaten
func _read_inputs(delta: float) -> void:
	_buffer_timer -= delta
	if _buffer_timer <= 0.0:
		_buffered = ""
	if Input.is_action_just_pressed("dodge"):
		_buffered = "dodge"
		_buffer_timer = input_buffer_time
	elif Input.is_action_just_pressed("attack"):
		_buffered = "attack"
		_buffer_timer = input_buffer_time

func _consume(action: String) -> bool:
	if _buffered == action:
		_buffered = ""
		return true
	return false

func _physics_process(delta: float) -> void:
	if puppet:
		_puppet_tick(delta)
		return
	_local_physics(delta)
	if Net.online(get_tree()):
		_net_send_t -= delta
		if _net_send_t <= 0.0:
			_net_send_t = NET_SEND_RATE
			_net_send()


func _local_physics(delta: float) -> void:
	roll_cooldown_timer = max(roll_cooldown_timer - delta, 0.0)
	_swap_cd = maxf(_swap_cd - delta, 0.0)
	_swap_nag = maxf(_swap_nag - delta, 0.0)
	# dash charges slowly refill
	dash_charge = minf(dash_charge + delta / dash_recharge_time, dash_max)
	can_roll = roll_cooldown_timer <= 0.0 and dash_charge >= 1.0
	# pressed dodge with nothing left in the tank: the bar tells you
	if _buffered == "dodge" and dash_charge < 1.0 and roll_cooldown_timer <= 0.0 and state != State.DEAD:
		_consume("dodge")
		hud.deny_dash()
	if invincible_timer > 0.0:
		invincible_timer -= delta
		# blink while invincible
		animated_sprite.visible = state == State.DEAD or int(invincible_timer * 20.0) % 2 == 0
		if invincible_timer <= 0.0:
			animated_sprite.visible = true
	if untargetable_timer > 0.0:
		untargetable_timer -= delta
		if untargetable_timer <= 0.0:
			_phase_in()
	if _paralysis > 0.0:
		_paralysis -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 2400.0 * delta)
		move_and_slide()
		if _paralysis <= 0.0 or state == State.DEAD:
			_paralysis = 0.0
			animated_sprite.modulate = Color.WHITE
			if state != State.DEAD:
				state = State.MOVE
				animated_sprite.play()
		else:
			animated_sprite.modulate = Color(0.7, 1.0, 0.85) if int(_paralysis * 14.0) % 2 == 0 else Color(0.9, 1.3, 1.1)
		return
	_read_inputs(delta)
	if Input.is_action_just_pressed("swap_weapon"):
		_try_swap()
	elif Input.is_action_just_pressed("weapon_1") and GameState.active_slot != 0:
		_try_swap()
	elif Input.is_action_just_pressed("weapon_2") and GameState.active_slot != 1:
		_try_swap()
	_handle_ultimate(delta)
	_attack_lock = maxf(_attack_lock - delta, 0.0)
	_update_combo(delta)

	match state:
		State.MOVE:
			_handle_move(delta)
		State.ROLL:
			_handle_roll(delta)
		State.ATTACK:
			_handle_attack(delta)
		State.BLOCK:
			_handle_block(delta)
		State.HURT:
			velocity = knockback
			knockback = knockback.move_toward(Vector2.ZERO, 1200.0 * delta)
		State.DEAD:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	_update_animation()
	if swing_fx.visible:
		if state != State.ATTACK or swing_fx.animation != animated_sprite.animation:
			swing_fx.visible = false
		elif swing_fx.frame != animated_sprite.frame:
			swing_fx.frame = animated_sprite.frame

func _get_input_dir() -> Vector2:
	return Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	).normalized()

func _handle_move(delta: float) -> void:
	var input_dir := _get_input_dir()

	if input_dir != Vector2.ZERO:
		last_direction = input_dir
		velocity = velocity.move_toward(input_dir * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	if _buffered == "dodge" and can_roll:
		_consume("dodge")
		_start_roll(input_dir)
	elif _consume("attack"):
		_start_attack("attack1")
	elif Input.is_action_pressed("block"):
		_start_block()

## right click (hold). Added at runtime so no Input Map setup is needed.
func _ensure_block_action() -> void:
	if InputMap.has_action("block"):
		return
	InputMap.add_action("block")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("block", ev)

func _start_block() -> void:
	state = State.BLOCK
	_block_time = 0.0
	combo_queued = false
	_face_mouse()
	# guard pose: sword raised (2nd frame of the slash)
	animated_sprite.speed_scale = 1.0
	animated_sprite.flip_h = not facing_right
	animated_sprite.play("attack1")
	animated_sprite.pause()
	animated_sprite.frame = 1
	_guard.visible = true

func _handle_block(delta: float) -> void:
	_block_time += delta
	var input_dir := _get_input_dir()
	velocity = velocity.move_toward(input_dir * speed * block_move_factor, acceleration * delta)
	_face_mouse()
	animated_sprite.flip_h = not facing_right
	_guard.dir = aim_indicator.last_direction
	_guard.perfect = _block_time <= parry_window
	if not Input.is_action_pressed("block"):
		_end_block()
		state = State.MOVE
	elif _buffered == "dodge" and can_roll:
		_consume("dodge")
		_end_block()
		_start_roll(input_dir)
	elif _consume("attack"):
		_end_block()
		_start_attack("attack1")

func _end_block() -> void:
	_guard.visible = false
	animated_sprite.play("idle")

## is a hit coming from in front of the guard?
func _blocks_from(from_position: Vector2) -> bool:
	if state != State.BLOCK:
		return false
	var to_hit := (from_position - global_position).normalized()
	return to_hit.dot(aim_indicator.last_direction) >= cos(deg_to_rad(block_angle))

func _parry(attacker: Node, from_position: Vector2) -> void:
	var dir := (from_position - global_position).normalized()
	var at := global_position + Vector2(0, -12) + dir * 26.0
	if attacker and attacker.has_method("stun"):
		attacker.stun(parry_stun_time)
	Juice.hit_stop(self, 0.2)
	Juice.slow_mo(self, 0.55, 0.35)
	Juice.shake(self, 0.7, dir)
	Juice.zoom_punch(self, 0.1)
	Juice.impact_flash(self, 0.35, Color(0.7, 1.0, 1.0))
	Juice.spark(get_parent(), at, dir, true, Color(0.2, 0.9, 1.0))
	Juice.damage_number(get_parent(), at + Vector2(0, -20), "PARRY!", Color(1, 0.85, 0.3), 34)
	_guard.hit_flash(Color(1, 1, 1))
	_guard.parry_burst()
	invincible_timer = 0.0
	untargetable_timer = maxf(untargetable_timer, 0.35)
	# reward: a little dash back
	dash_charge = minf(dash_charge + 0.5, dash_max)
	_bump_combo()

func _blocked(amount: int, from_position: Vector2) -> void:
	var dir := (from_position - global_position).normalized()
	knockback = -dir * 120.0
	velocity = knockback
	Juice.hit_stop(self, 0.06)
	Juice.shake(self, 0.35, -dir)
	Juice.spark(get_parent(), global_position + Vector2(0, -12) + dir * 26.0, dir, false, Color(0.5, 0.75, 1.0))
	Juice.damage_number(get_parent(), global_position + Vector2(0, -40), "BLOCK", Color(0.6, 0.85, 1.0), 20)
	_guard.hit_flash(Color(1, 1, 1))

func _start_roll(input_dir: Vector2) -> void:
	state = State.ROLL
	roll_timer = roll_duration
	can_roll = false
	roll_cooldown_timer = roll_cooldown
	dash_charge -= 1.0
	combo_queued = false
	# roll in whatever direction is currently held, fallback to last faced direction if standing still
	roll_direction = input_dir if input_dir != Vector2.ZERO else last_direction
	velocity = roll_direction * roll_speed
	# phase out: untargetable until the timer runs out, and pass through monsters
	untargetable_timer = dodge_untargetable_time
	collision_mask = 1
	animated_sprite.modulate = phase_color
	ghost_timer = 0.0
	_spawn_ghost()

func _handle_roll(delta: float) -> void:
	roll_timer -= delta
	ghost_timer -= delta
	if ghost_timer <= 0.0:
		ghost_timer = ghost_interval
		_spawn_ghost()
	if roll_timer <= 0.0:
		state = State.MOVE
		velocity = velocity.limit_length(speed)
		collision_mask = 17   # monsters are solid again
		# you stay phased (untargetable) until untargetable_timer runs out

## leave a glowing copy of the current frame behind that fades out
func _spawn_ghost() -> void:
	var frames := animated_sprite.sprite_frames
	if frames == null or get_parent() == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.flip_h = animated_sprite.flip_h
	ghost.scale = animated_sprite.scale
	ghost.material = _ghost_material
	ghost.modulate = ghost_color
	get_parent().add_child(ghost)
	ghost.global_position = animated_sprite.global_position
	# sort with the world just behind the player
	ghost.z_index = z_index
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, ghost_fade_time)
	tw.parallel().tween_property(ghost, "scale", ghost.scale * 0.92, ghost_fade_time)
	tw.tween_callback(ghost.queue_free)

## snap back from the phased look with a quick bright flash
func _phase_in() -> void:
	animated_sprite.modulate = Color(1.6, 1.9, 2.0, 1.0)
	var tw := create_tween()
	tw.tween_property(animated_sprite, "modulate", Color.WHITE, 0.12)

func _start_attack(anim_name: String) -> void:
	if _attack_lock > 0.0:
		# just swapped weapons: hold the swing, and keep the click queued so it
		# goes off the moment the lockout ends
		if state != State.ROLL:
			state = State.MOVE
		_buffered = "attack"
		_buffer_timer = _attack_lock + 0.05
		return
	state = State.ATTACK
	combo_queued = false
	# swing toward the mouse, not toward where you're walking
	_face_mouse()
	# the sword reaches out toward the aim marker (up, down, diagonal, anywhere)
	var aim: Vector2 = aim_indicator.last_direction
	sword_hitbox.position = aim * sword_reach + Vector2(0, -8)
	_strike_index = -1
	_hit_this_strike.clear()
	_clapped = false
	animated_sprite.speed_scale = 1.0
	animated_sprite.flip_h = not facing_right
	animated_sprite.play(anim_name)
	_play_swing_fx(anim_name, aim)
	# step into the swing
	velocity = aim * (finisher_lunge if anim_name == "attack2" else attack_lunge)

## the pack's own sword swoosh, pulled onto its own layer, scaled up and
## aimed at the marker (snapped to 8 directions so the pixels stay crisp)
func _play_swing_fx(anim_name: String, aim: Vector2) -> void:
	if not swing_fx.sprite_frames.has_animation(anim_name):
		swing_fx.visible = false
		return
	var angle := snappedf(aim.angle(), PI / 4.0)
	# the swoosh is drawn facing right: flip it for the left side instead of
	# rotating it upside down
	if cos(angle) < -0.01:
		swing_fx.flip_h = true
		swing_fx.rotation = wrapf(angle - PI, -PI, PI)
	else:
		swing_fx.flip_h = false
		swing_fx.rotation = angle
	var k := finisher_fx_scale if anim_name == "attack2" else swing_fx_scale
	swing_fx.scale = Vector2(k, k)
	swing_fx.visible = true
	swing_fx.speed_scale = 1.0
	swing_fx.play(anim_name)
	swing_fx.frame = 0

func _handle_attack(delta: float) -> void:
	var input_dir := _get_input_dir()
	velocity = velocity.move_toward(input_dir * speed * attack_move_factor, friction * delta)
	if animated_sprite.animation == "attack1" and _consume("attack"):
		combo_queued = true
	_check_sword_hits()
	# roll cancels a swing
	if _buffered == "dodge" and can_roll:
		_consume("dodge")
		_start_roll(input_dir)

func _on_frame_changed() -> void:
	_check_sword_hits()
	if state == State.ATTACK:
		_cut_sound(String(animated_sprite.animation), animated_sprite.frame, animated_sprite.frame - 1)


## a whoosh the moment each cut starts. attack1 = one cut, attack2 = three cuts,
## and the last cut of attack2 (the finisher) is deeper and heavier
func _cut_sound(anim: String, frame: int, prev_frame: int) -> void:
	var windows: Array = HIT_WINDOWS.get(anim, [])
	for i in windows.size():
		var start: int = windows[i][0] - 1
		if frame >= start and prev_frame < start:
			var finisher := anim == "attack2" and i == windows.size() - 1
			_swing_sound(finisher)
			return

## runs every frame of a swing: anything inside the sword area during a strike window gets hit once
func _check_sword_hits() -> void:
	if state != State.ATTACK:
		return
	var windows: Array = HIT_WINDOWS.get(String(animated_sprite.animation), [])
	var frame := animated_sprite.frame
	var idx := -1
	for i in windows.size():
		if frame >= windows[i][0] and frame <= windows[i][1]:
			idx = i
			break
	if idx != _strike_index:
		_strike_index = idx
		_hit_this_strike.clear()
	if idx < 0:
		return
	var targets: Array = []
	for body in sword_hitbox.get_overlapping_bodies():
		targets.append(body)
	for area in sword_hitbox.get_overlapping_areas():
		targets.append(area.get_parent())  # enemy hurtboxes sit right under the enemy
	for enemy in targets:
		if enemy in _hit_this_strike:
			continue
		if enemy.is_in_group("enemy") and enemy.has_method("take_damage"):
			_hit_this_strike.append(enemy)
			var finisher: bool = idx == windows.size() - 1 and animated_sprite.animation == "attack2"
			# small shove on combo hits so the bat stays in reach, big launch on the finisher
			enemy.take_damage(sword_damage, global_position, 1.3 if finisher else 0.4)
			_on_sword_hit(enemy, finisher)

func _hit_point(e: Node2D) -> Vector2:
	var hb = e.get_node_or_null("Hurtbox")
	return hb.global_position if hb else e.global_position

func _is_dead(e) -> bool:
	return e.get("state") != null and e.state == e.State.DEAD

## lightning jumps from whoever you hit to the next closest enemies
func _chain_lightning(origin: Node2D) -> void:
	var zapped: Array = [origin]
	var from_pos := _hit_point(origin)
	for i in chain_count:
		var best: Node2D = null
		var best_d := chain_range
		for e in get_tree().get_nodes_in_group("enemy"):
			if e in zapped or e in _hit_this_strike or _is_dead(e) or not e.has_method("take_damage"):
				continue
			var d := from_pos.distance_to(_hit_point(e))
			if d < best_d:
				best_d = d
				best = e
		if best == null:
			return
		zapped.append(best)
		var to_pos := _hit_point(best)
		LightningBolt.zap(get_parent(), from_pos, to_pos, 1.4, 0.28)
		best.take_damage(chain_damage, from_pos, 0.25)
		# a little strike lands on them (effect pack 2)
		FxSprite.spawn(get_parent(), "chain_strike", best.global_position, {"z": 35})
		if _is_dead(best):
			Juice.damage_number(get_parent(), to_pos + Vector2(0, -16), "KO!", Color(0.5, 0.85, 1.0), 30)
		else:
			Juice.damage_number(get_parent(), to_pos + Vector2(0, -14), str(chain_damage), Color(0.55, 0.85, 1.0), 22)
		from_pos = to_pos

## Storm ultimate: lightning from the sky where you aimed, hurts and stuns everything in the ring
func _thunderclap(center: Vector2) -> void:
	var aim: Vector2 = (center - global_position).normalized()
	# thunderclap landing in a poison rune = Toxic Storm
	var rune: Node2D = null
	for z in get_tree().get_nodes_in_group("venom_zone"):
		if z.contains(center):
			rune = z
			break
	var tc = Thunderclap.new()
	tc.radius = clap_radius
	get_parent().add_child(tc)
	tc.global_position = center
	Sfx.play(self, "storm_ult", center, 1.0, 0.04)
	Juice.shockwave(self, center, 34.0)
	Juice.impact_flash(self, 0.2, Color(0.6, 0.95, 1.0))
	Juice.shake(self, 0.85, aim)
	Juice.zoom_punch(self, 0.06)
	Juice.hit_stop(self, 0.08)
	for e in get_tree().get_nodes_in_group("enemy"):
		if _is_dead(e) or not e.has_method("take_damage"):
			continue
		var off: Vector2 = e.global_position - center
		# the floor is iso, so the ring is an ellipse
		if Vector2(off.x, off.y * 2.0).length() > clap_radius:
			continue
		var hp := _hit_point(e)
		e.take_damage(clap_damage, center, 0.6)
		LightningBolt.zap(get_parent(), center + Vector2(0, -10), hp, 0.8, 0.2)
		Juice.damage_number(get_parent(), hp + Vector2(0, -14), str(clap_damage), Color(0.55, 0.85, 1.0), 26)
		if not _is_dead(e) and e.has_method("stun") and e.state != e.State.STUNNED:
			e.stun(clap_stun)
	if rune:
		if GameState.has_mastery("tetrodotoxin"):
			_toxic_storm(rune)
		else:
			# you can feel something there, but you don't know how to use it yet
			Juice.damage_number(get_parent(), rune.global_position + Vector2(0, -60), "?", Color(0.6, 1.0, 0.75), 30)


## COMBO "Tetrodotoxin": thunderclap on a poison rune. The rune fires two electric
## waves out both sides, perpendicular to the line from you to the rune. Anything a
## wave passes through is paralyzed (4s, bosses 2s) and takes 30% more damage.
## Each wave travels as far as your ult aim range, measured from the rune. Rune is used up.
func _toxic_storm(rune: Node2D) -> void:
	var c: Vector2 = rune.global_position
	rune.consume()
	# work on the flat floor (undo the iso squash), then turn 90 degrees
	var to_rune := c - global_position
	var flat := Vector2(to_rune.x, to_rune.y * 2.0)
	if flat.length() < 1.0:
		flat = Vector2.from_angle(aim_indicator.last_direction.angle())
	var side := Vector2(-flat.y, flat.x).normalized()
	for s in [side, -side]:
		ToxicWave.fire(get_parent(), c, s, ult_range, paralysis_time)
	var title = ParalysisWave.new()
	get_parent().add_child(title)
	title.global_position = c
	Juice.impact_flash(self, 0.3, Color(0.7, 1.0, 0.8))
	Juice.hit_stop(self, 0.12)
	Juice.shake(self, 0.8)
	Juice.zoom_punch(self, 0.08)


## all the feedback for landing a hit. Everything turned up.
func _on_sword_hit(enemy: Node2D, finisher: bool) -> void:
	var hit_pos: Vector2 = enemy.global_position
	var hurtbox = enemy.get_node_or_null("Hurtbox")
	if hurtbox:
		hit_pos = hurtbox.global_position
	var dir := (hit_pos - global_position).normalized()
	var kill: bool = enemy.get("state") != null and enemy.state == enemy.State.DEAD
	var heavy := finisher or kill
	_bump_combo()
	Sfx.play(self, "hit", hit_pos, 0.0 if heavy else -3.0)
	if is_storm():
		# full lightning strike for finishers and kills, a short crack otherwise
		Sfx.play(self, "storm_zap" if heavy else "storm_crack", hit_pos, -2.0)
	elif is_venom():
		Sfx.play(self, "venom_bubble", hit_pos, -3.0)
	if is_storm():
		_chain_lightning(enemy)
		FxSprite.spawn(get_parent(), "chain_strike", enemy.global_position, {"z": 35})
	elif is_venom() and not kill:
		# every hit stacks poison, the finisher stacks two
		PoisonStatus.apply(enemy, 2 if finisher else 1)
		FxSprite.spawn(get_parent(), "poison_pop", hit_pos, {"scale": 1.0, "z": 35})
	# exit wound: everything blows out the BACK of the target
	var ichor: Color = enemy.get("ichor_color") if enemy.get("ichor_color") != null else Color(0.5, 0.06, 0.32)
	Juice.spark(get_parent(), hit_pos, dir, heavy, ichor)
	Juice.splat(self, enemy.global_position, dir, 5 if kill else (3 if finisher else 2), ichor.darkened(0.2))
	if kill:
		Juice.damage_number(get_parent(), hit_pos + Vector2(0, -18), "KO!", Color(1, 0.25, 0.3), 40)
		Juice.hit_stop(self, hit_stop_kill)
		Juice.shake(self, 0.95, dir)
		Juice.zoom_punch(self, 0.12)
		Juice.impact_flash(self, 0.45)
	elif finisher:
		Juice.damage_number(get_parent(), hit_pos + Vector2(0, -16), str(sword_damage) + "!", Color(1, 0.6, 0.15), 32)
		Juice.hit_stop(self, hit_stop_heavy)
		Juice.shake(self, 0.75, dir)
		Juice.zoom_punch(self, 0.07)
		Juice.impact_flash(self, 0.18)
	else:
		Juice.damage_number(get_parent(), hit_pos + Vector2(0, -14), str(sword_damage), Color(1, 0.92, 0.35), 26)
		Juice.hit_stop(self, hit_stop_light)
		Juice.shake(self, 0.5, dir)
		Juice.zoom_punch(self, 0.03)

func _on_animation_finished() -> void:
	match state:
		State.ATTACK:
			if combo_queued and animated_sprite.animation == "attack1":
				_start_attack("attack2")
			else:
				state = State.MOVE
		State.HURT:
			state = State.MOVE
		State.DEAD:
			# endless maps show a score card instead of sending you home
			if hold_on_death:
				return
			await get_tree().create_timer(1.0).timeout
			Engine.set_meta("arrival_spawn", "Start")
			get_tree().change_scene_to_file(respawn_scene)

## enemies check this so they lose track of you while you're phased out
func is_untargetable() -> bool:
	return untargetable_timer > 0.0 or state == State.ROLL or state == State.DEAD

func take_damage(amount: int, from_position: Vector2, attacker: Node = null) -> void:
	if is_untargetable() or invincible_timer > 0.0:
		return
	if _blocks_from(from_position):
		if _block_time <= parry_window:
			_parry(attacker, from_position)
		else:
			_blocked(amount, from_position)
		return
	if state == State.BLOCK:
		_end_block()
	health = max(health - amount, 0)
	health_changed.emit(health, max_health)
	knockback = (global_position - from_position).normalized() * knockback_strength
	# feel the hit
	Juice.hit_stop(self, hit_stop_hurt)
	Juice.shake(self, 0.85, global_position - from_position)
	Juice.zoom_punch(self, 0.05)
	Juice.impact_flash(self, 0.2, Color(1, 0.1, 0.15))
	_hurt_flash.modulate.a = 0.8
	var tw := create_tween()
	tw.tween_property(_hurt_flash, "modulate:a", 0.0, 0.4)
	animated_sprite.scale = Vector2(2.5, 1.6)
	var sq := create_tween()
	sq.tween_property(animated_sprite, "scale", Vector2(2, 2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if health <= 0:
		state = State.DEAD
		invincible_timer = 0.0
		animated_sprite.visible = true
		animated_sprite.speed_scale = 1.0
		animated_sprite.play("death")
		died.emit()
		return
	state = State.HURT
	invincible_timer = invincible_time
	animated_sprite.speed_scale = 1.0
	animated_sprite.play("hurt")

## nerves locked up by a Tetrodotoxin wave
func paralyze(duration: float) -> void:
	if state == State.DEAD or is_untargetable():
		return
	if state == State.BLOCK:
		_end_block()
	state = State.MOVE
	swing_fx.visible = false
	_paralysis = duration
	animated_sprite.play("idle")
	animated_sprite.pause()
	Juice.damage_number(get_parent(), global_position + Vector2(0, -60), "PARALYZED!", Color(0.6, 1.0, 0.75), 24)
	Juice.shake(self, 0.5)


func heal(amount: int) -> void:
	health = min(health + amount, max_health)
	health_changed.emit(health, max_health)

## You always look toward the mouse, no matter which way you walk.
func _face_mouse() -> void:
	var aim: Vector2 = aim_indicator.last_direction
	# small dead zone so it doesn't flicker when the mouse is straight above/below you
	if aim.x > 0.1:
		facing_right = true
	elif aim.x < -0.1:
		facing_right = false

func _update_animation() -> void:
	if state == State.ATTACK or state == State.HURT or state == State.DEAD or state == State.BLOCK:
		return  # these play out on their own
	_face_mouse()
	animated_sprite.flip_h = not facing_right
	# walking away from where you're looking = backpedal (walk cycle in reverse)
	var facing_sign := 1.0 if facing_right else -1.0
	var backpedal := velocity.x * facing_sign < -10.0
	if state == State.ROLL:
		# no roll animation in the pack, so fast-forward the walk cycle
		_play_anim("walk", 2.5, backpedal)
	elif velocity.length() > 10.0:
		# legs keep up with the move speed (walk cycle was drawn for ~120 px/s)
		_play_anim("walk", speed / 120.0, backpedal)
	else:
		_play_anim("idle", 1.0, false)

func _play_anim(anim_name: String, anim_speed: float, backwards: bool) -> void:
	var frames := animated_sprite.sprite_frames
	if frames and frames.has_animation(anim_name):
		animated_sprite.speed_scale = -anim_speed if backwards else anim_speed
		if animated_sprite.animation != anim_name or not animated_sprite.is_playing():
			animated_sprite.play(anim_name)
