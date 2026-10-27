class_name BoardCameraController
extends CameraController

## BoardCameraController — Mobile-first pan & zoom camera for Scotland Yard.
## Features:
## - One-finger drag pan, two-finger pinch zoom (0.4x–2x), mouse drag + wheel.
## - Drag vs Tap discrimination: pan triggers after 10px; taps select stations safely.
## - Light inertia / fling with smooth friction decay.
## - Fit map to screen on start and on viewport size change.
## - Smooth pan_to_position() for human turn focus.
## - Map bounds clamping with margin.

@export var min_zoom: float = 0.4
@export var max_zoom: float = 2.0
## Zoom the camera moves to when a human player's turn starts.
@export var focus_zoom: float = 1.25
@export var zoom_step: float = 1.15
@export var map_bounds: Rect2 = Rect2(-100.0, -100.0, 2600.0, 2000.0)
## Area covered by the baked city background (BoardBuilder.CITY_AREA).
@export var visual_bounds: Rect2 = Rect2(-400.0, -400.0, 3200.0, 2600.0)

## Global / static drag tracking so Station clicks are safely suppressed during a pan
static var is_dragging: bool = false
static var drag_distance: float = 0.0

var _is_panning: bool = false
var _pan_start_screen: Vector2 = Vector2.ZERO
var _pan_velocity: Vector2 = Vector2.ZERO
var _recent_velocity: Vector2 = Vector2.ZERO
var _touch_points: Dictionary = {}  # index (int) -> position (Vector2)
var _last_touch_distance: float = 0.0
var _focus_tween: Tween = null

func _ready() -> void:
	super._ready()
	# Default center
	position = Vector2(1200.0, 900.0)
	zoom = Vector2(0.65, 0.65)

	# Connect viewport resize signal for responsive auto-fit
	if get_viewport() != null:
		get_viewport().size_changed.connect(_on_viewport_size_changed)

	fit_to_screen()
	_update_board_lod()

func _on_viewport_size_changed() -> void:
	_clamp_to_bounds()
	_update_board_lod()

## Auto-fits the map to the visible screen while respecting bounds and zoom limits
func fit_to_screen() -> void:
	if not is_inside_tree():
		return

	var vp_rect := get_viewport_rect()
	if vp_rect.size.x <= 0 or vp_rect.size.y <= 0:
		return

	var fit_x: float = vp_rect.size.x / 2400.0
	var fit_y: float = vp_rect.size.y / 1800.0
	# Fit the entire map comfortably on screen
	var target_zoom: float = clampf(maxf(fit_x, fit_y), min_zoom, max_zoom)
	zoom = Vector2(target_zoom, target_zoom)
	_clamp_to_bounds()
	_update_board_lod()

