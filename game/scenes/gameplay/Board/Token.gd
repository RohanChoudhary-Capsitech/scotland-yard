@tool
class_name Token
extends Node2D

## Token — Visual player piece for Mr. X or Detectives.
## Supports tweened movement along paths and idle animations ("bob", "pulse").

const COLORS: Dictionary = {
	0: Color("#212121"), # Mr. X (Dark Charcoal)
	1: Color("#E53935"), # Detective 1 (Red)
	2: Color("#1E88E5"), # Detective 2 (Blue)
	3: Color("#43A047"), # Detective 3 (Green)
	4: Color("#FB8C00"), # Detective 4 (Orange)
	5: Color("#8E24AA")  # Detective 5 (Purple)
}

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

	var col: Color = COLORS.get(player_id, Color.WHITE)
	if _disc != null:
		_disc.modulate = col
	if _label_x != null:
		_label_x.visible = (player_id == 0)

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
