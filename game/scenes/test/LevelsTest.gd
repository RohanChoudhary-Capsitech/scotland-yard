extends SceneTree

## LevelsTest.gd — Headless test suite for Scotland Yard Map Levels feature.
## Verifies levels.json data, MapData subsets, GameState rules, Board filtering,
## Camera bounds, SaveManager progression, and Home menu level selection.
## Run with:
##   godot --headless -s game/scenes/test/LevelsTest.gd

class MockSaveManager extends SaveManager:
	var store: Dictionary = {}
	func get_value(key: String, default_val: Variant = null) -> Variant:
		return store.get(key, default_val)
	func set_value(key: String, value: Variant) -> void:
		store[key] = value
	func has(key: String) -> bool:
		return store.has(key)
	func save_game() -> DataResult:
		return null

var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	print("\n==================================================")
	print("       RUNNING SCOTLAND YARD LEVELS TESTS         ")
	print("==================================================")

	test_levels_json_data()
	test_map_data_level_loading()
	test_game_state_level_rules()
	test_board_level_filtering()
	test_camera_region_bounds()
	test_save_manager_level_progression()
	test_home_level_selection()

	print("\n==================================================")
	print("LEVELS TEST RESULTS: %d Passed, %d Failed (Total %d)" % [_passed, _failed, _passed + _failed])
	print("==================================================")

	if _failed == 0:
		quit(0)
	else:
		quit(1)

func _assert_true(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] %s" % msg)
	else:
		_failed += 1
		printerr("  [FAIL] %s" % msg)

func test_levels_json_data() -> void:
	print("\n--- 1. Testing levels.json Structure & Constraints ---")
	var path := "res://game/assets/data/levels.json"
	_assert_true(FileAccess.file_exists(path), "levels.json file exists")

	var f := FileAccess.open(path, FileAccess.READ)
	_assert_true(f != null, "levels.json opened successfully")

	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	_assert_true(err == OK, "levels.json parsed with no errors")

	var data: Dictionary = json.data as Dictionary
	for expected_key in ["tutorial", "neighbourhood", "district", "city"]:
		_assert_true(data.has(expected_key), "levels.json contains level '%s'" % expected_key)

	var to_int_arr = func(arr: Array) -> Array[int]:
		var res: Array[int] = []
		for v in arr:
			res.append(int(v))
		return res

	var tut: Dictionary = data["tutorial"]
	_assert_true(tut["stations"].size() <= 14 and tut["stations"].size() >= 10, "Tutorial has <= 14 stations (got %d)" % tut["stations"].size())
	_assert_true(tut["rounds"] == 8, "Tutorial has 8 rounds")
	_assert_true(tut["detective_count"] == 2, "Tutorial has 2 detectives")
	_assert_true(to_int_arr.call(tut["reveal_rounds"]) == [2, 5, 8], "Tutorial reveal rounds are [2, 5, 8]")

	var neigh: Dictionary = data["neighbourhood"]
	_assert_true(neigh["stations"].size() == 30, "Neighbourhood has exactly 30 stations (got %d)" % neigh["stations"].size())
	_assert_true(neigh["rounds"] == 12, "Neighbourhood has 12 rounds")
	_assert_true(neigh["detective_count"] == 3, "Neighbourhood has 3 detectives")
	_assert_true(to_int_arr.call(neigh["reveal_rounds"]) == [3, 6, 9, 12], "Neighbourhood reveal rounds are [3, 6, 9, 12]")

	var dist: Dictionary = data["district"]
	_assert_true(dist["stations"].size() == 80, "District has exactly 80 stations (got %d)" % dist["stations"].size())
	_assert_true(dist["rounds"] == 18, "District has 18 rounds")
	_assert_true(dist["detective_count"] == 4, "District has 4 detectives")
	_assert_true(to_int_arr.call(dist["reveal_rounds"]) == [3, 8, 13, 18], "District reveal rounds are [3, 8, 13, 18]")

	var city: Dictionary = data["city"]
	_assert_true(city["stations"].size() == 199, "City has all 199 stations (got %d)" % city["stations"].size())
	_assert_true(city["rounds"] == 24, "City has 24 rounds")
	_assert_true(city["detective_count"] == 4, "City has 4 detectives")
	_assert_true(to_int_arr.call(city["reveal_rounds"]) == [3, 8, 13, 18, 24], "City reveal rounds are [3, 8, 13, 18, 24]")

