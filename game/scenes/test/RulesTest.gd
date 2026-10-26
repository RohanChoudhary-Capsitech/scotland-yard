extends SceneTree

## RulesTest — Headless test script for Scotland Yard rules and state logic.
## Run with: godot --headless -s res://game/scenes/test/RulesTest.gd

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	print("==================================================")
	print("       RUNNING SCOTLAND YARD RULES TESTS          ")
	print("==================================================")

	var map_data: MapData = MapData.new("res://game/assets/data/map.json")
	if map_data.stations.is_empty():
		_fail("MapData load", "Failed to load map.json or map.json is empty")
		quit(1)
		return
	else:
		total_tests += 1
		_pass("MapData loaded (%d stations, %d links)" % [map_data.stations.size(), _count_links(map_data)])

	test_ticket_counts(map_data)
	test_ticket_transfer_to_mrx(map_data)
	test_black_ticket_on_ferry(map_data)
	test_double_move(map_data)
	test_reveal_rounds(map_data)
	test_detective_blocking(map_data)
	test_skipped_detective(map_data)
	test_win_detective_catches_mrx(map_data)
	test_win_mrx_no_legal_moves(map_data)
	test_win_no_detectives_can_move(map_data)
	test_win_mrx_survives_24_rounds(map_data)
	test_match_feature_lifecycle()
	test_ai_driving(map_data)

	print("==================================================")
	print("TEST RESULTS: %d Passed, %d Failed (Total %d)" % [passed_tests, failed_tests, total_tests])
	print("==================================================")

	if failed_tests > 0:
		quit(1)
	else:
		quit(0)

func _count_links(map_data: MapData) -> int:
	var total: int = 0
	for s in map_data.adjacency:
		var links: Array = map_data.adjacency[s]
		total += links.size()
	return total / 2

func _assert_true(cond: bool, test_name: String, msg: String = "") -> void:
	total_tests += 1
	if cond:
		_pass(test_name)
	else:
		_fail(test_name, msg)

func _pass(test_name: String) -> void:
	passed_tests += 1
	print("  [PASS] %s" % test_name)

func _fail(test_name: String, reason: String = "") -> void:
	failed_tests += 1
	if reason.is_empty():
		print("  [FAIL] %s" % test_name)
	else:
		print("  [FAIL] %s: %s" % [test_name, reason])

# ── 1. Ticket Counts ──────────────────────────────────────────────────────────
func test_ticket_counts(map_data: MapData) -> void:
	var state: SYGameState = SYGameState.new(map_data, 4)

	# Mr. X with 4 detectives
	_assert_true(state.tickets[0]["taxi"] == 4, "Mr. X taxi tickets == 4")
	_assert_true(state.tickets[0]["bus"] == 3, "Mr. X bus tickets == 3")
	_assert_true(state.tickets[0]["underground"] == 3, "Mr. X underground tickets == 3")
	_assert_true(state.tickets[0]["black"] == 4, "Mr. X black tickets == 4 (detectives count)")
	_assert_true(state.tickets[0]["double"] == 2, "Mr. X double move tickets == 2")

	# Detectives
	for d in range(1, 5):
		_assert_true(state.tickets[d]["taxi"] == 10, "Detective %d taxi == 10" % d)
		_assert_true(state.tickets[d]["bus"] == 8, "Detective %d bus == 8" % d)
		_assert_true(state.tickets[d]["underground"] == 4, "Detective %d underground == 4" % d)
		_assert_true(state.tickets[d]["black"] == 0, "Detective %d black == 0" % d)
		_assert_true(state.tickets[d]["double"] == 0, "Detective %d double == 0" % d)

	# Dynamic black ticket count matching detective count (3 and 5)
	var state3: SYGameState = SYGameState.new(map_data, 3)
	_assert_true(state3.tickets[0]["black"] == 3, "Mr. X black tickets == 3 for 3 detectives")

	var state5: SYGameState = SYGameState.new(map_data, 5)
	_assert_true(state5.tickets[0]["black"] == 5, "Mr. X black tickets == 5 for 5 detectives")

