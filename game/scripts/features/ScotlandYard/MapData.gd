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

func load_from_file(path: String = "res://game/assets/data/map.json") -> bool:
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

	# 1. Parse stations
	var raw_stations: Array = data.get("stations", [])
	for s in raw_stations:
		if s is Dictionary:
			var sid: int = int(s.get("id", 0))
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
			var type_str: String = str(link.get("type", "taxi"))

			if not adjacency.has(a):
				adjacency[a] = []
			if not adjacency.has(b):
				adjacency[b] = []

			adjacency[a].append({"to": b, "type": type_str})
			adjacency[b].append({"to": a, "type": type_str})

	# 3. Parse start stations
	var raw_starts: Array = data.get("start_stations", [])
	for sid in raw_starts:
		start_stations.append(int(sid))

	# 4. Precompute all-pairs shortest path distances (unrestricted by transport type)
	_compute_all_pairs_distances()

	# 5. Cache central underground stations
	_cache_central_underground_stations()

	return true

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

	var map_center := Vector2(1200.0, 900.0)
	for sid in ug_stations.keys():
		var pos: Vector2 = stations.get(sid, Vector2.ZERO)
		if pos.distance_to(map_center) < 650.0:
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
