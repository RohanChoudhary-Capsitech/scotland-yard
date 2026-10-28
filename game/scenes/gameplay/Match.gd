class_name Match
extends Node2D

## Match — Scene controller for the Scotland Yard gameplay scene.
## Mobile-first integration: Board view, BoardCameraController, InGameHUD, and MatchFeature.
## Supports Local Pass-and-Play (Handover screen, glance replay, mixed seats).
## Follows project DI architecture (inject_services -> inject_dependencies).

@onready var _board: Board = $Board
@onready var _camera: BoardCameraController = $BoardCameraController
@onready var _match_feature: MatchFeature = $MatchFeature
@onready var _hud: InGameHUD = $HUD

var board: Board:
	get:
		_ensure_nodes()
		return _board

var match_feature: MatchFeature:
	get:
		_ensure_nodes()
		return _match_feature

var camera: BoardCameraController:
	get:
		_ensure_nodes()
		return _camera

var hud: InGameHUD:
	get:
		_ensure_nodes()
		return _hud

var _game_manager: GameManager
var _bus: Node
var _save: Object
var _logger: Node
var _audio: AudioManager

const SFX_MOVE := preload("res://game/assets/audio/sfx/move.wav")
const SFX_REVEAL := preload("res://game/assets/audio/sfx/reveal.wav")
const SFX_WIN := preload("res://game/assets/audio/sfx/win.wav")
const SFX_LOSE := preload("res://game/assets/audio/sfx/lose.wav")
const SFX_TAP := preload("res://game/assets/audio/sfx/tap.wav")

## AI Detective Turn Timing Constants
const AI_DETECTIVE_PAN_TIME: float = 0.5
const AI_DETECTIVE_THINK_TIME: float = 0.8
const AI_DETECTIVE_ROUTE_PREVIEW_TIME: float = 0.4
const AI_DETECTIVE_POST_MOVE_PAUSE: float = 0.5
const AI_DETECTIVE_STUCK_PAUSE: float = 0.8
const AI_DETECTIVE_RETURN_TO_MRX_PAN_TIME: float = 0.5

func _sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if _audio != null:
		_audio.play_sfx(stream, volume_db)
var _ui_manager: UIManager

var _initialized_gameplay: bool = false
var _ai_timer_pending: bool = false
var _is_animating_move: bool = false
var _pending_station_id: int = 0

# Pass-and-Play state
var _is_handover_active: bool = false
var _previous_player: int = -1
var _recorded_mrx_path: Array[Dictionary] = []
var _mrx_closed_eyes_this_round: bool = false

const TutorialControllerClass = preload("res://game/scripts/controllers/TutorialController.gd")
var _tutorial_controller: Node = null
var tutorial_controller: Node:
	get: return _tutorial_controller

func _ready() -> void:
	# Fallback resolution for standalone/editor play (F6) when SceneManager injection didn't run
	if not _initialized_gameplay and get_tree() != null and get_tree().root != null:
		var registry: Node = get_tree().root.get_node_or_null("ServiceRegistry")
		if registry != null and registry.has_method("has_service") and registry.has_service(&"game"):
			inject_services(registry)

func inject_services(registry: Node) -> void:
	if not registry:
		return
	var game: GameManager = registry.get_service(&"game") as GameManager
	var bus: Node = registry.get_service(&"bus") as Node
	var save: SaveManager = registry.get_service(&"save") as SaveManager
	var logger: Node = registry.get_service(&"logger") as Node
	var audio: AudioManager = registry.get_service(&"audio") as AudioManager
	_ui_manager = registry.get_service(&"ui") as UIManager
	inject_dependencies(game, bus, save, logger, audio)

func inject_dependencies(
	game: GameManager,
	bus: Node,
	save: Object,
	logger: Node,
	audio: AudioManager
) -> void:
	_game_manager = game
	_bus = bus
	_save = save
	_logger = logger
	_audio = audio

	_setup_match()

func _ensure_nodes() -> void:
	if _board == null:
		_board = get_node_or_null("Board") as Board
	if _camera == null:
		_camera = get_node_or_null("BoardCameraController") as BoardCameraController
	if _match_feature == null:
		_match_feature = get_node_or_null("MatchFeature") as MatchFeature
	if _hud == null:
		_hud = get_node_or_null("HUD") as InGameHUD

