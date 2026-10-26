class_name BoardCameraController
extends CameraController

## BoardCameraController — Specialized pan & zoom camera for the Scotland Yard board.
## Supports right/middle mouse drag pan, mouse wheel zoom, touch pinch/drag, and map bounds clamping.
## Preserves CameraController's CPU-idle behaviour (set_process(false) when idle).

@export var min_zoom: float = 0.4
@export var max_zoom: float = 2.0
@export var zoom_step: float = 1.15
@export var map_bounds: Rect2 = Rect2(-100.0, -100.0, 2600.0, 2000.0)

var _is_panning: bool = false
var _touch_points: Dictionary = {}  # index (int) -> position (Vector2)
var _last_touch_distance: float = 0.0

func _ready() -> void:
	super._ready()
	# Center camera on map by default (2400x1800 map center is 1200, 900)
	position = Vector2(1200.0, 900.0)
	zoom = Vector2(0.65, 0.65)
	_clamp_to_bounds()

func _unhandled_input(event: InputEvent) -> void:
	# 1. Mouse Drag Panning (Right or Middle button)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_towards_screen_pos(zoom.x * zoom_step, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_towards_screen_pos(zoom.x / zoom_step, mb.position)

	elif event is InputEventMouseMotion and _is_panning:
		var mm := event as InputEventMouseMotion
		global_position -= mm.relative / zoom.x
		_clamp_to_bounds()

	# 2. Touch / Pinch Gestures
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touch_points[st.index] = st.position
		else:
			_touch_points.erase(st.index)
			if _touch_points.size() < 2:
				_last_touch_distance = 0.0

	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touch_points[sd.index] = sd.position

		if _touch_points.size() == 1:
			# Single-finger pan
			global_position -= sd.relative / zoom.x
			_clamp_to_bounds()
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

func _zoom_towards_screen_pos(new_zoom_factor: float, screen_pos: Vector2) -> void:
	var clamped_factor: float = clampf(new_zoom_factor, min_zoom, max_zoom)
	if is_equal_approx(zoom.x, clamped_factor):
		return

	# Calculate mouse world position before zoom
	var mouse_world_before: Vector2 = get_global_mouse_position()

	zoom = Vector2(clamped_factor, clamped_factor)

	# Calculate mouse world position after zoom
	var mouse_world_after: Vector2 = get_global_mouse_position()

	# Adjust position so world position under cursor remains unchanged
	global_position += (mouse_world_before - mouse_world_after)
	_clamp_to_bounds()

func _clamp_to_bounds() -> void:
	global_position.x = clampf(global_position.x, map_bounds.position.x, map_bounds.end.x)
	global_position.y = clampf(global_position.y, map_bounds.position.y, map_bounds.end.y)

func _process(delta: float) -> void:
	super._process(delta)
	if _target != null or _shake_time > 0.0:
		_clamp_to_bounds()
