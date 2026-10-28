extends SceneTree

## BoardPlayabilityTest — Verifies that Board.tscn, Match.tscn,
## and all gameplay components are properly constructed, connected,
## styled with the illustrated city art, and fully playable in both modes.

var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	_run_all_tests.call_deferred()

func _run_all_tests() -> void:
	print("\n==================================================")
	print("       RUNNING BOARD & PLAYABILITY TESTS          ")
	print("==================================================")

	test_board_hierarchy()
	test_road_styling()
	test_board_methods()
	test_camera_and_readability_lod()
	await test_board_play_move()
	await test_playability_detectives_mode()
	await test_playability_mrx_mode()

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
	print("\n--- 1. Testing Board.tscn Hierarchy & Draw Order ---")
	var board_scene: PackedScene = load("res://game/scenes/gameplay/Board/Board.tscn")
	_assert_true(board_scene != null, "Board.tscn loaded successfully")

	var board := board_scene.instantiate() as Board
	_assert_true(board != null, "Board instantiated successfully")

	# 1. Background (Layer 0, first child)
	_assert_true(board.get_child_count() > 0, "Board has children")
	var first_child := board.get_child(0)
	_assert_true(first_child is Node2D and first_child.name == "Background", "First child is the Background tiles node")
	var bg := first_child as Node2D
	_assert_true(bg.z_index == 0, "Background z_index == 0")
	_assert_true(bg.get_child_count() == BoardBuilder.CITY_TILES.x * BoardBuilder.CITY_TILES.y, "Background has one Sprite2D per baked city tile")
	var covered := Rect2()
	for tile in bg.get_children():
		var spr := tile as Sprite2D
		_assert_true(spr != null and spr.texture != null, "City tile %s has a texture" % tile.name)
		var r := Rect2(spr.position, spr.texture.get_size() * spr.scale)
		covered = r if covered.size == Vector2.ZERO else covered.merge(r)
	_assert_true(covered.position.is_equal_approx(BoardBuilder.CITY_AREA.position) and covered.size.is_equal_approx(BoardBuilder.CITY_AREA.size),
		"City tiles exactly cover CITY_AREA (got %s)" % str(covered))

	# 2. Links Node + Groups
	var links_node: Node2D = board.get_node_or_null("Links")
	_assert_true(links_node != null, "Board has $Links node")

	var bus_group: Node2D = links_node.get_node_or_null("Bus")
	var taxi_group: Node2D = links_node.get_node_or_null("Taxi")
	var ug_group: Node2D = links_node.get_node_or_null("Underground")
	var ferry_group: Node2D = links_node.get_node_or_null("Ferry")

	_assert_true(bus_group != null, "Links has Bus group")
	_assert_true(taxi_group != null, "Links has Taxi group")
	_assert_true(ug_group != null, "Links has Underground group")
	_assert_true(ferry_group != null, "Links has Ferry group")

	var total_links: int = (
		ug_group.get_child_count()
		+ bus_group.get_child_count()
		+ taxi_group.get_child_count()
		+ ferry_group.get_child_count()
	)
	_assert_true(total_links == 468, "Total links across groups == 468 (got %d)" % total_links)

	# 3. Buildings and trees are baked into the background (no runtime props)
	_assert_true(board.get_node_or_null("Props") == null, "No Props node: city is baked into the background tiles")

	# 4. Stations (Layer 50)
	var stations_node: Node2D = board.get_node_or_null("Stations")
	_assert_true(stations_node != null, "Board has $Stations node")
	_assert_true(stations_node.get_child_count() == 199, "Board has exactly 199 Station instances (got %d)" % stations_node.get_child_count())

	var sample_st: Station = stations_node.get_node_or_null("Station_1") as Station
	_assert_true(sample_st != null, "Station_1 exists")
	_assert_true(sample_st.get_node_or_null("Base") != null, "Station has Base pin sprite")
	_assert_true(sample_st.get_node_or_null("Number") != null, "Station has Number label")
	_assert_true(sample_st.get_node_or_null("Highlight") != null, "Station has Highlight sprite")
	_assert_true(sample_st.get_node_or_null("MetroEntrance") != null, "Station has MetroEntrance sprite")
	_assert_true(sample_st.get_node_or_null("Dock") != null, "Station has Dock sprite")

	# 5. Vehicles (Layer 60)
	var vehicles: BoardVehicles = board.get_node_or_null("Vehicles") as BoardVehicles
	_assert_true(vehicles != null, "Board has $Vehicles instance")
	vehicles._ensure_nodes()
	_assert_true(vehicles.taxi != null, "Vehicles has Taxi Sprite2D")
	_assert_true(vehicles.bus != null, "Vehicles has Bus Sprite2D")
	_assert_true(vehicles.train != null, "Vehicles has Train Sprite2D")
	_assert_true(vehicles.ferry != null, "Vehicles has Ferry Sprite2D")
	_assert_true(vehicles.wake != null, "Vehicles has Wake GPUParticles2D")

	# 6. Tokens (Layer 70)
	var tokens_node: Node2D = board.get_node_or_null("Tokens")
	_assert_true(tokens_node != null, "Board has $Tokens node")
	_assert_true(tokens_node.get_child_count() == 6, "Board has 6 Token instances")

	# 7. LastSeen (Layer 80)
	var last_seen: LastSeenMarker = board.get_node_or_null("LastSeen") as LastSeenMarker
	_assert_true(last_seen != null, "Board has $LastSeen marker")

	# 8. Darkness (CanvasModulate) and Spotlight (Layer 90)
	var darkness: CanvasModulate = board.get_node_or_null("Darkness") as CanvasModulate
	_assert_true(darkness != null, "Board has $Darkness CanvasModulate")
	_assert_true(not darkness.visible, "Darkness CanvasModulate hidden by default")

	var spotlight_node: Node2D = board.get_node_or_null("Spotlight") as Node2D
	_assert_true(spotlight_node != null, "Board has $Spotlight Node2D")
	_assert_true(spotlight_node.z_index == 90, "Spotlight layer is 90 (on top of tokens)")
	var point_light: PointLight2D = spotlight_node.get_node_or_null("Light") as PointLight2D
	_assert_true(point_light != null, "Spotlight has PointLight2D child")
	_assert_true(point_light.texture != null, "PointLight2D has radial gradient texture assigned")

	# Verify Draw Order: Background(0) < Bus(10) < Taxi(20) < Metro/Ferry(40) < Stations(50) < Vehicles(60) < Tokens(70) < LastSeen(80) < Spotlight(90)
	_assert_true(bg.z_index < bus_group.z_index, "Background layer < Bus layer")
	_assert_true(bus_group.z_index < taxi_group.z_index, "Bus layer < Taxi layer (%d < %d)" % [bus_group.z_index, taxi_group.z_index])
	_assert_true(taxi_group.z_index < ug_group.z_index, "Taxi layer < Metro layer (%d < %d)" % [taxi_group.z_index, ug_group.z_index])
	_assert_true(ug_group.z_index < stations_node.z_index, "Metro layer < Stations layer (%d < %d)" % [ug_group.z_index, stations_node.z_index])
	_assert_true(stations_node.z_index < vehicles.z_index, "Stations layer < Vehicles layer (%d < %d)" % [stations_node.z_index, vehicles.z_index])
	_assert_true(vehicles.z_index < tokens_node.z_index, "Vehicles layer < Tokens layer (%d < %d)" % [vehicles.z_index, tokens_node.z_index])
	_assert_true(tokens_node.z_index < last_seen.z_index, "Tokens layer < LastSeen layer (%d < %d)" % [tokens_node.z_index, last_seen.z_index])
	_assert_true(last_seen.z_index < spotlight_node.z_index, "LastSeen layer < Spotlight layer (%d < %d)" % [last_seen.z_index, spotlight_node.z_index])

	board.free()

