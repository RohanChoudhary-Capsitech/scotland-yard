class_name AIGaze
extends RefCounted

## AIGaze — Generates believable gaze behavior for AI Mr. X.
## Truth vs Bluff: 65% around his real area, 35% a bluff region.
## Nervousness: When a detective is within 2 steps, jumps between regions.
## Drifts between 2-3 points during a 1-2s planning time.
## Uses "Close Eyes" cards when in immediate danger.

var map_data: MapData
var state: SYGameState
var mrx_ai: MrXAI = null

var current_weights: Dictionary = {}
var gaze_waypoints: Array[Vector2] = []
const PLANNING_DURATION: float = 2.0
var planning_duration: float = PLANNING_DURATION
var is_eyes_closed: bool = false
var spotlight_radius: float = 280.0
var truth_rate: float = 0.75

func _init(p_map_data: MapData, p_state: SYGameState, p_mrx_ai: MrXAI = null) -> void:
	map_data = p_map_data
	state = p_state
	mrx_ai = p_mrx_ai

## Generates gaze waypoints and attention weights for Mr. X's turn
func generate_turn_gaze(rng: RandomNumberGenerator = null) -> Dictionary:
	current_weights.clear()
	gaze_waypoints.clear()
	is_eyes_closed = false

	if state == null or map_data == null:
		return {}

	# 1. Check danger & consider using "Close Eyes" card
	# Calculate minimum BFS distance from Mr. X to any detective
	var mrx_pos: int = state.positions.get(0, 0)
	var min_det_dist: int = 9999
	for d in range(1, state.detective_count + 1):
		var d_pos: int = state.positions.get(d, 0)
		var dist: int = map_data.bfs_distance(d_pos, mrx_pos)
		if dist >= 0 and dist < min_det_dist:
			min_det_dist = dist

	# When in critical danger (detective 1-2 steps away) and has cards remaining:
	if min_det_dist <= 2 and state.close_eyes_cards > 0:
		var roll: float = rng.randf() if rng != null else randf()
		if roll < 0.35:
			if state.use_close_eyes():
				is_eyes_closed = true
				return {}

	# 2. Fixed gaze duration of exactly 2.0s
	planning_duration = PLANNING_DURATION

	# 3. Truth vs Bluff Roll: truth_rate (default 65-70%) real area, remainder bluff region
	# ARCHITECTURE CONSTRAINT: Mr. X's real position is ONLY read here for the truth/bluff roll.
	var is_truth: bool = (rng.randf() if rng != null else randf()) < truth_rate
	var is_nervous: bool = (min_det_dist <= 2)

	var real_center_st: int = mrx_pos
	if mrx_ai != null:
		var planned_move: Dictionary = mrx_ai.choose_move(state, map_data)
		if not planned_move.is_empty():
			real_center_st = int(planned_move.get("to", mrx_pos))

	var bluff_center_st: int = _pick_bluff_station(mrx_pos, rng)
	var chosen_center_st: int = real_center_st if is_truth else bluff_center_st

	# 4. Generate 2-3 waypoints
	if is_nervous:
		# Nervous: jumps between regions (real and bluff glance)
		var p1: Vector2 = map_data.get_station_position(real_center_st)
		var n1: int = _get_neighbor_or_same(real_center_st, rng)
		var p2: Vector2 = map_data.get_station_position(n1)
		var p3: Vector2 = map_data.get_station_position(bluff_center_st)
		gaze_waypoints = [p1, p2, p3]
	else:
		# Drifts smoothly within the chosen region
		var p1: Vector2 = map_data.get_station_position(chosen_center_st)
		var n1: int = _get_neighbor_or_same(chosen_center_st, rng)
		var p2: Vector2 = map_data.get_station_position(n1)
		var n2: int = _get_neighbor_or_same(n1, rng)
		var p3: Vector2 = map_data.get_station_position(n2)
		gaze_waypoints = [p1, p2, p3]

	# 5. Compute attention weights based on gaze region
	var gaze_center: Vector2 = gaze_waypoints[0]
	for sid in map_data.stations:
		var spos: Vector2 = map_data.stations[sid]
		var d: float = spos.distance_to(gaze_center)
		if d <= spotlight_radius:
			var raw: float = 1.0 - (d / spotlight_radius)
			var jitter: float = (rng.randf_range(-0.03, 0.03) if rng != null else randf_range(-0.03, 0.03))
			current_weights[sid] = clampf(raw + jitter, 0.0, 1.0)

	return current_weights

func get_attention_weights() -> Dictionary:
	return current_weights

func get_waypoints() -> Array[Vector2]:
	return gaze_waypoints

func get_planning_duration() -> float:
	return planning_duration

func _pick_bluff_station(real_pos: int, rng: RandomNumberGenerator = null) -> int:
	var candidate_bluffs: Array[int] = []
	for sid in map_data.stations:
		var d: int = map_data.bfs_distance(real_pos, int(sid))
		if d >= 4:
			candidate_bluffs.append(int(sid))
	if candidate_bluffs.is_empty():
		return 1
	var idx: int = rng.randi_range(0, candidate_bluffs.size() - 1) if rng != null else randi() % candidate_bluffs.size()
	return candidate_bluffs[idx]

func _get_neighbor_or_same(st_id: int, rng: RandomNumberGenerator = null) -> int:
	var links := map_data.get_links_from(st_id)
	if links.is_empty():
		return st_id
	var idx: int = rng.randi_range(0, links.size() - 1) if rng != null else randi() % links.size()
	return int(links[idx].get("to", st_id))
