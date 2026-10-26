class_name SYGameState
extends RefCounted

## SYGameState — Pure data representation of Scotland Yard board game state.
## Implements all game rules defined in docs/RULES.md. Contains no scene nodes.

const REVEAL_ROUNDS: Array[int] = [3, 8, 13, 18, 24]
const MAX_ROUNDS: int = 24

var map_data: MapData

var positions: Dictionary = {}         # player_index (int) -> station_id (int)
var tickets: Dictionary = {}           # player_index (int) -> { ticket_type (String) -> count (int) }
var round: int = 1                     # 1..24
var current_player: int = 0            # 0 = Mr. X, 1..detective_count = Detectives
var detective_count: int = 4           # 3..5
var double_move_phase: int = 0         # 0 = normal, 1 = first move made in double move, 2 = second move made
var mrx_move_log: Array[Dictionary] = [] # [{ "round": int, "ticket": String, "station": int, "revealed": bool }]
var last_revealed_position: int = 0
var last_skipped_detectives: Array[int] = [] # Detectives skipped in the last transition

var game_over: bool = false
var winner: String = ""                # "detectives" or "mrx"
var reason: String = ""

func _init(p_map_data: MapData = null, p_detective_count: int = 4, p_start_stations: Array[int] = []) -> void:
	if p_map_data != null:
		setup_new_game(p_map_data, p_detective_count, p_start_stations)

func setup_new_game(p_map_data: MapData, p_detective_count: int = 4, p_start_stations: Array[int] = []) -> void:
	map_data = p_map_data
	detective_count = clampi(p_detective_count, 3, 5)
	round = 1
	current_player = 0
	double_move_phase = 0
	mrx_move_log.clear()
	last_revealed_position = 0
	last_skipped_detectives.clear()
	game_over = false
	winner = ""
	reason = ""

	# 1. Setup Tickets
	# Mr. X: 4 taxi, 3 bus, 3 underground, black = detective_count, 2 double-move cards
	tickets[0] = {
		"taxi": 4,
		"bus": 3,
		"underground": 3,
		"black": detective_count,
		"double": 2,
	}

	# Detectives: 10 taxi, 8 bus, 4 underground
	for d in range(1, detective_count + 1):
		tickets[d] = {
			"taxi": 10,
			"bus": 8,
			"underground": 4,
			"black": 0,
			"double": 0,
		}

	# 2. Setup Starting Stations
	# Distinct starting stations picked from 18 start stations
	var available_starts: Array[int] = []
	if not p_start_stations.is_empty():
		available_starts = p_start_stations.duplicate()
	else:
		available_starts = map_data.get_start_stations()
		available_starts.shuffle()

	# Assign Mr. X (0) and Detectives (1..detective_count)
	for i in range(detective_count + 1):
		if i < available_starts.size():
			positions[i] = available_starts[i]
		else:
			positions[i] = i + 1

func is_reveal_round(r: int) -> bool:
	return r in REVEAL_ROUNDS

## Returns all legal moves for player as Array[Dictionary] of {"to": int, "ticket": String}.
func legal_moves(player: int) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	if game_over or map_data == null:
		return moves

	var cur_station: int = positions.get(player, 0)
	if cur_station == 0:
		return moves

	# Blocked stations: stations occupied by any other detective
	var blocked_stations: Dictionary = {}
	for d in range(1, detective_count + 1):
		if d != player:
			blocked_stations[positions.get(d, 0)] = true

	# Mr. X also cannot move onto any detective's station
	if player == 0:
		for d in range(1, detective_count + 1):
			blocked_stations[positions.get(d, 0)] = true

	var p_tickets: Dictionary = tickets.get(player, {})
	var links: Array = map_data.get_links_from(cur_station)

	for link in links:
		var to_station: int = link.get("to", 0)
		var l_type: String = link.get("type", "taxi")

		# Cannot move to a blocked station
		if blocked_stations.has(to_station):
			continue

		if player > 0:
			# Detective: cannot use ferry (no black tickets)
			if l_type == "ferry":
				continue
			if p_tickets.get(l_type, 0) > 0:
				var m := {"to": to_station, "ticket": l_type}
				if not moves.has(m):
					moves.append(m)
		else:
			# Mr. X:
			if l_type == "ferry":
				# Ferry can ONLY be used with black ticket
				if p_tickets.get("black", 0) > 0:
					var m := {"to": to_station, "ticket": "black"}
					if not moves.has(m):
						moves.append(m)
			else:
				# Normal transport matching ticket
				if p_tickets.get(l_type, 0) > 0:
					var m := {"to": to_station, "ticket": l_type}
					if not moves.has(m):
						moves.append(m)
				# Black ticket can be used for any transport
				if p_tickets.get("black", 0) > 0:
					var m_black := {"to": to_station, "ticket": "black"}
					if not moves.has(m_black):
						moves.append(m_black)

	return moves

## Activates a double-move card for Mr. X.
func use_double_move() -> bool:
	if game_over or current_player != 0 or double_move_phase != 0:
		return false
	if tickets[0].get("double", 0) <= 0:
		return false

	var transport_tickets: int = (
		tickets[0].get("taxi", 0)
		+ tickets[0].get("bus", 0)
		+ tickets[0].get("underground", 0)
		+ tickets[0].get("black", 0)
	)
	if transport_tickets < 2:
		return false

	tickets[0]["double"] -= 1
	double_move_phase = 1
	return true