func _setup_match() -> void:
	if _initialized_gameplay:
		return
	_initialized_gameplay = true
	_ensure_nodes()

	# Read game settings from SaveManager
	var mode: String = "detectives"
	var detective_count: int = 4
	var tells_enabled: bool = false
	var seats: Array = []
	var selected_level: String = "city"
	var tutorial_lesson: int = 0

	if _save != null:
		if _save.has_method("get_selected_level"):
			selected_level = _save.get_selected_level()
		else:
			selected_level = str(_save.get_value("selected_level", "city"))
		if _save.has_method("get_tutorial_lesson"):
			tutorial_lesson = _save.get_tutorial_lesson()
		else:
			tutorial_lesson = int(_save.get_value("tutorial_lesson", 0))
		if selected_level == "tutorial" and tutorial_lesson == 0:
			tutorial_lesson = 1
		mode = str(_save.get_value("match_mode", "detectives"))
		detective_count = int(_save.get_value("detective_count", 4))
		tells_enabled = bool(_save.get_value("tells_enabled", false))
		var s_val = _save.get_value("seats", [])
		if s_val is Array and not s_val.is_empty():
			seats = s_val

	# Connect Board signals
	if _board != null:
		_board.station_clicked.connect(_on_station_clicked)

	# Connect GameBus signals
	if _bus != null:
		_bus.mrx_surfaced.connect(_on_mrx_surfaced)
		_bus.game_over.connect(_on_game_over)
		if _bus.has_signal("focus_requested"):
			_bus.focus_requested.connect(_on_focus_requested)
		if _bus.has_signal("pause_requested") and not _bus.pause_requested.is_connected(_on_pause_requested):
			_bus.pause_requested.connect(_on_pause_requested)
		if _bus.has_signal("player_stuck"):
			_bus.player_stuck.connect(_on_player_stuck)
		if _bus.has_signal("mrx_closed_eyes"):
			_bus.mrx_closed_eyes.connect(_on_mrx_closed_eyes)
		if _bus.has_signal("mrx_gaze_started"):
			_bus.mrx_gaze_started.connect(_on_mrx_gaze_started)
		if _bus.has_signal("mrx_gaze_ended"):
			_bus.mrx_gaze_ended.connect(_on_mrx_gaze_ended)

	# Initialize MatchFeature
	if _match_feature != null:
		var deps: Dictionary = {
			"game": _game_manager,
			"bus": _bus,
			"logger": _logger,
			"detectives": detective_count,
			"tells_enabled": tells_enabled,
			"auto_play_ai": false,
			"level": selected_level,
			"tutorial_lesson": tutorial_lesson
		}
		if not seats.is_empty():
			deps["seats"] = seats
		else:
			deps["mode"] = mode

		_match_feature.initialize(deps)
		_match_feature.start()

		# Filter board and camera to active level region
		if _board != null and _match_feature.map_data != null:
			var active_stations: Array[int] = []
			for sid in _match_feature.map_data.stations.keys():
				active_stations.append(int(sid))
			_board.apply_level_filter(active_stations)

			if _camera != null and active_stations.size() < 199:
				var region_box := _match_feature.map_data.get_bounding_box(150.0)
				_camera.set_region_bounds(region_box, 150.0)

		# Setup initial token positions
		_setup_initial_tokens()

		# Configure HUD
		if _hud != null:
			var names_map: Dictionary = {}
			for s in _match_feature.seats:
				names_map[int(s.get("id", 0))] = str(s.get("name", ""))
			_hud.configure_hud(_match_feature.state, _match_feature.mode, _match_feature.detective_count, _bus, names_map)
			if _hud.ticket_picker != null:
				_hud.ticket_picker.ticket_chosen.connect(_on_ticket_picker_chosen)
				_hud.ticket_picker.picker_cancelled.connect(_on_ticket_picker_cancelled)
				if _hud.ticket_picker.has_signal("close_eyes_requested"):
					_hud.ticket_picker.close_eyes_requested.connect(_on_close_eyes_requested)

		# Initialize TutorialController if tutorial active
		if tutorial_lesson > 0 and _hud != null and _hud.coach_mark != null:
			_tutorial_controller = TutorialControllerClass.new()
			_tutorial_controller.name = "TutorialController"
			add_child(_tutorial_controller)
			if get_tree() != null and get_tree().root != null:
				var registry: Node = get_tree().root.get_node_or_null("ServiceRegistry")
				if registry != null:
					_tutorial_controller.inject_services(registry)
			_tutorial_controller.configure(_hud.coach_mark, _match_feature, _board, _camera, _hud, tutorial_lesson)
			_tutorial_controller.start_tutorial()

		# Initial turn trigger
		_on_turn_started(_match_feature.state.current_player)

		if _bus != null and not _bus.turn_started.is_connected(_on_turn_started):
			_bus.turn_started.connect(_on_turn_started)

func _setup_initial_tokens() -> void:
	if _board == null or _match_feature == null:
		return

	var det_count: int = _match_feature.detective_count
	for p in range(det_count + 1):
		var station_id: int = _match_feature.state.positions.get(p, 0)
		_board.set_token_position(p, station_id, false)

		if p == 0:
			# Mr. X token is visible ONLY during a human Mr. X's own turn.
			# If human Mr. X with AI detectives (single player), visible immediately.
			# If pass-and-play with human detectives, initially hidden until handover.
			var is_h_mrx := _match_feature.is_human_player(0)
			var has_h_dets := _match_feature.has_human_detectives()
			var mrx_vis := (is_h_mrx and not has_h_dets)
			_board.set_token_visible(0, mrx_vis)
		else:
			_board.set_token_visible(p, true)

	# Hide unused detective tokens (if detective_count < 5)
	for unused in range(det_count + 1, 6):
		_board.set_token_visible(unused, false)