# ── 2. Ticket Transfer to Mr. X ──────────────────────────────────────────────
func test_ticket_transfer_to_mrx(map_data: MapData) -> void:
	var state: SYGameState = SYGameState.new(map_data, 4)

	# Pick initial Mr. X move
	var mrx_moves: Array[Dictionary] = state.legal_moves(0)
	var mrx_m: Dictionary = mrx_moves[0]
	var mrx_ticket_used: String = mrx_m["ticket"]
	state.apply_move(0, mrx_m["to"], mrx_ticket_used)

	# Detective 1 moves with a taxi ticket
	var d1_moves: Array[Dictionary] = state.legal_moves(1)
	var taxi_move: Dictionary = {}
	for m in d1_moves:
		if m["ticket"] == "taxi":
			taxi_move = m
			break

	_assert_true(not taxi_move.is_empty(), "Detective 1 has a taxi move available")
	var mrx_taxi_count_before: int = state.tickets[0]["taxi"]
	var d1_taxi_count_before: int = state.tickets[1]["taxi"]

	state.apply_move(1, taxi_move["to"], "taxi")

	_assert_true(state.tickets[1]["taxi"] == d1_taxi_count_before - 1, "Detective 1 taxi decremented by 1")
	_assert_true(state.tickets[0]["taxi"] == mrx_taxi_count_before + 1, "Mr. X received Detective 1's taxi ticket")

# ── 3. Black Ticket on Ferry ─────────────────────────────────────────────────
func test_black_ticket_on_ferry(map_data: MapData) -> void:
	# Find a ferry link
	var ferry_a: int = 0
	var ferry_b: int = 0
	for sid in map_data.adjacency:
		var links: Array = map_data.adjacency[sid]
		for link in links:
			if link["type"] == "ferry":
				ferry_a = sid
				ferry_b = link["to"]
				break
		if ferry_a != 0:
			break

	_assert_true(ferry_a != 0, "Found a ferry link (%d <-> %d)" % [ferry_a, ferry_b])

	var state: SYGameState = SYGameState.new(map_data, 4)
	state.positions[0] = ferry_a
	state.positions[1] = ferry_a

	# Mr. X should have legal move to ferry_b with "black" ticket
	var mrx_moves: Array[Dictionary] = state.legal_moves(0)
	var has_ferry_black: bool = false
	var has_ferry_taxi: bool = false
	for m in mrx_moves:
		if m["to"] == ferry_b:
			if m["ticket"] == "black":
				has_ferry_black = true
			if m["ticket"] == "taxi":
				has_ferry_taxi = true

	_assert_true(has_ferry_black, "Mr. X can traverse ferry with black ticket")
	_assert_true(not has_ferry_taxi, "Mr. X cannot traverse ferry with taxi ticket")

	# Detective at ferry_a cannot traverse ferry
	var d1_moves: Array[Dictionary] = state.legal_moves(1)
	var d1_can_ferry: bool = false
	for m in d1_moves:
		if m["to"] == ferry_b:
			var links: Array = map_data.adjacency[ferry_a]
			for link in links:
				if link["to"] == ferry_b and link["type"] == "ferry":
					d1_can_ferry = true
	_assert_true(not d1_can_ferry, "Detective cannot traverse ferry link")

	# Test Mr. X can also use black ticket on normal taxi link
	var taxi_link_b: int = 0
	var f_links: Array = map_data.adjacency[ferry_a]
	for link in f_links:
		if link["type"] == "taxi":
			taxi_link_b = link["to"]
			break
	if taxi_link_b != 0:
		var has_black_on_taxi: bool = false
		for m in mrx_moves:
			if m["to"] == taxi_link_b and m["ticket"] == "black":
				has_black_on_taxi = true
				break
		_assert_true(has_black_on_taxi, "Mr. X can use black ticket on taxi link")

