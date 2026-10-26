class_name MrXAI
extends RefCounted

## MrXAI — Autonomous AI decision maker for Mr. X in Scotland Yard.
## Uses only MapData and SYGameState data.

## Evaluates whether Mr. X should play a double-move card this turn.
func choose_double_move(state: SYGameState, map_data: MapData) -> bool:
	if state.game_over or state.current_player != 0 or state.double_move_phase != 0:
		return false
	if state.tickets[0].get("double", 0) <= 0:
		return false

	var total_transport: int = (
		state.tickets[0].get("taxi", 0)
		+ state.tickets[0].get("bus", 0)
		+ state.tickets[0].get("underground", 0)
		+ state.tickets[0].get("black", 0)
	)
	if total_transport < 2:
		return false

	var legal: Array[Dictionary] = state.legal_moves(0)
	if legal.is_empty():
		return false

	# Find the best single move's minimum distance to any detective
	var best_single_dist: int = 0
	for m in legal:
		var to_st: int = int(m["to"])
		var min_d: int = 9999
		for d in range(1, state.detective_count + 1):
			var d_pos: int = state.positions.get(d, 0)
			var dist: int = map_data.bfs_distance(to_st, d_pos)
			if dist >= 0 and dist < min_d:
				min_d = dist
		if min_d > best_single_dist:
			best_single_dist = min_d

	var cur_pos: int = state.positions.get(0, 0)
	var cur_min_dist: int = 9999
	for d in range(1, state.detective_count + 1):
		var d_pos: int = state.positions.get(d, 0)
		var dist: int = map_data.bfs_distance(cur_pos, d_pos)
		if dist >= 0 and dist < cur_min_dist:
			cur_min_dist = dist

	var right_after_reveal: bool = (state.round - 1) in SYGameState.REVEAL_ROUNDS

	# Trigger double move:
	# 1) When best single move still leaves a detective 1 step away (best_single_dist <= 1)
	# 2) Or right after a reveal when in danger (cur_min_dist <= 2)
	if best_single_dist <= 1:
		return true
	if right_after_reveal and cur_min_dist <= 2:
		return true

	return false

## Selects the optimal move for Mr. X among legal moves.
## Returns Dictionary {"to": int, "ticket": String}.
func choose_move(state: SYGameState, map_data: MapData) -> Dictionary:
	var legal: Array[Dictionary] = state.legal_moves(0)
	if legal.is_empty():
		return {}

	var cur_pos: int = state.positions.get(0, 0)
	var right_after_reveal: bool = (state.round - 1) in SYGameState.REVEAL_ROUNDS

	# Collect all stations that any detective can reach next turn
	var det_reachable: Dictionary = {}
	for d in range(1, state.detective_count + 1):
		var d_moves: Array[Dictionary] = state.legal_moves(d)
		for dm in d_moves:
			det_reachable[int(dm["to"])] = true

	# Avoid stations a detective can reach next turn if a safer move exists
	var safer_moves: Array[Dictionary] = []
	for m in legal:
		var to_st: int = int(m["to"])
		if not det_reachable.has(to_st):
			safer_moves.append(m)

	var candidate_moves: Array[Dictionary] = safer_moves if not safer_moves.is_empty() else legal

	# Score candidate moves
	var best_score: float = -999999.0
	var best_move: Dictionary = candidate_moves[0]

	for m in candidate_moves:
		var to_st: int = int(m["to"])
		var t_used: String = str(m["ticket"])

		# Minimum BFS distance to any detective
		var min_d: int = 9999
		for d in range(1, state.detective_count + 1):
			var d_pos: int = state.positions.get(d, 0)
			var dist: int = map_data.bfs_distance(to_st, d_pos)
			if dist >= 0 and dist < min_d:
				min_d = dist

		var exits: int = map_data.get_links_from(to_st).size()
		var score: float = float(min_d) * 10.0 + float(exits) * 0.1

		# Link properties between current position and target
		var is_ferry: bool = false
		var is_bus_or_underground: bool = false
		for link in map_data.get_links_from(cur_pos):
			if int(link.get("to", 0)) == to_st:
				var ltype: String = str(link.get("type", ""))
				if ltype == "ferry":
					is_ferry = true
				elif ltype == "bus" or ltype == "underground":
					is_bus_or_underground = true

		# Black ticket preferences:
		# - Prefer black on ferry (bonus +3.0)
		# - Black ticket after a reveal round (bonus +2.0)
		# - Black ticket on bus/underground moves (bonus +1.5)
		# - Discourage wasting black ticket on normal taxi when not after reveal (-5.0)
		if t_used == "black":
			if is_ferry:
				score += 3.0
			elif right_after_reveal:
				score += 2.0
			elif is_bus_or_underground:
				score += 1.5
			else:
				score -= 5.0

		if score > best_score:
			best_score = score
			best_move = m

	return best_move