func _on_station_clicked(station_id: int) -> void:
	_sfx(SFX_TAP, -8.0)
	if _is_animating_move or _is_handover_active or _match_feature == null or _match_feature.state.game_over:
		return

	# Only accept station clicks during human turn
	if _match_feature.is_ai_turn():
		return

	if _tutorial_controller != null and not _tutorial_controller.is_station_tap_allowed(station_id):
		return

	var cur_p: int = _match_feature.state.current_player
	var legal_moves: Array[Dictionary] = _match_feature.state.legal_moves(cur_p)

	# Filter legal moves matching the clicked destination station
	var matching_moves: Array[Dictionary] = []
	for m in legal_moves:
		if int(m["to"]) == station_id:
			matching_moves.append(m)

	if matching_moves.is_empty():
		return

	if _tutorial_controller != null:
		_tutorial_controller.on_station_tapped(station_id)

	# If human Mr. X, tapping a station pulls gaze briefly
	if cur_p == 0 and _match_feature.tells_enabled and _match_feature.player_gaze != null and _board != null:
		_match_feature.player_gaze.on_station_tapped(_board.get_station_position(station_id))

	if matching_moves.size() == 1:
		# Single transport link: execute immediately
		_execute_move_and_animate(cur_p, station_id, str(matching_moves[0]["ticket"]))
	else:
		# Multiple transport links: open TicketPicker
		_pending_station_id = station_id
		var ticket_types: Array[String] = []
		for m in matching_moves:
			var t := str(m["ticket"])
			if not ticket_types.has(t):
				ticket_types.append(t)

		var can_double: bool = (cur_p == 0 and _match_feature.state.tickets[0].get("double_move", _match_feature.state.tickets[0].get("double", 0)) > 0 and _match_feature.state.double_move_phase == 0)
		var close_eyes_left: int = _match_feature.state.close_eyes_cards if cur_p == 0 else 0

		if _hud != null and _hud.ticket_picker != null:
			_hud.ticket_picker.open_picker(station_id, ticket_types, cur_p == 0, can_double, close_eyes_left)
		else:
			_execute_move_and_animate(cur_p, station_id, ticket_types[0])

func _on_ticket_picker_chosen(ticket: String, use_double_move: bool) -> void:
	if _match_feature == null or _is_animating_move:
		return

	if _tutorial_controller != null:
		_tutorial_controller.on_ticket_picked(ticket)

	var cur_p: int = _match_feature.state.current_player
	if use_double_move and cur_p == 0:
		_match_feature.use_double_move()

	_execute_move_and_animate(cur_p, _pending_station_id, ticket)

func _on_ticket_picker_cancelled() -> void:
	_pending_station_id = 0

## Turn flow orchestration with Pass-and-Play Handover support
func _on_turn_started(player: int) -> void:
	if _is_animating_move or _match_feature == null or _match_feature.state.game_over:
		return

	# Check if Handover screen is needed between Mr. X and Detectives
	if _should_trigger_handover(player):
		_trigger_handover(player)
		return

	await _start_player_turn(player)

func _should_trigger_handover(player: int) -> bool:
	if _match_feature == null:
		return false
	# Handover screen is needed only when both Mr. X is human and at least one detective is human
	if not (_match_feature.is_human_mrx() and _match_feature.has_human_detectives()):
		return false

	if player == 0:
		# Shown before every Human Mr. X turn (if coming from match start or detective)
		return _previous_player != 0
	else:
		# Shown before a human detective's turn ONLY when switching from Mr. X
		# Detectives sharing the phone in a row do not need it between each other
		return (_match_feature.is_human_player(player) and _previous_player == 0)

func _trigger_handover(player: int) -> void:
	_is_handover_active = true

	# Ensure the map underneath is ALREADY in the correct view (Mr. X hidden)
	if _board != null:
		_board.set_token_visible(0, false)
		_board.clear_all_highlights()
		if _board.is_spotlight_visible():
			_board.hide_spotlight(true)
	if _hud != null:
		_hud.update_hud(false)

	var p_name: String = _match_feature.get_player_name(player)
	_show_handover_panel(p_name, player == 0, func():
		_is_handover_active = false
		_start_player_turn(player)
	)

func _show_handover_panel(player_name: String, is_mrx: bool, on_dismissed: Callable) -> void:
	var ui_mgr: UIManager = _ui_manager
	if ui_mgr == null and get_tree() != null and get_tree().root != null:
		var registry: Node = get_tree().root.get_node_or_null("ServiceRegistry")
		if registry != null and registry.has_method("get_service"):
			ui_mgr = registry.get_service(&"ui") as UIManager

	var panel_path: String = GameConfig.UI_PANELS.get("handover", "res://game/scenes/ui/hfw/HandoverPanel.tscn")
	var packed: PackedScene = load(panel_path)
	if packed == null or not is_inside_tree():
		on_dismissed.call()
		return

	var panel: HandoverPanel = null
	if ui_mgr != null:
		while not ui_mgr._stack.is_empty() and ui_mgr._stack.back() is HandoverPanel:
			ui_mgr.pop()
		ui_mgr.push_packed(packed)
		panel = ui_mgr._stack.back() as HandoverPanel
	else:
		panel = packed.instantiate() as HandoverPanel
		add_child(panel)

	if panel != null:
		panel.setup_handover(player_name, is_mrx)
		panel.handed_over.connect(func():
			on_dismissed.call()
		, CONNECT_ONE_SHOT)
	else:
		on_dismissed.call()

