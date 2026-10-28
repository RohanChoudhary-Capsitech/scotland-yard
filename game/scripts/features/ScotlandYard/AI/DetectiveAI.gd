class_name DetectiveAI
extends RefCounted

## DetectiveAI — Autonomous AI decision maker for detectives in Scotland Yard.
## Uses only MapData and SYGameState data.
## Strictly follows information hiding: NEVER reads Mr. X's secret position.

var candidates: Dictionary = {}         # station_id (int) -> true
var _last_processed_log_count: int = 0
var gaze_weights: Dictionary = {}       # station_id (int) -> weight (float 0..1)
var tells_enabled: bool = false
var priority_mult: float = 1.0
var easy_mode: bool = false

func reset() -> void:
	candidates.clear()
	_last_processed_log_count = 0
	gaze_weights.clear()

func set_gaze_weights(weights: Dictionary, enabled: bool = true) -> void:
	gaze_weights = weights
	tells_enabled = enabled

## Updates possible candidate stations using Mr. X's move log and reveal events.
## MUST NEVER read state.positions[0] or unrevealed station entries.
func update_candidates(state: SYGameState, map_data: MapData) -> void:
	if state.mrx_move_log.size() < _last_processed_log_count:
		reset()

	while _last_processed_log_count < state.mrx_move_log.size():
		var entry: Dictionary = state.mrx_move_log[_last_processed_log_count]
		_last_processed_log_count += 1

		var is_revealed: bool = bool(entry.get("revealed", false))
		var ticket: String = str(entry.get("ticket", "taxi"))

		if is_revealed:
			# Reset candidates to the single revealed station
			candidates.clear()
			var rev_st: int = int(entry.get("station", 0))
			if rev_st > 0:
				candidates[rev_st] = true
		else:
			if candidates.is_empty():
				# Before first reveal round, candidates are untracked
				pass
			else:
				# Expand candidates based on the transport ticket used by Mr. X
				var next_candidates: Dictionary = {}
				for c in candidates.keys():
					var c_id: int = int(c)
					for link in map_data.get_links_from(c_id):
						var to_st: int = int(link.get("to", 0))
						var ltype: String = str(link.get("type", ""))
						# Black ticket covers any transport type (including ferry)
						if ticket == "black" or ltype == ticket:
							next_candidates[to_st] = true
				candidates = next_candidates

	# Prune stations currently occupied by detectives (never check player 0)
	for d in range(1, state.detective_count + 1):
		var d_pos: int = state.positions.get(d, 0)
		candidates.erase(d_pos)

## Selects the optimal move for detective_id.
## Returns Dictionary {"to": int, "ticket": String}.
func choose_move(detective_id: int, state: SYGameState, map_data: MapData) -> Dictionary:
	var d_moves: Array[Dictionary] = state.legal_moves(detective_id)
	if d_moves.is_empty():
		return {}

	if easy_mode and randf() < 0.65:
		return d_moves[randi() % d_moves.size()]

	update_candidates(state, map_data)

	var cur_pos: int = state.positions.get(detective_id, 0)

	# 1. Take any move onto a candidate station
	var win_moves: Array[Dictionary] = []
	for m in d_moves:
		var to_st: int = int(m["to"])
		if candidates.has(to_st):
			win_moves.append(m)

	if not win_moves.is_empty():
		# Pick win move with highest candidate priority, tie-break by exits
		var best_win_m: Dictionary = win_moves[0]
		var best_p: float = -1.0
		var max_exits: int = -1
		for m in win_moves:
			var to_st: int = int(m["to"])
			var p: float = (1.0 + priority_mult * float(gaze_weights.get(to_st, 0.0))) if tells_enabled else 1.0
			var exits: int = map_data.get_links_from(to_st).size()
			if p > best_p or (abs(p - best_p) < 0.001 and exits > max_exits):
				best_p = p
				max_exits = exits
				best_win_m = m
		candidates.erase(int(best_win_m["to"]))
		return best_win_m

	# 2. Before the first reveal, head for underground stations near the centre
	var has_revealed_yet: bool = false
	for entry in state.mrx_move_log:
		if entry.get("revealed", false):
			has_revealed_yet = true
			break

	if not has_revealed_yet:
		var central_ugs: Array[int] = map_data.get_central_underground_stations()
		var ug_index: int = (detective_id - 1) % central_ugs.size()
		var target_ug: int = central_ugs[ug_index]

		var best_score: float = 999999.0
		var best_m: Dictionary = d_moves[0]
		for m in d_moves:
			var to_st: int = int(m["to"])
			var d: int = map_data.bfs_distance(to_st, target_ug)
			var exits: int = map_data.get_links_from(to_st).size()
			var sc: float = float(d) * 10.0 - float(exits) * 0.1
			if sc < best_score:
				best_score = sc
				best_m = m
		return best_m

	# 3. After reveal: split candidate stations by nearest detective taking priority into account
	var assigned_cands: Array[int] = []
	for c in candidates.keys():
		var c_id: int = int(c)
		var p: float = (1.0 + priority_mult * float(gaze_weights.get(c_id, 0.0))) if tells_enabled else 1.0
		var closest_det: int = -1
		var min_det_dist: float = 9999.0
		for d in range(1, state.detective_count + 1):
			var d_pos: int = state.positions.get(d, 0)
			var dist: int = map_data.bfs_distance(d_pos, c_id)
			if dist >= 0:
				var eff_dist: float = float(dist) / p
				if eff_dist < min_det_dist:
					min_det_dist = eff_dist
					closest_det = d
		if closest_det == detective_id:
			assigned_cands.append(c_id)

	var target_pool: Array[int] = []
	if not assigned_cands.is_empty():
		target_pool = assigned_cands.duplicate()
	else:
		for c in candidates.keys():
			target_pool.append(int(c))

	if not target_pool.is_empty():
		# Move towards the closest prioritized candidate in target_pool
		# With Tells On: multiply candidate priority by (1 + priority_mult * weight)
		var target_c: int = target_pool[0]
		var best_cand_score: float = 9999.0
		for c in target_pool:
			var d: int = map_data.bfs_distance(cur_pos, c)
			if d >= 0:
				var priority: float = (1.0 + priority_mult * float(gaze_weights.get(c, 0.0))) if tells_enabled else 1.0
				var eff_d: float = float(d) / priority
				if eff_d < best_cand_score:
					best_cand_score = eff_d
					target_c = c

		var best_score: float = 999999.0
		var best_m: Dictionary = d_moves[0]
		for m in d_moves:
			var to_st: int = int(m["to"])
			var target_p: float = (1.0 + priority_mult * float(gaze_weights.get(target_c, 0.0))) if tells_enabled else 1.0
			var d_eff: float = float(map_data.bfs_distance(to_st, target_c)) / target_p

			var min_dist_to_any_candidate: float = 9999.0
			for c in target_pool:
				var cd: int = map_data.bfs_distance(to_st, c)
				if cd >= 0:
					var p: float = (1.0 + priority_mult * float(gaze_weights.get(c, 0.0))) if tells_enabled else 1.0
					var eff_cd: float = float(cd) / p
					if eff_cd < min_dist_to_any_candidate:
						min_dist_to_any_candidate = eff_cd

			var exits: int = map_data.get_links_from(to_st).size()
			var sc: float = d_eff * 10.0 + min_dist_to_any_candidate * 5.0 - float(exits) * 0.1
			if sc < best_score:
				best_score = sc
				best_m = m
		return best_m

	return d_moves[0]
