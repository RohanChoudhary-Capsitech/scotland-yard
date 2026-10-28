class_name MatchFeature
extends GameFeature

## MatchFeature — Coordinates a Scotland Yard match instance.
## Owns MapData, SYGameState, and AI drivers (MrXAI, DetectiveAI).
## Interfaces with GameManager and broadcasts GameBus signals.

var map_data: MapData
var state: SYGameState
var mrx_ai: MrXAI
var detective_ai: DetectiveAI
var ai_gaze: AIGaze
var player_gaze: PlayerGaze

var _game: GameManager
var _bus: Node
var _logger: Node
var seats: Array[Dictionary] = [] # [{ "id": int, "name": String, "type": "human"|"ai", "is_human": bool }]
var detective_count: int = 4
var auto_play_ai: bool = false   # When true, automatically steps AI turns until next human turn
var tells_enabled: bool = false
var tutorial_lesson: int = 0

var mode: String:
	get:
		if seats.is_empty():
			return "detectives"
		var mrx_h := is_human_player(0)
		var any_det_h := false
		var all_det_h := true
		for d in range(1, seats.size()):
			if is_human_player(d):
				any_det_h = true
			else:
				all_det_h = false
		if not mrx_h and all_det_h:
			return "detectives"
		elif mrx_h and not any_det_h:
			return "mrx"
		elif mrx_h and all_det_h:
			return "pass_and_play"
		elif not mrx_h and not any_det_h:
			return "ai_vs_ai"
		return "mixed"
	set(val):
		seats = _build_seats_from_mode(val, detective_count)

func _build_seats_from_mode(p_mode: String, p_count: int) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	var is_mrx_human: bool = (p_mode == "mrx" or p_mode == "pass_and_play")
	res.append({
		"id": 0,
		"name": "Mr. X",
		"type": "human" if is_mrx_human else "ai",
		"is_human": is_mrx_human
	})
	var are_dets_human: bool = (p_mode == "detectives" or p_mode == "pass_and_play")
	for d in range(1, p_count + 1):
		res.append({
			"id": d,
			"name": "Detective %d" % d,
			"type": "human" if are_dets_human else "ai",
			"is_human": are_dets_human
		})
	return res