func _start_player_turn(player: int) -> void:
	if _match_feature == null or _match_feature.state.game_over:
		return

	var prev_player := _previous_player
	_previous_player = player

	# Visibility rule: Mr. X's real position, token, and ticket choices are visible
	# ONLY while a Human Mr. X is taking his turn (behind the handover screen)
	var is_human_mrx_turn: bool = (player == 0 and _match_feature.is_human_player(0))
	if _board != null:
		_board.set_token_visible(0, is_human_mrx_turn)
	if _hud != null:
		_hud.update_hud(is_human_mrx_turn)

	if not _match_feature.is_ai_player(player):
		# Human turn
		var legal_moves: Array[Dictionary] = _match_feature.state.legal_moves(player)
		var target_stations: Array[int] = []
		for m in legal_moves:
			var to_st: int = int(m["to"])
			if not target_stations.has(to_st):
				target_stations.append(to_st)
		if player > 0 and prev_player == 0:
			# Coming from Mr. X: Pan camera (0.45s) to the next detective.
			# Only AFTER the pan finishes, show that detective's highlights/route preview and accept taps.
			_is_animating_move = true
			if _board != null:
				_board.clear_all_highlights()
			_focus_on_player(player)

			if is_inside_tree():
				await get_tree().create_timer(0.45).timeout

			if not is_instance_valid(self) or not is_inside_tree() or _match_feature == null:
				return

			if _board != null and not _match_feature.state.game_over and _match_feature.state.current_player == player:
				_board.highlight_stations(target_stations)
				_board.show_routes(int(_match_feature.state.positions.get(player, 0)), legal_moves)

			_is_animating_move = false
		elif player == 0 and prev_player > 0:
			# Returning to Mr. X after detectives: Pan camera (AI_DETECTIVE_RETURN_TO_MRX_PAN_TIME) back to Mr. X's station with focus_zoom.
			# Only AFTER the pan finishes, show Mr. X's highlights/route preview and accept taps.
			_is_animating_move = true
			if _board != null:
				_board.clear_all_highlights()
			_focus_on_player(0, AI_DETECTIVE_RETURN_TO_MRX_PAN_TIME)

			if is_inside_tree():
				await get_tree().create_timer(AI_DETECTIVE_RETURN_TO_MRX_PAN_TIME).timeout

			if not is_instance_valid(self) or not is_inside_tree() or _match_feature == null:
				return

			if _board != null and not _match_feature.state.game_over and _match_feature.state.current_player == 0:
				_board.highlight_stations(target_stations)
				_board.show_routes(int(_match_feature.state.positions.get(0, 0)), legal_moves)

			_start_human_mrx_gaze()
			_is_animating_move = false
		else:
			_focus_on_player(player)
			if _board != null:
				_board.highlight_stations(target_stations)
				_board.show_routes(int(_match_feature.state.positions.get(player, 0)), legal_moves)
			if player == 0:
				_start_human_mrx_gaze()

		if player > 0:
			# Human Detective turn: check if we should replay Mr. X's glance
			if _match_feature.tells_enabled and not _mrx_closed_eyes_this_round and _recorded_mrx_path.size() >= 2:
				_play_gaze_replay(_recorded_mrx_path)
				_recorded_mrx_path.clear()
			elif _board != null and _board.is_spotlight_visible():
				_board.hide_spotlight(true)

		if _tutorial_controller != null:
			_tutorial_controller.on_turn_started(player)
	else:
		# AI turn: clear highlights and ensure spotlight hidden if not AI Mr. X
		if _board != null:
			_board.clear_all_highlights()
			if player > 0 and _board.is_spotlight_visible():
				_board.hide_spotlight(true)

		_trigger_ai_turn_with_delay(0.1)

## Plays Mr. X's glance replay at 2x speed for human detectives in pass-and-play
func _play_gaze_replay(path: Array[Dictionary]) -> void:
	if path.size() < 2 or _board == null or not is_inside_tree():
		return

	if _hud != null and _hud.toast != null:
		_hud.toast.show_toast("Replaying Mr. X's glance")

	var total_rec_time: float = path.back()["time"] - path.front()["time"]
	var replay_duration: float = clampf(total_rec_time / 2.0, 0.8, 3.2)
	var step_time: float = replay_duration / float(path.size())

	_board.show_spotlight(path[0]["pos"])
	var replay_points: Array[Vector2] = []
	for p in path:
		replay_points.append(p["pos"])
	_focus_on_gaze(replay_points)
	var tween := create_tween()
	for i in range(1, path.size()):
		var target_pt: Vector2 = path[i]["pos"]
		tween.tween_interval(step_time)
		tween.tween_callback(func():
			if _board != null:
				_board.set_spotlight_target(target_pt)
		)
	tween.tween_interval(0.35)
	tween.tween_callback(func():
		if _board != null:
			_board.hide_spotlight()
	)

