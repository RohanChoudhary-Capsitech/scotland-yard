@tool
class_name Link
extends Line2D

## Link — overlay for one transit connection between two stations.
## The streets themselves are baked into the city background, so:
## - taxi / bus links stay hidden until shown as a route preview for the player's legal moves
## - underground links are pink dashed metro lines with a soft white casing
## - ferry links are white dotted routes curving along the river

const COLOR_TAXI := Color("#F5C542")
const COLOR_BUS := Color("#3BC48A")
const COLOR_UNDERGROUND := Color("#E8457A")
const COLOR_FERRY := Color(1.0, 1.0, 1.0, 0.95)
const COLOR_CASING := Color(1.0, 1.0, 1.0, 0.55)

const METRO_DASH_PATH := "res://game/assets/sprites/single/shared/metro_dash.png"
const FERRY_DASH_PATH := "res://game/assets/sprites/single/shared/ferry_dash.png"

@export_enum("taxi", "bus", "underground", "ferry") var type: String = "taxi":
	set = set_type

var _route_on: bool = false
var is_active_link: bool = true

func set_active_link(active: bool) -> void:
	is_active_link = active
	if not active:
		_route_on = false
		visible = false
		if _casing != null:
			_casing.visible = false
	else:
		_apply_style()

@onready var _casing: Line2D = get_node_or_null("InnerRoad")
@onready var _centre_line: Line2D = get_node_or_null("CentreLine")

func _ensure_children() -> void:
	if _casing == null:
		_casing = get_node_or_null("InnerRoad") as Line2D
	if _centre_line == null:
		_centre_line = get_node_or_null("CentreLine") as Line2D

func _ready() -> void:
	_apply_style()

func set_type(val: String) -> void:
	type = val
	_apply_style()

func set_endpoints(a_pos: Vector2, b_pos: Vector2) -> void:
	points = PackedVector2Array([a_pos, b_pos])
	_sync_children()

func _sync_children() -> void:
	_ensure_children()
	if _casing != null:
		_casing.points = points
	if _centre_line != null:
		_centre_line.points = points

## Shows or hides this link as part of the current player's route preview.
func set_route_highlight(on: bool, color: Color = Color.TRANSPARENT) -> void:
	if not is_active_link and on:
		return
	_route_on = on
	_apply_style()
	if on:
		visible = true
		texture = null
		texture_mode = Line2D.LINE_TEXTURE_NONE
		width = 7.0
		default_color = color if color.a > 0.0 else _type_color()
		if _casing != null:
			_casing.visible = true
			_casing.show_behind_parent = true
			_casing.width = 12.0
			_casing.default_color = Color(1, 1, 1, 0.9)

func is_route_highlighted() -> bool:
	return _route_on

func _type_color() -> Color:
	match type:
		"bus": return COLOR_BUS
		"underground": return COLOR_UNDERGROUND
		"ferry": return COLOR_FERRY
	return COLOR_TAXI

func _apply_style() -> void:
	_ensure_children()
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	_sync_children()
	if _centre_line != null:
		_centre_line.visible = false
	if _casing != null:
		_casing.visible = false
		_casing.show_behind_parent = true
		_casing.joint_mode = Line2D.LINE_JOINT_ROUND
		_casing.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_casing.end_cap_mode = Line2D.LINE_CAP_ROUND
	texture = null
	texture_mode = Line2D.LINE_TEXTURE_NONE

	match type:
		"underground":
			visible = true
			width = 5.0
			default_color = Color(COLOR_UNDERGROUND, 0.92)
			_dash(METRO_DASH_PATH)
			if _casing != null:
				_casing.visible = true
				_casing.width = 9.0
				_casing.default_color = COLOR_CASING
		"ferry":
			visible = true
			width = 4.0
			default_color = COLOR_FERRY
			_dash(FERRY_DASH_PATH)
		_:
			# Taxi and bus streets are part of the baked city; overlay only for route preview.
			visible = false
			width = 7.0
			default_color = _type_color()

func _dash(path: String) -> void:
	if ResourceLoader.exists(path):
		texture = load(path)
		texture_mode = Line2D.LINE_TEXTURE_TILE
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