func test_road_styling() -> void:
	print("\n--- 2. Testing Road & Link Styling ---")
	var board_scene: PackedScene = load("res://game/scenes/gameplay/Board/Board.tscn")
	var board := board_scene.instantiate() as Board

	var links_root := board.get_node("Links")

	# 1. Taxi / bus streets are baked into the city; their links only show as route previews
	var taxi_link := links_root.get_node("Taxi").get_child(0) as Link
	_assert_true(taxi_link != null, "Found taxi link")
	_assert_true(not taxi_link.visible, "Taxi link overlay hidden by default (street is in the background)")
	taxi_link.set_route_highlight(true)
	_assert_true(taxi_link.visible and taxi_link.default_color == Link.COLOR_TAXI, "Taxi route preview shows in taxi yellow")
	_assert_true(taxi_link.width == 7.0, "Route preview width == 7")
	taxi_link.set_route_highlight(false)
	_assert_true(not taxi_link.visible, "Taxi route preview hides again")

	var bus_link := links_root.get_node("Bus").get_child(0) as Link
	_assert_true(bus_link != null and not bus_link.visible, "Bus link overlay hidden by default")
	bus_link.set_route_highlight(true)
	_assert_true(bus_link.visible and bus_link.default_color == Link.COLOR_BUS, "Bus route preview shows in bus green")
	bus_link.set_route_highlight(false)

	# 2. Underground link: always-visible pink dashed metro line with a white casing
	var ug_link := links_root.get_node("Underground").get_child(0) as Link
	_assert_true(ug_link != null and ug_link.visible, "Underground metro line visible")
	_assert_true(ug_link.width == 5.0, "Underground metro line width == 5.0")
	_assert_true(ug_link.texture != null, "Underground metro line is dashed")
	var casing := ug_link.get_node_or_null("InnerRoad") as Line2D
	_assert_true(casing != null and casing.visible and casing.show_behind_parent, "Metro line has a casing drawn behind it")

	# 3. Ferry link: white dotted curve that bows into the river
	var ferry_link := links_root.get_node("Ferry").get_child(0) as Link
	_assert_true(ferry_link != null and ferry_link.visible, "Ferry route visible")
	_assert_true(ferry_link.width == 4.0, "Ferry route line width == 4.0")
	_assert_true(ferry_link.points.size() > 2, "Ferry route is a curve (got %d points)" % ferry_link.points.size())

	board.free()

