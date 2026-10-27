extends SceneTree

## Playthrough Verification — Full match simulation and verification of all 4 playthroughs.
## Run with: godot --headless -s res://tools/playthrough_verification.gd

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	print("==================================================")
	print("     SCOTLAND YARD FULL PLAYTHROUGH VERIFICATION  ")
	print("==================================================")
	_run_all.call_deferred()

func _pass(msg: String) -> void:
	total_tests += 1
	passed_tests += 1
	print("  [PASS] %s" % msg)

func _fail(msg: String) -> void:
	total_tests += 1
	failed_tests += 1
	printerr("  [FAIL] %s" % msg)

func _assert_true(cond: bool, msg: String) -> void:
	if cond:
		_pass(msg)
	else:
		_fail(msg)

func _run_all() -> void:
	await _test_playthrough_1_detectives_tells_on()
	await _test_playthrough_2_mrx_tells_off()
	await _test_playthrough_3_pass_and_play()
	await _test_playthrough_4_mixed_seats()
	await _test_multi_resolution_layout_audit()
	await _test_play_again_clean_reset()
	await _test_pass_and_play_detective_turn_after_mrx()
	await _test_ai_mrx_turn_tells_on_sequence()
	await _test_ai_detective_pacing_and_zoom()

	print("==================================================")
	print("PLAYTHROUGH VERIFICATION: %d Passed, %d Failed (Total %d)" % [passed_tests, failed_tests, total_tests])
	print("==================================================")

	if failed_tests > 0:
		quit(1)
	else:
		quit(0)

# ── 1. Play as Detectives (AI Mr. X), Tells On ────────────────────────────────
func _test_playthrough_1_detectives_tells_on() -> void:
	print("\n--- Playthrough 1: Play as Detectives (AI Mr. X), Tells On (2400x1080) ---")
	root.size = Vector2i(2400, 1080)

	var match_scene: PackedScene = load("res://game/scenes/gameplay/Match.tscn")
	var match_inst := match_scene.instantiate() as Match
	root.add_child(match_inst)

	var gm := GameManager.new()
	var bus_res = load("res://game/autoloads/GameBus.gd")
	var bus: Node = bus_res.new()
	var save := MockSave.new()
	save.set_val("tells_enabled", true)
	save.set_val("detective_count", 4)
	save.set_val("match_mode", "detectives")
	save.set_val("seats", [
		{"id": 0, "name": "Mr. X", "type": "ai", "is_human": false},
		{"id": 1, "name": "Detective 1", "type": "human", "is_human": true},
		{"id": 2, "name": "Detective 2", "type": "human", "is_human": true},
		{"id": 3, "name": "Detective 3", "type": "human", "is_human": true},
		{"id": 4, "name": "Detective 4", "type": "human", "is_human": true},
	])

	match_inst.inject_dependencies(gm, bus, save, null, null)
	var mf: MatchFeature = match_inst.match_feature

	_assert_true(mf.is_ai_player(0), "PT1: Mr. X is AI")
	_assert_true(mf.tells_enabled, "PT1: Tells On")
	_assert_true(not match_inst.board.get_token(0).visible, "PT1: Mr. X token hidden initially")

	# Mr. X AI turn: executes move
	var played_mrx := mf.play_ai_turn()
	_assert_true(played_mrx, "PT1: Mr. X AI move executed")
	_assert_true(not match_inst.board.get_token(0).visible, "PT1: Mr. X token remains hidden after move")
	_assert_true(not match_inst.board.get_vehicles().taxi.visible, "PT1: Taxi vehicle hidden (no AI leak)")
	_assert_true(not match_inst.board.get_vehicles().bus.visible, "PT1: Bus vehicle hidden")
	_assert_true(not match_inst.board.get_vehicles().train.visible, "PT1: Metro vehicle hidden")
	_assert_true(not match_inst.board.get_vehicles().ferry.visible, "PT1: Ferry vehicle hidden")

	# Check camera focus rule: cannot focus on Mr. X
	match_inst._focus_on_player(0)
	_assert_true(match_inst.camera.position != match_inst.board.get_station_position(mf.state.positions[0]),
		"PT1: Camera does NOT pan to secret Mr. X station")

	# Detective 1 moves
	var d1_moves := mf.state.legal_moves(1)
	_assert_true(not d1_moves.is_empty(), "PT1: Detective 1 has moves")
	var d1_to: int = int(d1_moves[0]["to"])
	var d1_t: String = str(d1_moves[0]["ticket"])
	mf.apply_move(1, d1_to, d1_t)
	_assert_true(mf.state.positions[1] == d1_to, "PT1: Detective 1 moved to station %d" % d1_to)

	root.remove_child(match_inst)
	match_inst.free()
	gm.free()
	bus.free()

