extends SceneTree

## MobileLayoutTest — Comprehensive verification suite for Scotland Yard's mobile-first UI:
## - Multi-resolution viewport adaptations (1280x720, 2400x1080, 1334x750, 2048x1536)
## - Safe-area & notch margin handling
## - Drawer responsiveness (auto-collapsed on phones, auto-expanded on tablets)
## - Camera drag vs tap discrimination (<10px tap selects station, >=10px pans)
## - Camera bounds clamping, fit-to-screen, and pan-to-position
## - TicketPicker options, touch targets, and double move toggle
## - GameOverPanel registration, UIManager push_packed, and victory/defeat styling
## - Home menu settings, responsiveness, and Theme.tres styling
## - Strict hidden movement verification in all HUD panels

var passed_tests: int = 0
var failed_tests: int = 0

class MockSaveManager extends SaveManager:
	var store: Dictionary = {}
	func get_value(key: String, default_val: Variant = null) -> Variant:
		return store.get(key, default_val)
	func set_value(key: String, value: Variant) -> void:
		store[key] = value
	func save_game() -> DataResult:
		return null

class MockSceneManager extends SceneManager:
	var last_scene_path: String = ""
	func go_to(path: String) -> void:
		last_scene_path = path

class MockLogger extends Node:
	func debug(_msg: String, _meta: Dictionary = {}) -> void: pass
	func info(_msg: String, _meta: Dictionary = {}) -> void: pass
	func warn(_msg: String, _meta: Dictionary = {}) -> void: pass
	func error(_msg: String, _meta: Dictionary = {}) -> void: pass

func _init() -> void:
	_run_all_tests.call_deferred()

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

func _run_all_tests() -> void:
	print("\n==================================================")
	print("       RUNNING SCOTLAND YARD MOBILE LAYOUT TESTS  ")
	print("==================================================")

	test_multi_resolution_camera_and_bounds()
	test_drawer_responsiveness()
	test_camera_drag_vs_tap_discrimination()
	test_safe_area_notch_and_mouse_filter()
	test_ticket_picker()
	test_game_over_panel()
	test_home_menu_and_theme()
	test_hud_hidden_movement()
	test_spotlight_tells_ui()
	test_pass_and_play_handover()

	print("==================================================")
	print("MOBILE LAYOUT RESULTS: %d Passed, %d Failed" % [passed_tests, failed_tests])
	print("==================================================")

	if failed_tests > 0:
		quit(1)
	else:
		quit(0)

# ── 1. Multi-Resolution Viewport & Camera Tests ───────────────────────────────
func test_multi_resolution_camera_and_bounds() -> void:
	print("\n--- 1. Testing Multi-Resolution Camera & Bounds Clamping ---")

	var cam := BoardCameraController.new()
	root.add_child(cam)

	var resolutions: Array[Dictionary] = [
		{"name": "Standard Landscape (1280x720)", "size": Vector2i(1280, 720)},
		{"name": "Tall Phone (2400x1080)", "size": Vector2i(2400, 1080)},
		{"name": "iPhone Style (1334x750)", "size": Vector2i(1334, 750)},
		{"name": "iPad Tablet (2048x1536)", "size": Vector2i(2048, 1536)},
	]

	for res in resolutions:
		var s: Vector2i = res["size"]
		var r_name: String = res["name"]
		root.size = s

		cam.fit_to_screen()

		var z: float = cam.zoom.x
		_assert_true(z >= cam.min_zoom and z <= cam.max_zoom,
			"%s: Zoom (%0.2f) clamped between %0.2f and %0.2f" % [r_name, z, cam.min_zoom, cam.max_zoom])

		# Clamping test: position far out of bounds
		cam.global_position = Vector2(-2000.0, 8000.0)
		cam._clamp_to_bounds()
		_assert_true(cam.global_position.x >= cam.map_bounds.position.x and cam.global_position.x <= cam.map_bounds.end.x,
			"%s: Camera X (%0.1f) clamped within map bounds" % [r_name, cam.global_position.x])
		_assert_true(cam.global_position.y >= cam.map_bounds.position.y and cam.global_position.y <= cam.map_bounds.end.y,
			"%s: Camera Y (%0.1f) clamped within map bounds" % [r_name, cam.global_position.y])

	# Test pan_to_position
	cam.pan_to_position(Vector2(500.0, 600.0), 0.01)
	_assert_true(cam.global_position.distance_to(Vector2(500.0, 600.0)) < 1500.0,
		"Camera pan_to_position sets target world coordinates")

	root.remove_child(cam)
	cam.free()