func test_board_methods() -> void:
	print("\n--- 3. Testing Board.gd Methods ---")
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

	# Test spotlight controls
	_assert_true(not board.is_spotlight_visible(), "Spotlight initially not visible")
	board.show_spotlight()
	_assert_true(board.is_spotlight_visible(), "Spotlight shown via show_spotlight()")
	board.set_spotlight_target(Vector2(600, 600))
	_assert_true(board._spotlight_target == Vector2(600, 600), "Spotlight target set to (600, 600)")
	board.hide_spotlight(true)
	_assert_true(not board.is_spotlight_visible(), "Spotlight hidden via hide_spotlight()")

	board.free()

func test_camera_and_readability_lod() -> void:
	print("\n--- 4. Testing BoardCameraController & Readability LOD ---")
	var board_scene: PackedScene = load("res://game/scenes/gameplay/Board/Board.tscn")
	var board := board_scene.instantiate() as Board

	# 1. Zoomed out (< 0.7): station pins scale up for readability
	board.set_zoom_lod(0.5)
	var sample_station: Station = board.get_station(1)
	_assert_true(sample_station.scale == Vector2(1.35, 1.35), "Zoomed out: Station pins scaled up to 1.35x for readability")

	# 2. Zoomed in (>= 0.7): normal pins
	board.set_zoom_lod(1.0)
	_assert_true(sample_station.scale == Vector2.ONE, "Zoomed in: Station pins normal 1.0x scale")

	# Route preview from station 1 lights its links and clears with the highlights
	board.show_routes(1, [{"to": 8, "ticket": "bus"}])
	_assert_true(board.get_route_link_count() >= 1, "show_routes() lights the 1-8 bus link")
	board.clear_all_highlights()
	_assert_true(board.get_route_link_count() == 0, "clear_all_highlights() clears route previews")

	# 3. Test Camera Controller bounds
	var cam := BoardCameraController.new()
	cam._ready()
	_assert_true(cam.zoom == Vector2(0.65, 0.65), "Initial camera zoom is 0.65")
	_assert_true(cam.position.x >= cam.map_bounds.position.x and cam.position.x <= cam.map_bounds.end.x, "Camera inside bounds")

	cam.free()
	board.free()

