extends Node2D
## The camp hub. Wires up the stations (telecom, seed shop, farm)
## and shows a simple info panel for now. Each station will get its
## real menu later; swap the panel out per station_id when that happens.

const TransferBoard = preload("res://scenes/levels/shared/transfer_board.gd")
const Music = preload("res://scenes/audio/music.gd")

@onready var info_panel: PanelContainer = $UI/InfoPanel
@onready var info_title: Label = $UI/InfoPanel/Margin/VBox/Title
@onready var info_body: Label = $UI/InfoPanel/Margin/VBox/Body

var _open_station: Area2D = null


func _ready() -> void:
	info_panel.visible = false
	for station in get_tree().get_nodes_in_group("hub_station"):
		if station.station_id == "transfer":
			continue  # the transfer board handles itself
		station.interacted.connect(_on_station_interacted)
		station.player_left.connect(_on_station_left)
	TransferBoard.place_player(self)
	Music.ensure(self)


func _on_station_interacted(station: Area2D) -> void:
	if _open_station == station:
		_close_panel()
		return
	_open_station = station
	info_title.text = station.station_name
	info_body.text = station.description
	info_panel.visible = true


func _on_station_left(station: Area2D) -> void:
	if _open_station == station:
		_close_panel()


func _close_panel() -> void:
	_open_station = null
	info_panel.visible = false
