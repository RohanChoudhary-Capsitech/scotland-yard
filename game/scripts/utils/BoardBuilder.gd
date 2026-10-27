class_name BoardBuilder
extends RefCounted

## BoardBuilder — generates and saves Board.tscn from map.json.
## - Background: baked 3D city tiles (see CityRenderer.gd; run that first after changing map.json)
## - Links: taxi/bus links are invisible route-preview overlays (the roads are in the background),
##   metro lines are pink dashed, ferry routes are white dotted curves on the river
## - Stations, Vehicles, Tokens, LastSeen marker, Darkness and Spotlight
## Run from the editor via BuildBoard.gd, or headless:
##   godot --headless --path . -s res://game/scripts/utils/BuildBoardHeadless.gd

const MAP_PATH := "res://game/assets/data/map.json"
const TARGET_SCENE_PATH := "res://game/scenes/gameplay/Board/Board.tscn"

const STATION_SCENE_PATH := "res://game/scenes/gameplay/Board/Station.tscn"
const LINK_SCENE_PATH := "res://game/scenes/gameplay/Board/Link.tscn"
const TOKEN_SCENE_PATH := "res://game/scenes/gameplay/Board/Token.tscn"
const LAST_SEEN_SCENE_PATH := "res://game/scenes/gameplay/Board/LastSeen.tscn"
const BOARD_SCRIPT_PATH := "res://game/scenes/gameplay/Board/Board.gd"
const VEHICLES_SCENE_PATH := "res://game/scenes/gameplay/Board/Vehicles.tscn"


## Must match CityRenderer.gd (AREA, px_per_unit, TILES_X/Y, RIVER_OFFSET).
const CITY_TILE_DIR := "res://game/assets/sprites/backgrounds/city"
const CITY_AREA := Rect2(-400.0, -400.0, 3200.0, 2600.0)
const CITY_PX_PER_UNIT := 1.25
const CITY_TILES := Vector2i(2, 2)
const RIVER_OFFSET := 52.0