func _unhandled_input(event: InputEvent) -> void:
	# 1. Mouse Drag Panning (Left, Right, or Middle button)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.pressed:
				_start_pan(mb.position)
			else:
				_end_pan()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_towards_screen_pos(zoom.x * zoom_step, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_towards_screen_pos(zoom.x / zoom_step, mb.position)

	elif event is InputEventMouseMotion and _is_panning:
		var mm := event as InputEventMouseMotion
		_process_pan_motion(mm.relative, mm.position)

	# 2. Touch / Pinch Gestures
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touch_points[st.index] = st.position
			if _touch_points.size() == 1:
				_start_pan(st.position)
		else:
			_touch_points.erase(st.index)
			if _touch_points.is_empty():
				_end_pan()
			elif _touch_points.size() == 1:
				_last_touch_distance = 0.0
				var remaining_key: int = _touch_points.keys()[0]
				_start_pan(_touch_points[remaining_key])

	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touch_points[sd.index] = sd.position

		if _touch_points.size() == 1 and _is_panning:
			_process_pan_motion(sd.relative, sd.position)
		elif _touch_points.size() >= 2:
			# Two-finger pinch-zoom
			var keys: Array = _touch_points.keys()
			var p1: Vector2 = _touch_points[keys[0]]
			var p2: Vector2 = _touch_points[keys[1]]
			var cur_dist: float = p1.distance_to(p2)
			var center_screen: Vector2 = (p1 + p2) * 0.5

			if _last_touch_distance > 0.0 and cur_dist > 0.0:
				var factor: float = cur_dist / _last_touch_distance
				_zoom_towards_screen_pos(zoom.x * factor, center_screen)

			_last_touch_distance = cur_dist

func _start_pan(screen_pos: Vector2) -> void:
	_is_panning = true
	_pan_start_screen = screen_pos
	drag_distance = 0.0
	is_dragging = false
	_pan_velocity = Vector2.ZERO
	_recent_velocity = Vector2.ZERO
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()

func _process_pan_motion(relative: Vector2, current_screen_pos: Vector2) -> void:
	drag_distance += relative.length()
	if drag_distance >= 10.0:
		is_dragging = true

	if is_dragging:
		global_position -= relative / zoom.x
		_clamp_to_bounds()
		# Track motion velocity for fling
		_recent_velocity = -relative / zoom.x

func _end_pan() -> void:
	if is_dragging and _recent_velocity.length_squared() > 10.0:
		# Apply light inertia fling
		_pan_velocity = _recent_velocity * 18.0
		var max_fling: float = 2400.0
		if _pan_velocity.length() > max_fling:
			_pan_velocity = _pan_velocity.normalized() * max_fling

	_is_panning = false
	is_dragging = false
	_touch_points.clear()
	_last_touch_distance = 0.0

func _zoom_towards_screen_pos(new_zoom_factor: float, screen_pos: Vector2) -> void:
	var clamped_factor: float = clampf(new_zoom_factor, min_zoom, max_zoom)
	if is_equal_approx(zoom.x, clamped_factor):
		return

	var mouse_world_before: Vector2 = get_global_mouse_position()
	zoom = Vector2(clamped_factor, clamped_factor)
	var mouse_world_after: Vector2 = get_global_mouse_position()
	global_position += (mouse_world_before - mouse_world_after)
	_clamp_to_bounds()
	_update_board_lod()

func _update_board_lod() -> void:
	var board := get_node_or_null("../Board") as Board
	if board == null and get_parent() != null:
		board = get_parent().get_node_or_null("Board") as Board
	if board != null:
		board.set_zoom_lod(zoom.x)

## Smoothly pans to a target world position (used on human turn start & Focus button).
## With target_zoom > 0 it also zooms in to at least that level (never zooms out).
func pan_to_position(target_world_pos: Vector2, duration: float = 0.45, target_zoom: float = 0.0) -> void:
	_pan_velocity = Vector2.ZERO
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()

	var end_zoom: float = clampf(maxf(zoom.x, target_zoom), min_zoom, max_zoom)
	var start_zoom: Vector2 = zoom
	zoom = Vector2(end_zoom, end_zoom) # clamp the target at the final zoom
	var clamped_target := _clamped_center(target_world_pos)
	zoom = start_zoom

	_focus_tween = create_tween()
	_focus_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_focus_tween.tween_property(self, "global_position", clamped_target, duration)
	if not is_equal_approx(end_zoom, zoom.x):
		_focus_tween.parallel().tween_property(self, "zoom", Vector2(end_zoom, end_zoom), duration)
		_focus_tween.finished.connect(_update_board_lod)

func _clamp_to_bounds() -> void:
	_enforce_cover_zoom()
	global_position = _clamped_center(global_position)

## Zoom never goes so far out that the view shows past the baked city background.
func _enforce_cover_zoom() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var cover: float = maxf(vp.x / visual_bounds.size.x, vp.y / visual_bounds.size.y)
	if zoom.x < cover:
		zoom = Vector2(cover, cover)

## Clamps a camera centre to map_bounds, then keeps the whole view inside visual_bounds.
func _clamped_center(p: Vector2) -> Vector2:
	p.x = clampf(p.x, map_bounds.position.x, map_bounds.end.x)
	p.y = clampf(p.y, map_bounds.position.y, map_bounds.end.y)
	if not is_inside_tree():
		return p
	var vp := get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return p
	var half := vp / zoom * 0.5
	var lo := visual_bounds.position + half
	var hi := visual_bounds.end - half
	p.x = visual_bounds.get_center().x if lo.x > hi.x else clampf(p.x, lo.x, hi.x)
	p.y = visual_bounds.get_center().y if lo.y > hi.y else clampf(p.y, lo.y, hi.y)
	return p

func _process(delta: float) -> void:
	super._process(delta)

	# Apply fling inertia
	if not _is_panning and _pan_velocity.length_squared() > 10.0:
		global_position += _pan_velocity * delta
		_pan_velocity = _pan_velocity.move_toward(Vector2.ZERO, 1600.0 * delta)
		_clamp_to_bounds()
	elif not _is_panning:
		_pan_velocity = Vector2.ZERO