# ── 4. Double Move ───────────────────────────────────────────────────────────
func test_double_move(map_data: MapData) -> void:
	var state: SYGameState = SYGameState.new(map_data, 4)
	var initial_double: int = state.tickets[0]["double"]

	_assert_true(state.use_double_move(), "Mr. X successfully activates double move")
	_assert_true(state.tickets[0]["double"] == initial_double - 1, "Double move card count decremented")
	_assert_true(state.double_move_phase == 1, "Double move phase is 1")

	# Move 1
	var m1: Dictionary = state.legal_moves(0)[0]
	var ok1: bool = state.apply_move(0, m1["to"], m1["ticket"])
	_assert_true(ok1, "First move of double move succeeded")
	_assert_true(state.current_player == 0, "Current player remains Mr. X for second move")
	_assert_true(state.double_move_phase == 2, "Double move phase advanced to 2")
	_assert_true(state.round == 2, "Round incremented to 2 for second move slot")

	# Move 2
	var m2: Dictionary = state.legal_moves(0)[0]
	var ok2: bool = state.apply_move(0, m2["to"], m2["ticket"])
	_assert_true(ok2, "Second move of double move succeeded")
	_assert_true(state.current_player == 1, "Turn passed to Detective 1 after double move")
	_assert_true(state.double_move_phase == 0, "Double move phase reset to 0")

	# Verify move log has 2 separate logged moves
	_assert_true(state.mrx_move_log.size() == 2, "Mr. X move log recorded both moves")
	_assert_true(state.mrx_move_log[0]["round"] == 1, "First move logged at round 1")
	_assert_true(state.mrx_move_log[1]["round"] == 2, "Second move logged at round 2")

# ── 5. Reveal Rounds ─────────────────────────────────────────────────────────
func test_reveal_rounds(map_data: MapData) -> void:
	var state: SYGameState = SYGameState.new(map_data, 4)

	# Verify reveal schedule
	for r in [3, 8, 13, 18, 24]:
		_assert_true(state.is_reveal_round(r), "Round %d is a reveal round" % r)
	for r in [1, 2, 4, 7, 9, 12, 14, 19]:
		_assert_true(not state.is_reveal_round(r), "Round %d is NOT a reveal round" % r)

	# Fast-forward to round 3 Mr. X move
	state.round = 3
	state.current_player = 0
	var mrx_m: Dictionary = state.legal_moves(0)[0]
	var target_st: int = mrx_m["to"]
	state.apply_move(0, target_st, mrx_m["ticket"])

	var last_entry: Dictionary = state.mrx_move_log.back()
	_assert_true(last_entry["revealed"] == true, "Round 3 move marked revealed in log")
	_assert_true(state.last_revealed_position == target_st, "last_revealed_position updated to station %d" % target_st)

# ── 6. Detective Blocking ────────────────────────────────────────────────────
func test_detective_blocking(map_data: MapData) -> void:
	var state: SYGameState = SYGameState.new(map_data, 4)

	# Find two adjacent stations
	var st_a: int = 1
	var links: Array = map_data.get_links_from(st_a)
	var st_b: int = links[0]["to"]

	# Place Detective 1 at st_a, Detective 2 at st_b
	state.positions[1] = st_a
	state.positions[2] = st_b
	state.current_player = 1

	var moves: Array[Dictionary] = state.legal_moves(1)
	var moves_to_b: bool = false
	for m in moves:
		if m["to"] == st_b:
			moves_to_b = true
			break

	_assert_true(not moves_to_b, "Detective 1 cannot move to station occupied by Detective 2")

	# Attempting apply_move onto Detective 2 must fail
	var rejected: bool = state.apply_move(1, st_b, "taxi")
	_assert_true(not rejected, "apply_move rejected when landing on another detective")