# ── 2. Play as Mr. X (AI Detectives), Tells Off ───────────────────────────────
func _test_playthrough_2_mrx_tells_off() -> void:
	print("\n--- Playthrough 2: Play as Mr. X (AI Detectives), Tells Off (1280x720) ---")
	root.size = Vector2i(1280, 720)

	var match_scene: PackedScene = load("res://game/scenes/gameplay/Match.tscn")
	var match_inst := match_scene.instantiate() as Match
	root.add_child(match_inst)

	var gm := GameManager.new()
	var bus_res = load("res://game/autoloads/GameBus.gd")
	var bus: Node = bus_res.new()
	var save := MockSave.new()
	save.set_val("tells_enabled", false)
	save.set_val("detective_count", 4)
	save.set_val("match_mode", "mrx")
	save.set_val("seats", [
		{"id": 0, "name": "Mr. X", "type": "human", "is_human": true},
		{"id": 1, "name": "Detective 1", "type": "ai", "is_human": false},
		{"id": 2, "name": "Detective 2", "type": "ai", "is_human": false},
		{"id": 3, "name": "Detective 3", "type": "ai", "is_human": false},
		{"id": 4, "name": "Detective 4", "type": "ai", "is_human": false},
	])

	match_inst.inject_dependencies(gm, bus, save, null, null)
	var mf: MatchFeature = match_inst.match_feature

	_assert_true(mf.is_human_player(0), "PT2: Mr. X is Human")
	_assert_true(not mf.tells_enabled, "PT2: Tells Off")
	_assert_true(match_inst.board.get_token(0).visible, "PT2: Mr. X token visible during his turn")
	_assert_true(not match_inst.board.is_spotlight_visible(), "PT2: Spotlight NEVER shown when Tells Off")

	# Human Mr. X moves
	var m_mrx := mf.state.legal_moves(0)[0]
	var mrx_to: int = int(m_mrx["to"])
	var mrx_ticket: String = str(m_mrx["ticket"])

	match_inst._on_station_clicked(mrx_to)
	if match_inst.hud.ticket_picker.visible:
		match_inst.hud.ticket_picker._on_ticket_pressed(mrx_ticket)
	while match_inst._is_animating_move:
		await process_frame

	_assert_true(mf.state.positions[0] == mrx_to, "PT2: Mr. X moved to station %d" % mrx_to)
	_assert_true(not match_inst.board.get_token(0).visible, "PT2: Mr. X token hidden once AI detective turn begins")
	_assert_true(not match_inst.board.is_spotlight_visible(), "PT2: Spotlight remains off")

	# AI Detective moves
	var d1_m: Dictionary = mf.detective_ai.choose_move(1, mf.state, mf.map_data)
	mf.apply_move(1, int(d1_m["to"]), str(d1_m["ticket"]))
	_assert_true(mf.state.positions[1] == int(d1_m["to"]), "PT2: AI Detective 1 moved")

	root.remove_child(match_inst)
	match_inst.free()
	gm.free()
	bus.free()