func test_board_play_move() -> void:
	print("\n--- 5. Testing Board.play_move() Vehicle Animations ---")
	var board_scene: PackedScene = load("res://game/scenes/gameplay/Board/Board.tscn")
	var board := board_scene.instantiate() as Board
	root.add_child(board)

	# 1. Test taxi move
	board.set_token_position(1, 1, false)
	board.set_token_visible(1, true)
	await board.play_move(1, 1, 2, "taxi")
	_assert_true(board.get_token(1).position == board.get_station_position(2), "Taxi move: Token 1 arrived at Station 2")
	_assert_true(board.get_token(1).visible, "Taxi move: Token 1 visible after arrival")
	_assert_true(not board.get_vehicles().taxi.visible, "Taxi move: Taxi sprite hidden on completion")

	# 2. Test bus move
	board.set_token_position(2, 3, false)
	board.set_token_visible(2, true)
	await board.play_move(2, 3, 22, "bus")
	_assert_true(board.get_token(2).position == board.get_station_position(22), "Bus move: Token 2 arrived at Station 22")
	_assert_true(board.get_token(2).visible, "Bus move: Token 2 visible after arrival")
	_assert_true(not board.get_vehicles().bus.visible, "Bus move: Bus sprite hidden on completion")

	# 3. Test underground move
	board.set_token_position(3, 3, false)
	board.set_token_visible(3, true)
	await board.play_move(3, 3, 22, "underground")
	_assert_true(board.get_token(3).position == board.get_station_position(22), "Underground move: Token 3 arrived at Station 22")
	_assert_true(board.get_token(3).visible, "Underground move: Token 3 visible after arrival")
	_assert_true(not board.get_vehicles().train.visible, "Underground move: Train sprite hidden on completion")

	# 4. Test ferry move
	board.set_token_position(4, 16, false)
	board.set_token_visible(4, true)
	await board.play_move(4, 16, 19, "ferry")
	_assert_true(board.get_token(4).position == board.get_station_position(19), "Ferry move: Token 4 arrived at Station 19")
	_assert_true(board.get_token(4).visible, "Ferry move: Token 4 visible after arrival")
	_assert_true(not board.get_vehicles().ferry.visible, "Ferry move: Ferry sprite hidden on completion")
	_assert_true(not board.get_vehicles().wake.emitting, "Ferry move: Wake particles stopped emitting")

	# 5. Test Mr. X black ticket on ferry link (uses Ferry + wake particles)
	board.set_token_position(0, 16, false)
	board.set_token_visible(0, true)
	await board.play_move(0, 16, 19, "black")
	_assert_true(board.get_token(0).position == board.get_station_position(19), "Black ticket on ferry: Token 0 arrived at Station 19")
	_assert_true(not board.get_vehicles().ferry.visible, "Black ticket on ferry: Ferry sprite hidden on completion")
	_assert_true(not board.get_vehicles().wake.emitting, "Black ticket on ferry: Wake particles stopped emitting")

	# 6. Test Mr. X black ticket on land link (uses shadow car)
	board.set_token_position(0, 1, false)
	board.set_token_visible(0, true)
	await board.play_move(0, 1, 2, "black")
	_assert_true(board.get_token(0).position == board.get_station_position(2), "Black ticket on land: Token 0 arrived at Station 2")
	_assert_true(not board.get_vehicles().taxi.visible, "Black ticket on land: Shadow car hidden on completion")

	root.remove_child(board)
	board.free()

class MockSaveManager extends RefCounted:
	var store: Dictionary = {}
	func get_value(key: String, default_val: Variant = null) -> Variant:
		return store.get(key, default_val)
	func set_value(key: String, value: Variant) -> void:
		store[key] = value
	func save_game() -> void:
		pass