# ── 7. Skipped Detective ─────────────────────────────────────────────────────
func test_skipped_detective(map_data: MapData) -> void:
	var state: SYGameState = SYGameState.new(map_data, 4)

	# Strip Detective 2 of all tickets
	state.tickets[2]["taxi"] = 0
	state.tickets[2]["bus"] = 0
	state.tickets[2]["underground"] = 0

	# Mr. X moves
	var mrx_m: Dictionary = state.legal_moves(0)[0]
	state.apply_move(0, mrx_m["to"], mrx_m["ticket"])

	_assert_true(state.current_player == 1, "Detective 1's turn")

	# Detective 1 moves
	var d1_m: Dictionary = state.legal_moves(1)[0]
	state.apply_move(1, d1_m["to"], d1_m["ticket"])

	# Since Detective 2 has no legal moves, turn must skip to Detective 3!
	_assert_true(state.current_player == 3, "Detective 2 skipped; turn automatically advanced to Detective 3")
	_assert_true(state.last_skipped_detectives.has(2), "Detective 2 recorded in last_skipped_detectives")

# ── 8. Win Conditions ────────────────────────────────────────────────────────
func test_win_detective_catches_mrx(map_data: MapData) -> void:
	var state: SYGameState = SYGameState.new(map_data, 4)

	var mrx_st: int = 10
	var links: Array = map_data.get_links_from(mrx_st)
	var d1_st: int = links[0]["to"]

	state.positions[0] = mrx_st
	state.positions[1] = d1_st
	state.current_player = 1

	var ok: bool = state.apply_move(1, mrx_st, "taxi")
	_assert_true(ok, "Detective 1 moves onto Mr. X's station")
	_assert_true(state.game_over, "Game is over")
	_assert_true(state.winner == "detectives", "Winner is 'detectives'")
	_assert_true("caught" in state.reason.to_lower(), "Reason mentions caught: %s" % state.reason)

func test_win_mrx_no_legal_moves(map_data: MapData) -> void:
	var state: SYGameState = SYGameState.new(map_data, 4)
	state.current_player = 0

	# Strip Mr. X of all tickets
	state.tickets[0]["taxi"] = 0
	state.tickets[0]["bus"] = 0
	state.tickets[0]["underground"] = 0
	state.tickets[0]["black"] = 0

	state.check_win()

	_assert_true(state.game_over, "Game over when Mr. X has no legal moves")
	_assert_true(state.winner == "detectives", "Detectives win when Mr. X is trapped/ticketless")

func test_win_no_detectives_can_move(map_data: MapData) -> void:
	var state: SYGameState = SYGameState.new(map_data, 4)

	# Strip all detectives of tickets
	for d in range(1, 5):
		state.tickets[d]["taxi"] = 0
		state.tickets[d]["bus"] = 0
		state.tickets[d]["underground"] = 0

	# Mr. X moves
	var mrx_m: Dictionary = state.legal_moves(0)[0]
	state.apply_move(0, mrx_m["to"], mrx_m["ticket"])

	_assert_true(state.game_over, "Game over when no detective can move")
	_assert_true(state.winner == "mrx", "Mr. X wins when no detective can move")
	_assert_true("no detective can move" in state.reason.to_lower(), "Reason: %s" % state.reason)

func test_win_mrx_survives_24_rounds(map_data: MapData) -> void:
	var state: SYGameState = SYGameState.new(map_data, 4)
	state.round = 24

	# Mr. X moves on round 24
	var mrx_m: Dictionary = state.legal_moves(0)[0]
	state.apply_move(0, mrx_m["to"], mrx_m["ticket"])
	_assert_true(not state.game_over, "Game continues until round 24 detectives finish")

	# Detectives 1..4 move on round 24
	for d in range(1, 5):
		if state.game_over:
			break
		# Ensure they don't land on Mr. X
		var d_moves: Array[Dictionary] = state.legal_moves(d)
		var safe_move: Dictionary = {}
		for m in d_moves:
			if m["to"] != state.positions[0]:
				safe_move = m
				break
		if not safe_move.is_empty():
			state.apply_move(d, safe_move["to"], safe_move["ticket"])

	_assert_true(state.game_over, "Game over after 24 rounds completed")
	_assert_true(state.winner == "mrx", "Mr. X wins by surviving 24 rounds")
	_assert_true("24" in state.reason, "Reason mentions 24 rounds: %s" % state.reason)

