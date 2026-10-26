class_name Board
extends Node2D

## Board — View controller for the Scotland Yard board.
## Only manipulates existing nodes placed in the scene tree. NEVER creates nodes at runtime.

signal station_clicked(station_id: int)

@onready var _stations: Node2D = $Stations
@onready var _tokens: Node2D = $Tokens
@onready var _last_seen: LastSeenMarker = $LastSeen

func _ensure_nodes() -> void:
	if _stations == null:
		_stations = get_node_or_null("Stations")
	if _tokens == null:
		_tokens = get_node_or_null("Tokens")
	if _last_seen == null:
		_last_seen = get_node_or_null("LastSeen")

func _ready() -> void:
	_ensure_nodes()
	# Connect click signals from all pre-built station nodes
	if _stations != null:
		for child in _stations.get_children():
			if child is Station:
				child.clicked.connect(_on_station_clicked)

func _on_station_clicked(id: int) -> void:
	station_clicked.emit(id)

func get_station(station_id: int) -> Station:
	_ensure_nodes()
	if _stations == null:
		return null
	return _stations.get_node_or_null("Station_%d" % station_id) as Station

func get_station_position(station_id: int) -> Vector2:
	var st := get_station(station_id)
	return st.position if st != null else Vector2.ZERO

func set_station_highlight(station_id: int, on: bool) -> void:
	var st := get_station(station_id)
	if st != null:
		st.set_highlighted(on)

func clear_all_highlights() -> void:
	_ensure_nodes()
	if _stations == null:
		return
	for child in _stations.get_children():
		if child is Station:
			child.set_highlighted(false)

func highlight_stations(station_ids: Array[int]) -> void:
	clear_all_highlights()
	for sid in station_ids:
		set_station_highlight(sid, true)

func get_token(player_id: int) -> Token:
	_ensure_nodes()
	if _tokens == null:
		return null
	return _tokens.get_node_or_null("Token_%d" % player_id) as Token

func set_token_position(player_id: int, station_id: int, animate: bool = false) -> void:
	var token := get_token(player_id)
	if token == null:
		return
	var target_pos := get_station_position(station_id)
	if animate:
		token.move_along([target_pos])
	else:
		token.position = target_pos

func set_token_visible(player_id: int, is_vis: bool) -> void:
	var token := get_token(player_id)
	if token != null:
		token.visible = is_vis

func set_last_seen(station_id: int, is_vis: bool) -> void:
	_ensure_nodes()
	if _last_seen == null:
		return
	if is_vis:
		var target_pos := get_station_position(station_id)
		_last_seen.show_at(target_pos)
	else:
		_last_seen.hide_marker()