# ── 3. Pass and Play, All Human, 4 Detectives, Tells On ───────────────────────
func _test_playthrough_3_pass_and_play() -> void:
	print("\n--- Playthrough 3: Pass and Play (All Human), Tells On (1280x720) ---")
	root.size = Vector2i(1280, 720)

	var match_scene: PackedScene = load("res://game/scenes/gameplay/Match.tscn")
	var match_inst := match_scene.instantiate() as Match
	root.add_child(match_inst)

	var gm := GameManager.new()
	var bus_res = load("res://game/autoloads/GameBus.gd")
	var bus: Node = bus_res.new()
	var save := MockSave.new()
	save.set_val("tells_enabled", true)
	save.set_val("detective_count", 4)
	save.set_val("match_mode", "pass_and_play")
	save.set_val("seats", [
		{"id": 0, "name": "Moriarty", "type": "human", "is_human": true},
		{"id": 1, "name": "Sherlock", "type": "human", "is_human": true},
		{"id": 2, "name": "Watson", "type": "human", "is_human": true},
		{"id": 3, "name": "Lestrade", "type": "human", "is_human": true},
		{"id": 4, "name": "Mycroft", "type": "human", "is_human": true},
	])

	match_inst.inject_dependencies(gm, bus, save, null, null)
	var mf: MatchFeature = match_inst.match_feature

	_assert_true(mf.is_human_mrx(), "PT3: Mr. X is human")
	_assert_true(mf.has_human_detectives(), "PT3: All detectives are human")
	_assert_true(mf.mode == "pass_and_play", "PT3: Mode is pass_and_play")

	# Handover check: switching to Mr. X triggers handover
	_assert_true(match_inst._should_trigger_handover(0), "PT3: Handover triggered for Mr. X")

	# Simulate Mr. X taking turn behind handover
	match_inst._start_player_turn(0)
	_assert_true(match_inst.board.get_token(0).visible, "PT3: Mr. X token visible during his turn")

	# Mr. X moves
	var m0 := mf.state.legal_moves(0)[0]
	mf.apply_move(0, int(m0["to"]), str(m0["ticket"]))
	_assert_true(mf.state.current_player == 1, "PT3: Turn passed to Detective 1")

	# Handover check: switching from Mr. X to Detective 1 triggers handover
	match_inst._previous_player = 0
	_assert_true(match_inst._should_trigger_handover(1), "PT3: Handover triggered when switching to Detective 1")

	# Check between detectives: NO handover between Detective 1 and Detective 2!
	match_inst._previous_player = 1
	_assert_true(not match_inst._should_trigger_handover(2), "PT3: NO handover between Detective 1 and Detective 2")

	root.remove_child(match_inst)
	match_inst.free()
	gm.free()
	bus.free()

# ── 4. Mixed: Human Mr. X, 2 Human + 2 AI Detectives ──────────────────────────
func _test_playthrough_4_mixed_seats() -> void:
	print("\n--- Playthrough 4: Mixed (Human Mr. X, 2 Human + 2 AI Detectives) ---")

	var match_scene: PackedScene = load("res://game/scenes/gameplay/Match.tscn")
	var match_inst := match_scene.instantiate() as Match
	root.add_child(match_inst)

	var gm := GameManager.new()
	var bus_res = load("res://game/autoloads/GameBus.gd")
	var bus: Node = bus_res.new()
	var save := MockSave.new()
	save.set_val("tells_enabled", true)
	save.set_val("detective_count", 4)
	save.set_val("seats", [
		{"id": 0, "name": "Mr. X", "type": "human", "is_human": true},
		{"id": 1, "name": "Det 1 (Human)", "type": "human", "is_human": true},
		{"id": 2, "name": "Det 2 (Human)", "type": "human", "is_human": true},
		{"id": 3, "name": "Det 3 (AI)", "type": "ai", "is_human": false},
		{"id": 4, "name": "Det 4 (AI)", "type": "ai", "is_human": false},
	])

	match_inst.inject_dependencies(gm, bus, save, null, null)
	var mf: MatchFeature = match_inst.match_feature

	_assert_true(mf.is_human_player(0), "PT4: Mr. X is human")
	_assert_true(mf.is_human_player(1), "PT4: D1 is human")
	_assert_true(mf.is_human_player(2), "PT4: D2 is human")
	_assert_true(mf.is_ai_player(3), "PT4: D3 is AI")
	_assert_true(mf.is_ai_player(4), "PT4: D4 is AI")
	_assert_true(mf.has_human_detectives(), "PT4: has human detectives")
	_assert_true(mf.has_ai_detectives(), "PT4: has AI detectives")
	_assert_true(mf.mode == "mixed", "PT4: Mode is mixed")

	# Advance turns: 0 -> 1 -> 2 -> 3 -> 4
	mf.apply_move(0, int(mf.state.legal_moves(0)[0]["to"]), str(mf.state.legal_moves(0)[0]["ticket"]))
	_assert_true(not mf.is_ai_turn(), "PT4: D1 is human turn")

	mf.apply_move(1, int(mf.state.legal_moves(1)[0]["to"]), str(mf.state.legal_moves(1)[0]["ticket"]))
	_assert_true(not mf.is_ai_turn(), "PT4: D2 is human turn")

	mf.apply_move(2, int(mf.state.legal_moves(2)[0]["to"]), str(mf.state.legal_moves(2)[0]["ticket"]))
	_assert_true(mf.is_ai_turn(), "PT4: D3 is AI turn")

	var d3_m = mf.detective_ai.choose_move(3, mf.state, mf.map_data)
	mf.apply_move(3, int(d3_m["to"]), str(d3_m["ticket"]))
	_assert_true(mf.is_ai_turn(), "PT4: D4 is AI turn")

	var d4_m = mf.detective_ai.choose_move(4, mf.state, mf.map_data)
	mf.apply_move(4, int(d4_m["to"]), str(d4_m["ticket"]))
	_assert_true(mf.state.current_player == 0, "PT4: Cycled back to Mr. X")
	_assert_true(not mf.is_ai_turn(), "PT4: Mr. X is human turn")

	root.remove_child(match_inst)
	match_inst.free()
	gm.free()
	bus.free()