func test_map_data_level_loading() -> void:
	print("\n--- 2. Testing MapData Level Subsets ---")
	var map_tut := MapData.new("")
	var ok_tut := map_tut.load_level("tutorial")
	_assert_true(ok_tut, "MapData.load_level('tutorial') succeeded")
	_assert_true(map_tut.stations.size() <= 14 and map_tut.stations.size() >= 10, "Tutorial MapData has <= 14 stations")

	# Check that tutorial region has bus, underground, and ferry links
	var has_bus := false
	var has_ug := false
	var has_ferry := false
	for sid in map_tut.stations.keys():
		for link in map_tut.get_links_from(int(sid)):
			if link["type"] == "bus":
				has_bus = true
			elif link["type"] == "underground":
				has_ug = true
			elif link["type"] == "ferry":
				has_ferry = true
	_assert_true(has_bus, "Tutorial MapData contains bus links")
	_assert_true(has_ug, "Tutorial MapData contains underground links")
	_assert_true(has_ferry, "Tutorial MapData contains river ferry link")

	# Distance to stations outside tutorial should be -1
	var outside_sid := 99
	_assert_true(not map_tut.has_station(outside_sid), "Station 99 is not in Tutorial")
	_assert_true(map_tut.bfs_distance(22, outside_sid) == -1, "bfs_distance to outside station returns -1")

	# Neighbourhood
	var map_neigh := MapData.new("")
	map_neigh.load_level("neighbourhood")
	_assert_true(map_neigh.stations.size() == 30, "Neighbourhood MapData has 30 stations")

	# District
	var map_dist := MapData.new("")
	map_dist.load_level("district")
	_assert_true(map_dist.stations.size() == 80, "District MapData has 80 stations")

	# City
	var map_city := MapData.new("")
	map_city.load_level("city")
	_assert_true(map_city.stations.size() == 199, "City MapData has all 199 stations")

func test_game_state_level_rules() -> void:
	print("\n--- 3. Testing GameState Rules per Level ---")
	var map_tut := MapData.new("")
	map_tut.load_level("tutorial")

	var lf := FileAccess.open("res://game/assets/data/levels.json", FileAccess.READ)
	var ldata: Dictionary = (JSON.parse_string(lf.get_as_text()) as Dictionary)["tutorial"]

	var state := SYGameState.new(
		map_tut,
		int(ldata["detective_count"]),
		[],
		int(ldata["rounds"]),
		[2, 5, 8],
		ldata["tickets"],
		[47, 78],
		[1, 18]
	)

	_assert_true(state.detective_count == 2, "GameState detective_count is 2 for tutorial")
	_assert_true(state.max_rounds == 8, "GameState max_rounds is 8 for tutorial")
	_assert_true(state.is_reveal_round(2), "Round 2 is reveal round for tutorial")
	_assert_true(state.is_reveal_round(5), "Round 5 is reveal round for tutorial")
	_assert_true(state.is_reveal_round(8), "Round 8 is reveal round for tutorial")
	_assert_true(not state.is_reveal_round(3), "Round 3 is NOT reveal round for tutorial")

	# Start stations inside tutorial
	_assert_true(map_tut.has_station(state.positions[0]), "Mr. X starts inside tutorial")
	_assert_true(map_tut.has_station(state.positions[1]), "Detective 1 starts inside tutorial")
	_assert_true(map_tut.has_station(state.positions[2]), "Detective 2 starts inside tutorial")

	# All legal moves stay within tutorial
	for m in state.legal_moves(0):
		_assert_true(map_tut.has_station(int(m["to"])), "Mr. X move to %d is inside tutorial" % int(m["to"]))

	# Clone preserves level rules
	var copy := state.duplicate()
	_assert_true(copy.max_rounds == 8, "duplicate() preserves max_rounds == 8")
	_assert_true(copy.reveal_rounds == [2, 5, 8], "duplicate() preserves reveal_rounds")

