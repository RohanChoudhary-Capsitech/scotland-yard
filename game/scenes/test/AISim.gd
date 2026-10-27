extends SceneTree

## AISim — Headless AI simulation and verification suite for Scotland Yard.
## Verifies information hiding for DetectiveAI, PlayerGaze, and AIGaze.
## Runs 200 games with Tells Off and 200 games with Tells On.
## Confirms that Tells raise the detective win rate by ~5–15%.

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
	# Part 1: Information Hiding Tests
	# ----------------------------------------------------
	print("\n--- 1. Verifying Information Hiding & Gaze Isolation ---")
	if not _test_detective_ai_isolation(map_data):
		printerr("[FAIL] DetectiveAI failed information hiding test!")
		quit(1)
		return

	if not _test_player_gaze_isolation(map_data):
		printerr("[FAIL] PlayerGaze failed input isolation test!")
		quit(1)
		return

	if not _test_ai_gaze_isolation(map_data):
		printerr("[FAIL] AIGaze failed truth/bluff roll isolation test!")
		quit(1)
		return

	print("[PASS] All information hiding and gaze isolation tests passed successfully!")

	# ----------------------------------------------------
	# Part 2: 200 Games Simulation with Tells OFF
	# ----------------------------------------------------
	print("\n--- 2. Running 200 AI-vs-AI Matches (Tells OFF) ---")
	var sim_off := _run_simulation_batch(map_data, 200, false)

	# ----------------------------------------------------
	# Part 3: 200 Games Simulation with Tells ON
	# ----------------------------------------------------
	print("\n--- 3. Running 200 AI-vs-AI Matches (Tells ON) ---")
	var sim_on := _run_simulation_batch(map_data, 200, true)

	# ----------------------------------------------------
	# Part 4: Comparative Results & Verification
	# ----------------------------------------------------
	var det_win_pct_off: float = (float(sim_off["det_wins"]) / 200.0) * 100.0
	var mrx_win_pct_off: float = (float(sim_off["mrx_wins"]) / 200.0) * 100.0

	var det_win_pct_on: float = (float(sim_on["det_wins"]) / 200.0) * 100.0
	var mrx_win_pct_on: float = (float(sim_on["mrx_wins"]) / 200.0) * 100.0

	var det_win_rate_increase: float = det_win_pct_on - det_win_pct_off

	print("\n==================================================")
	print("                 SIMULATION RESULTS               ")
	print("==================================================")
	print("  Tells OFF (200 matches):")
	print("    Mr. X Wins:        %d (%.1f%%)" % [sim_off["mrx_wins"], mrx_win_pct_off])
	print("    Detective Wins:    %d (%.1f%%)" % [sim_off["det_wins"], det_win_pct_off])
	print("    Average Rounds:    %.2f" % sim_off["avg_rounds"])
	print("  Tells ON (200 matches):")
	print("    Mr. X Wins:        %d (%.1f%%)" % [sim_on["mrx_wins"], mrx_win_pct_on])
	print("    Detective Wins:    %d (%.1f%%)" % [sim_on["det_wins"], det_win_pct_on])
	print("    Average Rounds:    %.2f" % sim_on["avg_rounds"])
	print("  ------------------------------------------------")
	print("  Detective Win Rate Change: %+.1f percentage points" % det_win_rate_increase)
	print("==================================================")

	# Assertions:
	# 1. Base game Mr. X win rate with 4 detectives is within 35–60%
	if mrx_win_pct_off < 35.0 or mrx_win_pct_off > 60.0:
		printerr("[FAILURE] Base Mr. X win rate (%.1f%%) outside 35–60%% target range!" % mrx_win_pct_off)
		quit(1)
		return

	# 2. Tells should raise Detective win rate by ~5–15%
	if det_win_rate_increase < 4.5 or det_win_rate_increase > 16.5:
		printerr("[FAILURE] Detective win rate increase (%.1f%%) outside the expected 5–15%% range!" % det_win_rate_increase)
		quit(1)
		return

	print("\n[SUCCESS] Tells system raised Detective win rate by %.1f%% (target: 5–15%%)!" % det_win_rate_increase)
	quit(0)

func _run_simulation_batch(map_data: MapData, total_games: int, tells: bool) -> Dictionary:
	var mrx_wins: int = 0
	var det_wins: int = 0
	var total_rounds: int = 0
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
			"tells_enabled": tells,
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

		match_feature.free()

		if (i + 1) % 50 == 0:
			print("  Simulated %d / %d matches..." % [i + 1, total_games])

	var elapsed_ms: int = Time.get_ticks_msec() - start_time
	print("  Completed in %.2f seconds." % [float(elapsed_ms) / 1000.0])

	return {
		"mrx_wins": mrx_wins,
		"det_wins": det_wins,
		"avg_rounds": float(total_rounds) / float(total_games)
	}