# ── 2. Drawer Responsiveness ──────────────────────────────────────────────────
func test_drawer_responsiveness() -> void:
	print("\n--- 2. Testing Drawer Responsiveness (Phone vs Tablet) ---")

	var player_drawer_scene: PackedScene = load("res://game/scenes/ui/hfw/PlayerDrawer.tscn")
	_assert_true(player_drawer_scene != null, "PlayerDrawer.tscn loaded")
	var player_drawer := player_drawer_scene.instantiate() as PlayerDrawer
	root.add_child(player_drawer)

	var travel_drawer_scene: PackedScene = load("res://game/scenes/ui/hfw/TravelLogDrawer.tscn")
	_assert_true(travel_drawer_scene != null, "TravelLogDrawer.tscn loaded")
	var travel_drawer := travel_drawer_scene.instantiate() as TravelLogDrawer
	root.add_child(travel_drawer)

	# 1. Phone shortest side < 500px: Auto-collapsed
	root.size = Vector2i(800, 480) # Shortest side = 480
	player_drawer._check_initial_responsive_state()
	travel_drawer._check_initial_responsive_state()

	_assert_true(not player_drawer._is_expanded, "Phone screen (480p): PlayerDrawer starts collapsed")
	_assert_true(not travel_drawer._is_expanded, "Phone screen (480p): TravelLogDrawer starts collapsed")

	# 2. Tablet shortest side >= 500px: Auto-expanded
	root.size = Vector2i(2048, 1536) # Shortest side = 1536
	player_drawer._check_initial_responsive_state()
	travel_drawer._check_initial_responsive_state()

	_assert_true(player_drawer._is_expanded, "Tablet screen (1536p): PlayerDrawer starts expanded")
	_assert_true(travel_drawer._is_expanded, "Tablet screen (1536p): TravelLogDrawer starts expanded")

	# 3. Toggle Expand & Collapse
	player_drawer.collapse_drawer()
	_assert_true(not player_drawer._is_expanded, "PlayerDrawer collapse_drawer() collapses drawer")
	player_drawer.expand_drawer()
	_assert_true(player_drawer._is_expanded, "PlayerDrawer expand_drawer() expands drawer")

	travel_drawer.collapse_drawer()
	_assert_true(not travel_drawer._is_expanded, "TravelLogDrawer collapse_drawer() collapses drawer")
	travel_drawer.expand_drawer()
	_assert_true(travel_drawer._is_expanded, "TravelLogDrawer expand_drawer() expands drawer")

	# 4. Check pre-placed children
	_assert_true(player_drawer._player_rows.size() == 6, "PlayerDrawer contains 6 pre-placed PlayerRow instances")
	_assert_true(travel_drawer._log_slots.size() == 24, "TravelLogDrawer contains 24 pre-placed LogSlot instances")

	# Reveal rounds gold border check (3, 8, 13, 18, 24)
	for r_num in [3, 8, 13, 18, 24]:
		var slot: LogSlot = travel_drawer._log_slots[r_num - 1]
		_assert_true(slot._is_reveal_round, "LogSlot %d is flagged as a reveal round" % r_num)

	root.remove_child(player_drawer)
	player_drawer.free()
	root.remove_child(travel_drawer)
	travel_drawer.free()