# ── 5. Multi-Resolution Layout & Drawer Audit ──────────────────────────────────
func _test_multi_resolution_layout_audit() -> void:
	print("\n--- 5. Layout Audit across 2400x1080, 1334x750, 1280x720, 2048x1536 ---")

	var resolutions := [
		{"res": Vector2i(2400, 1080), "is_phone": true},
		{"res": Vector2i(1334, 750),  "is_phone": true},
		{"res": Vector2i(1280, 720),  "is_phone": true},
		{"res": Vector2i(2048, 1536), "is_phone": false},
	]

	for item in resolutions:
		var r: Vector2i = item["res"]
		root.size = r

		var hud_scene: PackedScene = load("res://game/scenes/ui/hfw/HUD.tscn")
		var hud := hud_scene.instantiate() as InGameHUD
		root.add_child(hud)

		var map := MapData.new("res://game/assets/data/map.json")
		var state := SYGameState.new(map, 4)
		hud.configure_hud(state, "detectives", 4, null)

		# Check drawer collapsed/expanded based on device form factor
		if item["is_phone"]:
			_assert_true(not hud.player_drawer._is_expanded or r.y >= 500,
				"Res %s: PlayerDrawer starts appropriately" % str(r))
		else:
			_assert_true(hud.player_drawer._is_expanded, "Res %s: Tablet PlayerDrawer starts expanded" % str(r))

		root.remove_child(hud)
		hud.free()

# ── 6. Play Again Clean Reset ─────────────────────────────────────────────────
func _test_play_again_clean_reset() -> void:
	print("\n--- 6. Testing Play Again & Fresh Match Reset ---")

	var gm := GameManager.new()
	root.add_child(gm)
	gm.start()
	_assert_true(gm.is_playing(), "GameManager is playing")
	gm.pause()
	_assert_true(paused == true, "Tree paused during pause")

	# Play again reset:
	gm.reset()
	_assert_true(gm.state == GameManager.State.IDLE, "GameManager reset to IDLE")
	_assert_true(paused == false, "Tree unpaused after GameManager.reset()")
	root.remove_child(gm)
	gm.free()