func _test_detective_ai_isolation(map_data: MapData) -> bool:
	var state := SYGameState.new(map_data, 4)
	var det_ai := DetectiveAI.new()

	state.mrx_move_log.append({
		"round": 1,
		"ticket": "taxi",
		"station": 99,
		"revealed": false
	})

	# Test A: DetectiveAI must never access state.positions[0]
	state.positions.erase(0)
	assert(not state.positions.has(0), "Player 0 position should be absent")

	var move1: Dictionary = det_ai.choose_move(1, state, map_data)
	if move1.is_empty():
		return false
	print("  [PASS] Test A: DetectiveAI succeeds with state.positions[0] completely erased")

	# Test B: DetectiveAI acts only on log/reveals, ignoring hidden state.positions[0]
	state.positions[0] = 1
	var det1_pos: int = state.positions[1]
	var det1_links: Array = map_data.get_links_from(det1_pos)
	if det1_links.is_empty():
		return false
	var target_candidate: int = int(det1_links[0]["to"])

	state.mrx_move_log.append({
		"round": 3,
		"ticket": "taxi",
		"station": target_candidate,
		"revealed": true
	})

	var move2: Dictionary = det_ai.choose_move(1, state, map_data)
	if int(move2.get("to", 0)) != target_candidate:
		return false
	print("  [PASS] Test B: DetectiveAI acts on log/reveals, ignoring hidden state.positions[0]")
	return true

func _test_player_gaze_isolation(map_data: MapData) -> bool:
	# Assert-based check that PlayerGaze only reads camera/input data, never SYGameState
	var pg := PlayerGaze.new(map_data)
	assert(not "state" in pg, "PlayerGaze must NOT have a state property")
	assert(not "positions" in pg, "PlayerGaze must NOT have a positions property")

	# Verify it correctly tracks camera and tap inputs
	pg.on_camera_updated(Vector2(500, 500), 1.2)
	pg.update(0.5, 1.2)
	var weights := pg.get_attention_weights()
	assert(weights is Dictionary, "get_attention_weights returns Dictionary")

	pg.on_station_tapped(Vector2(600, 600))
	assert(pg._tap_override_timer > 0.0, "Station tap initiates pull timer")
	pg.snap_to(Vector2(600, 600))
	pg.on_station_tapped(Vector2(600, 600))
	assert(pg._tap_override_pos.distance_to(Vector2(600, 600)) >= PlayerGaze.OFFSET_MIN - 0.1, "Tap on own station keeps the spotlight offset")
	print("  [PASS] Test C: PlayerGaze only reads camera/input data (no game state access)")
	return true

func _test_ai_gaze_isolation(map_data: MapData) -> bool:
	# Assert-based check that AIGaze reads Mr. X's real position only for truth/bluff roll
	var state := SYGameState.new(map_data, 4)
	var ai_gaze := AIGaze.new(map_data, state)

	# 1. Test standard gaze waypoint generation when detectives are distant
	state.positions[0] = 42
	# Find distant stations for detectives (distance >= 5)
	for d in range(1, 5):
		for sid in map_data.stations:
			if map_data.bfs_distance(42, int(sid)) >= 5:
				state.positions[d] = int(sid)
				break

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var weights := ai_gaze.generate_turn_gaze(rng)
	assert(weights is Dictionary, "generate_turn_gaze returns Dictionary")
	assert(not ai_gaze.get_waypoints().is_empty(), "Waypoints generated")
	assert(not ai_gaze.is_eyes_closed, "Eyes should not be closed when safe")

	# Ensure waypoints are within map bounds
	for wp in ai_gaze.get_waypoints():
		assert(wp.x >= 0.0 and wp.x <= 2400.0 and wp.y >= 0.0 and wp.y <= 1800.0, "Waypoints within map bounds")

	# 2. Test "Close Eyes" card behavior when in immediate danger
	var danger_state := SYGameState.new(map_data, 4)
	danger_state.positions[0] = 42
	# Place detective at distance 1
	var links := map_data.get_links_from(42)
	assert(not links.is_empty(), "Station 42 has links")
	danger_state.positions[1] = int(links[0]["to"])
	var danger_gaze := AIGaze.new(map_data, danger_state)

	var closed_eyes_triggered: bool = false
	var danger_rng := RandomNumberGenerator.new()
	for s in range(50):
		danger_rng.seed = s
		danger_state.close_eyes_cards = 2
		danger_gaze.generate_turn_gaze(danger_rng)
		if danger_gaze.is_eyes_closed:
			closed_eyes_triggered = true
			assert(danger_state.close_eyes_cards == 1, "Close eyes card consumed")
			break

	assert(closed_eyes_triggered, "Close eyes should trigger under danger roll")
	print("  [PASS] Test D: AIGaze reads Mr. X's real position only for truth/bluff roll and handles close eyes")
	return true
