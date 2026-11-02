extends Node
## Online co-op connection. Lives at /root/Net, made at runtime (no autoload).
##   const Net = preload("res://scenes/core/net.gd")
##   Net.get_node_in(tree)      the live Net node (makes it if needed)
##   Net.online(tree)           true while hosting or connected
##   Net.change_scene(tree, path, spawn)   use this instead of change_scene_to_file
##
## Two ways to connect:
##   Steam (the real one): host gets a short join code, friends type it in or
##     accept a Steam invite. Uses Steam's free test app (Spacewar, 480) for now.
##   Local (testing): ENet by address. Blank address = another window on this PC.
##
## Who runs what: the HOST runs the real game. Every player sends their own
## character's state to everyone else, who show it as a "puppet" copy.

signal roster_changed
signal status(text: String)

const PORT := 24565
const MAX_PLAYERS := 4
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const TITLE := "res://scenes/ui/title_screen.tscn"
## Steam's free test app. Swap for the real app ID at release.
const STEAM_APP_ID := 480
const LOBBY_GAME_TAG := "MinersFury"
## no 0/O or 1/I so codes are easy to read out loud
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

## peer id -> {"name": String}
var roster: Dictionary = {}
var my_name: String = "Miner"
## the scene everyone is in (host keeps this so late joiners land in the same place)
var current_scene: String = ""
var in_game: bool = false
## Steam
var steam_ok: bool = false
var steam_error: String = ""
var lobby_id: int = 0
var join_code: String = ""
var _steam = null
var _joining_code: String = ""


static func get_node_in(tree: SceneTree) -> Node:
	var n := tree.root.get_node_or_null("Net")
	if n == null:
		n = load("res://scenes/core/net.gd").new()
		n.name = "Net"
		tree.root.add_child(n)
	return n


static func online(tree: SceneTree) -> bool:
	var mp := tree.get_multiplayer()
	return mp.has_multiplayer_peer() and not (mp.multiplayer_peer is OfflineMultiplayerPeer) \
		and mp.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


static func is_host(tree: SceneTree) -> bool:
	return not online(tree) or tree.get_multiplayer().is_server()


## the one call every scene change should go through
##   offline: just changes scene
##   host: takes everyone along
##   client: refuses (returns false) and says why
static func change_scene(tree: SceneTree, path: String, spawn: String = "Start") -> bool:
	if not online(tree):
		if spawn != "":
			Engine.set_meta("arrival_spawn", spawn)
		tree.change_scene_to_file(path)
		return true
	var n = get_node_in(tree)
	if not tree.get_multiplayer().is_server():
		n.status.emit("Only the host can travel")
		n._toast("Only the host can travel")
		return false
	n.rpc("_load", path, spawn)
	return true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_steam_init()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


# ---------------------------------------------------------------- connect

func host() -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		status.emit("Couldn't host (is another game already hosting?)")
		return err
	multiplayer.multiplayer_peer = peer
	roster = {1: {"name": my_name}}
	roster_changed.emit()
	status.emit("Hosting. Friends join with your address.")
	return OK


func join(address: String) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges() if address.strip_edges() != "" else "127.0.0.1", PORT)
	if err != OK:
		status.emit("Couldn't start connecting")
		return err
	multiplayer.multiplayer_peer = peer
	status.emit("Connecting...")
	return OK


func leave() -> void:
	if _steam and lobby_id != 0:
		_steam.leaveLobby(lobby_id)
	lobby_id = 0
	join_code = ""
	if multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	roster = {}
	in_game = false
	current_scene = ""
	roster_changed.emit()


# ---------------------------------------------------------------- Steam

func _steam_init() -> void:
	if not Engine.has_singleton("Steam"):
		steam_error = "Steam plug-in missing"
		return
	_steam = Engine.get_singleton("Steam")
	var res: Dictionary = _steam.steamInitEx(STEAM_APP_ID, true)
	steam_ok = int(res.get("status", -1)) == 0
	if not steam_ok:
		steam_error = "Steam isn't running (open Steam and log in)"
		return
	my_name = _steam.getPersonaName()
	_steam.lobby_created.connect(_on_lobby_created)
	_steam.lobby_joined.connect(_on_lobby_joined)
	_steam.lobby_match_list.connect(_on_lobby_match_list)
	_steam.join_requested.connect(_on_join_requested)


func host_steam() -> void:
	if not steam_ok:
		status.emit(steam_error)
		return
	leave()
	status.emit("Making a lobby...")
	_steam.createLobby(_steam.LOBBY_TYPE_PUBLIC, MAX_PLAYERS)


func _on_lobby_created(result: int, new_lobby: int) -> void:
	if result != 1:
		status.emit("Steam couldn't make a lobby (error %d)" % result)
		return
	lobby_id = new_lobby
	join_code = ""
	for i in 5:
		join_code += CODE_CHARS[randi() % CODE_CHARS.length()]
	_steam.setLobbyData(lobby_id, "game", LOBBY_GAME_TAG)
	_steam.setLobbyData(lobby_id, "code", join_code)
	_steam.setLobbyData(lobby_id, "host", my_name)
	_steam.setLobbyJoinable(lobby_id, true)
	var peer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err: int = peer.host_with_lobby(lobby_id)
	if err != OK:
		status.emit("Couldn't start hosting (error %d)" % err)
		return
	multiplayer.multiplayer_peer = peer
	roster = {1: {"name": my_name}}
	roster_changed.emit()
	status.emit("Hosting! Your code: %s" % join_code)