## Applies a move for player to `to` station using `ticket`.
## Returns true if the move was successfully made, false otherwise.
func apply_move(player: int, to: int, ticket: String) -> bool:
	if game_over or player != current_player:
		return false

	var valid_moves := legal_moves(player)
	var move_to_apply := {"to": to, "ticket": ticket}
	if not valid_moves.has(move_to_apply):
		return false

	last_skipped_detectives.clear()

	# 1. Deduct Ticket
	tickets[player][ticket] -= 1

	# 2. Detective tickets are surrendered to Mr. X
	if player > 0:
		tickets[0][ticket] += 1

	# 3. Update Position
	positions[player] = to

	# 4. Check Detective Catching Mr. X
	if player > 0:
		if positions[player] == positions[0]:
			game_over = true
			winner = "detectives"
			reason = "Detective %d caught Mr. X at station %d" % [player, to]
			return true

		# Advance to next detective
		_advance_detective_turn()
		return true

	# 5. Mr. X Move Logic
	var is_revealed: bool = is_reveal_round(round)
	mrx_move_log.append({
		"round": round,
		"ticket": ticket,
		"station": to,
		"revealed": is_revealed,
	})
	if is_revealed:
		last_revealed_position = to

	if double_move_phase == 1:
		# First step of double move completed; advance round and prompt second step
		double_move_phase = 2
		round += 1
		current_player = 0
		if legal_moves(0).is_empty():
			game_over = true
			winner = "detectives"
			reason = "Mr. X has no legal moves on second double-move step"
		return true
	elif double_move_phase == 2:
		# Second step of double move completed; transition to detectives
		double_move_phase = 0
		_start_detectives_turn()
		return true
	else:
		# Normal Mr. X move completed; transition to detectives
		_start_detectives_turn()
		return true

func _start_detectives_turn() -> void:
	current_player = 1
	_skip_stuck_detectives()
	if current_player > detective_count:
		_finish_round_detectives()

func _advance_detective_turn() -> void:
	current_player += 1
	_skip_stuck_detectives()
	if current_player > detective_count:
		_finish_round_detectives()

func _skip_stuck_detectives() -> void:
	while current_player <= detective_count and not game_over:
		if legal_moves(current_player).is_empty():
			last_skipped_detectives.append(current_player)
			current_player += 1
		else:
			break

func _finish_round_detectives() -> void:
	# All detectives have completed their turns (or were skipped)
	# Check if ALL detectives were unable to move
	var any_detective_moved := false
	for d in range(1, detective_count + 1):
		if d not in last_skipped_detectives:
			any_detective_moved = true
			break

	# Check if all detectives are currently unable to move
	var any_can_move := false
	for d in range(1, detective_count + 1):
		if not legal_moves(d).is_empty():
			any_can_move = true
			break

	if not any_can_move:
		game_over = true
		winner = "mrx"
		reason = "No detective can move"
		return

	# Check round limit: Mr. X survives 24 rounds
	if round >= MAX_ROUNDS:
		game_over = true
		winner = "mrx"
		reason = "Mr. X survived 24 rounds"
		return

	# Advance to next round for Mr. X
	round += 1
	current_player = 0

	# Check if Mr. X has legal moves
	if legal_moves(0).is_empty():
		game_over = true
		winner = "detectives"
		reason = "Mr. X has no legal moves"

## Checks win conditions explicitly.
func check_win() -> void:
	if game_over:
		return

	# 1. Did any detective catch Mr. X?
	var mrx_pos: int = positions.get(0, -1)
	for d in range(1, detective_count + 1):
		if positions.get(d, -1) == mrx_pos:
			game_over = true
			winner = "detectives"
			reason = "Detective %d caught Mr. X at station %d" % [d, mrx_pos]
			return

	# 2. If it's Mr. X's turn, can he move?
	if current_player == 0 and legal_moves(0).is_empty():
		game_over = true
		winner = "detectives"
		reason = "Mr. X has no legal moves"
		return

	# 3. Can any detective move?
	var any_can_move := false
	for d in range(1, detective_count + 1):
		if not legal_moves(d).is_empty():
			any_can_move = true
			break
	if not any_can_move:
		game_over = true
		winner = "mrx"
		reason = "No detective can move"
		return

	# 4. Has Mr. X survived all 24 rounds?
	if round > MAX_ROUNDS:
		game_over = true
		winner = "mrx"
		reason = "Mr. X survived 24 rounds"
		return

## Returns a deep clone of the current state.
func duplicate() -> SYGameState:
	var copy := SYGameState.new()
	copy.map_data = map_data
	copy.detective_count = detective_count
	copy.round = round
	copy.current_player = current_player
	copy.double_move_phase = double_move_phase
	copy.last_revealed_position = last_revealed_position
	copy.game_over = game_over
	copy.winner = winner
	copy.reason = reason
	copy.positions = positions.duplicate()
	copy.last_skipped_detectives = last_skipped_detectives.duplicate()

	copy.tickets = {}
	for p in tickets:
		copy.tickets[p] = tickets[p].duplicate()

	copy.mrx_move_log = []
	for entry in mrx_move_log:
		copy.mrx_move_log.append(entry.duplicate())

	return copy
