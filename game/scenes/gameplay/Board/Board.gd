class_name Board
extends Node2D

## Board — View controller for the Scotland Yard board.
## Only manipulates existing nodes placed in the scene tree. NEVER creates nodes at runtime.

signal station_clicked(station_id: int)

@onready var _stations: Node2D = $Stations
@onready var _tokens: Node2D = $Tokens
@onready var _last_seen: LastSeenMarker = $LastSeen
@onready var _vehicles: BoardVehicles = $Vehicles
@onready var _darkness: CanvasModulate = get_node_or_null("Darkness") as CanvasModulate
@onready var _spotlight: Node2D = get_node_or_null("Spotlight") as Node2D
@onready var _spotlight_light: PointLight2D = get_node_or_null("Spotlight/Light") as PointLight2D

const DARKNESS_COLOR: Color = Color(0.62, 0.62, 0.70, 1.0)
## Vehicle sprites are drawn at 2x resolution.
const VEHICLE_SCALE: float = 0.5

var _spotlight_target: Vector2 = Vector2.ZERO
var _spotlight_wobble_time: float = 0.0
@export var spotlight_lag: float = 0.15
var _darkness_tween: Tween = null
var _route_links: Array[Link] = []

func _ensure_nodes() -> void:
	if _stations == null:
		_stations = get_node_or_null("Stations")
	if _tokens == null:
		_tokens = get_node_or_null("Tokens")
	if _last_seen == null:
		_last_seen = get_node_or_null("LastSeen")
	if _vehicles == null:
		_vehicles = get_node_or_null("Vehicles") as BoardVehicles
	if _darkness == null:
		_darkness = get_node_or_null("Darkness") as CanvasModulate
	if _spotlight == null:
		_spotlight = get_node_or_null("Spotlight") as Node2D
	if _spotlight_light == null and _spotlight != null:
		_spotlight_light = _spotlight.get_node_or_null("Light") as PointLight2D

func _ready() -> void:
	_ensure_nodes()
	# Connect click signals from all pre-built station nodes
	if _stations != null:
		for child in _stations.get_children():
			if child is Station:
				child.clicked.connect(_on_station_clicked)

func _on_station_clicked(id: int) -> void:
	station_clicked.emit(id)

## Filters board elements (stations and links) to the specified active stations list.
## Stations outside the active list are hidden and disabled from input.
## Links connecting outside the active region are hidden.
func apply_level_filter(active_station_ids: Array[int]) -> void:
	_ensure_nodes()
	var is_all: bool = active_station_ids.is_empty() or active_station_ids.size() >= 199
	var active_set: Dictionary = {}
	if not is_all:
		for sid in active_station_ids:
			active_set[sid] = true

	# Filter stations
	if _stations != null:
		for child in _stations.get_children():
			if child is Station:
				var is_active: bool = is_all or active_set.has(child.id)
				child.set_active_station(is_active)

	# Filter links
	var links_root := get_node_or_null("Links")
	if links_root != null:
		for group in links_root.get_children():
			for child in group.get_children():
				if child is Link:
					var l := child as Link
					var n_parts := l.name.split("_")
					var is_active: bool = is_all
					if not is_all and n_parts.size() >= 3:
						var a := int(n_parts[1])
						var b := int(n_parts[2])
						is_active = active_set.has(a) and active_set.has(b)
					l.set_active_link(is_active)

func get_station(station_id: int) -> Station:
	_ensure_nodes()
	if _stations == null:
		return null
	return _stations.get_node_or_null("Station_%d" % station_id) as Station

func has_station(station_id: int) -> bool:
	return get_station(station_id) != null

func get_last_seen_node() -> Node:
	_ensure_nodes()
	return _last_seen

func get_spotlight_node() -> Node:
	_ensure_nodes()
	return _spotlight

func get_station_position(station_id: int) -> Vector2:
	var st := get_station(station_id)
	return st.position if st != null else Vector2.ZERO

func set_station_highlight(station_id: int, on: bool) -> void:
	var st := get_station(station_id)
	if st != null:
		st.set_highlighted(on)

func clear_all_highlights() -> void:
	_ensure_nodes()
	clear_routes()
	if _stations == null:
		return
	for child in _stations.get_children():
		if child is Station:
			child.set_highlighted(false)

func highlight_stations(station_ids: Array[int]) -> void:
	clear_all_highlights()
	for sid in station_ids:
		set_station_highlight(sid, true)

## Route preview: lights up the streets/lines from `from_id` to every legal destination,
## coloured by transport. `moves` are legal_moves() entries ({"to", "ticket"}).
func show_routes(from_id: int, moves: Array) -> void:
	clear_routes()
	for m in moves:
		var to_id: int = int(m["to"])
		var ticket: String = str(m["ticket"])
		var types: Array = [ticket] if ticket in ["taxi", "bus", "underground", "ferry"] else ["taxi", "bus", "underground", "ferry"]
		for t in types:
			var l := _find_link(from_id, to_id, t)
			if l != null and not _route_links.has(l):
				l.set_route_highlight(true)
				_route_links.append(l)