func test_playability_detectives_mode() -> void:
	print("\n--- 6. Testing Gameplay in 'Play as Detectives' Mode ---")
	var match_scene: PackedScene = load("res://game/scenes/gameplay/Match.tscn")
	_assert_true(match_scene != null, "Match.tscn loaded successfully")

	var match_inst := match_scene.instantiate() as Match
	_assert_true(match_inst != null, "Match.tscn instantiated")
	root.add_child(match_inst)

	var game_manager := GameManager.new()
	var bus_script = load("res://game/autoloads/GameBus.gd")
	var bus: Node = bus_script.new()
	var save := MockSaveManager.new()
	save.set_value("match_mode", "detectives")
	save.set_value("detective_count", 4)

	match_inst.inject_dependencies(game_manager, bus, save, null, null)

	var match_feat: MatchFeature = match_inst.match_feature
	_assert_true(match_feat != null, "Match has MatchFeature")
	_assert_true(match_feat.mode == "detectives", "Match mode is 'detectives'")

	# Initial token visibilities
	_assert_true(not match_inst.board.get_token(0).visible, "Detectives mode: Mr. X token is hidden initially")
	_assert_true(match_inst.board.get_token(1).visible, "Detectives mode: Detective 1 token is visible")
	_assert_true(match_inst.board.get_token(2).visible, "Detectives mode: Detective 2 token is visible")
	_assert_true(match_inst.board.get_token(3).visible, "Detectives mode: Detective 3 token is visible")
	_assert_true(match_inst.board.get_token(4).visible, "Detectives mode: Detective 4 token is visible")

	# Initial vehicle states
	_assert_true(not match_inst.board.get_vehicles().taxi.visible, "Taxi initially hidden")
	_assert_true(not match_inst.board.get_vehicles().bus.visible, "Bus initially hidden")
	_assert_true(not match_inst.board.get_vehicles().train.visible, "Train initially hidden")
	_assert_true(not match_inst.board.get_vehicles().ferry.visible, "Ferry initially hidden")
	_assert_true(not match_inst.board.get_vehicles().wake.emitting, "Wake initially not emitting")

	# Initial turn is Mr. X (AI)
	_assert_true(match_feat.is_ai_turn(), "Turn 0 is AI turn (Mr. X)")

	# Let Mr. X move using _execute_move_and_animate
	var legal_mrx: Array[Dictionary] = match_feat.state.legal_moves(0)
	_assert_true(not legal_mrx.is_empty(), "Mr. X has legal moves")
	var mrx_target: int = int(legal_mrx[0]["to"])
	var mrx_ticket: String = str(legal_mrx[0]["ticket"])

	await match_inst._execute_move_and_animate(0, mrx_target, mrx_ticket)

	# CRITICAL HIDDEN-MOVEMENT ASSERTIONS FOR MR. X IN DETECTIVES MODE:
	_assert_true(not match_inst.board.get_vehicles().taxi.visible, "CRITICAL: Mr. X move did NOT show Taxi sprite")
	_assert_true(not match_inst.board.get_vehicles().bus.visible, "CRITICAL: Mr. X move did NOT show Bus sprite")
	_assert_true(not match_inst.board.get_vehicles().train.visible, "CRITICAL: Mr. X move did NOT show Train sprite")
	_assert_true(not match_inst.board.get_vehicles().ferry.visible, "CRITICAL: Mr. X move did NOT show Ferry sprite")
	_assert_true(not match_inst.board.get_vehicles().wake.emitting, "CRITICAL: Mr. X move did NOT emit Wake particles")
	_assert_true(not match_inst.board.get_token(0).visible, "CRITICAL: Mr. X token remains invisible after round 1 non-reveal move")
	_assert_true(match_feat.state.mrx_move_log.size() == 1, "Mr. X move logged in travel log")
	_assert_true(match_feat.state.positions[0] == mrx_target, "Mr. X position updated internally in state")

	# Turn passed to Detective 1 (human)
	_assert_true(match_feat.state.current_player == 1, "Turn passed to Detective 1 (human)")
	_assert_true(not match_feat.is_ai_turn(), "Detective 1 turn is human turn")

	# Simulate human clicking a legal station for Detective 1
	var legal_d1: Array[Dictionary] = match_feat.state.legal_moves(1)
	_assert_true(not legal_d1.is_empty(), "Detective 1 has legal moves")
	var chosen_st: int = int(legal_d1[0]["to"])
	var chosen_ticket: String = str(legal_d1[0]["ticket"])

	match_inst._on_station_clicked(chosen_st)
	if match_inst.hud != null and match_inst.hud.ticket_picker != null and match_inst.hud.ticket_picker.visible:
		match_inst.hud.ticket_picker._on_ticket_pressed(chosen_ticket)
	while match_inst._is_animating_move:
		await process_frame

	_assert_true(match_feat.state.positions[1] == chosen_st, "Detective 1 moved to clicked station %d" % chosen_st)
	_assert_true(match_inst.board.get_token(1).position == match_inst.board.get_station_position(chosen_st), "Detective 1 token positioned at station %d" % chosen_st)
	_assert_true(match_inst.board.get_token(1).visible, "Detective 1 token visible")
	_assert_true(not match_inst.board.get_vehicles().get_vehicle(chosen_ticket).visible, "Vehicle hidden after Detective 1 move finishes")

	root.remove_child(match_inst)
	match_inst.free()
	game_manager.free()
	bus.free()

