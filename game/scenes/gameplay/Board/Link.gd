@tool
class_name Link
extends Line2D

## Link — Visual transit link between stations on the Scotland Yard board.
## Automatically configures width, colour, and texture based on transport type.

const COLOR_TAXI := Color("#F5C542")
const COLOR_BUS := Color("#3BC48A")
const COLOR_UNDERGROUND := Color("#E8457A")
const COLOR_FERRY := Color("#4A90E2")

const FERRY_TEXTURE_PATH := "res://game/assets/sprites/single/shared/ferry_dash.png"

@export_enum("taxi", "bus", "underground", "ferry") var type: String = "taxi":
	set = set_type

func _ready() -> void:
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	_apply_style()

func set_type(val: String) -> void:
	type = val
	_apply_style()

func set_endpoints(a_pos: Vector2, b_pos: Vector2) -> void:
	points = PackedVector2Array([a_pos, b_pos])

func _apply_style() -> void:
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND

	match type:
		"taxi":
			width = 3.0
			default_color = COLOR_TAXI
			texture = null
			texture_mode = Line2D.LINE_TEXTURE_NONE
		"bus":
			width = 5.0
			default_color = COLOR_BUS
			texture = null
			texture_mode = Line2D.LINE_TEXTURE_NONE
		"underground":
			width = 7.0
			default_color = COLOR_UNDERGROUND
			texture = null
			texture_mode = Line2D.LINE_TEXTURE_NONE
		"ferry":
			width = 4.0
			default_color = COLOR_FERRY
			if ResourceLoader.exists(FERRY_TEXTURE_PATH):
				texture = load(FERRY_TEXTURE_PATH)
			texture_mode = Line2D.LINE_TEXTURE_TILE
			texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_:
			width = 3.0
			default_color = COLOR_TAXI
			texture = null
			texture_mode = Line2D.LINE_TEXTURE_NONE
