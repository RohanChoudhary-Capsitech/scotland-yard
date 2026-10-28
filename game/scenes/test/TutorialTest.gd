extends SceneTree

## TutorialTest — Full verification suite for Scotland Yard First-Time Player Tutorial.
## Tests CoachMark UI, tutorial_steps.json data, rule requirements, camera focus within 20px,
## "Show me" drift recentering, Back button re-reading, Lesson 1 & Lesson 2 flow,
## and transition to Neighbourhood progression.

const CoachMarkClass := preload("res://game/scenes/ui/hfw/CoachMark.gd")
const TutorialControllerClass := preload("res://game/scripts/controllers/TutorialController.gd")
const BoardClass := preload("res://game/scenes/gameplay/Board/Board.tscn")

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

var passed: int = 0
var failed: int = 0

func _init() -> void:
	print("\n==================================================")
	print("       RUNNING SCOTLAND YARD TUTORIAL TESTS       ")
	print("==================================================\n")

	_test_tutorial_steps_json()
	_test_coach_mark_component()
	_test_save_manager_tutorial_progression()
	_test_camera_focus_and_show_me()
	_test_back_button_behavior()
	_test_match_tutorial_lesson_1_flow()
	_test_match_tutorial_lesson_2_flow()
	_test_replay_and_skip_buttons()

	print("\n==================================================")
	print("TUTORIAL TEST RESULTS: %d Passed, %d Failed (Total %d)" % [passed, failed, passed + failed])
	print("==================================================")

	if failed > 0:
		quit(1)
	else:
		quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("  [PASS] %s" % message)
	else:
		failed += 1
		print("  [FAIL] %s" % message)

# ------------------------------------------------------------------------------
# 1. Testing tutorial_steps.json Structure & Rule Topics
# ------------------------------------------------------------------------------

func _test_tutorial_steps_json() -> void:
	print("--- 1. Testing tutorial_steps.json Structure & Rule Topics ---")
	var path := "res://game/assets/data/tutorial_steps.json"
	_assert(FileAccess.file_exists(path), "tutorial_steps.json exists")

	var f := FileAccess.open(path, FileAccess.READ)
	_assert(f != null, "Opened tutorial_steps.json")
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	_assert(err == OK, "tutorial_steps.json parsed with no errors")

	var data: Dictionary = json.data as Dictionary
	_assert(data.has("lesson_1"), "Contains lesson_1")
	_assert(data.has("lesson_2"), "Contains lesson_2")

	var l1: Array = data.get("lesson_1", [])
	var l2: Array = data.get("lesson_2", [])
	_assert(l1.size() == 15, "Lesson 1 has exactly 15 steps (got %d)" % l1.size())
	_assert(l2.size() == 8, "Lesson 2 has exactly 8 steps (got %d)" % l2.size())

	# Required rule topics verification
	var l1_required_ids := [
		"l1_goal", "l1_turn_order", "l1_your_token", "l1_move_taxi", "l1_ticket_costs",
		"l1_pair_picker", "l1_ferry_rule", "l1_blocked_station", "l1_travel_log",
		"l1_reveal_rounds", "l1_deduction", "l1_spotlight_tells", "l1_stuck_detective",
		"l1_ways_to_lose", "l1_catch_mrx"
	]
	var l1_ids := []
	for s in l1:
		l1_ids.append(str(s.get("id", "")))
	var all_l1_present := true
	for req in l1_required_ids:
		if not l1_ids.has(req):
			all_l1_present = false
			print("  [FAIL] Missing required Lesson 1 step: %s" % req)
	_assert(all_l1_present, "All 15 required Lesson 1 rule steps exist")

	var l2_required_ids := [
		"l2_secret_movement", "l2_black_ticket", "l2_double_move", "l2_surrendered_tickets",
		"l2_reveal_escape", "l2_close_eyes", "l2_camera_gaze", "l2_win_conditions"
	]
	var l2_ids := []
	for s in l2:
		l2_ids.append(str(s.get("id", "")))
	var all_l2_present := true
	for req in l2_required_ids:
		if not l2_ids.has(req):
			all_l2_present = false
			print("  [FAIL] Missing required Lesson 2 step: %s" % req)
	_assert(all_l2_present, "All 8 required Lesson 2 rule steps exist")

	# Check title, body, why constraints on every step
	var all_steps := []
	all_steps.append_array(l1)
	all_steps.append_array(l2)

	var format_ok := true
	for s in all_steps:
		var sid := str(s.get("id", ""))
		var title := str(s.get("title", ""))
		var body := str(s.get("body", ""))
		var why := str(s.get("why", ""))

		var title_words := title.split(" ", false).size()
		if title_words < 2 or title_words > 4:
			format_ok = false
			print("  [FAIL] Step '%s' title '%s' has %d words (expected 2-4)" % [sid, title, title_words])

		if body.is_empty():
			format_ok = false
			print("  [FAIL] Step '%s' has empty body" % sid)

		if why.is_empty():
			format_ok = false
			print("  [FAIL] Step '%s' has empty why" % sid)

	_assert(format_ok, "All steps adhere to Title (2-4 words), Body, and Why structure")