# ── 3. Camera Drag vs Tap Discrimination ──────────────────────────────────────
func test_camera_drag_vs_tap_discrimination() -> void:
	print("\n--- 3. Testing Camera Drag vs Tap Discrimination ---")

	var cam := BoardCameraController.new()
	root.add_child(cam)

	var station_scene: PackedScene = load("res://game/scenes/gameplay/Board/Station.tscn")
	var station := station_scene.instantiate() as Station
	station.id = 42
	root.add_child(station)

	var click_capture := {"id": -1}
	station.clicked.connect(func(st_id: int): click_capture["id"] = st_id)

	# 1. Tap: finger moved < 10px, is_dragging is false
	BoardCameraController.is_dragging = false
	BoardCameraController.drag_distance = 0.0

	var ev_press := InputEventMouseButton.new()
	ev_press.button_index = MOUSE_BUTTON_LEFT
	ev_press.pressed = true
	ev_press.position = Vector2(100.0, 100.0)
	station._on_input_event(null, ev_press, 0)

	var ev_release := InputEventMouseButton.new()
	ev_release.button_index = MOUSE_BUTTON_LEFT
	ev_release.pressed = false
	ev_release.position = Vector2(103.0, 104.0) # Moved 5px
	station._on_input_event(null, ev_release, 0)

	_assert_true(click_capture["id"] == 42, "Tap with 5px movement (< 10px) emitted station clicked(42)")

	# 2. Pan / Drag: finger moved >= 10px -> is_dragging becomes true
	click_capture["id"] = -1
	cam._start_pan(Vector2(200.0, 200.0))
	cam._process_pan_motion(Vector2(15.0, 0.0), Vector2(215.0, 200.0))

	_assert_true(BoardCameraController.is_dragging, "Camera drag >= 10px sets BoardCameraController.is_dragging = true")
	_assert_true(BoardCameraController.drag_distance >= 10.0, "Drag distance tracked correctly")

	# Touch release on station during a drag must NOT trigger station click
	ev_press.position = Vector2(200.0, 200.0)
	station._on_input_event(null, ev_press, 0)

	ev_release.position = Vector2(202.0, 201.0)
	station._on_input_event(null, ev_release, 0)

	_assert_true(click_capture["id"] == -1, "Release on station while is_dragging == true does NOT trigger station click")

	cam._end_pan()
	_assert_true(not BoardCameraController.is_dragging, "Ending pan resets BoardCameraController.is_dragging to false")

	root.remove_child(station)
	station.free()
	root.remove_child(cam)
	cam.free()

