@tool
class_name Token
extends Node2D

## Token — Visual player piece for Mr. X or Detectives.
## Supports tweened movement along paths and idle animations ("bob", "pulse").

@export var player_id: int = 0:
	set = set_player_id

@onready var _disc: Sprite2D = get_node_or_null("Disc")
@onready var _border: Sprite2D = get_node_or_null("Border")
@onready var _label_x: Label = get_node_or_null("LabelX")
@onready var _anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")

var _active_tween: Tween

func _ready() -> void:
	_apply_style()

func set_player_id(val: int) -> void:
	player_id = val
	_apply_style()

func _apply_style() -> void:
	if _disc == null:
		_disc = get_node_or_null("Disc")
	if _border == null:
		_border = get_node_or_null("Border")
	if _label_x == null:
		_label_x = get_node_or_null("LabelX")

	var col: Color = Palette.player(player_id) if player_id > 0 else Color("#1F1B2E")
	if _disc != null:
		_disc.modulate = col
	if _label_x != null:
		_label_x.visible = false
	var icon := get_node_or_null("Icon") as Sprite2D
	if icon != null:
		icon.texture = Palette.player_icon(player_id)
		icon.modulate = Palette.player(0).lightened(0.35) if player_id == 0 else Color.WHITE

## Smoothly moves the token along a sequence of points using a Tween.
func move_along(points: Array[Vector2], duration_per_hop: float = 0.35) -> Tween:
	if points.is_empty():
		return null

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUAD)
	_active_tween.set_ease(Tween.EASE_IN_OUT)

	for pt in points:
		_active_tween.tween_property(self, "position", pt, duration_per_hop)

	return _active_tween

func play_anim(anim_name: String) -> void:
	if _anim_player == null:
		_anim_player = get_node_or_null("AnimationPlayer")
	if _anim_player != null and _anim_player.has_animation(anim_name):
		_anim_player.play(anim_name)

func stop_anim() -> void:
	if _anim_player == null:
		_anim_player = get_node_or_null("AnimationPlayer")
	if _anim_player != null:
		_anim_player.stop()