## friends type the host's code
func join_steam_code(code: String) -> void:
	if not steam_ok:
		status.emit(steam_error)
		return
	code = code.strip_edges().to_upper()
	if code.length() < 4:
		status.emit("Type the host's code first")
		return
	leave()
	_joining_code = code
	status.emit("Looking for %s..." % code)
	_steam.addRequestLobbyListStringFilter("game", LOBBY_GAME_TAG, _steam.LOBBY_COMPARISON_EQUAL)
	_steam.addRequestLobbyListStringFilter("code", code, _steam.LOBBY_COMPARISON_EQUAL)
	_steam.addRequestLobbyListDistanceFilter(_steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	_steam.addRequestLobbyListResultCountFilter(5)
	_steam.requestLobbyList()


func _on_lobby_match_list(lobbies: Array) -> void:
	if _joining_code == "":
		return
	if lobbies.is_empty():
		status.emit("No game found with code %s" % _joining_code)
		_joining_code = ""
		return
	_joining_code = ""
	status.emit("Found it. Joining...")
	_steam.joinLobby(int(lobbies[0]))


## clicked "Join game" on a friend in Steam, or accepted an invite
func _on_join_requested(lobby: int, _friend: int) -> void:
	leave()
	status.emit("Joining your friend...")
	_steam.joinLobby(lobby)


func _on_lobby_joined(lobby: int, _perms: int, _locked: bool, response: int) -> void:
	if response != _steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		status.emit("Couldn't join (it may be full or closed)")
		return
	lobby_id = lobby
	# the host also gets this for its own lobby: nothing more to do
	if _steam.getLobbyOwner(lobby) == _steam.getSteamID():
		return
	join_code = _steam.getLobbyData(lobby, "code")
	var peer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err: int = peer.connect_to_lobby(lobby)
	if err != OK:
		status.emit("Couldn't connect to the host (error %d)" % err)
		return
	multiplayer.multiplayer_peer = peer
	status.emit("Connecting to %s..." % _steam.getLobbyData(lobby, "host"))


## Steam overlay friend picker (Shift+Tab overlay must be on)
func invite_friends() -> void:
	if _steam and lobby_id != 0:
		_steam.activateGameOverlayInviteDialog(lobby_id)


func player_name(id: int) -> String:
	return str(roster.get(id, {}).get("name", "Miner %d" % id))


# ---------------------------------------------------------------- roster

func _on_connected() -> void:
	status.emit("Connected! Waiting for the host to start.")
	rpc_id(1, "_hello", my_name)


func _on_failed() -> void:
	status.emit("Couldn't reach the host")
	leave()


func _on_server_gone() -> void:
	leave()
	_toast("Host left the game")
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(TITLE)


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		roster.erase(id)
		rpc("_set_roster", roster)
	_remove_puppet(id)


@rpc("any_peer", "reliable")
func _hello(pname: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	roster[id] = {"name": pname.substr(0, 16) if pname.strip_edges() != "" else "Miner %d" % id}
	rpc("_set_roster", roster)
	# game already going: pull them straight in
	if in_game and current_scene != "":
		rpc_id(id, "_load", current_scene, "Start")


@rpc("authority", "call_local", "reliable")
func _set_roster(r: Dictionary) -> void:
	roster = r
	roster_changed.emit()
	if in_game:
		sync_puppets()


## host: everyone into a scene together
func start_game(path: String) -> void:
	if multiplayer.is_server():
		rpc("_load", path, "Start")


@rpc("authority", "call_local", "reliable")
func _load(path: String, spawn: String) -> void:
	in_game = true
	current_scene = path
	get_tree().paused = false
	Engine.time_scale = 1.0
	if spawn != "":
		Engine.set_meta("arrival_spawn", spawn)
	get_tree().change_scene_to_file(path)


# ---------------------------------------------------------------- puppets

## called by the local player once it's in a level: rename it to P<my id>
## (so everyone's copies line up) and make puppets for the others
func local_ready(local: Node2D) -> void:
	in_game = true
	var me := multiplayer.get_unique_id()
	local.name = "P%d" % me
	local.set("net_id", me)
	local.call("show_name_tag", my_name)
	sync_puppets()


func sync_puppets() -> void:
	var local := get_tree().get_first_node_in_group("player") as Node2D
	if local == null:
		return
	var parent := local.get_parent()
	var me := multiplayer.get_unique_id()
	var k := 0
	for id in roster:
		if id == me:
			continue
		k += 1
		var nm := "P%d" % id
		if parent.has_node(nm):
			continue
		var p = load(PLAYER_SCENE).instantiate()
		p.set("puppet", true)
		p.set("net_id", id)
		p.name = nm
		p.position = local.position + Vector2(40 * k, 20 * k)
		parent.add_child(p)
		p.call("show_name_tag", player_name(id))
	# anyone who left
	for c in parent.get_children():
		if c.get("puppet") and not roster.has(int(c.get("net_id"))):
			c.queue_free()


func _remove_puppet(id: int) -> void:
	var cs := get_tree().current_scene
	if cs == null:
		return
	var p := cs.find_child("P%d" % id, true, false)
	if p and p.get("puppet"):
		p.queue_free()


# ---------------------------------------------------------------- little popup

func _toast(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.06))
	l.add_theme_color_override("font_color", Color(1.0, 0.75, 0.6))
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.position = Vector2(-160, 70)
	layer.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(layer.queue_free)