func _start_human_mrx_gaze() -> void:
	# Human Mr. X turn: start recording gaze path
	# Spotlight starts near Mr. X (where the camera is heading), shifted off him by a random offset
	var init_pos := _board.get_station_position(int(_match_feature.state.positions.get(0, 0))) if _board != null else Vector2.ZERO
	if init_pos == Vector2.ZERO and _camera != null:
		init_pos = _camera.global_position
	if _match_feature.player_gaze != null:
		_match_feature.player_gaze.snap_to(init_pos)
		init_pos = _match_feature.player_gaze.current_gaze_pos # near Mr. X, not on him
		_match_feature.player_gaze.start_recording()
	if _match_feature.tells_enabled and _board != null and not _match_feature.player_gaze.is_eyes_closed():
		_board.show_spotlight(init_pos)
		if _bus != null:
			_bus.mrx_gaze_started.emit(init_pos)

func _focus_on_player(player_index: int, duration: float = 0.45) -> void:
	if _camera == null or _board == null or _match_feature == null:
		return
	# CRITICAL HIDDEN INFO RULE:
	# NEVER focus camera on Mr. X unless it is actively a Human Mr. X's own turn (and not during handover)
	if player_index == 0:
		if not _match_feature.is_human_player(0) or _is_handover_active:
			return

	var st_id: int = _match_feature.state.positions.get(player_index, 0)
	if st_id > 0:
		var target_pos := _board.get_station_position(st_id)
		if target_pos != Vector2.ZERO:
			_camera.pan_to_position(target_pos, duration, _camera.focus_zoom)

## Zooms in on Mr. X's glance (AI gaze or pass-and-play replay) so detectives can read it.
## Not used for a human Mr. X's own turn: his camera *is* his gaze, following it would loop.
func _focus_on_gaze(points: Array[Vector2]) -> void:
	if _camera == null or points.is_empty():
		return
	var centre := Vector2.ZERO
	for p in points:
		centre += p
	_camera.pan_to_position(centre / points.size(), 0.5, _camera.focus_zoom)

func _on_pause_requested() -> void:
	var path: String = GameConfig.UI_PANELS.get("pause", "")
	if _ui_manager != null and not path.is_empty() and _ui_manager.stack_size() == 0:
		_ui_manager.push_packed(load(path))

func _on_focus_requested() -> void:
	if _match_feature != null:
		var cur_p := _match_feature.state.current_player
		if cur_p == 0 and not _match_feature.is_human_player(0):
			return
		_focus_on_player(cur_p)

func _trigger_ai_turn_with_delay(delay: float) -> void:
	if _ai_timer_pending or _is_animating_move:
		return

	if not is_inside_tree():
		# In headless tests / outside tree, do not schedule timers
		return

	_ai_timer_pending = true
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func():
		_ai_timer_pending = false
		if _match_feature != null and _match_feature.is_ai_turn() and not _match_feature.state.game_over and not _is_animating_move:
			_execute_ai_turn()
	)

var _gaze_drift_tween: Tween = null

func _format_ticket_toast(ticket: String) -> String:
	match ticket:
		"taxi":
			return "Mr. X used a Taxi ticket"
		"bus":
			return "Mr. X used a Bus ticket"
		"underground":
			return "Mr. X used an Underground ticket"
		"black":
			return "Mr. X used a Black ticket"
		"ferry":
			return "Mr. X used a Ferry ticket"
		_:
			return "Mr. X used a %s ticket" % ticket.capitalize()

func _drift_spotlight_waypoints(waypoints: Array[Vector2], duration: float) -> Tween:
	if _gaze_drift_tween != null and _gaze_drift_tween.is_valid():
		_gaze_drift_tween.kill()

	if waypoints.is_empty() or _board == null or not is_inside_tree():
		return null

	_gaze_drift_tween = create_tween()
	if waypoints.size() == 1:
		_gaze_drift_tween.tween_interval(duration)
		return _gaze_drift_tween

	var step_time: float = duration / float(waypoints.size())
	for i in range(1, waypoints.size()):
		_gaze_drift_tween.tween_interval(step_time)
		var wp: Vector2 = waypoints[i]
		_gaze_drift_tween.tween_callback(func():
			if _board != null:
				_board.set_spotlight_target(wp)
		)
	_gaze_drift_tween.tween_interval(step_time)
	return _gaze_drift_tween

