class_name PlayerGaze
extends RefCounted

## PlayerGaze — Tracks human Mr. X's gaze via camera view centre, zoom, station taps, and mouse.
## Strict privacy rule: Does NOT access SYGameState secret data; only receives camera and input events.

var map_data: MapData

var dwell_times: Dictionary = {}         # station_id (int) -> float
var current_gaze_pos: Vector2 = Vector2.ZERO
var _target_gaze_pos: Vector2 = Vector2.ZERO
var _tap_override_pos: Vector2 = Vector2.ZERO
var _tap_override_timer: float = 0.0
var _is_eyes_closed: bool = false
var spotlight_radius: float = 670.0
## Per-turn shift of the spotlight away from the camera centre, so it never sits exactly on Mr. X
var gaze_offset: Vector2 = Vector2.ZERO
const OFFSET_MIN := 220.0
const OFFSET_MAX := 380.0

# Recording path for Pass-and-Play glance replay
var recorded_path: Array[Dictionary] = [] # [{ "pos": Vector2, "time": float }]
var _is_recording: bool = false
var _elapsed_record_time: float = 0.0
var _record_sample_interval: float = 0.05
var _record_sample_timer: float = 0.0

func _init(p_map_data: MapData = null) -> void:
	map_data = p_map_data

## Resets or decays dwell times at the start of a new round
func decay_for_new_round(decay_rate: float = 0.35) -> void:
	for s in dwell_times.keys():
		dwell_times[s] = float(dwell_times[s]) * decay_rate
		if dwell_times[s] < 0.05:
			dwell_times.erase(s)

func reset() -> void:
	dwell_times.clear()
	_tap_override_timer = 0.0
	_is_eyes_closed = false
	clear_recorded_path()

func set_eyes_closed(closed: bool) -> void:
	_is_eyes_closed = closed
	if closed:
		clear_recorded_path()

func is_eyes_closed() -> bool:
	return _is_eyes_closed

func start_recording() -> void:
	recorded_path.clear()
	_is_recording = true
	_elapsed_record_time = 0.0
	_record_sample_timer = 0.0
	if current_gaze_pos != Vector2.ZERO and not _is_eyes_closed:
		recorded_path.append({"pos": current_gaze_pos, "time": 0.0})

func stop_recording() -> void:
	_is_recording = false

func clear_recorded_path() -> void:
	recorded_path.clear()
	_is_recording = false

func get_recorded_path() -> Array[Dictionary]:
	return recorded_path

## Jumps the gaze straight to a point (start of turn), with no drift from the old spot
## Also picks a fresh random offset for this turn.
func snap_to(pos: Vector2) -> void:
	gaze_offset = Vector2.from_angle(randf() * TAU) * randf_range(OFFSET_MIN, OFFSET_MAX)
	current_gaze_pos = pos + gaze_offset
	_target_gaze_pos = current_gaze_pos
	_tap_override_timer = 0.0

## Updates gaze position based on camera position and zoom
func on_camera_updated(cam_center: Vector2, _zoom_factor: float = 1.0) -> void:
	if _tap_override_timer <= 0.0:
		_target_gaze_pos = cam_center + gaze_offset

## Tapping a station pulls gaze towards it for ~0.8s
## (keeps the turn's offset, so tapping his own station never lights it up exactly)
func on_station_tapped(station_pos: Vector2) -> void:
	_tap_override_pos = station_pos + gaze_offset
	_tap_override_timer = 0.8
	_target_gaze_pos = _tap_override_pos

## Desktop mouse movement gently nudges gaze
func on_mouse_moved(world_mouse_pos: Vector2) -> void:
	if _tap_override_timer <= 0.0:
		_target_gaze_pos = _target_gaze_pos.lerp(world_mouse_pos, 0.4)

## Per-frame update accumulating dwell time per station
func update(delta: float, zoom_factor: float = 1.0) -> void:
	if _is_eyes_closed or map_data == null:
		return

	if _tap_override_timer > 0.0:
		_tap_override_timer -= delta
		current_gaze_pos = current_gaze_pos.lerp(_tap_override_pos, 1.0 - exp(-delta * 5.0))
	else:
		current_gaze_pos = current_gaze_pos.lerp(_target_gaze_pos, 1.0 - exp(-delta * 3.0))

	# Zooming in counts as stronger attention (e.g. zoom 1.0 -> 1.0x, zoom 1.5 -> 1.5x)
	var attention_mult: float = maxf(0.5, zoom_factor)

	# Record sample if recording is active
	if _is_recording:
		_elapsed_record_time += delta
		_record_sample_timer += delta
		if _record_sample_timer >= _record_sample_interval:
			_record_sample_timer = 0.0
			if current_gaze_pos != Vector2.ZERO:
				recorded_path.append({"pos": current_gaze_pos, "time": _elapsed_record_time})

	# Accumulate dwell time for all stations inside the spotlight
	for sid in map_data.stations:
		var spos: Vector2 = map_data.stations[sid]
		var dist: float = spos.distance_to(current_gaze_pos)
		if dist <= spotlight_radius:
			var falloff: float = (1.0 - (dist / spotlight_radius))
			var gain: float = delta * falloff * attention_mult
			dwell_times[sid] = dwell_times.get(sid, 0.0) + gain

## Returns normalized, noisy, and capped attention weights {station_id: 0.0..1.0}
func get_attention_weights() -> Dictionary:
	if _is_eyes_closed or dwell_times.is_empty():
		return {}

	var max_val: float = 0.0
	for sid in dwell_times:
		var v: float = float(dwell_times[sid])
		if v > max_val:
			max_val = v

	if max_val <= 0.001:
		return {}

	var weights: Dictionary = {}
	for sid in dwell_times:
		var raw: float = float(dwell_times[sid]) / max_val
		# Add subtle noise (+/- 0.04) and clamp
		var noisy: float = raw + randf_range(-0.04, 0.04)
		weights[sid] = clampf(noisy, 0.0, 1.0)

	return weights