# ── 9. MatchFeature Lifecycle ────────────────────────────────────────────────
func test_match_feature_lifecycle() -> void:
	var game_manager: GameManager = GameManager.new()
	var bus_script = load("res://game/autoloads/GameBus.gd")
	var bus = bus_script.new()
	var logger_script = load("res://game/autoloads/Logger.gd")
	var logger = logger_script.new()

	game_manager.configure(logger, bus)

	var match_feature: MatchFeature = MatchFeature.new()
	match_feature.initialize({
		"game": game_manager,
		"bus": bus,
		"logger": logger,
		"mode": "detectives",
		"detectives": 4
	})

	var turn_started_players: Array[int] = []
	bus.turn_started.connect(func(p: int): turn_started_players.append(p))

	var moved_events: Array[Dictionary] = []
	bus.player_moved.connect(func(p: int, to: int, t: String): moved_events.append({"player": p, "to": to, "ticket": t}))

	match_feature.start()

	_assert_true(game_manager.is_playing(), "GameManager is playing after MatchFeature.start()")
	_assert_true(turn_started_players.has(0), "turn_started emitted for Mr. X on start")

	var state: SYGameState = match_feature.state
	var mrx_m: Dictionary = state.legal_moves(0)[0]
	var ok: bool = match_feature.apply_move(0, mrx_m["to"], mrx_m["ticket"])

	_assert_true(ok, "MatchFeature.apply_move succeeded")
	_assert_true(moved_events.size() == 1, "player_moved signal emitted")
	_assert_true(moved_events[0]["player"] == 0, "player_moved event has player 0")

	match_feature.free()
	game_manager.free()
	bus.free()
	logger.free()

# ── 10. AI Driving & Information Hiding ──────────────────────────────────────
func test_ai_driving(map_data: MapData) -> void:
	# Test A: Mode "detectives" (AI Mr. X, Human Detectives)
	var match_det := MatchFeature.new()
	match_det.initialize({
		"map_data": map_data,
		"mode": "detectives",
		"detectives": 4
	})
	match_det.start()

	_assert_true(match_det.is_ai_player(0), "Mr. X is AI in 'detectives' mode")
	_assert_true(not match_det.is_ai_player(1), "Detective 1 is human in 'detectives' mode")
	_assert_true(match_det.is_ai_turn(), "Initial turn is AI turn (Mr. X)")

	var played_mrx := match_det.play_ai_turn()
	_assert_true(played_mrx, "MatchFeature.play_ai_turn executed Mr. X AI move")
	_assert_true(match_det.state.current_player == 1, "Turn passed to Detective 1 (human)")
	_assert_true(not match_det.is_ai_turn(), "Detective 1 turn is not AI turn")
	match_det.free()

	# Test B: Mode "mrx" (Human Mr. X, AI Detectives)
	var match_mrx := MatchFeature.new()
	match_mrx.initialize({
		"map_data": map_data,
		"mode": "mrx",
		"detectives": 4
	})
	match_mrx.start()

	_assert_true(not match_mrx.is_ai_player(0), "Mr. X is human in 'mrx' mode")
	_assert_true(match_mrx.is_ai_player(1), "Detective 1 is AI in 'mrx' mode")
	_assert_true(not match_mrx.is_ai_turn(), "Initial turn is human turn (Mr. X)")

	var mrx_m: Dictionary = match_mrx.state.legal_moves(0)[0]
	match_mrx.apply_move(0, mrx_m["to"], mrx_m["ticket"])

	_assert_true(match_mrx.state.current_player == 1, "Turn passed to Detective 1 (AI)")
	_assert_true(match_mrx.is_ai_turn(), "Detective 1 turn is AI turn")

	var played_det1 := match_mrx.play_ai_turn()
	_assert_true(played_det1, "MatchFeature.play_ai_turn executed Detective 1 AI move")
	match_mrx.free()

	# Test C: DetectiveAI information hiding (never access state.positions[0])
	var state := SYGameState.new(map_data, 4)
	var det_ai := DetectiveAI.new()
	state.positions.erase(0)
	var d_move := det_ai.choose_move(1, state, map_data)
	_assert_true(not d_move.is_empty(), "DetectiveAI chooses legal move with state.positions[0] completely erased")