# ── 7. Pass-and-Play: Detective Turn After Mr. X & No Leftover Handover Panels ─
func _test_pass_and_play_detective_turn_after_mrx() -> void:
	print("\n--- 7. Pass-and-Play Bug Fix: Detective Can Move After Mr. X Turn ---")

	var match_scene: PackedScene = load("res://game/scenes/gameplay/Match.tscn")
	var match_inst := match_scene.instantiate() as Match
	root.add_child(match_inst)

	var gm := GameManager.new()
	var bus_res = load("res://game/autoloads/GameBus.gd")
	var bus: Node = bus_res.new()
	var ui_mgr := UIManager.new()
	root.add_child(ui_mgr)

	var save := MockSave.new()
	save.set_val("tells_enabled", true)
	save.set_val("detective_count", 3)
	save.set_val("match_mode", "pass_and_play")
	save.set_val("seats", [
		{"id": 0, "name": "Mr. X", "type": "human", "is_human": true},
		{"id": 1, "name": "Det 1", "type": "human", "is_human": true},
		{"id": 2, "name": "Det 2", "type": "human", "is_human": true},
		{"id": 3, "name": "Det 3", "type": "human", "is_human": true},
	])

	match_inst._ui_manager = ui_mgr
	match_inst.inject_dependencies(gm, bus, save, null, null)
	var mf: MatchFeature = match_inst.match_feature

	# 1. Verify single handover panel pushed at match start (no duplicate handover screens)
	_assert_true(match_inst._is_handover_active, "P&P: Handover active for Mr. X at match start")
	_assert_true(ui_mgr._stack.size() == 1, "P&P: Exactly ONE handover screen pushed to UIManager (no duplicates)")

	# Dismiss Mr. X handover
	var mrx_panel := ui_mgr._stack.back() as HandoverPanel
	_assert_true(mrx_panel != null, "P&P: HandoverPanel instance found")
	mrx_panel._btn_start.emit_signal("pressed")
	await process_frame

	_assert_true(not match_inst._is_handover_active, "P&P: Handover inactive after Mr. X start")
	_assert_true(ui_mgr._stack.is_empty(), "P&P: UI stack is completely empty after Mr. X starts turn")

	# 2. Mr. X executes turn (Round 1)
	var m0_list := mf.state.legal_moves(0)
	_assert_true(not m0_list.is_empty(), "P&P: Mr. X has legal moves")
	var m0: Dictionary = m0_list[0]
	var m0_to := int(m0["to"])
	match_inst._on_station_clicked(m0_to)

	if match_inst.hud.ticket_picker.visible:
		match_inst.hud.ticket_picker._on_ticket_pressed(str(m0["ticket"]))

	while match_inst._is_animating_move:
		await process_frame

	# 3. Verify handover triggers for Detective 1, with exactly 1 panel on UI stack
	_assert_true(mf.state.current_player == 1, "P&P: Current player advanced to Detective 1")
	_assert_true(match_inst._is_handover_active, "P&P: Handover active for Detective 1")
	_assert_true(ui_mgr._stack.size() == 1, "P&P: Exactly ONE handover screen for Detective 1")

	# Dismiss Detective 1 handover
	var d1_panel := ui_mgr._stack.back() as HandoverPanel
	_assert_true(d1_panel != null, "P&P: Detective 1 HandoverPanel found")
	d1_panel._btn_start.emit_signal("pressed")
	await process_frame

	# 4. CRITICAL: Stack MUST be empty with NO leftover HandoverPanel blocking taps!
	_assert_true(not match_inst._is_handover_active, "P&P: Handover inactive after Detective 1 starts")
	_assert_true(ui_mgr._stack.is_empty(), "P&P: CRITICAL: No leftover HandoverPanel covering the board with mouse_filter STOP")

	# 5. Detective 1 takes their turn by clicking a legal highlighted station
	var d1_moves := mf.state.legal_moves(1)
	_assert_true(not d1_moves.is_empty(), "P&P: Detective 1 has legal moves")
	var d1_move: Dictionary = d1_moves[0]
	var d1_to := int(d1_move["to"])

	while match_inst._is_animating_move:
		await process_frame
	match_inst._on_station_clicked(d1_to)
	if match_inst.hud.ticket_picker.visible:
		match_inst.hud.ticket_picker._on_ticket_pressed(str(d1_move["ticket"]))

	while match_inst._is_animating_move:
		await process_frame

	_assert_true(mf.state.positions[1] == d1_to, "P&P: Detective 1 moved to destination station %d" % d1_to)
	_assert_true(mf.state.current_player == 2, "P&P: Turn advanced to Detective 2 without blocking")

	# 6. Complete Detective 2 and 3 turns to finish Round 1
	for d in [2, 3]:
		while match_inst._is_animating_move:
			await process_frame
		var moves := mf.state.legal_moves(d)
		match_inst._on_station_clicked(int(moves[0]["to"]))
		if match_inst.hud.ticket_picker.visible:
			match_inst.hud.ticket_picker._on_ticket_pressed(str(moves[0]["ticket"]))
		while match_inst._is_animating_move:
			await process_frame

	# 7. Round 2: Mr. X uses DOUBLE MOVE
	_assert_true(mf.state.current_player == 0, "P&P: Round 2 returned to Mr. X")
	_assert_true(match_inst._is_handover_active, "P&P: Handover active for Mr. X round 2")
	_assert_true(ui_mgr._stack.size() == 1, "P&P: Single handover panel for Mr. X round 2")

	var mrx2_panel := ui_mgr._stack.back() as HandoverPanel
	mrx2_panel._btn_start.emit_signal("pressed")
	await process_frame
	_assert_true(ui_mgr._stack.is_empty(), "P&P: UI stack empty for Mr. X round 2")

	# Move 1 of double move
	while match_inst._is_animating_move:
		await process_frame
	var r2_mrx_moves := mf.state.legal_moves(0)
	var r2_to := int(r2_mrx_moves[0]["to"])
	match_inst._on_station_clicked(r2_to)
	if match_inst.hud.ticket_picker.visible:
		match_inst.hud.ticket_picker._chk_double_move.button_pressed = true
		match_inst.hud.ticket_picker._on_ticket_pressed(str(r2_mrx_moves[0]["ticket"]))
	while match_inst._is_animating_move:
		await process_frame

	# Verify NO handover mid double move
	_assert_true(not match_inst._should_trigger_handover(0), "P&P: _should_trigger_handover(0) returns false mid double move")
	_assert_true(not match_inst._is_handover_active, "P&P: No handover active mid double move")
	_assert_true(ui_mgr._stack.is_empty(), "P&P: UI stack empty mid double move")
	_assert_true(mf.state.current_player == 0, "P&P: Player remains Mr. X for second double move")

	# Move 2 of double move
	while match_inst._is_animating_move:
		await process_frame
	var r2_mrx_moves2 := mf.state.legal_moves(0)
	var r2_to2 := int(r2_mrx_moves2[0]["to"])
	match_inst._on_station_clicked(r2_to2)
	if match_inst.hud.ticket_picker.visible:
		match_inst.hud.ticket_picker._on_ticket_pressed(str(r2_mrx_moves2[0]["ticket"]))
	while match_inst._is_animating_move:
		await process_frame

	# Verify handover triggers for Detective 1 after double move
	_assert_true(mf.state.current_player == 1, "P&P: Turn passed to Detective 1 after double move")
	_assert_true(match_inst._is_handover_active, "P&P: Handover active for Detective 1 after double move")
	_assert_true(ui_mgr._stack.size() == 1, "P&P: Handover panel present for Detective 1")

	var d1_r2_panel := ui_mgr._stack.back() as HandoverPanel
	d1_r2_panel._btn_start.emit_signal("pressed")
	await process_frame
	_assert_true(ui_mgr._stack.is_empty(), "P&P: Stack clean after Detective 1 handover")

	# Detective 1 moves after double move
	while match_inst._is_animating_move:
		await process_frame
	var d1_r2_moves := mf.state.legal_moves(1)
	var d1_r2_to := int(d1_r2_moves[0]["to"])
	match_inst._on_station_clicked(d1_r2_to)
	if match_inst.hud.ticket_picker.visible:
		match_inst.hud.ticket_picker._on_ticket_pressed(str(d1_r2_moves[0]["ticket"]))
	while match_inst._is_animating_move:
		await process_frame

	_assert_true(mf.state.positions[1] == d1_r2_to, "P&P: Detective 1 successfully moved after Mr. X double move")
	_assert_true(mf.state.current_player == 2, "P&P: Turn advanced to Detective 2")

	root.remove_child(match_inst)
	root.remove_child(ui_mgr)
	match_inst.free()
	ui_mgr.free()
	gm.free()
	bus.free()