func _run_ai_mrx_turn() -> void:
	if _match_feature == null or not _match_feature.is_ai_player(0) or _match_feature.state.game_over:
		return

	_is_animating_move = true
	if _board != null:
		_board.clear_all_highlights()

	# Double move check if starting first phase of double move
	if _match_feature.mrx_ai.choose_double_move(_match_feature.state, _match_feature.map_data):
		_match_feature.use_double_move()

	if _match_feature.tells_enabled and _match_feature.ai_gaze != null:
		var gaze_w := _match_feature.ai_gaze.generate_turn_gaze()
		_match_feature.detective_ai.set_gaze_weights(gaze_w, true)
		if _match_feature.ai_gaze.is_eyes_closed:
			if _bus != null:
				_bus.mrx_closed_eyes.emit()
			if _board != null and _board.is_spotlight_visible():
				_board.hide_spotlight(true)
			if _hud != null and _hud.toast != null:
				_hud.toast.show_toast("Mr. X closed his eyes")
			if is_inside_tree():
				await get_tree().create_timer(1.0).timeout
		else:
			var waypoints: Array[Vector2] = _match_feature.ai_gaze.get_waypoints()
			# 1. Toast "Mr. X is thinking…". Camera pans to center of gaze waypoints (0.5s)
			if _hud != null and _hud.toast != null:
				_hud.toast.show_toast("Mr. X is thinking…")
			if not waypoints.is_empty():
				_focus_on_gaze(waypoints)
			if is_inside_tree():
				await get_tree().create_timer(0.5).timeout

			if not is_instance_valid(self) or not is_inside_tree() or _match_feature == null or _match_feature.state.game_over or _match_feature.state.current_player != 0:
				_is_animating_move = false
				return

			# 2. Spotlight fades in and drifts through waypoints over 2.0s
			if not waypoints.is_empty() and _board != null:
				_board.show_spotlight(waypoints[0])
				if _bus != null:
					_bus.mrx_gaze_started.emit(waypoints[0])
				var drift_tween := _drift_spotlight_waypoints(waypoints, 2.0)
				if drift_tween != null and drift_tween.is_valid():
					await drift_tween.finished
				elif is_inside_tree():
					await get_tree().create_timer(2.0).timeout

			if not is_instance_valid(self) or not is_inside_tree() or _match_feature == null or _match_feature.state.game_over or _match_feature.state.current_player != 0:
				_is_animating_move = false
				return

			# 3. Spotlight fades out over ~0.3s, then wait ~0.3s
			if _board != null:
				_board.hide_spotlight(false)
			if _bus != null:
				_bus.mrx_gaze_ended.emit()
			if is_inside_tree():
				await get_tree().create_timer(0.3).timeout
				await get_tree().create_timer(0.3).timeout
	else:
		# Tells OFF
		_match_feature.detective_ai.set_gaze_weights({}, false)
		if _board != null and _board.is_spotlight_visible():
			_board.hide_spotlight(true)
		if _hud != null and _hud.toast != null:
			_hud.toast.show_toast("Mr. X is thinking…")
		if is_inside_tree():
			await get_tree().create_timer(0.6).timeout

	if not is_instance_valid(self) or not is_inside_tree() or _match_feature == null or _match_feature.state.game_over or _match_feature.state.current_player != 0:
		_is_animating_move = false
		return

	# 4. Mr. X moves (hidden)
	var move: Dictionary = _match_feature.mrx_ai.choose_move(_match_feature.state, _match_feature.map_data)
	if not move.is_empty():
		await _execute_move_and_animate(0, int(move["to"]), str(move["ticket"]))
	else:
		_is_animating_move = false

func _execute_ai_turn() -> void:
	if _match_feature == null or not _match_feature.is_ai_turn() or _match_feature.state.game_over:
		return

	var cur_p: int = _match_feature.state.current_player
	if cur_p == 0:
		_run_ai_mrx_turn()
	else:
		_run_ai_detective_turn(cur_p)

