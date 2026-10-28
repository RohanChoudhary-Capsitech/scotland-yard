extends SceneTree

## tools/simulate_levels.gd
## Simulates AI matches on "neighbourhood" and "district" levels.
## Measures Mr. X win rate and average rounds to ensure 40–60% target balance.
## Run with:
##   godot --headless -s tools/simulate_levels.gd

func _init() -> void:
	print("\n==================================================")
	print("       RUNNING LEVEL BALANCE SIMULATIONS          ")
	print("==================================================")

	var levels_to_test: Array[String] = ["neighbourhood", "district"]
	var matches_per_level: int = 200

	var results: Dictionary = {}

	for lvl in levels_to_test:
		print("\n--- Simulating %s (%d matches) ---" % [lvl.to_upper(), matches_per_level])
		var res: Dictionary = _simulate_level(lvl, matches_per_level)
		results[lvl] = res
		var mrx_pct: float = (float(res["mrx_wins"]) / float(matches_per_level)) * 100.0
		var det_pct: float = (float(res["det_wins"]) / float(matches_per_level)) * 100.0
		print("  Results for %s:" % lvl.capitalize())
		print("    Mr. X Wins:      %d (%.1f%%)" % [res["mrx_wins"], mrx_pct])
		print("    Detective Wins:  %d (%.1f%%)" % [res["det_wins"], det_pct])
		print("    Average Rounds:  %.2f" % res["avg_rounds"])
		if mrx_pct >= 40.0 and mrx_pct <= 60.0:
			print("    [PASS] Mr. X win rate %.1f%% is within 40-60%% range!" % mrx_pct)
		else:
			print("    [WARN] Mr. X win rate %.1f%% is OUTSIDE 40-60%% range!" % mrx_pct)

	print("\n==================================================")
	print("                  FINAL SUMMARY                   ")
	print("==================================================")
	var all_pass := true
	for lvl in levels_to_test:
		var r: Dictionary = results[lvl]
		var pct: float = (float(r["mrx_wins"]) / float(matches_per_level)) * 100.0
		print("  %s: Mr. X win rate = %.1f%%" % [lvl.capitalize(), pct])
		if pct < 40.0 or pct > 60.0:
			all_pass = false

	if all_pass:
		print("\n[ALL PASSED] Both levels balanced within 40–60% Mr. X win rate!")
		quit(0)
	else:
		print("\n[NEEDS TUNING] Adjust ticket counts in levels.json.")
		quit(1)

func _simulate_level(level_id: String, total_games: int) -> Dictionary:
	var mrx_wins: int = 0
	var det_wins: int = 0
	var total_rounds: int = 0
	var start_time: int = Time.get_ticks_msec()

	for i in range(total_games):
		seed(1000 + i * 29)

		var mf := MatchFeature.new()
		mf.initialize({
			"level": level_id,
			"mode": "ai_vs_ai",
			"auto_play_ai": false,
			"tells_enabled": false
		})
		mf.start()

		var max_turn_guard := 500
		while not mf.state.game_over and max_turn_guard > 0:
			mf.play_ai_turn()
			max_turn_guard -= 1

		var st: SYGameState = mf.state
		total_rounds += st.round
		if st.winner == "mrx":
			mrx_wins += 1
		else:
			det_wins += 1
		if i < 5:
			print("    Game %d: winner=%s, round=%d, reason=%s" % [i, st.winner, st.round, st.reason])

		mf.free()

		if (i + 1) % 50 == 0:
			print("  Simulated %d / %d matches..." % [i + 1, total_games])

	var elapsed_ms: int = Time.get_ticks_msec() - start_time
	return {
		"mrx_wins": mrx_wins,
		"det_wins": det_wins,
		"avg_rounds": float(total_rounds) / float(total_games),
		"elapsed_sec": float(elapsed_ms) / 1000.0
	}
