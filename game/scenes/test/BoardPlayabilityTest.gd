extends SceneTree

## BoardPlayabilityTest — Verifies that Board.tscn, Match.tscn,
## and all gameplay components are properly constructed, connected,
## and fully playable in both game modes ("detectives" and "mrx").

var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	print("\n==================================================")
	print("       RUNNING BOARD & PLAYABILITY TESTS          ")
	print("==================================================")

	test_board_hierarchy()
	test_board_methods()
	test_board_camera()
	test_playability_detectives_mode()
	test_playability_mrx_mode()

	print("==================================================")
	print("TEST RESULTS: %d Passed, %d Failed" % [passed_tests, failed_tests])
	print("==================================================")

	if failed_tests > 0:
		quit(1)
	else:
		quit(0)

func _pass(msg: String) -> void:
	passed_tests += 1
	print("  [PASS] %s" % msg)

func _fail(msg: String) -> void:
	failed_tests += 1
	printerr("  [FAIL] %s" % msg)

func _assert_true(cond: bool, msg: String) -> void:
	if cond:
		_pass(msg)
	else:
		_fail(msg)

func test_board_hierarchy() -> void:
	print("\n--- 1. Testing Board.tscn Hierarchy ---")
	var board_scene: PackedScene = load("res://game/scenes/gameplay/Board/Board.tscn")
	_assert_true(board_scene != null, "Board.tscn loaded successfully")

	var board := board_scene.instantiate() as Board
	_assert_true(board != null, "Board instantiated successfully")

	var stations_node: Node2D = board.get_node_or_null("Stations")
	_assert_true(stations_node != null, "Board has $Stations node")
	_assert_true(stations_node.get_child_count() == 199, "Board has exactly 199 Station instances (got %d)" % stations_node.get_child_count())

	var links_node: Node2D = board.get_node_or_null("Links")
	_assert_true(links_node != null, "Board has $Links node")

	var ug_group: Node2D = links_node.get_node_or_null("Underground")
	var bus_group: Node2D = links_node.get_node_or_null("Bus")
	var taxi_group: Node2D = links_node.get_node_or_null("Taxi")
	var ferry_group: Node2D = links_node.get_node_or_null("Ferry")

	_assert_true(ug_group != null, "Links has Underground group")
	_assert_true(bus_group != null, "Links has Bus group")
	_assert_true(taxi_group != null, "Links has Taxi group")
	_assert_true(ferry_group != null, "Links has Ferry group")

	var total_links: int = (
		ug_group.get_child_count()
		+ bus_group.get_child_count()
		+ taxi_group.get_child_count()
		+ ferry_group.get_child_count()
	)
	_assert_true(total_links == 449, "Total links across groups == 449 (got %d)" % total_links)

	var tokens_node: Node2D = board.get_node_or_null("Tokens")
	_assert_true(tokens_node != null, "Board has $Tokens node")
	_assert_true(tokens_node.get_child_count() == 6, "Board has 6 Token instances")

	var last_seen: LastSeenMarker = board.get_node_or_null("LastSeen") as LastSeenMarker
	_assert_true(last_seen != null, "Board has $LastSeen marker")

	board.free()

func test_board_methods() -> void:
	print("\n--- 2. Testing Board.gd Methods ---")
	var board_scene: PackedScene = load("res://game/scenes/gameplay/Board/Board.tscn")
	var board := board_scene.instantiate() as Board

	# Test get_station & position
	var st1: Station = board.get_station(1)
	_assert_true(st1 != null, "get_station(1) returns Station_1")
	var pos1: Vector2 = board.get_station_position(1)
	_assert_true(pos1 != Vector2.ZERO, "get_station_position(1) is non-zero (%s)" % str(pos1))

	# Test highlights
	board.highlight_stations([1, 5, 10])
	_assert_true(board.get_station(1).is_highlighted(), "Station 1 is highlighted")
	_assert_true(board.get_station(5).is_highlighted(), "Station 5 is highlighted")
	_assert_true(not board.get_station(2).is_highlighted(), "Station 2 is not highlighted")

	board.clear_all_highlights()
	_assert_true(not board.get_station(1).is_highlighted(), "Station 1 highlight cleared")

	# Test token movement and visibility
	board.set_token_position(0, 10, false)
	_assert_true(board.get_token(0).position == board.get_station_position(10), "Token 0 moved to station 10")

	board.set_token_visible(0, true)
	_assert_true(board.get_token(0).visible, "Token 0 visibility set to true")
	board.set_token_visible(0, false)
	_assert_true(not board.get_token(0).visible, "Token 0 visibility set to false")

	# Test last seen
	board.set_last_seen(15, true)
	_assert_true(board.get_node("LastSeen").visible, "LastSeen marker shown")
	board.set_last_seen(15, false)
	_assert_true(not board.get_node("LastSeen").visible, "LastSeen marker hidden")

	board.free()

