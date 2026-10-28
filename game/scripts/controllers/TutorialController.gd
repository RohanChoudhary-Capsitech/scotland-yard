class_name TutorialController
extends Node

## TutorialController — Coordinates first-time player interactive tutorial lessons.
## Follows project architecture (inject_services / inject_dependencies pattern).
## Reads steps from game/assets/data/tutorial_steps.json.
## Controls CoachMark overlay, camera focus, and enforces valid taps during tutorial steps.

signal step_advanced(step_id: String, step_index: int)
signal tutorial_completed(lesson: int)

var coach_mark: CoachMark
var match_feature: MatchFeature
var board: Board
var camera: BoardCameraController
var hud: InGameHUD

var _bus: Node
var _save: SaveManager
var _scene: SceneManager
var _logger: Node

var lesson: int = 1
var current_step_index: int = 0
var steps: Array = []
var is_running: bool = false
var immediate_camera: bool = false

var _furthest_step_index: int = 0
var _waiting_for_action: String = ""
var _expected_station: int = 0
var _is_camera_moving: bool = false
var _current_focus_world_pos: Vector2 = Vector2.INF
var _current_focus_zoom: float = 0.0
var _step_sequence: int = 0

func inject_services(registry: Node) -> void:
	if registry == null:
		return
	_bus = registry.get_service(&"bus") as Node
	_save = registry.get_service(&"save") as SaveManager
	_scene = registry.get_service(&"scene") as SceneManager
	_logger = registry.get_service(&"logger") as Node

func configure(
	p_coach_mark: CoachMark,
	p_match_feature: MatchFeature,
	p_board: Board,
	p_camera: BoardCameraController,
	p_hud: InGameHUD,
	p_lesson: int = 1
) -> void:
	coach_mark = p_coach_mark
	match_feature = p_match_feature
	board = p_board
	camera = p_camera
	hud = p_hud
	lesson = p_lesson

	_load_steps()

	if coach_mark != null:
		if not coach_mark.next_pressed.is_connected(_on_next_pressed):
			coach_mark.next_pressed.connect(_on_next_pressed)
		if not coach_mark.back_pressed.is_connected(_on_back_pressed):
			coach_mark.back_pressed.connect(_on_back_pressed)
		if not coach_mark.skip_pressed.is_connected(_on_skip_pressed):
			coach_mark.skip_pressed.connect(_on_skip_pressed)
		if not coach_mark.show_me_pressed.is_connected(_on_show_me_pressed):
			coach_mark.show_me_pressed.connect(_on_show_me_pressed)

	if _bus != null:
		if not _bus.game_over.is_connected(_on_game_over):
			_bus.game_over.connect(_on_game_over)
		if _bus.has_signal("mrx_surfaced") and not _bus.mrx_surfaced.is_connected(_on_mrx_surfaced):
			_bus.mrx_surfaced.connect(_on_mrx_surfaced)

func _process(_delta: float) -> void:
	if not is_running or _is_camera_moving:
		return
	if _current_focus_world_pos != Vector2.INF and camera != null and coach_mark != null:
		var cam_pos: Vector2 = camera.global_position
		var dist: float = cam_pos.distance_to(_current_focus_world_pos)
		coach_mark.set_show_me_visible(dist > 60.0)

func start_tutorial() -> void:
	if steps.is_empty():
		_load_steps()
	if steps.is_empty():
		return

	is_running = true
	current_step_index = 0
	_furthest_step_index = 0
	_execute_current_step()

func _load_steps() -> void:
	var path := "res://game/assets/data/tutorial_steps.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK or not (json.data is Dictionary):
		return

	var key: String = "lesson_1" if lesson == 1 else "lesson_2"
	steps = (json.data as Dictionary).get(key, [])

func get_current_step() -> Dictionary:
	if current_step_index >= 0 and current_step_index < steps.size():
		return steps[current_step_index]
	return {}

func is_station_tap_allowed(station_id: int) -> bool:
	if not is_running:
		return true
	if _is_camera_moving:
		return false
	var step := get_current_step()
	if step.is_empty():
		return true
	var act := str(step.get("action", ""))
	if act == "station_tap" or act == "ticket_pick":
		var exp_st: int = int(step.get("expected_station", 0))
		if exp_st > 0 and station_id != exp_st:
			return false
	return true