# ------------------------------------------------------------------------------
# 2. Testing CoachMark Component
# ------------------------------------------------------------------------------

func _test_coach_mark_component() -> void:
	print("\n--- 2. Testing CoachMark UI & Expanders ---")
	var scene := load("res://game/scenes/ui/hfw/CoachMark.tscn") as PackedScene
	_assert(scene != null, "CoachMark.tscn loaded")

	var cm: CoachMark = scene.instantiate() as CoachMark
	root.add_child(cm)
	_assert(cm != null, "CoachMark instantiated and added to tree")

	cm.set_step_content("Catch Mr. X", "Your goal is to catch Mr. X.", "If he survives, he wins.", 1, 15, true, true)
	cm.show_target_rect(Rect2(200, 150, 100, 80), "Your goal is to catch Mr. X.", true)

	_assert(cm.is_active(), "CoachMark is active after show_target_rect")
	_assert(cm.get_current_target_rect() == Rect2(200, 150, 100, 80), "Target rect matches")

	var lbl_title: Label = cm.get_node("%LblTitle") as Label
	var lbl_counter: Label = cm.get_node("%LblStepCounter") as Label
	var btn_back: Button = cm.get_node("%BtnBack") as Button
	var btn_next: Button = cm.get_node("%BtnNext") as Button
	var btn_skip: Button = cm.get_node("%BtnSkip") as Button
	var btn_why: Button = cm.get_node("%BtnWhy") as Button
	var lbl_why: Label = cm.get_node("%LblWhy") as Label

	_assert(lbl_title.text == "Catch Mr. X", "Title set correctly")
	_assert(lbl_counter.text == "Step 1 / 15", "Step counter set to 'Step 1 / 15'")
	_assert(btn_back.visible, "Back button visible")
	_assert(btn_next.visible, "Next button visible")
	_assert(btn_skip.visible, "Skip button visible")
	_assert(btn_why.visible, "Why button visible")
	_assert(not lbl_why.visible, "Why label initially collapsed")

	# Test Why toggle
	cm.call("_on_why_pressed")
	_assert(lbl_why.visible, "Why label expanded after toggle")
	_assert("▴" in btn_why.text, "Why button arrow points up when expanded")

	cm.call("_on_why_pressed")
	_assert(not lbl_why.visible, "Why label collapsed after second toggle")
	_assert("▾" in btn_why.text, "Why button arrow points down when collapsed")

	# Test Confirm message
	cm.show_confirm_message("Nice move!")
	var confirm_bubble: PanelContainer = cm.get_node("%ConfirmBubble") as PanelContainer
	var lbl_confirm: Label = cm.get_node("%LblConfirm") as Label
	_assert(confirm_bubble.visible, "Confirm bubble visible")
	_assert(lbl_confirm.text == "Nice move!", "Confirm message matches")

	# Test Show me toggle
	cm.set_show_me_visible(true)
	var btn_show_me: Button = cm.get_node("%BtnShowMe") as Button
	_assert(btn_show_me.visible, "Show me button is visible")

	cm.set_show_me_visible(false)
	_assert(not btn_show_me.visible, "Show me button is hidden")

	cm.hide_coach_mark()
	_assert(not cm.is_active(), "CoachMark is inactive after hide_coach_mark")

	cm.queue_free()

# ------------------------------------------------------------------------------
# 3. Testing SaveManager Progression
# ------------------------------------------------------------------------------

func _test_save_manager_tutorial_progression() -> void:
	print("\n--- 3. Testing SaveManager Progression ---")
	var save := MockSaveManager.new()

	save.set_tutorial_lesson(1)
	_assert(save.get_tutorial_lesson() == 1, "Tutorial lesson persisted as 1")

	save.set_tutorial_lesson(2)
	_assert(save.get_tutorial_lesson() == 2, "Tutorial lesson updated to 2")

	save.set_tutorial_completed(true)
	_assert(save.is_tutorial_completed(), "Tutorial marked completed")
	_assert(save.is_level_unlocked("neighbourhood"), "Neighbourhood level unlocked on tutorial completion")

	save.queue_free()