func test_playability_mrx_mode() -> void:
	print("\n--- 7. Testing Gameplay in 'Play as Mr. X' Mode ---")
	var match_scene: PackedScene = load("res://game/scenes/gameplay/Match.tscn")
	var match_inst := match_scene.instantiate() as Match
	root.add_child(match_inst)

	var game_manager := GameManager.new()
	var bus_script = load("res://game/autoloads/GameBus.gd")
	var bus: Node = bus_script.new()
	var save := MockSaveManager.new()
	save.set_value("match_mode", "mrx")
	save.set_value("detective_count", 4)

	match_inst.inject_dependencies(game_manager, bus, save, null, null)

	var match_feat: MatchFeature = match_inst.match_feature
	_assert_true(match_feat != null, "Match has MatchFeature")
	_assert_true(match_feat.mode == "mrx", "Match mode is 'mrx'")

	# In Mr. X mode, Mr. X is human and visible to the player!
	_assert_true(not match_feat.is_ai_turn(), "Initial turn is human turn (Mr. X)")
	_assert_true(match_inst.board.get_token(0).visible, "In Mr. X mode, Mr. X token is visible to human player")

	# Human Mr. X clicks a legal station:
	var legal_mrx: Array[Dictionary] = match_feat.state.legal_moves(0)
	_assert_true(not legal_mrx.is_empty(), "Mr. X has legal moves")
	var target_st: int = int(legal_mrx[0]["to"])
	var ticket_mrx: String = str(legal_mrx[0]["ticket"])

	match_inst._on_station_clicked(target_st)
	if match_inst.hud != null and match_inst.hud.ticket_picker != null and match_inst.hud.ticket_picker.visible:
		match_inst.hud.ticket_picker._on_ticket_pressed(ticket_mrx)
	while match_inst._is_animating_move:
		await process_frame

	_assert_true(match_feat.state.positions[0] == target_st, "Mr. X moved to clicked station %d" % target_st)
	_assert_true(match_inst.board.get_token(0).position == match_inst.board.get_station_position(target_st), "Mr. X token moved to station %d" % target_st)
	# Visibility rule: Mr. X's token is shown ONLY while a Human Mr. X is taking his turn.
	# Once turn passes to Detective, Mr. X's token is hidden.
	_assert_true(not match_inst.board.get_token(0).visible, "Visibility rule: Mr. X token is hidden once Detective turn begins")
	_assert_true(not match_inst.board.get_vehicles().get_vehicle(ticket_mrx).visible, "Vehicle hidden after Mr. X move finishes")

	# Now it's Detective 1 (AI)
	_assert_true(match_feat.state.current_player == 1, "Turn passed to Detective 1 (AI)")
	_assert_true(match_feat.is_ai_turn(), "Detective 1 turn is AI turn")

	# Execute Detective 1 move with animation
	var legal_d1: Array[Dictionary] = match_feat.state.legal_moves(1)
	_assert_true(not legal_d1.is_empty(), "Detective 1 has legal moves")
	var d1_to: int = int(legal_d1[0]["to"])
	var d1_ticket: String = str(legal_d1[0]["ticket"])

	await match_inst._execute_move_and_animate(1, d1_to, d1_ticket)
	_assert_true(match_feat.state.positions[1] == d1_to, "Detective 1 moved to station %d" % d1_to)
	_assert_true(match_inst.board.get_token(1).position == match_inst.board.get_station_position(d1_to), "Detective 1 token positioned at station %d" % d1_to)
	_assert_true(match_inst.board.get_token(1).visible, "Detective 1 token visible")

	root.remove_child(match_inst)
	match_inst.free()
	game_manager.free()
	bus.free()