func on_turn_started(player: int) -> void:
	if not is_running:
		return

	var step := get_current_step()
	var step_id := str(step.get("id", ""))

	if lesson == 1:
		if player == 1 and current_step_index == 0:
			_execute_current_step()
		elif player == 1 and step_id == "l1_pair_picker":
			_execute_current_step()
	elif lesson == 2:
		if player == 0 and current_step_index == 0:
			_execute_current_step()
		elif player == 0 and match_feature != null and match_feature.state.round == 2 and step_id == "l2_reveal_escape":
			_execute_current_step()

func on_station_tapped(station_id: int) -> void:
	if not is_running:
		return

	var step := get_current_step()
	var act := str(step.get("action", ""))
	if act == "station_tap":
		if int(step.get("expected_station", 0)) == station_id:
			var confirm_msg: String = str(step.get("confirm", ""))
			if not confirm_msg.is_empty() and coach_mark != null:
				coach_mark.show_confirm_message(confirm_msg)
			advance_step()
	elif str(step.get("id", "")) == "l1_pair_picker" and station_id == 10:
		if hud != null and hud.ticket_picker != null and coach_mark != null:
			coach_mark.show_target_node(hud.ticket_picker, "Two ways to get there — pick a ticket.", false)

func on_ticket_picked(_ticket: String) -> void:
	if not is_running:
		return

	var step := get_current_step()
	if str(step.get("id", "")) == "l1_pair_picker":
		var confirm_msg: String = str(step.get("confirm", ""))
		if not confirm_msg.is_empty() and coach_mark != null:
			coach_mark.show_confirm_message(confirm_msg)
		advance_step()

func on_move_completed(player: int) -> void:
	if not is_running:
		return

	var step := get_current_step()
	var step_id := str(step.get("id", ""))
	if lesson == 1 and player == 1 and step_id == "l1_ticket_costs":
		_execute_current_step()

func _on_mrx_surfaced(_station: int) -> void:
	if not is_running:
		return
	if lesson == 1:
		var step := get_current_step()
		var step_id := str(step.get("id", ""))
		if step_id == "l1_travel_log" or step_id == "l1_reveal_rounds":
			_execute_current_step()

func _execute_current_step() -> void:
	if current_step_index >= steps.size():
		_finish_tutorial()
		return

	_step_sequence += 1
	var seq := _step_sequence

	var step: Dictionary = steps[current_step_index]
	var s_id: String = str(step.get("id", ""))
	var title: String = str(step.get("title", ""))
	var body: String = str(step.get("body", step.get("text", "")))
	var why: String = str(step.get("why", ""))
	var action: String = str(step.get("action", "next"))
	var is_revisit: bool = (current_step_index < _furthest_step_index)
	var show_next: bool = (action == "next" or is_revisit or action == "catch_mrx" or action == "survive")
	var show_back: bool = (current_step_index > 0)

	_waiting_for_action = "next" if is_revisit else action
	_expected_station = int(step.get("expected_station", 0))

	# Skip spotlight/gaze steps if tells are disabled
	if (s_id == "l1_spotlight_tells" or s_id == "l2_close_eyes" or s_id == "l2_camera_gaze") and match_feature != null and not match_feature.tells_enabled:
		advance_step()
		return

	# Camera focus handling
	var focus_target = step.get("focus", null)
	var step_zoom: float = float(step.get("zoom", 0.0))
	var has_camera_focus := false
	var focus_pos := Vector2.ZERO

	if focus_target != null and str(focus_target) != "none" and str(focus_target) != "hud":
		focus_pos = _resolve_focus_position(focus_target)
		if focus_pos != Vector2.INF and focus_pos != Vector2.ZERO:
			has_camera_focus = true

	if has_camera_focus and camera != null:
		_is_camera_moving = true
		_current_focus_world_pos = focus_pos
		_current_focus_zoom = step_zoom
		if coach_mark != null:
			coach_mark.hide_coach_mark()

		if immediate_camera:
			camera.global_position = focus_pos
			if step_zoom > 0.0:
				camera.zoom = Vector2(step_zoom, step_zoom)
			_is_camera_moving = false
		else:
			camera.pan_to_position(focus_pos, 0.6, step_zoom, true)
			if is_inside_tree() and get_tree() != null:
				await get_tree().create_timer(0.65).timeout
			if seq != _step_sequence:
				return
			_is_camera_moving = false
	else:
		_current_focus_world_pos = Vector2.INF
		_current_focus_zoom = 0.0
		if coach_mark != null:
			coach_mark.set_show_me_visible(false)

	# Special step hooks
	if s_id == "l1_deduction" and board != null:
		board.highlight_stations([3, 22, 26])
	elif s_id == "l1_ticket_costs" or s_id == "l2_black_ticket" or s_id == "l2_double_move" or s_id == "l2_surrendered_tickets":
		if hud != null and hud.player_drawer != null:
			hud.player_drawer.expand_drawer()
	elif s_id == "l1_travel_log":
		if hud != null and hud.travel_log_drawer != null:
			hud.travel_log_drawer.expand_drawer()
	elif s_id == "l1_reveal_rounds":
		if hud != null and hud.travel_log_drawer != null:
			hud.travel_log_drawer.collapse_drawer()

	if coach_mark != null:
		coach_mark.set_step_content(
			title,
			body,
			why,
			current_step_index + 1,
			steps.size(),
			show_back,
			show_next
		)

		var target_node: Node = _resolve_target_node(str(step.get("target", "")))
		if target_node != null:
			var custom_size := Vector2.ZERO
			if s_id == "l1_your_token" or s_id == "l2_secret_movement":
				custom_size = Vector2(80, 80)
			elif s_id == "l1_move_taxi" or s_id == "l1_pair_picker":
				custom_size = Vector2(76, 76)
			elif s_id == "l1_spotlight_tells":
				custom_size = Vector2(160, 160)
			coach_mark.show_target_node(target_node, body, show_next, custom_size)
		else:
			coach_mark.show_fullscreen_message(body, show_next)