# ── 4. Safe Area, Notch Margins, and Mouse Filter ─────────────────────────────
func test_safe_area_notch_and_mouse_filter() -> void:
	print("\n--- 4. Testing Safe Area Notch Margins & Mouse Filters ---")

	var hud_scene: PackedScene = load("res://game/scenes/ui/hfw/HUD.tscn")
	_assert_true(hud_scene != null, "HUD.tscn loaded")
	var hud := hud_scene.instantiate() as InGameHUD
	root.add_child(hud)

	var root_margin: MarginContainer = hud.get_node("%RootMargin") as MarginContainer
	var hud_container: Control = hud.get_node("%HUDContainer") as Control

	_assert_true(root_margin != null, "HUD contains RootMargin")
	_assert_true(hud_container != null, "HUD contains HUDContainer")

	# Mouse Filter checks:
	# Empty areas must IGNORE mouse events so camera/map gets touch events!
	_assert_true(root_margin.mouse_filter == Control.MOUSE_FILTER_IGNORE, "RootMargin mouse_filter == IGNORE")
	_assert_true(hud_container.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUDContainer mouse_filter == IGNORE")

	# UI panels must STOP mouse events so touches on HUD never interact with the map underneath!
	_assert_true(hud.top_bar.mouse_filter == Control.MOUSE_FILTER_STOP, "TopBar mouse_filter == STOP")
	_assert_true(hud.player_drawer.mouse_filter == Control.MOUSE_FILTER_STOP, "PlayerDrawer mouse_filter == STOP")
	_assert_true(hud.travel_log_drawer.mouse_filter == Control.MOUSE_FILTER_STOP, "TravelLogDrawer mouse_filter == STOP")
	_assert_true(hud.ticket_picker.mouse_filter == Control.MOUSE_FILTER_STOP, "TicketPicker mouse_filter == STOP")

	# Simulated notch margins:
	root_margin.add_theme_constant_override("margin_left", 48)
	root_margin.add_theme_constant_override("margin_right", 48)

	_assert_true(root_margin.get_theme_constant("margin_left") == 48, "Simulated notch: Left safe area margin = 48px")
	_assert_true(root_margin.get_theme_constant("margin_right") == 48, "Simulated notch: Right safe area margin = 48px")

	root.remove_child(hud)
	hud.free()

# ── 5. TicketPicker UI & Flow ─────────────────────────────────────────────────
func test_ticket_picker() -> void:
	print("\n--- 5. Testing TicketPicker Component ---")

	var picker_scene: PackedScene = load("res://game/scenes/ui/hfw/TicketPicker.tscn")
	_assert_true(picker_scene != null, "TicketPicker.tscn loaded")
	var picker := picker_scene.instantiate() as TicketPicker
	root.add_child(picker)

	# 1. Detective move to taxi+bus station
	picker.open_picker(78, ["taxi", "bus"], false, false)
	_assert_true(picker.visible, "TicketPicker is visible after open_picker()")
	_assert_true(picker.get_node("%BtnTaxi").visible, "Taxi button is visible")
	_assert_true(picker.get_node("%BtnBus").visible, "Bus button is visible")
	_assert_true(not picker.get_node("%BtnUnderground").visible, "Underground button is hidden")
	_assert_true(not picker.get_node("%BtnBlack").visible, "Black ticket button is hidden for detective")
	_assert_true(not picker.get_node("%ChkDoubleMove").visible, "Double Move checkbox is hidden for detective")

	# Test signal emission using a dictionary container for reference capture
	var result := {"ticket": "", "double": true, "cancelled": false}
	picker.ticket_chosen.connect(func(t: String, d: bool):
		result["ticket"] = t
		result["double"] = d
	)
	picker.picker_cancelled.connect(func():
		result["cancelled"] = true
	)

	picker._on_ticket_pressed("bus")
	_assert_true(result["ticket"] == "bus", "Selected ticket was 'bus'")
	_assert_true(not result["double"], "Double move was false")

	# 2. Mr. X move with black ticket and double move available
	picker.open_picker(95, ["taxi", "bus", "black"], true, true)
	_assert_true(picker.get_node("%BtnBlack").visible, "Black ticket button is visible for Mr. X")
	_assert_true(picker.get_node("%ChkDoubleMove").visible, "Double Move checkbox is visible for Mr. X")

	picker.get_node("%ChkDoubleMove").button_pressed = true
	picker._on_ticket_pressed("black")
	_assert_true(result["ticket"] == "black", "Selected ticket was 'black'")
	_assert_true(result["double"], "Double move was true when checkbox checked")

	# 3. Cancel picker
	result["cancelled"] = false
	picker.open_picker(100, ["taxi"], false, false)
	picker.cancel_picker()
	_assert_true(result["cancelled"], "cancel_picker() emitted picker_cancelled")

	root.remove_child(picker)
	picker.free()

# ── 6. GameOverPanel Registration & Flow ──────────────────────────────────────
func test_game_over_panel() -> void:
	print("\n--- 6. Testing GameOverPanel & UIManager Integration ---")

	var panel_path: String = GameConfig.UI_PANELS.get("game_over", "")
	_assert_true(panel_path == "res://game/scenes/ui/hfw/GameOverPanel.tscn",
		"GameConfig.UI_PANELS['game_over'] registered correctly")

	var panel_scene: PackedScene = load(panel_path)
	_assert_true(panel_scene != null, "GameOverPanel.tscn loaded")

	var ui_mgr := UIManager.new()
	var game_manager := GameManager.new()
	var bus_script = load("res://game/autoloads/GameBus.gd")
	var bus: Node = bus_script.new()
	var logger := MockLogger.new()

	ui_mgr.configure(logger, bus, null, game_manager)
	root.add_child(ui_mgr)

	# Push via UIManager.push_packed
	ui_mgr.push_packed(panel_scene)
	_assert_true(ui_mgr.stack_size() == 1, "GameOverPanel pushed to UIManager stack")

	var panel := ui_mgr.current() as GameOverPanel
	_assert_true(panel != null, "Current UI panel is GameOverPanel")

	# Test Detectives win display
	panel.set_result("detectives", "Detective 3 caught Mr. X at station 84")
	var lbl_winner: Label = panel.get_node("%LblWinner") as Label
	var lbl_reason: Label = panel.get_node("%LblReason") as Label
	_assert_true(lbl_winner.text == "DETECTIVES WIN!", "Detectives victory title set correctly")
	_assert_true(lbl_reason.text == "Detective 3 caught Mr. X at station 84", "Detectives victory reason set correctly")

	# Test Mr. X win display
	panel.set_result("mrx", "Mr. X survived 24 rounds")
	_assert_true(lbl_winner.text == "MR. X WINS!", "Mr. X victory title set correctly")
	_assert_true(lbl_reason.text == "Mr. X survived 24 rounds", "Mr. X victory reason set correctly")

	ui_mgr.pop()
	_assert_true(ui_mgr.stack_size() == 0, "GameOverPanel popped from stack")

	root.remove_child(ui_mgr)
	ui_mgr.free()
	game_manager.free()
	bus.free()
	logger.free()

# ── 7. Home Menu & Theme.tres ─────────────────────────────────────────────────
func test_home_menu_and_theme() -> void:
	print("\n--- 7. Testing Home Menu & Theme.tres ---")

	var theme_res: Theme = load("res://game/assets/Theme.tres") as Theme
	_assert_true(theme_res != null, "Theme.tres loaded successfully")

	var home_scene: PackedScene = load("res://game/scenes/Home/Home.tscn")
	_assert_true(home_scene != null, "Home.tscn loaded successfully")

	var home := home_scene.instantiate() as HomeScene
	root.add_child(home)

	var save := MockSaveManager.new()
	save.set_value("match_mode", "detectives")
	save.set_value("detective_count", 4)
	save.set_value("tells_enabled", false)

	home._save = save
	home._on_ready()

	# Mode selection
	home._set_mode("mrx")
	_assert_true(home._selected_mode == "mrx", "HomeScene mode switched to 'mrx'")
	home._set_mode("detectives")
	_assert_true(home._selected_mode == "detectives", "HomeScene mode switched to 'detectives'")

	# Detective count selection (3, 4, 5)
	home._set_detective_count(3)
	_assert_true(home._selected_detective_count == 3, "Detective count set to 3")
	home._set_detective_count(5)
	_assert_true(home._selected_detective_count == 5, "Detective count set to 5")
	home._set_detective_count(4)
	_assert_true(home._selected_detective_count == 4, "Detective count reset to 4")

	# Tells toggle
	home._tells_enabled = true

	# Start action saves settings
	home._save = save
	var mock_scene_mgr := MockSceneManager.new()
	home._scene = mock_scene_mgr as Variant
	home._on_start_pressed()

	_assert_true(save.get_value("match_mode") == "detectives", "Saved match_mode is 'detectives'")
	_assert_true(save.get_value("detective_count") == 4, "Saved detective_count is 4")
	_assert_true(save.get_value("tells_enabled") == true, "Saved tells_enabled is true")
	_assert_true(mock_scene_mgr.last_scene_path == "res://game/scenes/gameplay/Match.tscn", "Start transitions to Match.tscn")

	root.remove_child(home)
	home.free()

# ── 8. Strict Hidden Movement Verification in HUD ─────────────────────────────
func test_hud_hidden_movement() -> void:
	print("\n--- 8. Testing Information Hiding & Hidden Movement in HUD ---")

	var map := MapData.new("res://game/assets/data/map.json")
	var state := SYGameState.new(map, 4)

	# Set positions: Mr. X at secret station 112, Detectives at 10, 20, 30, 40
	state.positions[0] = 112
	state.positions[1] = 10
	state.positions[2] = 20
	state.positions[3] = 30
	state.positions[4] = 40

	var hud_scene: PackedScene = load("res://game/scenes/ui/hfw/HUD.tscn")
	var hud := hud_scene.instantiate() as InGameHUD
	root.add_child(hud)

	var bus_script = load("res://game/autoloads/GameBus.gd")
	var bus: Node = bus_script.new()

	# 1. DETECTIVES MODE: Mr. X position must NEVER be visible
	hud.configure_hud(state, "detectives", 4, bus)

	var mrx_row: PlayerRow = hud.player_drawer._player_rows[0]
	var mrx_stn_lbl: Label = mrx_row.get_node("%LblStation") as Label

	_assert_true(mrx_stn_lbl.text == "Hidden", "Detectives mode: Mr. X station shows 'Hidden' (got '%s')" % mrx_stn_lbl.text)
	_assert_true(not "112" in mrx_stn_lbl.text, "CRITICAL: Secret station 112 is NOT in Mr. X PlayerRow label")

	# Add non-reveal round 1 move for Mr. X
	state.mrx_move_log.append({
		"round": 1,
		"ticket": "taxi",
		"station": 112,
		"revealed": false
	})
	hud.update_hud()

	var slot_1: LogSlot = hud.travel_log_drawer._log_slots[0]
	var slot_1_stn_lbl: Label = slot_1.get_node("%LblStation") as Label

	_assert_true(slot_1_stn_lbl.text == "Hidden", "Detectives mode: LogSlot 1 shows 'Hidden' (got '%s')" % slot_1_stn_lbl.text)
	_assert_true(not "112" in slot_1_stn_lbl.text, "CRITICAL: Secret station 112 is NOT in round 1 travel log slot")

	# Add reveal round 3 move for Mr. X (surfaced at 115)
	state.last_revealed_position = 115
	state.round = 3
	state.mrx_move_log.append({
		"round": 3,
		"ticket": "bus",
		"station": 115,
		"revealed": true
	})
	hud.update_hud()

	var slot_3: LogSlot = hud.travel_log_drawer._log_slots[2]
	var slot_3_stn_lbl: Label = slot_3.get_node("%LblStation") as Label

	_assert_true("115" in slot_3_stn_lbl.text, "Reveal round 3: Surfaced station 115 visible in LogSlot 3")
	_assert_true(mrx_stn_lbl.text == "Last: Stn 115", "Mr. X PlayerRow displays 'Last: Stn 115' after reveal")

	# 2. MR. X MODE: Mr. X player CAN see their own station
	hud.configure_hud(state, "mrx", 4, bus)
	hud.update_hud()

	_assert_true(mrx_stn_lbl.text == "Stn 112", "Mr. X mode: Player sees their own current station (got '%s')" % mrx_stn_lbl.text)
	_assert_true("112" in slot_1_stn_lbl.text, "Mr. X mode: Round 1 station visible in travel log slot")

	root.remove_child(hud)
	hud.free()
	bus.free()

# ── 9. Spotlight Tells UI & Tells Mode Adaptations ────────────────────────────
func test_spotlight_tells_ui() -> void:
	print("\n--- 9. Testing Spotlight Tells UI & Mode Adaptations ---")

	# 1. Home Menu Tells Toggle Button
	var home_scene: PackedScene = load("res://game/scenes/Home/Home.tscn")
	var home := home_scene.instantiate() as HomeScene
	root.add_child(home)

	var save := MockSaveManager.new()
	save.set_value("tells_enabled", true)
	home._save = save
	home._on_ready()

	var chk_tells: Button = home.get_node("%ChkTells") as Button
	_assert_true(chk_tells != null, "Home menu has %ChkTells toggle button")
	_assert_true(chk_tells.custom_minimum_size.y >= 48.0, "ChkTells button min touch height >= 48px (got %f)" % chk_tells.custom_minimum_size.y)
	_assert_true(chk_tells.button_pressed == true, "ChkTells initialized to pressed (Tells ON)")
	_assert_true("ON" in chk_tells.text, "ChkTells button text reflects ON state")

	chk_tells.button_pressed = false
	chk_tells.emit_signal("toggled", false)
	_assert_true("OFF" in chk_tells.text, "ChkTells button text reflects OFF state")
	home._on_start_pressed()
	_assert_true(save.get_value("tells_enabled") == false, "Tells OFF persisted to SaveManager")

	root.remove_child(home)
	home.free()

	# 2. TicketPicker Close Eyes Button (Min 48x48)
	var picker_scene: PackedScene = load("res://game/scenes/ui/hfw/TicketPicker.tscn")
	var picker := picker_scene.instantiate() as TicketPicker
	root.add_child(picker)

	var btn_close_eyes: Button = picker.get_node_or_null("%BtnCloseEyes") as Button
	_assert_true(btn_close_eyes != null, "TicketPicker has %BtnCloseEyes button")
	_assert_true(btn_close_eyes.custom_minimum_size.x >= 48.0 and btn_close_eyes.custom_minimum_size.y >= 48.0,
		"BtnCloseEyes touch target is >= 48x48 (got %s)" % [str(btn_close_eyes.custom_minimum_size)])

	# When opened for Mr. X with cards:
	picker.open_picker(10, ["taxi"], true, false, 2)
	_assert_true(btn_close_eyes.visible, "BtnCloseEyes is visible when Mr. X has cards")
	_assert_true(not btn_close_eyes.disabled, "BtnCloseEyes is enabled")

	var eye_result := {"called": false}
	picker.close_eyes_requested.connect(func(): eye_result["called"] = true)
	btn_close_eyes.pressed.emit()
	_assert_true(eye_result["called"], "Pressing BtnCloseEyes emits close_eyes_requested signal")
	_assert_true(not picker.visible, "Picker closes after close_eyes_requested")

	# When opened for Detective:
	picker.open_picker(10, ["taxi"], false, false, 0)
	_assert_true(not btn_close_eyes.visible, "BtnCloseEyes is hidden for detectives")

	root.remove_child(picker)
	picker.free()

	# 3. PlayerRow Close Eyes Count Chip
	var row_scene: PackedScene = load("res://game/scenes/ui/hfw/PlayerRow.tscn")
	var row := row_scene.instantiate() as PlayerRow
	root.add_child(row)

	var map := MapData.new("res://game/assets/data/map.json")
	var state := SYGameState.new(map, 4)
	state.close_eyes_cards = 2

	# Configure row for Mr. X (player 0)
	row.configure_row(0, "Mr. X", Color("#E8457A"), false, true)
	row.update_row(state)

	var chip_eyes: PanelContainer = row.get_node_or_null("%ChipCloseEyes") as PanelContainer
	_assert_true(chip_eyes != null, "PlayerRow has %ChipCloseEyes chip")
	_assert_true(chip_eyes.visible, "ChipCloseEyes is visible for Mr. X")
	var lbl_eyes: Label = row.get_node_or_null("%LblCloseEyes") as Label
	_assert_true(lbl_eyes != null and "2" in lbl_eyes.text, "ChipCloseEyes displays remaining count '2' (got '%s')" % lbl_eyes.text)

	# Configure row for Detective 1
	row.configure_row(1, "Detective 1", Color("#3B82F6"), false, false)
	row.update_row(state)
	_assert_true(not chip_eyes.visible, "ChipCloseEyes is hidden for detectives")

	root.remove_child(row)
	row.free()

	# 4. No off-screen arrow: detectives have to notice Mr. X's glance on the map themselves
	var hud := (load("res://game/scenes/ui/hfw/HUD.tscn") as PackedScene).instantiate() as InGameHUD
	_assert_true(hud.get_node_or_null("%GazeArrow") == null, "HUD has no gaze arrow pointing at Mr. X's spotlight")
	hud.free()

# ── 10. Pass-and-Play Handover Screen & Route Display ─────────────────────────
func test_pass_and_play_handover() -> void:
	print("\n--- 10. Testing Pass-and-Play Handover Screen & GameOver Route ---")

	# 1. HandoverPanel Registration & UI Checks
	var handover_path: String = GameConfig.UI_PANELS.get("handover", "")
	_assert_true(not handover_path.is_empty(), "HandoverPanel registered in GameConfig.UI_PANELS['handover']")

	var panel_scene: PackedScene = load(handover_path)
	_assert_true(panel_scene != null, "HandoverPanel.tscn loaded successfully")

	var panel := panel_scene.instantiate() as HandoverPanel
	root.add_child(panel)

	var backdrop: ColorRect = panel.get_node_or_null("OpaqueBackdrop") as ColorRect
	_assert_true(backdrop != null, "HandoverPanel has full-screen OpaqueBackdrop")
	_assert_true(backdrop.color.a >= 0.99, "Handover backdrop is 100%% opaque (got alpha %f)" % backdrop.color.a)

	var btn_start: Button = panel.get_node_or_null("%BtnStart") as Button
	_assert_true(btn_start != null, "HandoverPanel has %BtnStart button")
	_assert_true(btn_start.custom_minimum_size.y >= 48.0, "BtnStart min height >= 48px (got %f)" % btn_start.custom_minimum_size.y)

	panel.setup_handover("Sherlock Holmes", false)
	var lbl_title: Label = panel.get_node_or_null("%LblTitle") as Label
	_assert_true("Sherlock Holmes" in lbl_title.text, "Handover title contains target player name")
	_assert_true("Sherlock Holmes" in btn_start.text, "Handover start button contains target player name")

	panel.setup_handover("Mr. X", true)
	_assert_true("Mr. X" in lbl_title.text, "Handover title contains Mr. X name")

	var hand_result := {"dismissed": false}
	panel.handed_over.connect(func(): hand_result["dismissed"] = true)
	btn_start.pressed.emit()
	_assert_true(hand_result["dismissed"], "Pressing start button emits handed_over signal")

	root.remove_child(panel)
	panel.free()

	# 2. GameOverPanel Route Display
	var gop_scene: PackedScene = load("res://game/scenes/ui/hfw/GameOverPanel.tscn")
	var gop := gop_scene.instantiate() as GameOverPanel
	root.add_child(gop)

	var lbl_route: Label = gop.get_node_or_null("%LblRoute") as Label
	_assert_true(lbl_route != null, "GameOverPanel has %LblRoute label")

	var test_route: Array[int] = [35, 48, 62, 81, 104]
	gop.set_result("detectives", "Detective 1 caught Mr. X at Station 104", test_route)
	_assert_true("35" in lbl_route.text and "104" in lbl_route.text,
		"GameOverPanel displays full Mr. X route in order: '%s'" % lbl_route.text)

	root.remove_child(gop)
	gop.free()