func initialize(deps: Dictionary) -> void:
	if _initialized:
		return
	super.initialize(deps)

	_game = deps.get("game") as GameManager
	_bus = deps.get("bus") as Node
	_logger = deps.get("logger") as Node
	auto_play_ai = bool(deps.get("auto_play_ai", false))
	tells_enabled = bool(deps.get("tells_enabled", false))

	# Load level info if specified
	var level_id: String = str(deps.get("level", deps.get("level_id", "")))
	var level_data: Dictionary = {}
	if deps.has("level_data") and deps["level_data"] is Dictionary:
		level_data = deps["level_data"]
	elif not level_id.is_empty() and level_id != "city":
		var levels_file := "res://game/assets/data/levels.json"
		if FileAccess.file_exists(levels_file):
			var lf := FileAccess.open(levels_file, FileAccess.READ)
			if lf != null:
				var ljson := JSON.new()
				if ljson.parse(lf.get_as_text()) == OK and ljson.data is Dictionary:
					level_data = (ljson.data as Dictionary).get(level_id, {})

	var level_rounds: int = int(level_data.get("rounds", 24))
	var level_reveals: Array[int] = []
	for r in level_data.get("reveal_rounds", []):
		level_reveals.append(int(r))
	var level_tickets: Dictionary = level_data.get("tickets", {})
	var level_mrx_starts: Array[int] = []
	for s in level_data.get("mrx_start_stations", []):
		level_mrx_starts.append(int(s))
	var level_det_starts: Array[int] = []
	for s in level_data.get("detective_start_stations", []):
		level_det_starts.append(int(s))
	var level_starts: Array[int] = []
	for s in level_data.get("start_stations", []):
		level_starts.append(int(s))

	var default_det_count: int = int(level_data.get("detective_count", 4)) if not level_data.is_empty() else 4

	# Setup seats (authoritative seat configuration)
	if deps.has("seats") and deps["seats"] != null and not deps["seats"].is_empty():
		seats = []
		for s in deps["seats"]:
			if s is Dictionary:
				var is_h: bool = (s.get("type", "human") == "human" or s.get("is_human", false))
				seats.append({
					"id": int(s.get("id", seats.size())),
					"name": str(s.get("name", "Mr. X" if seats.is_empty() else "Detective %d" % seats.size())),
					"type": "human" if is_h else "ai",
					"is_human": is_h
				})
		detective_count = clampi(seats.size() - 1, 2, 5)
	elif deps.has("mode"):
		var m_str: String = str(deps.get("mode", "detectives"))
		detective_count = clampi(int(deps.get("detectives", default_det_count)), 2, 5)
		seats = _build_seats_from_mode(m_str, detective_count)
	else:
		detective_count = clampi(int(deps.get("detectives", default_det_count)), 2, 5)
		seats = _build_seats_from_mode("detectives", detective_count)

	if deps.has("map_data") and deps["map_data"] != null:
		map_data = deps["map_data"] as MapData
	else:
		map_data = MapData.new("")
		if not level_id.is_empty() and level_id != "city":
			map_data.load_level(level_id)
		else:
			map_data.load_from_file("res://game/assets/data/map.json")

	state = SYGameState.new(
		map_data,
		detective_count,
		level_starts,
		level_rounds,
		level_reveals,
		level_tickets,
		level_mrx_starts,
		level_det_starts
	)
	tutorial_lesson = int(deps.get("tutorial_lesson", 0))
	mrx_ai = MrXAI.new()
	detective_ai = DetectiveAI.new()
	if tutorial_lesson > 0 or level_id == "tutorial":
		mrx_ai.easy_mode = true
		detective_ai.easy_mode = true

	if tutorial_lesson == 1:
		state.positions[0] = 26
		state.positions[1] = 18
		state.positions[2] = 10
	elif tutorial_lesson == 2:
		state.positions[0] = 47
		state.positions[1] = 1
		state.positions[2] = 24
		state.max_rounds = 6

	ai_gaze = AIGaze.new(map_data, state, mrx_ai)
	player_gaze = PlayerGaze.new(map_data)
	detective_ai.tells_enabled = tells_enabled

func start() -> void:
	if not _initialized or _started:
		return
	super.start()

	if _game:
		_game.start()

	if _logger:
		_logger.info("MatchFeature started", {"mode": mode, "detectives": detective_count, "seats": seats})

	if _bus:
		_bus.round_changed.emit(state.round)
		_bus.turn_started.emit(state.current_player)

	if auto_play_ai and is_ai_turn() and not state.game_over:
		step_ai_turns()

## Returns true if the given player is controlled by human in the current seat config.
func is_human_player(player: int) -> bool:
	if player >= 0 and player < seats.size():
		return seats[player].get("is_human", false) or seats[player].get("type", "") == "human"
	return false

## Returns true if the given player is controlled by AI in the current seat config.
func is_ai_player(player: int) -> bool:
	return not is_human_player(player)

## Returns the configured display name for the player.
func get_player_name(player: int) -> String:
	if player >= 0 and player < seats.size():
		return str(seats[player].get("name", "Mr. X" if player == 0 else "Detective %d" % player))
	return "Mr. X" if player == 0 else "Detective %d" % player

## Returns true if at least one detective is human controlled.
func has_human_detectives() -> bool:
	for d in range(1, seats.size()):
		if is_human_player(d):
			return true
	return false

## Returns true if at least one detective is AI controlled.
func has_ai_detectives() -> bool:
	for d in range(1, seats.size()):
		if is_ai_player(d):
			return true
	return false

## Returns true if Mr. X is human controlled.
func is_human_mrx() -> bool:
	return is_human_player(0)

