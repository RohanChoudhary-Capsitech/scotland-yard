@tool
class_name BuildBoard
extends EditorScript

## BuildBoard — EditorScript to generate and save Board.tscn from map.json.
## Run in Godot Editor via: Script Editor -> File -> Run (Ctrl+Shift+X).

const MAP_PATH := "res://game/assets/data/map.json"
const TARGET_SCENE_PATH := "res://game/scenes/gameplay/Board/Board.tscn"

const STATION_SCENE_PATH := "res://game/scenes/gameplay/Board/Station.tscn"
const LINK_SCENE_PATH := "res://game/scenes/gameplay/Board/Link.tscn"
const TOKEN_SCENE_PATH := "res://game/scenes/gameplay/Board/Token.tscn"
const LAST_SEEN_SCENE_PATH := "res://game/scenes/gameplay/Board/LastSeen.tscn"
const BOARD_SCRIPT_PATH := "res://game/scenes/gameplay/Board/Board.gd"

func _run() -> void:
	build_board_scene()

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
	var board_script: Script = load(BOARD_SCRIPT_PATH)

	# 1. Root Board Node
	var board := Node2D.new()
	board.name = "Board"
	board.set_script(board_script)

	# 2. Links Node + Groups
	var links_root := Node2D.new()
	links_root.name = "Links"
	board.add_child(links_root)
	links_root.owner = board

	var group_ug := Node2D.new()
	group_ug.name = "Underground"
	links_root.add_child(group_ug)
	group_ug.owner = board

	var group_bus := Node2D.new()
	group_bus.name = "Bus"
	links_root.add_child(group_bus)
	group_bus.owner = board

	var group_taxi := Node2D.new()
	group_taxi.name = "Taxi"
	links_root.add_child(group_taxi)
	group_taxi.owner = board

	var group_ferry := Node2D.new()
	group_ferry.name = "Ferry"
	links_root.add_child(group_ferry)
	group_ferry.owner = board

	# Map station coordinates and transit flags
	var station_positions: Dictionary = {}
	var station_transports: Dictionary = {} # sid -> {"taxi": bool, "bus": bool, "underground": bool}

	for s in raw_stations:
		var sid: int = int(s["id"])
		var pos := Vector2(float(s["x"]), float(s["y"]))
		station_positions[sid] = pos
		station_transports[sid] = {"taxi": false, "bus": false, "underground": false}

	# 3. Create Links
	var link_idx: int = 0
	for l in raw_links:
		link_idx += 1
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

	# 4. Create Stations
	var stations_root := Node2D.new()
	stations_root.name = "Stations"
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

		stations_root.add_child(station_instance)
		station_instance.owner = board

	# 5. Create Tokens (6 tokens: Mr. X = 0, Detectives = 1..5)
	var tokens_root := Node2D.new()
	tokens_root.name = "Tokens"
	board.add_child(tokens_root)
	tokens_root.owner = board

	for i in range(6):
		var token_instance: Token = token_scene.instantiate()
		token_instance.name = "Token_%d" % i
		token_instance.player_id = i
		token_instance.visible = false
		tokens_root.add_child(token_instance)
		token_instance.owner = board

	# 6. Create LastSeen Marker
	var last_seen_instance: LastSeenMarker = last_seen_scene.instantiate()
	last_seen_instance.name = "LastSeen"
	last_seen_instance.visible = false
	board.add_child(last_seen_instance)
	last_seen_instance.owner = board

	# 7. Pack and Save Scene
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

	print("BuildBoard: Successfully built and saved %s!" % TARGET_SCENE_PATH)
	return true
