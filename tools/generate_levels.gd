extends SceneTree

## tools/generate_levels.gd
## Generates game/assets/data/levels.json from game/assets/data/map.json
## Creates 4 levels: "tutorial", "neighbourhood", "district", "city".
## Runs headless:
##   godot --headless -s tools/generate_levels.gd

const MAP_PATH := "res://game/assets/data/map.json"
const OUTPUT_PATH := "res://game/assets/data/levels.json"

func _init() -> void:
	print("\n==================================================")
	print("       GENERATING SCOTLAND YARD MAP LEVELS        ")
	print("==================================================")

	if not FileAccess.file_exists(MAP_PATH):
		printerr("Map file not found: %s" % MAP_PATH)
		quit(1)
		return

	var file := FileAccess.open(MAP_PATH, FileAccess.READ)
	var text := file.get_as_text()
	var json := JSON.new()
	if json.parse(text) != OK:
		printerr("Failed to parse map.json: %s" % json.get_error_message())
		quit(1)
		return

	var data: Dictionary = json.data
	var raw_stations: Array = data.get("stations", [])
	var raw_links: Array = data.get("links", [])
	var global_starts: Array = data.get("start_stations", [])

	var all_station_ids: Array[int] = []
	var adj: Dictionary = {}
	for s in raw_stations:
		var sid := int(s["id"])
		all_station_ids.append(sid)
		adj[sid] = []

	for l in raw_links:
		var a := int(l["a"])
		var b := int(l["b"])
		var t := str(l.get("type", "taxi"))
		adj[a].append({"to": b, "type": t})
		adj[b].append({"to": a, "type": t})

	# Seed station 22 is a major central hub with taxi, bus, and underground links
	var seed_station := 22

	var tutorial_stations := _grow_bfs(seed_station, 10, adj)
	var neighbourhood_stations := _grow_bfs(seed_station, 30, adj)
	var district_stations := _grow_bfs(seed_station, 80, adj)
	var city_stations: Array[int] = []
	for sid in all_station_ids:
		city_stations.append(sid)
	city_stations.sort()

	# Validate requirements for each region
	_validate_region("tutorial", tutorial_stations, raw_links)
	_validate_region("neighbourhood", neighbourhood_stations, raw_links)
	_validate_region("district", district_stations, raw_links)
	_validate_region("city", city_stations, raw_links)

	# Initial ticket counts (tuned further via AISim)
	var levels_dict: Dictionary = {
		"tutorial": {
			"id": "tutorial",
			"name": "Tutorial",
			"description": "Small 10-station beginner sector with 2 detectives and 8 rounds.",
			"stations": tutorial_stations,
			"detective_count": 2,
			"rounds": 8,
			"reveal_rounds": [2, 5, 8],
			"mrx_start_stations": [47, 78, 26, 40],
			"detective_start_stations": [1, 18, 10, 24],
			"start_stations": [47, 1, 18, 26, 78, 10, 24, 40],
			"tickets": {
				"mrx": {
					"taxi": 4,
					"bus": 2,
					"underground": 1,
					"black": 3,
					"double": 1,
					"close_eyes": 1
				},
				"detectives": {
					"taxi": 2,
					"bus": 1,
					"underground": 1
				}
			}
		},
		"neighbourhood": {
			"id": "neighbourhood",
			"name": "Neighbourhood",
			"description": "30-station local neighbourhood with 3 detectives and 12 rounds.",
			"stations": neighbourhood_stations,
			"detective_count": 3,
			"rounds": 12,
			"reveal_rounds": [3, 6, 9, 12],
			"mrx_start_stations": [36, 47, 29, 78],
			"detective_start_stations": [1, 13, 53, 16],
			"start_stations": [36, 1, 13, 53, 47, 29, 78, 16],
			"tickets": {
				"mrx": {
					"taxi": 5,
					"bus": 3,
					"underground": 2,
					"black": 5,
					"double": 2,
					"close_eyes": 1
				},
				"detectives": {
					"taxi": 2,
					"bus": 1,
					"underground": 1
				}
			}
		},
		"district": {
			"id": "district",
			"name": "District",
			"description": "80-station central district with 4 detectives and 18 rounds.",
			"stations": district_stations,
			"detective_count": 4,
			"rounds": 18,
			"reveal_rounds": [3, 8, 13, 18],
			"mrx_start_stations": [48, 58, 59, 115, 148],
			"detective_start_stations": [1, 47, 52, 36, 16],
			"start_stations": [48, 1, 47, 52, 36, 58, 59, 115, 148, 16],
			"tickets": {
				"mrx": {
					"taxi": 5,
					"bus": 4,
					"underground": 3,
					"black": 5,
					"double": 2,
					"close_eyes": 2
				},
				"detectives": {
					"taxi": 4,
					"bus": 3,
					"underground": 2
				}
			}
		},
		"city": {
			"id": "city",
			"name": "City",
			"description": "The complete 199-station London map with 4 detectives and 24 rounds.",
			"stations": city_stations,
			"detective_count": 4,
			"rounds": 24,
			"reveal_rounds": [3, 8, 13, 18, 24],
			"mrx_start_stations": global_starts.duplicate(),
			"detective_start_stations": global_starts.duplicate(),
			"start_stations": global_starts.duplicate(),
			"tickets": {
				"mrx": {
					"taxi": 4,
					"bus": 3,
					"underground": 3,
					"black": 4,
					"double": 2,
					"close_eyes": 2
				},
				"detectives": {
					"taxi": 10,
					"bus": 8,
					"underground": 4
				}
			}
		}
	}

	# Write JSON output
	var out_file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if out_file == null:
		printerr("Failed to open output file for writing: %s" % OUTPUT_PATH)
		quit(1)
		return

	var out_json := JSON.stringify(levels_dict, "\t")
	out_file.store_string(out_json)
	out_file.close()

	print("\n[SUCCESS] Successfully generated levels at: %s" % OUTPUT_PATH)
	for lvl_key in ["tutorial", "neighbourhood", "district", "city"]:
		var lvl: Dictionary = levels_dict[lvl_key]
		print("  Level '%s': %d stations, %d rounds, %d detectives, reveals %s" % [
			lvl_key, lvl["stations"].size(), lvl["rounds"], lvl["detective_count"], str(lvl["reveal_rounds"])
		])
	quit(0)