func _run_ai_detective_turn(player: int) -> void:
	if _match_feature == null or not _match_feature.is_ai_player(player) or _match_feature.state.game_over:
		return

	_is_animating_move = true
	if _board != null:
		_board.clear_all_highlights()
		_board.clear_routes()
		if _board.is_spotlight_visible():
			_board.hide_spotlight(true)

	var cur_st: int = int(_match_feature.state.positions.get(player, 0))
	var moves: Array[Dictionary] = _match_feature.state.legal_moves(player)

	# A detective with no legal moves: toast "Detective N is stuck", 0.8s pause, continue
	if moves.is_empty():
		var name_str: String = _match_feature.get_player_name(player)
		if _hud != null and _hud.toast != null:
			_hud.toast.show_toast("%s is stuck" % name_str)
		if is_inside_tree():
			await get_tree().create_timer(AI_DETECTIVE_STUCK_PAUSE).timeout
		_is_animating_move = false
		_on_turn_started(_match_feature.state.current_player)
		return

	# 1. Camera pans AND zooms in to that detective's station (pan_to_position with focus_zoom, ~0.5s). Wait for pan to finish.
	if _camera != null and _board != null and cur_st > 0:
		var st_pos := _board.get_station_position(cur_st)
		if st_pos != Vector2.ZERO:
			_camera.pan_to_position(st_pos, AI_DETECTIVE_PAN_TIME, _camera.focus_zoom)
	if is_inside_tree():
		await get_tree().create_timer(AI_DETECTIVE_PAN_TIME).timeout

	if not is_instance_valid(self) or not is_inside_tree() or _match_feature == null or _match_feature.state.game_over or _match_feature.state.current_player != player:
		_is_animating_move = false
		return

	# 2. Toast "Detective N is thinking…" (use the seat name). Pause ~0.8s.
	var det_name: String = _match_feature.get_player_name(player)
	if _hud != null and _hud.toast != null:
		_hud.toast.show_toast("%s is thinking…" % det_name)
	if is_inside_tree():
		await get_tree().create_timer(AI_DETECTIVE_THINK_TIME).timeout

	if not is_instance_valid(self) or not is_inside_tree() or _match_feature == null or _match_feature.state.game_over or _match_feature.state.current_player != player:
		_is_animating_move = false
		return

	# Choose move using existing DetectiveAI logic (do not modify decision logic)
	var chosen_move: Dictionary = _match_feature.detective_ai.choose_move(player, _match_feature.state, _match_feature.map_data)
	if chosen_move.is_empty():
		_is_animating_move = false
		return

	var to_st: int = int(chosen_move["to"])
	var ticket: String = str(chosen_move["ticket"])

	# 3. Briefly show the chosen route: highlight the link from current station to target in that ticket's colour, ~0.4s.
	if _board != null:
		_board.show_routes(cur_st, [chosen_move])
	if is_inside_tree():
		await get_tree().create_timer(AI_DETECTIVE_ROUTE_PREVIEW_TIME).timeout

	if not is_instance_valid(self) or not is_inside_tree() or _match_feature == null or _match_feature.state.game_over or _match_feature.state.current_player != player:
		if _board != null:
			_board.clear_routes()
		_is_animating_move = false
		return

	# 4. Play the move animation (Board.play_move, vehicle visible).
	# The camera follows the vehicle while it travels (tween camera position along with it, keep zoom).
	var to_pos: Vector2 = _board.get_station_position(to_st) if _board != null else Vector2.ZERO

	# Apply move in MatchFeature
	var ok: bool = _match_feature.apply_move(player, to_st, ticket)
	if not ok:
		if _board != null:
			_board.clear_routes()
		_is_animating_move = false
		return

	if _hud != null:
		_hud.update_hud(false)

	# Determine vehicle travel duration matching Board.play_move
	var move_dur: float = 0.6
	if ticket == "bus":
		move_dur = 0.8
	elif ticket == "underground":
		move_dur = 0.5
	elif ticket == "ferry":
		move_dur = 0.85

	if _camera != null and to_pos != Vector2.ZERO:
		_camera.pan_to_position(to_pos, move_dur, _camera.focus_zoom)

	if _board != null:
		_sfx(SFX_MOVE, -4.0)
		await _board.play_move(player, cur_st, to_st, ticket)

	# 5. Clear route highlight, pause ~0.5s, then the next AI detective
	if _board != null:
		_board.clear_routes()

	# If an AI detective catches Mr. X: let the move animation finish, then game over (no cut-off)
	if _match_feature.state.game_over:
		_is_animating_move = false
		_on_game_over(_match_feature.state.reason)
		return

	if is_inside_tree():
		await get_tree().create_timer(AI_DETECTIVE_POST_MOVE_PAUSE).timeout

	if not is_instance_valid(self) or not is_inside_tree() or _match_feature == null or _match_feature.state.game_over:
		_is_animating_move = false
		return

	_is_animating_move = false
	_on_turn_started(_match_feature.state.current_player)

func _execute_move_and_animate(player: int, to: int, ticket: String) -> void:
	if _match_feature == null:
		return

	_is_animating_move = true
	if _board != null:
		_board.clear_all_highlights()
		if player == 0 and _board.is_spotlight_visible():
			_board.hide_spotlight()
			if _bus != null:
				_bus.mrx_gaze_ended.emit()

	var from_st: int = _match_feature.state.positions.get(player, 0)

	# If human Mr. X just completed a move, save recorded path for replay and reset eyes closed
	if player == 0 and _match_feature.is_human_player(0):
		if _match_feature.player_gaze != null:
			_match_feature.player_gaze.stop_recording()
			_recorded_mrx_path = _match_feature.player_gaze.get_recorded_path().duplicate()
			_mrx_closed_eyes_this_round = _match_feature.player_gaze.is_eyes_closed()
			_match_feature.player_gaze.set_eyes_closed(false)

	# 1. Apply move in MatchFeature
	var ok: bool = _match_feature.apply_move(player, to, ticket)
	if not ok:
		_is_animating_move = false
		return

	# Show ticket toast for Mr. X if not a reveal round (on reveal round, _on_mrx_surfaced will show)
	if player == 0 and _hud != null and _hud.toast != null:
		var last_entry: Dictionary = _match_feature.state.mrx_move_log.back() if not _match_feature.state.mrx_move_log.is_empty() else {}
		if not last_entry.get("revealed", false):
			_hud.toast.show_toast(_format_ticket_toast(ticket))

	# 2. Update HUD immediately
	if _hud != null:
		var is_human_mrx := (player == 0 and _match_feature.is_human_player(0))
		_hud.update_hud(is_human_mrx)

	# 3. Visibility rule:
	# Mr. X's real position, token, and vehicle animation are shown ONLY while a Human Mr. X is taking his turn
	var should_animate_vehicle: bool = true
	if player == 0:
		should_animate_vehicle = _match_feature.is_human_player(0)

	if should_animate_vehicle and _board != null:
		_sfx(SFX_MOVE, -4.0)
		if player > 0 and _camera != null:
			var to_pos := _board.get_station_position(to)
			if to_pos != Vector2.ZERO:
				_camera.pan_to_position(to_pos, 0.6, _camera.focus_zoom)
		await _board.play_move(player, from_st, to, ticket)
	else:
		if _board != null:
			_board.set_token_position(player, to, false)
			# AI Mr. X token stays invisible
			if player == 0:
				_board.set_token_visible(0, false)

	var next_p: int = _match_feature.state.current_player
	var next_is_mrx_double: bool = (next_p == 0 and _match_feature.state.double_move_phase == 2)
	_is_animating_move = false

	# 4. Immediately hide Mr. X token if turn is passing away from Mr. X
	if not next_is_mrx_double and _board != null:
		_board.set_token_visible(0, false)
		if _hud != null:
			_hud.update_hud(false)

	# 5. Check Game Over
	if _tutorial_controller != null:
		_tutorial_controller.on_move_completed(player)

	if _match_feature.state.game_over:
		_on_game_over(_match_feature.state.reason)
		return

	# 6. Next turn starts after animation finishes
	await _on_turn_started(_match_feature.state.current_player)

