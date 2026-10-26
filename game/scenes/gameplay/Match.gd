class_name Match
extends Node2D

## Match — Scene controller for the Scotland Yard gameplay scene.
## Integrates Board view, BoardCameraController, and MatchFeature logic.
## Follows project DI architecture (inject_services -> inject_dependencies).

@onready var _board: Board = $Board
@onready var _camera: BoardCameraController = $BoardCameraController
@onready var _match_feature: MatchFeature = $MatchFeature

var board: Board:
	get:
		_ensure_nodes()
		return _board

var match_feature: MatchFeature:
	get:
		_ensure_nodes()
		return _match_feature

var _game_manager: GameManager
var _bus: Node
var _save: Object
var _logger: Node
var _audio: AudioManager

var _initialized_gameplay: bool = false
var _ai_timer_pending: bool = false
var _is_animating_move: bool = false

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

func _setup_match() -> void:
	if _initialized_gameplay:
		return
	_initialized_gameplay = true
	_ensure_nodes()

	# Read game settings from SaveManager
	var mode: String = "detectives"
	var detective_count: int = 4
	if _save != null:
		mode = str(_save.get_value("match_mode", "detectives"))
		detective_count = int(_save.get_value("detective_count", 4))

	# Connect Board signals
	if _board != null:
		_board.station_clicked.connect(_on_station_clicked)

	# Connect GameBus signals
	if _bus != null:
		_bus.turn_started.connect(_on_turn_started)
		_bus.mrx_surfaced.connect(_on_mrx_surfaced)
		_bus.game_over.connect(_on_game_over)

	# Initialize MatchFeature
	if _match_feature != null:
		_match_feature.initialize({
			"game": _game_manager,
			"bus": _bus,
			"logger": _logger,
			"mode": mode,
			"detectives": detective_count,
			"auto_play_ai": false # Driven step-by-step with UI animation pacing
		})
		_match_feature.start()

		# Setup initial token positions
		_setup_initial_tokens(mode, detective_count)

		# Initial turn highlight / trigger
		_on_turn_started(_match_feature.state.current_player)

func _setup_initial_tokens(mode: String, detective_count: int) -> void:
	if _board == null or _match_feature == null:
		return

	for p in range(detective_count + 1):
		var station_id: int = _match_feature.state.positions.get(p, 0)
		_board.set_token_position(p, station_id, false)

		if p == 0:
			# Mr. X is visible if playing as Mr. X, hidden if playing as Detectives
			var mrx_visible := (mode == "mrx")
			_board.set_token_visible(0, mrx_visible)
		else:
			# Detectives are always visible
			_board.set_token_visible(p, true)

	# Hide unused detective tokens (if detective_count < 5)
	for unused in range(detective_count + 1, 6):
		_board.set_token_visible(unused, false)

func _on_station_clicked(station_id: int) -> void:
	if _is_animating_move or _match_feature == null or _match_feature.state.game_over:
		return

	# Only accept station clicks during human turn
	if _match_feature.is_ai_turn():
		return

	var cur_p: int = _match_feature.state.current_player
	var legal_moves: Array[Dictionary] = _match_feature.state.legal_moves(cur_p)

	# Find a matching move to the clicked station
	var chosen_move: Dictionary = {}
	for m in legal_moves:
		if int(m["to"]) == station_id:
			chosen_move = m
			break

	if not chosen_move.is_empty():
		_execute_move_and_animate(cur_p, int(chosen_move["to"]), str(chosen_move["ticket"]))

func _on_turn_started(player: int) -> void:
	if _is_animating_move or _match_feature == null or _match_feature.state.game_over:
		return

	if not _match_feature.is_ai_turn():
		# Human turn: highlight all legal destination stations
		var legal_moves: Array[Dictionary] = _match_feature.state.legal_moves(player)
		var target_stations: Array[int] = []
		for m in legal_moves:
			var to_st: int = int(m["to"])
			if not target_stations.has(to_st):
				target_stations.append(to_st)
		_board.highlight_stations(target_stations)
	else:
		# AI turn: clear highlights and wait 0.6s before moving
		_board.clear_all_highlights()
		_trigger_ai_turn_with_delay(0.6)

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

func _execute_ai_turn() -> void:
	if _match_feature == null or not _match_feature.is_ai_turn() or _match_feature.state.game_over:
		return

	var cur_p: int = _match_feature.state.current_player
	if cur_p == 0:
		# Mr. X AI turn
		if _match_feature.mrx_ai.choose_double_move(_match_feature.state, _match_feature.map_data):
			_match_feature.use_double_move()
		var move: Dictionary = _match_feature.mrx_ai.choose_move(_match_feature.state, _match_feature.map_data)
		if not move.is_empty():
			_execute_move_and_animate(0, int(move["to"]), str(move["ticket"]))
	else:
		# Detective AI turn
		var move: Dictionary = _match_feature.detective_ai.choose_move(cur_p, _match_feature.state, _match_feature.map_data)
		if not move.is_empty():
			_execute_move_and_animate(cur_p, int(move["to"]), str(move["ticket"]))

func _execute_move_and_animate(player: int, to: int, ticket: String) -> void:
	if _match_feature == null:
		return

	_is_animating_move = true
	if _board != null:
		_board.clear_all_highlights()

	var from_st: int = _match_feature.state.positions.get(player, 0)

	# 1. Apply move in MatchFeature
	var ok: bool = _match_feature.apply_move(player, to, ticket)
	if not ok:
		_is_animating_move = false
		return

	# 2. Enforce Hidden Movement Rule:
	# Rule 5 (critical): in "Play as Detectives" mode, Mr. X's moves must NOT call play_move
	# or show any vehicle, link glow or particles. Only the travel log updates.
	# In "Play as Mr. X" mode, the human sees their own vehicle.
	var should_animate_vehicle: bool = true
	if player == 0:
		if _match_feature.mode == "detectives":
			should_animate_vehicle = false
		elif _match_feature.mode == "mrx":
			should_animate_vehicle = true

	if should_animate_vehicle and _board != null:
		await _board.play_move(player, from_st, to, ticket)
	else:
		if _board != null:
			_board.set_token_position(player, to, false)
			if player == 0 and _match_feature.mode == "detectives":
				# Hidden Mr. X in detectives mode stays invisible unless revealed
				var last_entry: Dictionary = _match_feature.state.mrx_move_log.back() if not _match_feature.state.mrx_move_log.is_empty() else {}
				var is_revealed: bool = bool(last_entry.get("revealed", false))
				_board.set_token_visible(0, is_revealed)

	_is_animating_move = false

	# 3. Check Game Over
	if _match_feature.state.game_over:
		_on_game_over(_match_feature.state.reason)
		return

	# 4. Hook play_move into turn flow (Rule 6):
	# Next turn starts only after animation finishes.
	_on_turn_started(_match_feature.state.current_player)

func _on_mrx_surfaced(station: int) -> void:
	if _board != null:
		_board.set_last_seen(station, true)
		_board.set_token_visible(0, true)

func _on_game_over(_reason: String) -> void:
	if _board != null:
		_board.clear_all_highlights()
		# Reveal Mr. X at match end
		_board.set_token_visible(0, true)