func test_board_level_filtering() -> void:
	print("\n--- 4. Testing Board Station and Link Filtering ---")
	var board_scene: PackedScene = load("res://game/scenes/gameplay/Board/Board.tscn")
	_assert_true(board_scene != null, "Board.tscn loaded")

	var board := board_scene.instantiate() as Board
	_assert_true(board != null, "Board instantiated")

	var tut_stations: Array[int] = [1, 3, 10, 18, 22, 24, 26, 40, 47, 78]
	board.apply_level_filter(tut_stations)

	# Stations inside should be visible and pickable
	var st1 := board.get_station(1)
	_assert_true(st1.visible, "Station 1 is visible in tutorial")
	_assert_true(st1.input_pickable, "Station 1 is input_pickable in tutorial")

	var st22 := board.get_station(22)
	_assert_true(st22.visible, "Station 22 is visible in tutorial")

	# Station outside should be hidden and not pickable
	var st99 := board.get_station(99)
	_assert_true(not st99.visible, "Station 99 is hidden in tutorial")
	_assert_true(not st99.input_pickable, "Station 99 is NOT input_pickable in tutorial")

	var st50 := board.get_station(50)
	_assert_true(not st50.visible, "Station 50 is hidden in tutorial")

	# Reset filter to show everything
	board.apply_level_filter([])
	_assert_true(st99.visible, "Station 99 restored visible after clearing filter")
	_assert_true(st99.input_pickable, "Station 99 restored pickable after clearing filter")

	board.free()

func test_camera_region_bounds() -> void:
	print("\n--- 5. Testing Camera Region Bounding & Clamping ---")
	var cam := BoardCameraController.new()
	var test_box := Rect2(500.0, 500.0, 600.0, 400.0)
	cam.set_region_bounds(test_box, 100.0)

	_assert_true(cam.map_bounds.position.x == 400.0, "map_bounds.position.x includes 100px margin")
	_assert_true(cam.map_bounds.position.y == 400.0, "map_bounds.position.y includes 100px margin")
	_assert_true(cam.map_bounds.size.x == 800.0, "map_bounds.size.x includes margin * 2")
	_assert_true(cam.map_bounds.size.y == 600.0, "map_bounds.size.y includes margin * 2")

	# Clamping keeps camera inside map_bounds
	var clamped := cam._clamped_center(Vector2(2000.0, 2000.0))
	_assert_true(clamped.x <= cam.map_bounds.end.x, "Clamped X within map_bounds end")
	_assert_true(clamped.y <= cam.map_bounds.end.y, "Clamped Y within map_bounds end")

	cam.free()