# ------------------------------------------------------------------------------
# 4. Testing Camera Focus within 20px & "Show me" Recentering
# ------------------------------------------------------------------------------

func _test_camera_focus_and_show_me() -> void:
	print("\n--- 4. Testing Camera Focus within 20px & Show Me ---")

	var board_node: Board = BoardClass.instantiate() as Board
	root.add_child(board_node)

	var cam := BoardCameraController.new()
	root.add_child(cam)

	var cm_scene := load("res://game/scenes/ui/hfw/CoachMark.tscn") as PackedScene
	var cm: CoachMark = cm_scene.instantiate() as CoachMark
	root.add_child(cm)

	var mf := MatchFeature.new()
	var deps: Dictionary = {
		"level": "tutorial",
		"tutorial_lesson": 1,
		"tells_enabled": true,
		"seats": [
			{"id": 0, "name": "Mr. X", "type": "ai", "is_human": false},
			{"id": 1, "name": "Detective 1", "type": "human", "is_human": true},
			{"id": 2, "name": "Detective 2", "type": "ai", "is_human": false}
		]
	}
	mf.initialize(deps)
	mf.start()

	var tc: TutorialController = TutorialControllerClass.new()
	root.add_child(tc)
	tc.immediate_camera = true
	tc.configure(cm, mf, board_node, cam, null, 1)
	tc.is_running = true

	# Verify camera focus for all steps with focus
	var focus_tested := 0
	for i in range(tc.steps.size()):
		tc.current_step_index = i
		var step: Dictionary = tc.steps[i]
		var f = step.get("focus", null)
		if f != null and str(f) != "hud" and str(f) != "none":
			var target_pos: Vector2 = tc._resolve_focus_position(f)
			_assert(target_pos != Vector2.INF, "Step %s resolved focus position" % step.get("id", ""))
			tc._execute_current_step()
			var dist: float = cam.global_position.distance_to(target_pos)
			_assert(dist <= 20.0, "Camera within 20px of focus for step %s (dist: %.2f px)" % [step.get("id", ""), dist])
			focus_tested += 1
	_assert(focus_tested >= 7, "Verified camera focus for at least 7 map steps (got %d)" % focus_tested)

	# Test "Show me" drift button
	tc.current_step_index = 3 # l1_move_taxi (focus: 22)
	tc._execute_current_step()
	var target_22: Vector2 = tc._current_focus_world_pos
	_assert(target_22 != Vector2.INF, "Focus target stored for station 22")

	# Move camera away by 120px
	cam.global_position = target_22 + Vector2(120.0, 0.0)
	tc._process(0.016)
	_assert(cm.get_node("%BtnShowMe").visible, "Show me button appeared when camera drifted > 60px")

	# Press Show me
	tc.call("_on_show_me_pressed")
	var new_dist: float = cam.global_position.distance_to(target_22)
	_assert(new_dist <= 20.0, "Show me panned camera back within 20px (dist: %.2f px)" % new_dist)
	_assert(not cm.get_node("%BtnShowMe").visible, "Show me button hid after recentering")

	tc.queue_free()
	cm.queue_free()
	cam.queue_free()
	board_node.queue_free()

# ------------------------------------------------------------------------------
# 5. Testing Back Button Re-reading
# ------------------------------------------------------------------------------

func _test_back_button_behavior() -> void:
	print("\n--- 5. Testing Back Button Step Navigation ---")

	var tc: TutorialController = TutorialControllerClass.new()
	root.add_child(tc)
	tc.immediate_camera = true
	tc.configure(null, null, null, null, null, 1)
	tc.start_tutorial()

	_assert(tc.current_step_index == 0, "Starts on Step 0")

	# Advance to step 1 and step 2
	tc.advance_step()
	_assert(tc.current_step_index == 1, "Advanced to Step 1")
	tc.advance_step()
	_assert(tc.current_step_index == 2, "Advanced to Step 2")

	# Press Back
	tc.call("_on_back_pressed")
	_assert(tc.current_step_index == 1, "Back button decremented step index to 1")

	tc.call("_on_back_pressed")
	_assert(tc.current_step_index == 0, "Back button decremented step index to 0")

	# Back button does not decrement below 0
	tc.call("_on_back_pressed")
	_assert(tc.current_step_index == 0, "Back button clamped at Step 0")

	# Advancing resumes toward furthest index
	tc.advance_step()
	_assert(tc.current_step_index == 1, "Next advanced back toward previous progress")

	tc.queue_free()