func _grow_bfs(seed: int, target_count: int, adj: Dictionary) -> Array[int]:
	var visited: Array[int] = [seed]
	var queue: Array[int] = [seed]
	var in_visited: Dictionary = {seed: true}

	while not queue.is_empty() and visited.size() < target_count:
		var curr: int = queue.pop_front()
		var nbrs: Array = adj.get(curr, []).duplicate()
		# Sort neighbours ascending by station ID for deterministic reproducibility
		nbrs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["to"]) < int(b["to"]))
		for link_val in nbrs:
			var link: Dictionary = link_val as Dictionary
			var nxt: int = int(link["to"])
			if not in_visited.has(nxt):
				in_visited[nxt] = true
				visited.append(nxt)
				queue.append(nxt)
				if visited.size() == target_count:
					break

	visited.sort()
	return visited

func _validate_region(lvl_name: String, stations: Array[int], raw_links: Array) -> void:
	var st_set: Dictionary = {}
	for sid in stations:
		st_set[sid] = true

	var sub_links: Array = []
	var has_bus := false
	var has_ug := false

	for l in raw_links:
		var a := int(l["a"])
		var b := int(l["b"])
		if st_set.has(a) and st_set.has(b):
			sub_links.append(l)
			var t := str(l.get("type", ""))
			if t == "bus":
				has_bus = true
			elif t == "underground":
				has_ug = true

	assert(has_bus, "Level %s must contain at least one bus link!" % lvl_name)
	assert(has_ug, "Level %s must contain at least one underground link!" % lvl_name)
	print("  Region '%s' validated: %d stations, %d internal links (bus=%s, ug=%s)" % [
		lvl_name, stations.size(), sub_links.size(), str(has_bus), str(has_ug)
	])