func _on_mrx_surfaced(station: int) -> void:
	_sfx(SFX_REVEAL)
	if _board != null:
		_board.set_last_seen(station, true)

	if _hud != null and _hud.toast != null:
		var cur_r: int = _match_feature.state.round if _match_feature != null else 1
		_hud.toast.show_toast("Round %d: Mr. X surfaced at Station %d!" % [cur_r, station])

func _on_player_stuck(player: int) -> void:
	if _hud != null and _hud.toast != null:
		_hud.toast.show_toast("Detective %d has no legal moves and is skipped!" % player)

func _on_game_over(reason: String) -> void:
	var human_won: bool = _match_feature != null and (
		(_match_feature.state.winner == "detectives" and _match_feature.has_human_detectives())
		or (_match_feature.state.winner != "detectives" and _match_feature.is_human_player(0)))
	_sfx(SFX_WIN if human_won else SFX_LOSE)
	var route: Array[int] = _match_feature.state.get_mrx_route() if _match_feature != null else []
	if _board != null:
		_board.clear_all_highlights()
		if _board.is_spotlight_visible():
			_board.hide_spotlight(true)
		_board.show_mrx_route(route)

	if _hud != null:
		_hud.update_hud(true)

	# Unlock progression: completing a level unlocks the next
	if _save != null:
		var cur_level: String = str(_save.get_value("selected_level", "city"))
		var next_unlocked: String = ""
		if _save.has_method("unlock_next_level"):
			next_unlocked = _save.unlock_next_level(cur_level)
		if not next_unlocked.is_empty() and _hud != null and _hud.toast != null:
			_hud.toast.show_toast("New level unlocked: %s!" % next_unlocked.capitalize())

	_show_game_over_panel(reason, route)

func _show_game_over_panel(reason: String, route: Array = []) -> void:
	var ui_mgr: UIManager = _ui_manager
	if ui_mgr == null and get_tree() != null and get_tree().root != null:
		var registry: Node = get_tree().root.get_node_or_null("ServiceRegistry")
		if registry != null and registry.has_method("get_service"):
			ui_mgr = registry.get_service(&"ui") as UIManager

	var panel_path: String = GameConfig.UI_PANELS.get("game_over", "res://game/scenes/ui/hfw/GameOverPanel.tscn")
	var packed: PackedScene = load(panel_path)
	if ui_mgr != null and packed != null:
		ui_mgr.push_packed(packed)
		var panel = ui_mgr._stack.back() as GameOverPanel
		if panel != null:
			var winner: String = _match_feature.state.winner if _match_feature != null else "detectives"
			panel.set_result(winner, reason, route)

func _on_mrx_closed_eyes() -> void:
	if _board != null:
		_board.hide_spotlight()
	if _hud != null and _hud.toast != null:
		_hud.toast.show_toast("Mr. X closed his eyes")

func _on_mrx_gaze_started(target_pos: Vector2) -> void:
	if _board != null and _match_feature != null and _match_feature.tells_enabled:
		_board.show_spotlight(target_pos)

func _on_mrx_gaze_ended() -> void:
	if _board != null:
		_board.hide_spotlight()

func _on_close_eyes_requested() -> void:
	if _match_feature == null:
		return
	if _match_feature.state.use_close_eyes():
		if _match_feature.player_gaze != null:
			_match_feature.player_gaze.set_eyes_closed(true)
		if _board != null:
			_board.hide_spotlight()
		if _hud != null:
			_hud.update_hud()
		if _bus != null:
			_bus.mrx_closed_eyes.emit()

func _process(delta: float) -> void:
	# 1. Update Human Mr. X gaze tracking
	if _match_feature != null and _match_feature.tells_enabled and _match_feature.state.current_player == 0 and _match_feature.is_human_player(0) and not _is_handover_active:
		if _match_feature.player_gaze != null and _camera != null:
			_match_feature.player_gaze.on_camera_updated(_camera.global_position, _camera.zoom.x)
			_match_feature.player_gaze.update(delta, _camera.zoom.x)
			if _board != null and _board.is_spotlight_visible():
				_board.set_spotlight_target(_match_feature.player_gaze.current_gaze_pos)

