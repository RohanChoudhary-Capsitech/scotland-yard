extends SceneTree

## AISim — Headless 200-game AI-vs-AI simulation and test suite for Scotland Yard.
## Verifies information hiding (detectives never read Mr. X's real position)
## and tests win rates with 4 detectives (target: 35–60% Mr. X win rate).

func _init() -> void:
	print("\n==================================================")
	print("       RUNNING SCOTLAND YARD AI SIMULATION        ")
	print("==================================================")

	var map_path: String = "res://game/assets/data/map.json"
	var map_data := MapData.new(map_path)
	if map_data.stations.is_empty():
		push_error("Failed to load map data!")
		quit(1)
		return

	# ----------------------------------------------------
	# Part 1: Information Hiding Tests for DetectiveAI
	# ----------------------------------------------------
	print("\n--- Verifying DetectiveAI Information Hiding ---")
	var info_hiding_passed: bool = _test_information_hiding(map_data)
	if not info_hiding_passed:
		print("[FAIL] DetectiveAI failed information hiding test!")
		quit(1)
		return
	print("[PASS] DetectiveAI never accesses Mr. X's secret position!")

	# ----------------------------------------------------
	# Part 2: 200-Game AI Simulation
	# ----------------------------------------------------
	print("\n--- Running 200 AI-vs-AI Matches (4 Detectives) ---")
	var total_games: int = 200
	var mrx_wins: int = 0
	var det_wins: int = 0
	var total_rounds: int = 0
	var win_reasons: Dictionary = {}

	var start_time: int = Time.get_ticks_msec()

	for i in range(total_games):
		# Deterministic seed per game for reproducible runs
		var seed_val: int = 1000 + i * 17
		seed(seed_val)

		var match_feature := MatchFeature.new()
		match_feature.initialize({
			"map_data": map_data,
			"mode": "ai_vs_ai",
			"detectives": 4,
			"auto_play_ai": false
		})
		match_feature.start()

		while not match_feature.state.game_over:
			match_feature.play_ai_turn()

		var state: SYGameState = match_feature.state
		total_rounds += state.round
		if state.winner == "mrx":
			mrx_wins += 1
		else:
			det_wins += 1

		var r_text: String = state.reason
		win_reasons[r_text] = win_reasons.get(r_text, 0) + 1
		match_feature.free()

		if (i + 1) % 50 == 0:
			print("  Simulated %d / %d matches..." % [i + 1, total_games])

	var elapsed_ms: int = Time.get_ticks_msec() - start_time
	var mrx_win_pct: float = (float(mrx_wins) / float(total_games)) * 100.0
	var det_win_pct: float = (float(det_wins) / float(total_games)) * 100.0
	var avg_rounds: float = float(total_rounds) / float(total_games)

	print("\n==================================================")
	print("                 SIMULATION RESULTS               ")
	print("==================================================")
	print("  Total Matches:     %d" % total_games)
	print("  Execution Time:    %.2f seconds" % [float(elapsed_ms) / 1000.0])
	print("  Mr. X Wins:        %d (%.1f%%)" % [mrx_wins, mrx_win_pct])
	print("  Detective Wins:    %d (%.1f%%)" % [det_wins, det_win_pct])
	print("  Average Rounds:    %.2f" % avg_rounds)
	print("\n  Win Reasons Breakdown:")
	for reason_str in win_reasons.keys():
		print("    - %s: %d" % [reason_str, win_reasons[reason_str]])
	print("==================================================")

	# Verify target: Mr. X wins 35–60% with 4 detectives
	if mrx_win_pct >= 35.0 and mrx_win_pct <= 60.0:
		print("\n[SUCCESS] Mr. X win rate (%.1f%%) is within the target 35–60%% range!" % mrx_win_pct)
		quit(0)
	else:
		print("\n[FAILURE] Mr. X win rate (%.1f%%) is outside the target 35–60%% range!" % mrx_win_pct)
		quit(1)

func _test_information_hiding(map_data: MapData) -> bool:
	var state := SYGameState.new(map_data, 4)
	var det_ai := DetectiveAI.new()

	# Simulate Round 1 Mr. X hidden move
	state.mrx_move_log.append({
		"round": 1,
		"ticket": "taxi",
		"station": 99,
		"revealed": false
	})

	# Test A: DetectiveAI must never access state.positions[0]
	# Erase position 0 completely from state
	state.positions.erase(0)
	assert(not state.positions.has(0), "Player 0 position should be absent")

	# Calling choose_move must not throw, fail, or query positions[0]
	var move1: Dictionary = det_ai.choose_move(1, state, map_data)
	if move1.is_empty():
		push_error("choose_move returned empty move when player 0 position absent!")
		return false
	print("  [PASS] Test A: DetectiveAI succeeds with state.positions[0] completely erased")

	# Test B: DetectiveAI must only rely on revealed positions from log, not real position
	# Place real Mr. X at a decoy position (station 1)
	state.positions[0] = 1

	# Place Detective 1 at a known station
	var det1_pos: int = state.positions[1]
	# Find a neighbor of Detective 1 to use as the revealed station
	var det1_links: Array = map_data.get_links_from(det1_pos)
	if det1_links.is_empty():
		return false
	var target_candidate: int = int(det1_links[0]["to"])

	# Append a reveal entry to the log claiming Mr. X revealed at target_candidate
	state.mrx_move_log.append({
		"round": 3,
		"ticket": "taxi",
		"station": target_candidate,
		"revealed": true
	})

	# Choose move for Detective 1
	var move2: Dictionary = det_ai.choose_move(1, state, map_data)
	# Detective 1 should move directly to target_candidate because it's a candidate station,
	# even though real state.positions[0] is station 1!
	if int(move2.get("to", 0)) != target_candidate:
		push_error("DetectiveAI did not move onto revealed candidate station! Moved to %s instead" % str(move2.get("to")))
		return false
	print("  [PASS] Test B: DetectiveAI acts on log/reveals, ignoring hidden state.positions[0]")

	return true
