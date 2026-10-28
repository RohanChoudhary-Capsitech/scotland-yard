@tool
class_name Station
extends Area2D

## Station — Interactive station on the Scotland Yard board.
## Restyled as an illustrated map pin anchored at its bottom tip.
## Preserves existing node names (Base, TaxiRing, BusRing, UndergroundRing, Highlight, Number).
## Highlight performs a bounce + glow animation on the pin.

signal clicked(station_id: int)

@export var id: int = 1:
	set = set_id

@export var has_taxi: bool = false:
	set = set_has_taxi

@export var has_bus: bool = false:
	set = set_has_bus

@export var has_underground: bool = false:
	set = set_has_underground

@export var has_ferry: bool = false:
	set = set_has_ferry

@onready var _base: Sprite2D = get_node_or_null("Base")
@onready var _taxi_ring: Sprite2D = get_node_or_null("Base/TaxiRing")
@onready var _bus_ring: Sprite2D = get_node_or_null("Base/BusRing")
@onready var _underground_ring: Sprite2D = get_node_or_null("Base/UndergroundRing")
@onready var _highlight: Sprite2D = get_node_or_null("Highlight")
@onready var _anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var _label_number: Label = get_node_or_null("Number")
@onready var _metro_entrance: Sprite2D = get_node_or_null("MetroEntrance")
@onready var _dock: Sprite2D = get_node_or_null("Dock")

var _is_highlighted: bool = false
var _press_screen_pos: Vector2 = Vector2.ZERO
var _is_touch_pressed: bool = false
var is_active_station: bool = true

func set_active_station(active: bool) -> void:
	is_active_station = active
	visible = active
	input_pickable = active
	if not active:
		_is_touch_pressed = false
		set_highlighted(false)

func _ensure_nodes() -> void:
	if _base == null:
		_base = get_node_or_null("Base") as Sprite2D
	if _taxi_ring == null:
		_taxi_ring = get_node_or_null("Base/TaxiRing") as Sprite2D
	if _bus_ring == null:
		_bus_ring = get_node_or_null("Base/BusRing") as Sprite2D
	if _underground_ring == null:
		_underground_ring = get_node_or_null("Base/UndergroundRing") as Sprite2D
	if _highlight == null:
		_highlight = get_node_or_null("Highlight") as Sprite2D
	if _anim_player == null:
		_anim_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if _label_number == null:
		_label_number = get_node_or_null("Number") as Label
	if _metro_entrance == null:
		_metro_entrance = get_node_or_null("MetroEntrance") as Sprite2D
	if _dock == null:
		_dock = get_node_or_null("Dock") as Sprite2D

func _ready() -> void:
	_ensure_nodes()
	input_pickable = true
	input_event.connect(_on_input_event)
	_update_view()

func set_id(val: int) -> void:
	id = val
	_ensure_nodes()
	if _label_number != null:
		_label_number.text = str(id)

func set_has_taxi(val: bool) -> void:
	has_taxi = val
	_ensure_nodes()
	if _taxi_ring != null:
		_taxi_ring.visible = has_taxi

func set_has_bus(val: bool) -> void:
	has_bus = val
	_ensure_nodes()
	if _bus_ring != null:
		_bus_ring.visible = has_bus

func set_has_underground(val: bool) -> void:
	has_underground = val
	_ensure_nodes()
	if _underground_ring != null:
		_underground_ring.visible = has_underground
	if _metro_entrance != null:
		_metro_entrance.visible = has_underground

func set_has_ferry(val: bool) -> void:
	has_ferry = val
	_ensure_nodes()
	if _dock != null:
		_dock.visible = has_ferry

func set_highlighted(on: bool) -> void:
	_is_highlighted = on
	_ensure_nodes()

	if _highlight != null:
		_highlight.visible = on

	if _anim_player != null:
		if on:
			_anim_player.play("pulse")
		else:
			_anim_player.stop()
			_reset_pin_position()

func _reset_pin_position() -> void:
	if _base != null:
		_base.position = Vector2.ZERO
	if _label_number != null:
		_label_number.position = Vector2(-16, -33)
	if _highlight != null:
		_highlight.position = Vector2.ZERO
		_highlight.scale = Vector2(0.5, 0.5)
		_highlight.modulate.a = 0.8

func is_highlighted() -> bool:
	return _is_highlighted

func _update_view() -> void:
	set_id(id)
	set_has_taxi(has_taxi)
	set_has_bus(has_bus)
	set_has_underground(has_underground)
	set_has_ferry(has_ferry)
	if _highlight != null:
		_highlight.visible = _is_highlighted
	if not _is_highlighted:
		_reset_pin_position()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not is_active_station:
		return
	# Safe Tap vs Pan: Only emit clicked if touch moved < 10px and camera is not dragging
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_touch_pressed = true
			_press_screen_pos = event.position
		else:
			if _is_touch_pressed:
				_is_touch_pressed = false
				var moved: float = event.position.distance_to(_press_screen_pos)
				if moved < 10.0 and not BoardCameraController.is_dragging:
					clicked.emit(id)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_is_touch_pressed = true
			_press_screen_pos = event.position
		else:
			if _is_touch_pressed:
				_is_touch_pressed = false
				var moved: float = event.position.distance_to(_press_screen_pos)
				if moved < 10.0 and not BoardCameraController.is_dragging:
					clicked.emit(id)