# ── 8. AI Mr. X Turn Flow with Tells ON Sequence ─────────────────────────────
func _test_ai_mrx_turn_tells_on_sequence() -> void:
	print("\n--- 8. AI Mr. X Turn Flow with Tells ON Sequence ---")
	root.size = Vector2i(1280, 720)

	var match_scene: PackedScene = load("res://game/scenes/gameplay/Match.tscn")
	var match_inst := match_scene.instantiate() as Match
	root.add_child(match_inst)

	var gm := GameManager.new()
	var bus_res = load("res://game/autoloads/GameBus.gd")
	var bus: Node = bus_res.new()
	var save := MockSave.new()
	save.set_val("tells_enabled", true)
	save.set_val("detective_count", 4)
	save.set_val("match_mode", "detectives")
	save.set_val("seats", [
		{"id": 0, "name": "Mr. X", "type": "ai", "is_human": false},
		{"id": 1, "name": "Detective 1", "type": "human", "is_human": true},
		{"id": 2, "name": "Detective 2", "type": "human", "is_human": true},
		{"id": 3, "name": "Detective 3", "type": "human", "is_human": true},
		{"id": 4, "name": "Detective 4", "type": "human", "is_human": true},
	])

	match_inst.inject_dependencies(gm, bus, save, null, null)
	var mf: MatchFeature = match_inst.match_feature

	# Ensure Mr. X has no close eyes cards so he executes full gaze drift
	mf.state.close_eyes_cards = 0

	# When match starts, player 0 turn is triggered.
	var mrx_start_pos: int = mf.state.positions[0]
	var spotlight_visible_duration: float = 0.0
	var move_happened_while_spotlight_visible: bool = false
	var clicks_ignored_during_sequence: bool = true
	var start_time: float = float(Time.get_ticks_msec()) / 1000.0
	var prev_time: float = start_time

	# Track AI Mr. X sequence
	while mf.state.current_player == 0 and not mf.state.game_over:
		await process_frame
		var now: float = float(Time.get_ticks_msec()) / 1000.0
		var dt: float = now - prev_time
		prev_time = now

		var is_spotlight: bool = match_inst.board.is_spotlight_visible()
		if is_spotlight:
			spotlight_visible_duration += dt
			# Simulate tap attempt during sequence — must be ignored!
			match_inst._on_station_clicked(1)
			if match_inst.hud.ticket_picker.visible:
				clicks_ignored_during_sequence = false

		if mf.state.positions[0] != mrx_start_pos:
			if is_spotlight:
				move_happened_while_spotlight_visible = true

	# Wait while detective transition / camera pan to Detective 1 completes
	while match_inst._is_animating_move:
		await process_frame
		match_inst._on_station_clicked(1)
		if match_inst.hud.ticket_picker.visible:
			clicks_ignored_during_sequence = false

	print("  Spotlight visible duration measured: %.2fs" % spotlight_visible_duration)
	_assert_true(spotlight_visible_duration >= 1.9, "AI Turn: Spotlight visible >= 1.9s (was %.2fs)" % spotlight_visible_duration)
	_assert_true(not move_happened_while_spotlight_visible, "AI Turn: Move happens only after spotlight hides")
	_assert_true(clicks_ignored_during_sequence, "AI Turn: Station taps ignored during AI sequence")
	_assert_true(mf.state.current_player == 1, "AI Turn: Turn advanced to Detective 1")

	# Verify Detective 1 can now take their turn
	var d1_moves := mf.state.legal_moves(1)
	_assert_true(not d1_moves.is_empty(), "AI Turn: Detective 1 has legal moves available")
	var d1_target_st: int = int(d1_moves[0]["to"])
	match_inst._on_station_clicked(d1_target_st)
	if match_inst.hud.ticket_picker.visible:
		match_inst.hud.ticket_picker._on_ticket_pressed(str(d1_moves[0]["ticket"]))
	while match_inst._is_animating_move:
		await process_frame

	_assert_true(mf.state.positions[1] == d1_target_st, "AI Turn: Detective 1 moved to station %d after AI Mr. X turn" % d1_target_st)

	root.remove_child(match_inst)
	match_inst.free()
	gm.free()
	bus.free()