## Returns true if the currently active player is controlled by AI.
func is_ai_turn() -> bool:
	if not _started or state.game_over:
		return false
	return is_ai_player(state.current_player)

## Executes a single AI turn for the current player.
## Returns true if a move was successfully executed.
func play_ai_turn() -> bool:
	if not is_ai_turn():
		return false

	if state.current_player == 0:
		# Mr. X AI turn
		if tells_enabled and ai_gaze != null:
			var gaze_w := ai_gaze.generate_turn_gaze()
			detective_ai.set_gaze_weights(gaze_w, true)
			if ai_gaze.is_eyes_closed:
				if _bus != null:
					_bus.mrx_closed_eyes.emit()
			else:
				if _bus != null and not ai_gaze.gaze_waypoints.is_empty():
					_bus.mrx_gaze_started.emit(ai_gaze.gaze_waypoints[0])
		else:
			detective_ai.set_gaze_weights({}, false)

		if mrx_ai.choose_double_move(state, map_data):
			use_double_move()
		var move: Dictionary = mrx_ai.choose_move(state, map_data)
		if not move.is_empty():
			var ok := apply_move(0, int(move["to"]), str(move["ticket"]))
			if _bus != null and tells_enabled:
				_bus.mrx_gaze_ended.emit()
			return ok
		return false
	else:
		# Detective AI turn
		var d: int = state.current_player
		var move: Dictionary = detective_ai.choose_move(d, state, map_data)
		if not move.is_empty():
			return apply_move(d, int(move["to"]), str(move["ticket"]))
		return false

## Continuously executes AI turns until a human turn is reached or the match ends.
func step_ai_turns() -> void:
	while is_ai_turn() and not state.game_over:
		var moved := play_ai_turn()
		if not moved:
			break

func apply_move(player: int, to: int, ticket: String) -> bool:
	if not _started or state.game_over:
		return false

	# If human Mr. X just completed a move, feed accumulated gaze weights to detective AI if AI detectives exist
	if player == 0 and is_human_player(0) and tells_enabled and player_gaze != null:
		if has_ai_detectives():
			var gaze_w := player_gaze.get_attention_weights()
			detective_ai.set_gaze_weights(gaze_w, true)
		player_gaze.decay_for_new_round()

	var prev_round: int = state.round
	var ok := state.apply_move(player, to, ticket)
	if not ok:
		if _logger:
			_logger.warn("Invalid move rejected", {"player": player, "to": to, "ticket": ticket})
		return false

	if _bus:
		_bus.player_moved.emit(player, to, ticket)

	# If Mr. X moved and surfaced this turn
	if player == 0:
		var last_entry: Dictionary = state.mrx_move_log.back() if not state.mrx_move_log.is_empty() else {}
		if last_entry.get("revealed", false):
			if _bus:
				_bus.mrx_surfaced.emit(to)
			if _logger:
				_logger.info("Mr. X surfaced at station %d" % to)

	# Notify of any players skipped during transition
	if not state.last_skipped_detectives.is_empty():
		for stuck_p in state.last_skipped_detectives:
			if _bus:
				_bus.player_stuck.emit(stuck_p)
			if _logger:
				_logger.info("Player %d skipped (no legal moves)" % stuck_p)

	# Check win condition
	if state.game_over:
		if _game:
			_game.game_over(state.reason)
		if _logger:
			_logger.info("Match concluded", {"winner": state.winner, "reason": state.reason})
		return true

	# Emit round changed if advanced
	if state.round != prev_round and _bus:
		_bus.round_changed.emit(state.round)

	# Notify of next turn
	if _bus:
		_bus.turn_started.emit(state.current_player)

	# Auto-advance AI turns if enabled
	if auto_play_ai and is_ai_turn() and not state.game_over:
		step_ai_turns()

	return true

func use_double_move() -> bool:
	if not _started or state.game_over:
		return false
	var ok := state.use_double_move()
	if ok and _logger:
		_logger.info("Mr. X used double-move card")
	return ok
