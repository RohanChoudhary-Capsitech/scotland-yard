@tool
class_name Station
extends Area2D

## Station — Interactive station on the Scotland Yard board.
## Displays station number, transit availability rings, and turn highlight.

signal clicked(station_id: int)

@export var id: int = 1:
	set = set_id

@export var has_taxi: bool = false:
	set = set_has_taxi

@export var has_bus: bool = false:
	set = set_has_bus

@export var has_underground: bool = false:
	set = set_has_underground

@onready var _base: Sprite2D = get_node_or_null("Base")
@onready var _taxi_ring: Sprite2D = get_node_or_null("TaxiRing")
@onready var _bus_ring: Sprite2D = get_node_or_null("BusRing")
@onready var _underground_ring: Sprite2D = get_node_or_null("UndergroundRing")
@onready var _highlight: Sprite2D = get_node_or_null("Highlight")
@onready var _anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var _label_number: Label = get_node_or_null("Number")

var _is_highlighted: bool = false

func _ready() -> void:
	input_pickable = true
	input_event.connect(_on_input_event)
	_update_view()

func set_id(val: int) -> void:
	id = val
	if _label_number != null:
		_label_number.text = str(id)

func set_has_taxi(val: bool) -> void:
	has_taxi = val
	if _taxi_ring != null:
		_taxi_ring.visible = has_taxi

func set_has_bus(val: bool) -> void:
	has_bus = val
	if _bus_ring != null:
		_bus_ring.visible = has_bus

func set_has_underground(val: bool) -> void:
	has_underground = val
	if _underground_ring != null:
		_underground_ring.visible = has_underground

func set_highlighted(on: bool) -> void:
	_is_highlighted = on
	if _highlight == null:
		_highlight = get_node_or_null("Highlight")
	if _anim_player == null:
		_anim_player = get_node_or_null("AnimationPlayer")

	if _highlight != null:
		_highlight.visible = on
	if _anim_player != null:
		if on:
			_anim_player.play("pulse")
		else:
			_anim_player.stop()

func is_highlighted() -> bool:
	return _is_highlighted

func _update_view() -> void:
	set_id(id)
	set_has_taxi(has_taxi)
	set_has_bus(has_bus)
	set_has_underground(has_underground)
	if _highlight != null:
		_highlight.visible = _is_highlighted

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			clicked.emit(id)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			clicked.emit(id)