func _resolve_focus_position(focus_target: Variant) -> Vector2:
	if focus_target == null:
		return Vector2.INF

	# Guard against revealing Mr. X's real position in Detective mode
	if lesson == 1 and (str(focus_target) == "0" or str(focus_target) == "mrx"):
		return Vector2.INF

	if focus_target is int or focus_target is float:
		var sid := int(focus_target)
		if board != null and board.has_station(sid):
			return board.get_station_position(sid)
		return Vector2.INF

	if focus_target is Array:
		var sum := Vector2.ZERO
		var count := 0
		for item in (focus_target as Array):
			var sid := int(item)
			if board != null and board.has_station(sid):
				sum += board.get_station_position(sid)
				count += 1
		if count > 0:
			return sum / float(count)
		return Vector2.INF

	var s := str(focus_target)
	match s:
		"mrx_last_seen":
			var rev_pos: int = 0
			if match_feature != null and match_feature.state != null:
				rev_pos = match_feature.state.last_revealed_position
			if rev_pos <= 0 and lesson == 1:
				rev_pos = 26 # Deterministic reveal station in tutorial
			if rev_pos > 0 and board != null and board.has_station(rev_pos):
				return board.get_station_position(rev_pos)
			if board != null:
				var lsn := board.get_last_seen_node()
				if lsn != null:
					return lsn.global_position
		"spotlight":
			if board != null:
				var sp := board.get_spotlight_node()
				if sp != null:
					return sp.global_position
		"player_token":
			var pid: int = 1 if lesson == 1 else 0
			if match_feature != null and match_feature.state != null:
				var st: int = match_feature.state.positions.get(pid, 0)
				if board != null and board.has_station(st):
					return board.get_station_position(st)
		_:
			if s.begins_with("station_"):
				var sid := int(s.substr(8))
				if board != null and board.has_station(sid):
					return board.get_station_position(sid)

	return Vector2.INF

func _resolve_target_node(target_name: String) -> Node:
	match target_name:
		"player_token":
			if board != null:
				var pid: int = 1 if lesson == 1 else 0
				return board.get_token(pid)
		"station_22":
			return board.get_station(22) if board != null else null
		"station_18":
			return board.get_station(18) if board != null else null
		"station_10":
			return board.get_station(10) if board != null else null
		"ferry":
			return board.get_station(16) if board != null else null
		"player_drawer", "black_ticket", "double_button":
			return hud.player_drawer if (hud != null and hud.player_drawer != null) else null
		"ticket_picker":
			return hud.ticket_picker if (hud != null and hud.ticket_picker != null) else null
		"travel_log":
			return hud.travel_log_drawer if (hud != null and hud.travel_log_drawer != null) else null
		"last_seen":
			if board != null:
				var lsn := board.get_last_seen_node()
				if lsn != null:
					return lsn
				if match_feature != null and match_feature.state != null:
					return board.get_station(match_feature.state.last_revealed_position)
		"spotlight":
			return board.get_spotlight_node() if board != null else null
		_:
			if target_name.begins_with("station_"):
				var sid: int = int(target_name.substr(8))
				return board.get_station(sid) if board != null else null
	return null

