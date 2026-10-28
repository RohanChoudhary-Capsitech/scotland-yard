class_name MapData
extends RefCounted

## MapData — Scotland Yard graph data and pathfinding utilities.
## Loads res://game/assets/data/map.json and provides graph lookups.

var stations: Dictionary = {}         # station_id (int) -> Vector2
var adjacency: Dictionary = {}        # station_id (int) -> Array[Dictionary] ({"to": int, "type": String})
var start_stations: Array[int] = []   # Array of 18 starting station IDs
var _all_pairs_dist: Dictionary = {}  # station_a (int) -> {station_b (int): dist (int)}
var _central_ug_stations: Array[int] = [] # Cached central underground station IDs

func _init(path: String = "res://game/assets/data/map.json") -> void:
	if not path.is_empty():
		load_from_file(path)

func load_from_file(
	path: String = "res://game/assets/data/map.json",
	station_subset: Array = [],
	custom_start_stations: Array = []
) -> bool:
	if not FileAccess.file_exists(path):
		push_error("MapData: file does not exist: %s" % path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("MapData: failed to open file: %s" % path)
		return false

	var text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("MapData: failed to parse JSON in %s: error %s" % [path, json.get_error_message()])
		return false

	var data = json.data
	if not (data is Dictionary):
		push_error("MapData: root JSON is not a Dictionary in %s" % path)
		return false

	stations.clear()
	adjacency.clear()
	start_stations.clear()

	var subset_lookup: Dictionary = {}
	if not station_subset.is_empty():
		for sid_val in station_subset:
			subset_lookup[int(sid_val)] = true

	# 1. Parse stations
	var raw_stations: Array = data.get("stations", [])
	for s in raw_stations:
		if s is Dictionary:
			var sid: int = int(s.get("id", 0))
			if not subset_lookup.is_empty() and not subset_lookup.has(sid):
				continue
			var x: float = float(s.get("x", 0.0))
			var y: float = float(s.get("y", 0.0))
			stations[sid] = Vector2(x, y)
			if not adjacency.has(sid):
				adjacency[sid] = []

	# 2. Parse links
	var raw_links: Array = data.get("links", [])
	for link in raw_links:
		if link is Dictionary:
			var a: int = int(link.get("a", 0))
			var b: int = int(link.get("b", 0))
			if not subset_lookup.is_empty() and (not subset_lookup.has(a) or not subset_lookup.has(b)):
				continue

			var type_str: String = str(link.get("type", "taxi"))

			if not adjacency.has(a):
				adjacency[a] = []
			if not adjacency.has(b):
				adjacency[b] = []

			adjacency[a].append({"to": b, "type": type_str})
			adjacency[b].append({"to": a, "type": type_str})

	# 3. Parse start stations
	var raw_starts: Array = data.get("start_stations", [])
	if not custom_start_stations.is_empty():
		for sid in custom_start_stations:
			start_stations.append(int(sid))
	elif not subset_lookup.is_empty():
		for sid in raw_starts:
			if subset_lookup.has(int(sid)):
				start_stations.append(int(sid))
		if start_stations.is_empty():
			for sid in stations.keys():
				start_stations.append(int(sid))
	else:
		for sid in raw_starts:
			start_stations.append(int(sid))

	# 4. Precompute all-pairs shortest path distances (unrestricted by transport type)
	_compute_all_pairs_distances()

	# 5. Cache central underground stations
	_cache_central_underground_stations()

	return true

## Loads a level definition by ID from levels.json, filtering the graph to the level's region.
func load_level(
	level_id: String,
	levels_path: String = "res://game/assets/data/levels.json",
	map_path: String = "res://game/assets/data/map.json"
) -> bool:
	if level_id.is_empty() or level_id == "city":
		return load_from_file(map_path)

	if not FileAccess.file_exists(levels_path):
		push_error("MapData: levels file does not exist: %s" % levels_path)
		return load_from_file(map_path)

	var file := FileAccess.open(levels_path, FileAccess.READ)
	if file == null:
		return load_from_file(map_path)

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return load_from_file(map_path)

	var data: Dictionary = json.data as Dictionary
	if not data.has(level_id):
		push_warning("MapData: level '%s' not found in %s, falling back to full map" % [level_id, levels_path])
		return load_from_file(map_path)

	var lvl: Dictionary = data[level_id] as Dictionary
	var sub_stations: Array = lvl.get("stations", [])
	var starts: Array = lvl.get("start_stations", [])
	return load_from_file(map_path, sub_stations, starts)

## Returns the bounding box of all currently loaded stations, with optional margin.
func get_bounding_box(margin: float = 0.0) -> Rect2:
	if stations.is_empty():
		return Rect2(-100.0, -100.0, 2600.0, 2000.0)
	var min_p := Vector2(999999.0, 999999.0)
	var max_p := Vector2(-999999.0, -999999.0)
	for sid in stations.keys():
		var p: Vector2 = stations[sid]
		min_p.x = minf(min_p.x, p.x)
		min_p.y = minf(min_p.y, p.y)
		max_p.x = maxf(max_p.x, p.x)
		max_p.y = maxf(max_p.y, p.y)
	return Rect2(
		min_p - Vector2(margin, margin),
		(max_p - min_p) + Vector2(margin * 2.0, margin * 2.0)
	)

func get_station_position(station_id: int) -> Vector2:
	return stations.get(station_id, Vector2.ZERO)

func _compute_all_pairs_distances() -> void:
	_all_pairs_dist.clear()
	for s_id in stations.keys():
		var sid: int = int(s_id)
		var dists: Dictionary = {sid: 0}
		var queue: Array[int] = [sid]
		while not queue.is_empty():
			var curr: int = queue.pop_front()
			var cur_d: int = dists[curr]
			for link in adjacency.get(curr, []):
				var nxt: int = int(link["to"])
				if not dists.has(nxt):
					dists[nxt] = cur_d + 1
					queue.append(nxt)
		_all_pairs_dist[sid] = dists

func _cache_central_underground_stations() -> void:
	_central_ug_stations.clear()
	var ug_stations: Dictionary = {}
	for sid in stations.keys():
		for link in adjacency.get(sid, []):
			if link.get("type", "") == "underground":
				ug_stations[sid] = true
				break

	if ug_stations.is_empty():
		return

	var bbox := get_bounding_box()
	var map_center := bbox.get_center()
	var max_dist: float = maxf(bbox.size.x, bbox.size.y) * 0.45
	for sid in ug_stations.keys():
		var pos: Vector2 = stations.get(sid, Vector2.ZERO)
		if pos.distance_to(map_center) <= max_dist:
			_central_ug_stations.append(sid)
	if _central_ug_stations.is_empty():
		for sid in ug_stations.keys():
			_central_ug_stations.append(sid)
	_central_ug_stations.sort()

func has_station(station_id: int) -> bool:
	return stations.has(station_id)

func get_station_pos(station_id: int) -> Vector2:
	return stations.get(station_id, Vector2.ZERO)

func get_links_from(station_id: int) -> Array:
	return adjacency.get(station_id, [])

func get_start_stations() -> Array[int]:
	return start_stations.duplicate()

func get_central_underground_stations() -> Array[int]:
	return _central_ug_stations.duplicate()

## Returns shortest path distance (hop count) from station a to b.
## If transport_type is specified (e.g. "taxi"), only links of that type are traversed.
## Returns -1 if unreachable.
func bfs_distance(a: int, b: int, transport_type: String = "") -> int:
	if a == b:
		return 0
	if not adjacency.has(a) or not adjacency.has(b):
		return -1

	# Fast-path: precomputed all-pairs lookup for general graph distance
	if transport_type.is_empty():
		var row: Dictionary = _all_pairs_dist.get(a, {})
		return row.get(b, -1)

	var visited: Dictionary = {a: 0}
	var queue: Array[int] = [a]

	while not queue.is_empty():
		var curr: int = queue.pop_front()
		var cur_d: int = visited[curr]

		for link in adjacency.get(curr, []):
			var l_type: String = link["type"]
			if not transport_type.is_empty() and l_type != transport_type:
				continue
			var nxt: int = link["to"]
			if not visited.has(nxt):
				visited[nxt] = cur_d + 1
				if nxt == b:
					return cur_d + 1
				queue.append(nxt)

	return -1

## Returns a Dictionary {station_id: distance_int} from given station.
func distances_from(station: int, transport_type: String = "") -> Dictionary:
	if not adjacency.has(station):
		return {}

	# Fast-path: precomputed lookup for general graph distance
	if transport_type.is_empty() and _all_pairs_dist.has(station):
		return _all_pairs_dist[station].duplicate()

	var distances: Dictionary = {}
	distances[station] = 0
	var queue: Array[int] = [station]

	while not queue.is_empty():
		var curr: int = queue.pop_front()
		var cur_d: int = distances[curr]

		for link in adjacency.get(curr, []):
			var l_type: String = link["type"]
			if not transport_type.is_empty() and l_type != transport_type:
				continue
			var nxt: int = link["to"]
			if not distances.has(nxt):
				distances[nxt] = cur_d + 1
				queue.append(nxt)

	return distances
