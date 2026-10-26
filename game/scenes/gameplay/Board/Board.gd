class_name Board
extends Node2D

## Board — View controller for the Scotland Yard board.
## Only manipulates existing nodes placed in the scene tree. NEVER creates nodes at runtime.

signal station_clicked(station_id: int)

@onready var _stations: Node2D = $Stations
@onready var _tokens: Node2D = $Tokens
@onready var _last_seen: LastSeenMarker = $LastSeen
@onready var _vehicles: BoardVehicles = $Vehicles

func _ensure_nodes() -> void:
	if _stations == null:
		_stations = get_node_or_null("Stations")
	if _tokens == null:
		_tokens = get_node_or_null("Tokens")
	if _last_seen == null:
		_last_seen = get_node_or_null("LastSeen")
	if _vehicles == null:
		_vehicles = get_node_or_null("Vehicles") as BoardVehicles

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

func get_vehicles() -> BoardVehicles:
	_ensure_nodes()
	return _vehicles

## Animates a vehicle moving along the transit link between stations.
## Reuses existing pre-placed vehicle nodes without creating anything at runtime.
func play_move(player_index: int, from_id: int, to_id: int, ticket: String) -> void:
	_ensure_nodes()
	var from_pos := get_station_position(from_id)
	var to_pos := get_station_position(to_id)
	if from_pos == Vector2.ZERO or to_pos == Vector2.ZERO or _vehicles == null or not is_inside_tree():
		set_token_position(player_index, to_id, false)
		return

	_vehicles.hide_all()

	var dir: Vector2 = to_pos - from_pos
	var angle: float = dir.angle()

	var vehicle_sprite: Sprite2D = _vehicles.get_vehicle(ticket)
	var duration: float = 0.6
	var is_underground: bool = (ticket == "underground")
	var is_bus: bool = (ticket == "bus")
	var is_ferry: bool = (ticket == "ferry")
	var is_shadow_car: bool = false

	if ticket == "black":
		if _is_ferry_link(from_id, to_id):
			vehicle_sprite = _vehicles.ferry
			is_ferry = true
			duration = 0.85
		else:
			vehicle_sprite = _vehicles.taxi
			is_shadow_car = true
			duration = 0.6
	elif is_bus:
		duration = 0.8
	elif is_underground:
		duration = 0.5
	elif is_ferry:
		duration = 0.85

	if vehicle_sprite == null:
		set_token_position(player_index, to_id, false)
		return

	# Hide moving token while vehicle travels
	var token := get_token(player_index)
	var token_was_visible: bool = (token != null and token.visible)
	if token != null:
		token.visible = false

	# Position and orient vehicle
	vehicle_sprite.position = from_pos
	vehicle_sprite.rotation = angle
	vehicle_sprite.visible = true
	vehicle_sprite.scale = Vector2.ONE

	if is_shadow_car:
		vehicle_sprite.modulate = Color(0.2, 0.2, 0.25, 0.9)
	elif is_underground:
		vehicle_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	else:
		vehicle_sprite.modulate = Color.WHITE

	# Underground link glow effect
	var glowing_link: Link = null
	var original_link_color: Color = Color.WHITE
	var original_link_width: float = 7.0
	if is_underground:
		glowing_link = _find_link(from_id, to_id, "underground")
		if glowing_link != null:
			original_link_color = glowing_link.default_color
			original_link_width = glowing_link.width
			glowing_link.default_color = Color(1.0, 0.6, 0.85, 1.0)
			glowing_link.width = original_link_width + 3.0

	# Water wake particles for ferry
	if is_ferry and _vehicles.wake != null:
		_vehicles.wake.emitting = true

	# Drive tween
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)

	if is_underground:
		# Underground feel: fade in fast to 60% opacity, drive, fade out
		tween.tween_property(vehicle_sprite, "modulate:a", 0.6, 0.1)
		tween.parallel().tween_property(vehicle_sprite, "position", to_pos, duration)
		tween.tween_property(vehicle_sprite, "modulate:a", 0.0, 0.15)
	elif is_bus:
		# Bus drive + small brake squash at arrival
		tween.tween_property(vehicle_sprite, "position", to_pos, duration)
		tween.tween_property(vehicle_sprite, "scale", Vector2(0.85, 1.15), 0.08)
		tween.tween_property(vehicle_sprite, "scale", Vector2(1.0, 1.0), 0.08)
	else:
		tween.tween_property(vehicle_sprite, "position", to_pos, duration)

	await tween.finished

	# Stop wake particles
	if is_ferry and _vehicles.wake != null:
		_vehicles.wake.emitting = false

	# Restore underground link glow
	if glowing_link != null:
		var link_fade := create_tween()
		link_fade.tween_property(glowing_link, "default_color", original_link_color, 0.2)
		link_fade.parallel().tween_property(glowing_link, "width", original_link_width, 0.2)

	# Fade out vehicle
	if not is_underground:
		var fade_tween := create_tween()
		fade_tween.tween_property(vehicle_sprite, "modulate:a", 0.0, 0.12)
		await fade_tween.finished

	_vehicles.hide_all()

	# Pop player token back in at destination with "bob" animation
	set_token_position(player_index, to_id, false)
	if token != null and token_was_visible:
		token.visible = true
		token.play_anim("bob")

func _find_link(from_id: int, to_id: int, ltype: String) -> Link:
	var links_root := get_node_or_null("Links")
	if links_root == null:
		return null

	var group_name: String = "Taxi"
	match ltype:
		"underground": group_name = "Underground"
		"bus": group_name = "Bus"
		"ferry": group_name = "Ferry"
		_: group_name = "Taxi"

	var group := links_root.get_node_or_null(group_name) as Node2D
	if group == null:
		return null

	var n1 := "Link_%d_%d_%s" % [from_id, to_id, ltype]
	var n2 := "Link_%d_%d_%s" % [to_id, from_id, ltype]
	var l := group.get_node_or_null(n1) as Link
	if l == null:
		l = group.get_node_or_null(n2) as Link
	return l

func _is_ferry_link(a: int, b: int) -> bool:
	return _find_link(a, b, "ferry") != null