func advance_step() -> void:
	if not is_running:
		return

	var old_step := get_current_step()
	var old_id := str(old_step.get("id", ""))
	current_step_index += 1
	_furthest_step_index = maxi(_furthest_step_index, current_step_index)
	step_advanced.emit(old_id, current_step_index)

	if current_step_index >= steps.size():
		_finish_tutorial()
		return

	_execute_current_step()

func _on_next_pressed() -> void:
	if not is_running or _is_camera_moving:
		return

	var step := get_current_step()
	var s_id: String = str(step.get("id", ""))

	if s_id == "l1_ticket_costs" or s_id == "l2_black_ticket" or s_id == "l2_double_move" or s_id == "l2_surrendered_tickets":
		if hud != null and hud.player_drawer != null:
			hud.player_drawer.collapse_drawer()
	if s_id == "l1_travel_log":
		if hud != null and hud.travel_log_drawer != null:
			hud.travel_log_drawer.collapse_drawer()
	if s_id == "l1_deduction" and board != null:
		board.clear_all_highlights()

	if s_id == "l1_catch_mrx" or s_id == "l2_win_conditions":
		if coach_mark != null:
			coach_mark.hide_coach_mark()
		advance_step()
	else:
		advance_step()

func _on_back_pressed() -> void:
	if not is_running or _is_camera_moving or current_step_index <= 0:
		return

	if board != null:
		board.clear_all_highlights()

	current_step_index -= 1
	_execute_current_step()

func _on_show_me_pressed() -> void:
	if not is_running or _current_focus_world_pos == Vector2.INF or camera == null:
		return

	_is_camera_moving = true
	if coach_mark != null:
		coach_mark.set_show_me_visible(false)

	if immediate_camera:
		camera.global_position = _current_focus_world_pos
		if _current_focus_zoom > 0.0:
			camera.zoom = Vector2(_current_focus_zoom, _current_focus_zoom)
		_is_camera_moving = false
	else:
		camera.pan_to_position(_current_focus_world_pos, 0.45, _current_focus_zoom, true)
		if is_inside_tree() and get_tree() != null:
			await get_tree().create_timer(0.5).timeout
		_is_camera_moving = false

func _on_skip_pressed() -> void:
	if _save != null:
		_save.set_tutorial_completed(true)
		_save.set_selected_level("neighbourhood")
	if coach_mark != null:
		coach_mark.hide_coach_mark()
	is_running = false

	if _scene != null:
		_scene.go_to("res://game/scenes/Home/Home.tscn")
	elif is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file("res://game/scenes/Home/Home.tscn")

func _on_game_over(reason: String) -> void:
	if not is_running:
		return

	if coach_mark != null:
		coach_mark.hide_coach_mark()

	if lesson == 1:
		tutorial_completed.emit(1)
	elif lesson == 2:
		if _save != null:
			_save.set_tutorial_completed(true)
			_save.set_selected_level("neighbourhood")
		tutorial_completed.emit(2)

func _finish_tutorial() -> void:
	if coach_mark != null:
		coach_mark.hide_coach_mark()

	if lesson == 1:
		tutorial_completed.emit(1)
	elif lesson == 2:
		if _save != null:
			_save.set_tutorial_completed(true)
			_save.set_selected_level("neighbourhood")
		show_rules_recap()
		tutorial_completed.emit(2)

func show_rules_recap() -> void:
	if not is_inside_tree() or get_tree() == null or get_tree().root == null:
		return
	var registry: Node = get_tree().root.get_node_or_null("ServiceRegistry")
	var ui: UIManager = registry.get_service(&"ui") as UIManager if registry != null and registry.has_method("get_service") else null
	var path: String = GameConfig.UI_PANELS.get("how_to_play", "")
	if ui != null and not path.is_empty() and ResourceLoader.exists(path):
		ui.push_packed(load(path))