# ------------------------------------------------------------------------------
# 6. Testing Full Lesson 1 Playthrough
# ------------------------------------------------------------------------------

func _test_match_tutorial_lesson_1_flow() -> void:
	print("\n--- 6. Testing Full Lesson 1 Interactive Flow ---")

	var mf := MatchFeature.new()
	var deps: Dictionary = {
		"level": "tutorial",
		"tutorial_lesson": 1,
		"tells_enabled": true,
		"seats": [
			{"id": 0, "name": "Mr. X", "type": "ai", "is_human": false},
			{"id": 1, "name": "Detective 1", "type": "human", "is_human": true},
			{"id": 2, "name": "Detective 2", "type": "ai", "is_human": false}
		]
	}
	mf.initialize(deps)
	mf.start()

	_assert(mf.state.positions[0] == 26, "Mr. X starts at 26")
	_assert(mf.state.positions[1] == 18, "Detective 1 starts at 18")
	_assert(mf.state.positions[2] == 10, "Detective 2 starts at 10")

	var tc: TutorialController = TutorialControllerClass.new()
	root.add_child(tc)
	tc.immediate_camera = true
	tc.configure(null, mf, null, null, null, 1)
	tc.start_tutorial()

	_assert(tc.get_current_step().get("id", "") == "l1_goal", "Step 0 is 'l1_goal'")
	tc.advance_step()
	_assert(tc.get_current_step().get("id", "") == "l1_turn_order", "Step 1 is 'l1_turn_order'")
	tc.advance_step()
	_assert(tc.get_current_step().get("id", "") == "l1_your_token", "Step 2 is 'l1_your_token'")
	tc.advance_step()

	# Step 3: l1_move_taxi (tap station 22)
	_assert(tc.get_current_step().get("id", "") == "l1_move_taxi", "Step 3 is 'l1_move_taxi'")
	_assert(not tc.is_station_tap_allowed(10), "Station 10 tap rejected")
	_assert(not tc.is_station_tap_allowed(1), "Station 1 tap rejected")
	_assert(tc.is_station_tap_allowed(22), "Station 22 tap allowed")

	# Round 1: Mr. X moves first from 26 -> 3
	var ok_mrx1 := mf.apply_move(0, 3, "underground")
	_assert(ok_mrx1, "Mr. X moved to 3")

	# Detective 1 moves from 18 -> 22
	tc.on_station_tapped(22)
	_assert(tc.get_current_step().get("id", "") == "l1_ticket_costs", "Advanced to 'l1_ticket_costs'")
	var ok_d1 := mf.apply_move(1, 22, "taxi")
	_assert(ok_d1, "Detective 1 moved to 22")

	# Detective 2 moves 10 -> 18
	var ok_d2 := mf.apply_move(2, 18, "taxi")
	_assert(ok_d2, "Detective 2 moved to 18")

	# Round 2: Mr. X moves 3 -> 26 (black ticket, reveal round!)
	var ok_mrx2 := mf.apply_move(0, 26, "black")
	_assert(ok_mrx2, "Mr. X moved to 26 using black ticket")
	_assert(mf.state.last_revealed_position == 26, "Round 2 revealed Mr. X at 26")

	# Step through next steps
	tc.advance_step()
	_assert(tc.get_current_step().get("id", "") == "l1_pair_picker", "Step 5 is 'l1_pair_picker'")
	tc.on_ticket_picked("bus")

	_assert(tc.get_current_step().get("id", "") == "l1_ferry_rule", "Step 6 is 'l1_ferry_rule'")
	tc.advance_step()
	_assert(tc.get_current_step().get("id", "") == "l1_blocked_station", "Step 7 is 'l1_blocked_station'")
	tc.advance_step()
	_assert(tc.get_current_step().get("id", "") == "l1_travel_log", "Step 8 is 'l1_travel_log'")
	tc.advance_step()

	_assert(tc.get_current_step().get("id", "") == "l1_reveal_rounds", "Step 9 is 'l1_reveal_rounds'")
	tc.advance_step()
	_assert(tc.get_current_step().get("id", "") == "l1_deduction", "Step 10 is 'l1_deduction'")
	tc.advance_step()
	_assert(tc.get_current_step().get("id", "") == "l1_spotlight_tells", "Step 11 is 'l1_spotlight_tells'")
	tc.advance_step()
	_assert(tc.get_current_step().get("id", "") == "l1_stuck_detective", "Step 12 is 'l1_stuck_detective'")
	tc.advance_step()
	_assert(tc.get_current_step().get("id", "") == "l1_ways_to_lose", "Step 13 is 'l1_ways_to_lose'")
	tc.advance_step()
	_assert(tc.get_current_step().get("id", "") == "l1_catch_mrx", "Step 14 is 'l1_catch_mrx'")

	# Detective 1 moves 22 -> 26 (underground) directly onto Mr. X!
	var ok_catch := mf.apply_move(1, 26, "underground")
	_assert(ok_catch, "Detective 1 moved onto station 26")
	_assert(mf.state.game_over, "Game is over")
	_assert(mf.state.winner == "detectives", "Detectives win Lesson 1")
	_assert("caught" in mf.state.reason.to_lower(), "Reason mentions caught: %s" % mf.state.reason)

	tc.queue_free()