func clear_routes() -> void:
	for l in _route_links:
		if is_instance_valid(l):
			l.set_route_highlight(false)
	_route_links.clear()

func get_route_link_count() -> int:
	return _route_links.size()

## Reveals the full Mr. X route on the map for game over
func show_mrx_route(route: Array[int]) -> void:
	highlight_stations(route)
	set_token_visible(0, true)

## Shows Mr. X's gaze spotlight and softly fades in Darkness CanvasModulate
func show_spotlight(initial_pos: Vector2 = Vector2.ZERO) -> void:
	_ensure_nodes()
	if _spotlight == null or _darkness == null:
		return

	if initial_pos != Vector2.ZERO:
		_spotlight_target = initial_pos
		_spotlight.position = initial_pos

	_spotlight.visible = true
	_darkness.visible = true

	if _darkness_tween != null and _darkness_tween.is_valid():
		_darkness_tween.kill()

	_darkness_tween = create_tween()
	_darkness_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_darkness_tween.tween_property(_darkness, "color", DARKNESS_COLOR, 0.35)

## Hides Mr. X's gaze spotlight and restores normal map lighting
func hide_spotlight(immediate: bool = false) -> void:
	_ensure_nodes()
	if _darkness == null or _spotlight == null:
		return

	if _darkness_tween != null and _darkness_tween.is_valid():
		_darkness_tween.kill()

	if immediate:
		_darkness.visible = false
		_darkness.color = Color.WHITE
		_spotlight.visible = false
		return

	_darkness_tween = create_tween()
	_darkness_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_darkness_tween.tween_property(_darkness, "color", Color.WHITE, 0.3)
	_darkness_tween.finished.connect(func():
		if _darkness != null:
			_darkness.visible = false
		if _spotlight != null:
			_spotlight.visible = false
	)

func set_spotlight_target(world_pos: Vector2) -> void:
	_spotlight_target = world_pos

func get_spotlight_position() -> Vector2:
	_ensure_nodes()
	return _spotlight.position if _spotlight != null else Vector2.ZERO

func is_spotlight_visible() -> bool:
	_ensure_nodes()
	return _spotlight != null and _spotlight.visible

func _process(delta: float) -> void:
	if _spotlight != null and _spotlight.visible:
		_spotlight_wobble_time += delta * 2.8
		var wobble := Vector2(
			sin(_spotlight_wobble_time * 1.7) * 32.0,
			cos(_spotlight_wobble_time * 2.2) * 24.0
		)
		var lagged_target := _spotlight_target + wobble
		var lag_factor: float = 1.0 - exp(-delta / spotlight_lag)
		_spotlight.position = _spotlight.position.lerp(lagged_target, lag_factor)

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

## Readability LOD for camera zoom: station pins grow 1.35x when zoomed out (< 0.7)
## so all 199 stations stay readable over the city.
func set_zoom_lod(zoom_factor: float) -> void:
	_ensure_nodes()
	var zoomed_out: bool = (zoom_factor < 0.7)

	if _stations != null:
		var pin_scale: Vector2 = Vector2(1.35, 1.35) if zoomed_out else Vector2(1.0, 1.0)
		for child in _stations.get_children():
			if child is Station:
				child.scale = pin_scale

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
	vehicle_sprite.scale = Vector2.ONE * VEHICLE_SCALE

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
		tween.tween_property(vehicle_sprite, "scale", Vector2(0.85, 1.15) * VEHICLE_SCALE, 0.08)
		tween.tween_property(vehicle_sprite, "scale", Vector2.ONE * VEHICLE_SCALE, 0.08)
	elif is_ferry:
		var route := _ferry_route(from_id, to_id)
		tween.tween_method(func(t: float): _place_on_path(vehicle_sprite, route, t), 0.0, 1.0, duration)
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

## Ferry boats follow the curved ferry link (which bows into the river), in travel direction.
func _ferry_route(from_id: int, to_id: int) -> PackedVector2Array:
	var l := _find_link(from_id, to_id, "ferry")
	if l == null or l.points.size() < 2:
		return PackedVector2Array([get_station_position(from_id), get_station_position(to_id)])
	var pts := l.points
	if pts[0].distance_to(get_station_position(from_id)) > pts[-1].distance_to(get_station_position(from_id)):
		pts.reverse()
	return pts

func _place_on_path(sprite: Node2D, pts: PackedVector2Array, t: float) -> void:
	var f: float = clampf(t, 0.0, 1.0) * (pts.size() - 1)
	var i: int = mini(int(f), pts.size() - 2)
	sprite.position = pts[i].lerp(pts[i + 1], f - i)
	sprite.rotation = (pts[i + 1] - pts[i]).angle()

func _is_ferry_link(a: int, b: int) -> bool:
	return _find_link(a, b, "ferry") != null