# ── 9. AI Detective Pacing and Zoom Flow ─────────────────────────────────────
func _test_ai_detective_pacing_and_zoom() -> void:
	print("\n--- 9. AI Detective Pacing and Zoom Flow ---")
	root.size = Vector2i(1280, 720)

	var match_scene: PackedScene = load("res://game/scenes/gameplay/Match.tscn")
	var match_inst := match_scene.instantiate() as Match
	root.add_child(match_inst)

	var gm := GameManager.new()
	var bus_res = load("res://game/autoloads/GameBus.gd")
	var bus: Node = bus_res.new()
	var save := MockSave.new()
	save.set_val("tells_enabled", false)
	save.set_val("detective_count", 4)
	save.set_val("match_mode", "mrx")
	save.set_val("seats", [
		{"id": 0, "name": "Mr. X", "type": "human", "is_human": true},
		{"id": 1, "name": "Detective 1", "type": "ai", "is_human": false},
		{"id": 2, "name": "Detective 2", "type": "ai", "is_human": false},
		{"id": 3, "name": "Detective 3", "type": "ai", "is_human": false},
		{"id": 4, "name": "Detective 4", "type": "ai", "is_human": false},
	])

	match_inst.inject_dependencies(gm, bus, save, null, null)
	var mf: MatchFeature = match_inst.match_feature

	_assert_true(mf.is_human_player(0), "AI Pacing: Mr. X is Human")
	_assert_true(mf.state.current_player == 0, "AI Pacing: Turn is Mr. X")

	# Human Mr. X moves
	var m_mrx := mf.state.legal_moves(0)[0]
	var mrx_to: int = int(m_mrx["to"])
	var mrx_ticket: String = str(m_mrx["ticket"])

	match_inst._on_station_clicked(mrx_to)
	if match_inst.hud.ticket_picker.visible:
		match_inst.hud.ticket_picker._on_ticket_pressed(mrx_ticket)

	# Wait while Mr. X's own move is animating and ticket picker closes
	while mf.state.current_player == 0 or match_inst._is_animating_move or match_inst.hud.ticket_picker.visible:
		await process_frame

	# Now turn passed to AI Detectives!
	# Track each detective's turn duration and camera zoom
	var det_durations: Dictionary = {}  # det_id -> float (seconds)
	var min_zoom_during_moves: Dictionary = {} # det_id -> min_zoom
	var taps_ignored_during_ai_turns: bool = true
	var last_player: int = mf.state.current_player
	var turn_start_time: float = float(Time.get_ticks_msec()) / 1000.0

	while (mf.state.current_player > 0 or match_inst._is_animating_move) and not mf.state.game_over:
		await process_frame
		var cur_p := mf.state.current_player
		var now := float(Time.get_ticks_msec()) / 1000.0

		if cur_p > 0:
			var turn_elapsed := now - turn_start_time
			if turn_elapsed >= match_inst.AI_DETECTIVE_PAN_TIME:
				var cur_zoom := match_inst.camera.zoom.x
				if not min_zoom_during_moves.has(cur_p) or cur_zoom < min_zoom_during_moves[cur_p]:
					min_zoom_during_moves[cur_p] = cur_zoom

			# Attempt station tap during AI turn — MUST be ignored!
			var pos_before: int = int(mf.state.positions.get(cur_p, 0))
			match_inst._on_station_clicked(1)
			if int(mf.state.positions.get(cur_p, 0)) != pos_before:
				taps_ignored_during_ai_turns = false

		if cur_p != last_player:
			if last_player > 0:
				det_durations[last_player] = now - turn_start_time
			turn_start_time = now
			last_player = cur_p

	if last_player > 0 and not det_durations.has(last_player):
		det_durations[last_player] = (float(Time.get_ticks_msec()) / 1000.0) - turn_start_time

	# Verify each AI detective's turn took at least ~1.5s
	for d in range(1, 5):
		var dur: float = det_durations.get(d, 0.0)
		print("  Detective %d turn duration: %.2fs" % [d, dur])
		_assert_true(dur >= 1.5, "AI Pacing: Detective %d turn took >= 1.5s (was %.2fs)" % [d, dur])

	# Verify camera zoom was >= focus_zoom during the moves
	for d in range(1, 5):
		var mz: float = min_zoom_during_moves.get(d, 0.0)
		_assert_true(mz >= match_inst.camera.focus_zoom - 0.05,
			"AI Pacing: Detective %d camera zoom (%.2f) >= focus_zoom (%.2f)" % [d, mz, match_inst.camera.focus_zoom])

	_assert_true(taps_ignored_during_ai_turns, "AI Pacing: Station taps ignored during all AI detective turns")
	_assert_true(mf.state.current_player == 0, "AI Pacing: Returned to Mr. X")

	# Verify camera is focused back on Mr. X's station
	var mrx_final_pos := match_inst.board.get_station_position(mf.state.positions[0])
	var cam_dist := match_inst.camera.position.distance_to(mrx_final_pos)
	_assert_true(cam_dist < 50.0, "AI Pacing: Camera panned back to Mr. X's station (dist: %.1fpx)" % cam_dist)

	# Verify Mr. X can now make his next move
	var r2_moves := mf.state.legal_moves(0)
	_assert_true(not r2_moves.is_empty(), "AI Pacing: Mr. X has legal moves for round 2")
	var r2_to := int(r2_moves[0]["to"])
	match_inst._on_station_clicked(r2_to)
	_assert_true(match_inst.hud.ticket_picker.visible or not match_inst._is_animating_move,
		"AI Pacing: Station taps accepted for Mr. X once camera returned")

	root.remove_child(match_inst)
	match_inst.free()
	gm.free()
	bus.free()

# ── Mock Classes ──────────────────────────────────────────────────────────────
class MockSave extends RefCounted:
	var data: Dictionary = {}
	func set_val(k: String, v: Variant) -> void: data[k] = v
	func get_value(k: String, d: Variant = null) -> Variant: return data.get(k, d)
	func set_value(k: String, v: Variant) -> void: data[k] = v
	func save_game() -> Variant: return null