# ------------------------------------------------------------------------------
# 7. Testing Full Lesson 2 Playthrough
# ------------------------------------------------------------------------------

func _test_match_tutorial_lesson_2_flow() -> void:
	print("\n--- 7. Testing Full Lesson 2 Interactive Flow ---")

	var mf := MatchFeature.new()
	var deps: Dictionary = {
		"level": "tutorial",
		"tutorial_lesson": 2,
		"tells_enabled": true,
		"seats": [
			{"id": 0, "name": "Mr. X", "type": "human", "is_human": true},
			{"id": 1, "name": "Detective 1", "type": "ai", "is_human": false},
			{"id": 2, "name": "Detective 2", "type": "ai", "is_human": false}
		]
	}
	mf.initialize(deps)
	mf.start()

	_assert(mf.is_human_player(0), "Player is Mr. X (human) in Lesson 2")
	_assert(mf.state.positions[0] == 47, "Mr. X starts at 47")

	var save := MockSaveManager.new()
	var tc: TutorialController = TutorialControllerClass.new()
	root.add_child(tc)
	tc.immediate_camera = true
	tc._save = save
	tc.configure(null, mf, null, null, null, 2)
	tc.start_tutorial()

	var expected_l2_ids := [
		"l2_secret_movement", "l2_black_ticket", "l2_double_move", "l2_surrendered_tickets",
		"l2_reveal_escape", "l2_close_eyes", "l2_camera_gaze", "l2_win_conditions"
	]
	for idx in range(expected_l2_ids.size()):
		_assert(tc.get_current_step().get("id", "") == expected_l2_ids[idx], "L2 Step %d is '%s'" % [idx, expected_l2_ids[idx]])
		tc.advance_step()

	_assert(save.is_tutorial_completed(), "Tutorial marked completed after Lesson 2")
	_assert(save.is_level_unlocked("neighbourhood"), "Neighbourhood unlocked after Lesson 2")

	save.queue_free()
	tc.queue_free()

# ------------------------------------------------------------------------------
# 8. Testing Replay & Skip Tutorial Buttons
# ------------------------------------------------------------------------------

func _test_replay_and_skip_buttons() -> void:
	print("\n--- 8. Testing Replay & Skip Tutorial UI Integration ---")
	var home_scene := load("res://game/scenes/Home/Home.tscn") as PackedScene
	_assert(home_scene != null, "Home.tscn loaded")

	var home: HomeScene = home_scene.instantiate() as HomeScene
	root.add_child(home)
	var btn_replay_home: Button = home.get_node_or_null("%BtnReplayTutorial") as Button
	_assert(btn_replay_home != null, "Home menu has %BtnReplayTutorial button")
	home.queue_free()

	var pause_scene := load("res://game/scenes/ui/hfw/PausePanel.tscn") as PackedScene
	_assert(pause_scene != null, "PausePanel.tscn loaded")

	var pause: PausePanel = pause_scene.instantiate() as PausePanel
	root.add_child(pause)
	var btn_replay_pause: Button = pause.get_node_or_null("%BtnReplayTutorial") as Button
	_assert(btn_replay_pause != null, "Pause panel has %BtnReplayTutorial button")
	pause.queue_free()

	var go_scene := load("res://game/scenes/ui/hfw/GameOverPanel.tscn") as PackedScene
	_assert(go_scene != null, "GameOverPanel.tscn loaded")

	var go: GameOverPanel = go_scene.instantiate() as GameOverPanel
	root.add_child(go)
	var btn_next_lesson: Button = go.get_node_or_null("%BtnNextLesson") as Button
	_assert(btn_next_lesson != null, "GameOverPanel has %BtnNextLesson button")
	go.queue_free()
