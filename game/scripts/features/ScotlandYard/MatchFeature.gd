class_name MatchFeature
extends GameFeature

## MatchFeature — Coordinates a Scotland Yard match instance.
## Owns MapData, SYGameState, and AI drivers (MrXAI, DetectiveAI).
## Interfaces with GameManager and broadcasts GameBus signals.

var map_data: MapData
var state: SYGameState
var mrx_ai: MrXAI
var detective_ai: DetectiveAI

var _game: GameManager
var _bus: Node
var _logger: Node
var mode: String = "detectives"  # "detectives", "mrx", or "ai_vs_ai"
var detective_count: int = 4
var auto_play_ai: bool = false   # When true, automatically steps AI turns until next human turn

func initialize(deps: Dictionary) -> void:
	if _initialized:
		return
	super.initialize(deps)

	_game = deps.get("game") as GameManager
	_bus = deps.get("bus") as Node
	_logger = deps.get("logger") as Node
	mode = str(deps.get("mode", "detectives"))
	detective_count = int(deps.get("detectives", 4))
	auto_play_ai = bool(deps.get("auto_play_ai", false))

	if deps.has("map_data") and deps["map_data"] != null:
		map_data = deps["map_data"] as MapData
	else:
		var map_path: String = "res://game/assets/data/map.json"
		map_data = MapData.new(map_path)
	state = SYGameState.new(map_data, detective_count)
	mrx_ai = MrXAI.new()
	detective_ai = DetectiveAI.new()

func start() -> void:
	if not _initialized or _started:
		return
	super.start()

	if _game:
		_game.start()

	if _logger:
		_logger.info("MatchFeature started", {"mode": mode, "detectives": detective_count})

	if _bus:
		_bus.round_changed.emit(state.round)
		_bus.turn_started.emit(state.current_player)

	if auto_play_ai and is_ai_turn() and not state.game_over:
		step_ai_turns()

## Returns true if the given player is controlled by AI in the current mode.
func is_ai_player(player: int) -> bool:
	if mode == "ai_vs_ai":
		return true
	elif mode == "detectives":
		return player == 0
	elif mode == "mrx":
		return player > 0
	return false

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
		if mrx_ai.choose_double_move(state, map_data):
			use_double_move()
		var move: Dictionary = mrx_ai.choose_move(state, map_data)
		if not move.is_empty():
			return apply_move(0, int(move["to"]), str(move["ticket"]))
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