## Ferry routes bow down into the river, which runs RIVER_OFFSET below the ferry piers.
static func ferry_route(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var dip := Vector2(0.0, RIVER_OFFSET)
	for i in 13:
		var t := float(i) / 12.0
		pts.append(a.lerp(b, t) + dip * sin(PI * t) * 1.15)
	return pts

static func build_board_scene() -> bool:
	print("BuildBoard: Reading %s..." % MAP_PATH)
	if not FileAccess.file_exists(MAP_PATH):
		printerr("BuildBoard: map.json not found at %s" % MAP_PATH)
		return false

	var file := FileAccess.open(MAP_PATH, FileAccess.READ)
	var text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		printerr("BuildBoard: Failed to parse map.json: %s" % json.get_error_message())
		return false

	var data: Dictionary = json.data
	var raw_stations: Array = data.get("stations", [])
	var raw_links: Array = data.get("links", [])

	print("BuildBoard: Found %d stations, %d links" % [raw_stations.size(), raw_links.size()])

	var station_scene: PackedScene = load(STATION_SCENE_PATH)
	var link_scene: PackedScene = load(LINK_SCENE_PATH)
	var token_scene: PackedScene = load(TOKEN_SCENE_PATH)
	var last_seen_scene: PackedScene = load(LAST_SEEN_SCENE_PATH)
	var vehicles_scene: PackedScene = load(VEHICLES_SCENE_PATH)
	var board_script: Script = load(BOARD_SCRIPT_PATH)

	# 1. Root Board Node
	var board := Node2D.new()
	board.name = "Board"
	board.set_script(board_script)

	# 2. Background: baked 3D city tiles from CityRenderer (Layer 0, drawn under everything)
	var bg := Node2D.new()
	bg.name = "Background"
	bg.z_index = 0
	bg.z_as_relative = false
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS # smooth when zoomed out
	board.add_child(bg)
	bg.owner = board
	var tile_world := CITY_AREA.size / Vector2(CITY_TILES)
	for ty in CITY_TILES.y:
		for tx in CITY_TILES.x:
			var tile := Sprite2D.new()
			tile.name = "Tile_%d_%d" % [tx, ty]
			tile.texture = load("%s/City_%d_%d.png" % [CITY_TILE_DIR, tx, ty])
			tile.centered = false
			tile.position = CITY_AREA.position + tile_world * Vector2(tx, ty)
			tile.scale = Vector2.ONE / CITY_PX_PER_UNIT
			bg.add_child(tile)
			tile.owner = board

	# 3. Links Node + Groups
	var links_root := Node2D.new()
	links_root.name = "Links"
	board.add_child(links_root)
	links_root.owner = board

	# Roads (Bus then Taxi)
	var group_bus := Node2D.new()
	group_bus.name = "Bus"
	group_bus.z_index = 10
	group_bus.z_as_relative = false
	links_root.add_child(group_bus)
	group_bus.owner = board

	var group_taxi := Node2D.new()
	group_taxi.name = "Taxi"
	group_taxi.z_index = 20
	group_taxi.z_as_relative = false
	links_root.add_child(group_taxi)
	group_taxi.owner = board

	# Metro lines + Ferry route (Layer 40)
	var group_ug := Node2D.new()
	group_ug.name = "Underground"
	group_ug.z_index = 40
	group_ug.z_as_relative = false
	links_root.add_child(group_ug)
	group_ug.owner = board

	var group_ferry := Node2D.new()
	group_ferry.name = "Ferry"
	group_ferry.z_index = 40
	group_ferry.z_as_relative = false
	links_root.add_child(group_ferry)
	group_ferry.owner = board

	# Map station coordinates and transit flags
	var station_positions: Dictionary = {}
	var station_transports: Dictionary = {}

	for s in raw_stations:
		var sid: int = int(s["id"])
		var pos := Vector2(float(s["x"]), float(s["y"]))
		station_positions[sid] = pos
		station_transports[sid] = {"taxi": false, "bus": false, "underground": false, "ferry": false}

	# Instantiate Links
	for l in raw_links:
		var a: int = int(l["a"])
		var b: int = int(l["b"])
		var ltype: String = str(l.get("type", "taxi"))

		if station_transports.has(a) and station_transports[a].has(ltype):
			station_transports[a][ltype] = true
		if station_transports.has(b) and station_transports[b].has(ltype):
			station_transports[b][ltype] = true

		var pos_a: Vector2 = station_positions.get(a, Vector2.ZERO)
		var pos_b: Vector2 = station_positions.get(b, Vector2.ZERO)

		var link_instance: Link = link_scene.instantiate()
		link_instance.name = "Link_%d_%d_%s" % [a, b, ltype]
		link_instance.type = ltype
		link_instance.set_endpoints(pos_a, pos_b)
		if ltype == "ferry":
			link_instance.points = ferry_route(pos_a, pos_b)

		var target_group: Node2D = group_taxi
		match ltype:
			"underground":
				target_group = group_ug
			"bus":
				target_group = group_bus
			"taxi":
				target_group = group_taxi
			"ferry":
				target_group = group_ferry

		target_group.add_child(link_instance)
		link_instance.owner = board

	# 5. Stations (Layer 50)
	var stations_root := Node2D.new()
	stations_root.name = "Stations"
	stations_root.z_index = 50
	stations_root.z_as_relative = false
	board.add_child(stations_root)
	stations_root.owner = board

	for s in raw_stations:
		var sid: int = int(s["id"])
		var pos: Vector2 = station_positions[sid]
		var tr: Dictionary = station_transports[sid]

		var station_instance: Station = station_scene.instantiate()
		station_instance.name = "Station_%d" % sid
		station_instance.position = pos
		station_instance.id = sid
		station_instance.has_taxi = tr.get("taxi", false)
		station_instance.has_bus = tr.get("bus", false)
		station_instance.has_underground = tr.get("underground", false)
		station_instance.has_ferry = tr.get("ferry", false)

		stations_root.add_child(station_instance)
		station_instance.owner = board

	# 6. Vehicles (Layer 60)
	var vehicles_instance: Node2D = vehicles_scene.instantiate()
	vehicles_instance.name = "Vehicles"
	vehicles_instance.z_index = 60
	vehicles_instance.z_as_relative = false
	board.add_child(vehicles_instance)
	vehicles_instance.owner = board

	# 7. Tokens (Layer 70)
	var tokens_root := Node2D.new()
	tokens_root.name = "Tokens"
	tokens_root.z_index = 70
	tokens_root.z_as_relative = false
	board.add_child(tokens_root)
	tokens_root.owner = board

	for i in range(6):
		var token_instance: Token = token_scene.instantiate()
		token_instance.name = "Token_%d" % i
		token_instance.player_id = i
		token_instance.visible = false
		tokens_root.add_child(token_instance)
		token_instance.owner = board

	# 8. LastSeen Marker (Layer 80)
	var last_seen_instance: LastSeenMarker = last_seen_scene.instantiate()
	last_seen_instance.name = "LastSeen"
	last_seen_instance.z_index = 80
	last_seen_instance.z_as_relative = false
	last_seen_instance.visible = false
	board.add_child(last_seen_instance)
	last_seen_instance.owner = board

	# 9. Darkness (CanvasModulate, hidden by default)
	var darkness := CanvasModulate.new()
	darkness.name = "Darkness"
	darkness.color = Color.WHITE
	darkness.visible = false
	board.add_child(darkness)
	darkness.owner = board

	# 10. Spotlight (Node2D on top of tokens, Layer 90)
	var spotlight := Node2D.new()
	spotlight.name = "Spotlight"
	spotlight.z_index = 90
	spotlight.z_as_relative = false
	spotlight.visible = false
	spotlight.position = Vector2(1200.0, 900.0)
	board.add_child(spotlight)
	spotlight.owner = board

	var point_light := PointLight2D.new()
	point_light.name = "Light"
	point_light.texture = load("res://game/assets/sprites/single/shared/spotlight_gradient.png")
	point_light.texture_scale = 1.4 # Radius ≈ 5–7 stations, wide enough to hide which one Mr. X is on
	point_light.energy = 1.6
	point_light.blend_mode = PointLight2D.BLEND_MODE_ADD
	spotlight.add_child(point_light)
	point_light.owner = board

	# 11. Pack and Save Scene
	var packed := PackedScene.new()
	var pack_err := packed.pack(board)
	if pack_err != OK:
		printerr("BuildBoard: Failed to pack scene: %d" % pack_err)
		board.free()
		return false

	var save_err := ResourceSaver.save(packed, TARGET_SCENE_PATH)
	board.free()

	if save_err != OK:
		printerr("BuildBoard: Failed to save scene to %s: %d" % [TARGET_SCENE_PATH, save_err])
		return false

	print("BuildBoard: Successfully built and saved %s with illustrated art!" % TARGET_SCENE_PATH)
	return true