func test_save_manager_level_progression() -> void:
	print("\n--- 6. Testing SaveManager Progression & Unlocks ---")
	var save := MockSaveManager.new()

	# 1. New save: starts with only ["tutorial"]
	var initial_unlocked := save.get_unlocked_levels()
	_assert_true(initial_unlocked == ["tutorial"], "New save starts with ['tutorial'] unlocked")
	_assert_true(save.is_level_unlocked("tutorial"), "Tutorial is unlocked")
	_assert_true(not save.is_level_unlocked("neighbourhood"), "Neighbourhood is locked")
	_assert_true(not save.is_level_unlocked("district"), "District is locked")
	_assert_true(not save.is_level_unlocked("city"), "City is locked")

	# 2. Complete tutorial -> unlocks neighbourhood
	var next1 := save.unlock_next_level("tutorial")
	_assert_true(next1 == "neighbourhood", "unlock_next_level('tutorial') returns 'neighbourhood'")
	_assert_true(save.is_level_unlocked("neighbourhood"), "Neighbourhood is now unlocked")
	_assert_true(not save.is_level_unlocked("district"), "District is still locked")

	# 3. Complete neighbourhood -> unlocks district
	var next2 := save.unlock_next_level("neighbourhood")
	_assert_true(next2 == "district", "unlock_next_level('neighbourhood') returns 'district'")
	_assert_true(save.is_level_unlocked("district"), "District is now unlocked")

	# 4. Complete district -> unlocks city
	var next3 := save.unlock_next_level("district")
	_assert_true(next3 == "city", "unlock_next_level('district') returns 'city'")
	_assert_true(save.is_level_unlocked("city"), "City is now unlocked")

	# 5. Selected level
	save.set_selected_level("neighbourhood")
	_assert_true(save.get_selected_level() == "neighbourhood", "Selected level persisted as 'neighbourhood'")

	save.free()

func test_home_level_selection() -> void:
	print("\n--- 7. Testing Home Menu Level UI & Seat Synchronization ---")
	var home_scene: PackedScene = load("res://game/scenes/Home/Home.tscn")
	_assert_true(home_scene != null, "Home.tscn loaded")

	var home := home_scene.instantiate() as HomeScene
	_assert_true(home != null, "HomeScene instantiated")

	# Setup mock save with all levels unlocked
	var save := MockSaveManager.new()
	save.store["levels_unlocked"] = ["tutorial", "neighbourhood", "district", "city"]
	save.store["selected_level"] = "city"

	home._save = save
	home._on_ready()

	# Verify level buttons exist
	var btn_tut: Button = home.get_node("%BtnLevelTutorial") as Button
	var btn_neigh: Button = home.get_node("%BtnLevelNeighbourhood") as Button
	var btn_dist: Button = home.get_node("%BtnLevelDistrict") as Button
	var btn_city: Button = home.get_node("%BtnLevelCity") as Button

	_assert_true(btn_tut != null, "%BtnLevelTutorial found")
	_assert_true(btn_neigh != null, "%BtnLevelNeighbourhood found")
	_assert_true(btn_dist != null, "%BtnLevelDistrict found")
	_assert_true(btn_city != null, "%BtnLevelCity found")

	_assert_true(not btn_tut.disabled, "Tutorial button is enabled")
	_assert_true(not btn_neigh.disabled, "Neighbourhood button is enabled")
	_assert_true(not btn_dist.disabled, "District button is enabled")
	_assert_true(not btn_city.disabled, "City button is enabled")

	# Select Tutorial -> detective count should become 2
	home._select_level("tutorial")
	_assert_true(home._selected_level == "tutorial", "Selected level is 'tutorial'")
	_assert_true(home._selected_detective_count == 2, "Tutorial selects 2 detectives")
	var active_seats_tut := home._get_active_seats()
	_assert_true(active_seats_tut.size() == 3, "Tutorial active seats == 3 (Mr. X, D1, D2)")

	# Select Neighbourhood -> detective count should become 3
	home._select_level("neighbourhood")
	_assert_true(home._selected_level == "neighbourhood", "Selected level is 'neighbourhood'")
	_assert_true(home._selected_detective_count == 3, "Neighbourhood selects 3 detectives")

	# Select District -> detective count should become 4
	home._select_level("district")
	_assert_true(home._selected_level == "district", "Selected level is 'district'")
	_assert_true(home._selected_detective_count == 4, "District selects 4 detectives")

	# Select City -> restores 4 detectives (and CountHBox visible)
	home._select_level("city")
	_assert_true(home._selected_level == "city", "Selected level is 'city'")
	var count_box := home.get_node_or_null("%CountHBox") as HBoxContainer
	_assert_true(count_box != null and count_box.visible, "CountHBox is visible on City")

	home.free()
	save.free()