func test_board_camera() -> void:
	print("\n--- 3. Testing BoardCameraController ---")
	var cam := BoardCameraController.new()
	cam._ready()

	_assert_true(cam.zoom == Vector2(0.65, 0.65), "Initial zoom centered")
	_assert_true(cam.position.x >= cam.map_bounds.position.x and cam.position.x <= cam.map_bounds.end.x, "Initial position inside bounds")

	cam.free()

class MockSaveManager extends RefCounted:
	var store: Dictionary = {}
	func get_value(key: String, default_val: Variant = null) -> Variant:
		return store.get(key, default_val)
	func set_value(key: String, value: Variant) -> void:
		store[key] = value
	func save_game() -> void:
		pass

func test_playability_detectives_mode() -> void:
	print("\n--- 4. Testing Gameplay in 'Play as Detectives' Mode ---")
	var match_scene: PackedScene = load("res://game/scenes/gameplay/Match.tscn")
	_assert_true(match_scene != null, "Match.tscn loaded successfully")

	var match_inst := match_scene.instantiate() as Match
	_assert_true(match_inst != null, "Match.tscn instantiated")

	# Setup mock dependencies
	var game_manager := GameManager.new()
	var bus_script = load("res://game/autoloads/GameBus.gd")
	var bus: Node = bus_script.new()
	var save := MockSaveManager.new()
	save.set_value("match_mode", "detectives")
	save.set_value("detective_count", 4)

	match_inst.inject_dependencies(game_manager, bus, save, null, null)

	var match_feat: MatchFeature = match_inst.get_node("MatchFeature")
	_assert_true(match_feat != null, "Match has MatchFeature")
	_assert_true(match_feat.mode == "detectives", "Match mode is 'detectives'")

	# Initial turn is Mr. X (AI)
	_assert_true(match_feat.is_ai_turn(), "Turn 0 is AI turn (Mr. X)")

	# Let Mr. X AI move
	var mrx_ok := match_feat.play_ai_turn()
	_assert_true(mrx_ok, "Mr. X AI executed move successfully")
	_assert_true(match_feat.state.current_player == 1, "Turn passed to Detective 1 (human)")
	_assert_true(not match_feat.is_ai_turn(), "Detective 1 turn is human turn")

	# Simulate human clicking a legal station for Detective 1
	var legal_d1: Array[Dictionary] = match_feat.state.legal_moves(1)
	_assert_true(not legal_d1.is_empty(), "Detective 1 has legal moves")
	var chosen_st: int = int(legal_d1[0]["to"])

	match_inst._on_station_clicked(chosen_st)
	_assert_true(match_feat.state.positions[1] == chosen_st, "Detective 1 moved to clicked station %d" % chosen_st)

	match_inst.free()
	game_manager.free()
	bus.free()

func test_playability_mrx_mode() -> void:
	print("\n--- 5. Testing Gameplay in 'Play as Mr. X' Mode ---")
	var match_scene: PackedScene = load("res://game/scenes/gameplay/Match.tscn")
	var match_inst := match_scene.instantiate() as Match

	var game_manager := GameManager.new()
	var bus_script = load("res://game/autoloads/GameBus.gd")
	var bus: Node = bus_script.new()
	var save := MockSaveManager.new()
	save.set_value("match_mode", "mrx")
	save.set_value("detective_count", 4)

	match_inst.inject_dependencies(game_manager, bus, save, null, null)

	var match_feat: MatchFeature = match_inst.get_node("MatchFeature")
	_assert_true(match_feat.mode == "mrx", "Match mode is 'mrx'")

	# In Mr. X mode, Mr. X is human
	_assert_true(not match_feat.is_ai_turn(), "Initial turn is human turn (Mr. X)")

	# Human clicks a legal station for Mr. X
	var legal_mrx: Array[Dictionary] = match_feat.state.legal_moves(0)
	_assert_true(not legal_mrx.is_empty(), "Mr. X has legal moves")
	var target_st: int = int(legal_mrx[0]["to"])

	match_inst._on_station_clicked(target_st)
	_assert_true(match_feat.state.positions[0] == target_st, "Mr. X moved to clicked station %d" % target_st)

	# Now it's Detective 1 (AI)
	_assert_true(match_feat.state.current_player == 1, "Turn passed to Detective 1 (AI)")
	_assert_true(match_feat.is_ai_turn(), "Detective 1 turn is AI turn")

	# Let Detective 1 AI move
	var d1_ok := match_feat.play_ai_turn()
	_assert_true(d1_ok, "Detective 1 AI move executed")

	match_inst.free()
	game_manager.free()
	bus.free()
