@tool
class_name LastSeenMarker
extends Node2D

## LastSeenMarker — Visual indicator of Mr. X's last revealed position.

@onready var _sprite: Sprite2D = get_node_or_null("Sprite")
@onready var _label: Label = get_node_or_null("Label")
@onready var _anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")

func _ready() -> void:
	if _anim_player != null and _anim_player.has_animation("pulse"):
		_anim_player.play("pulse")

func show_at(pos: Vector2) -> void:
	global_position = pos
	visible = true
	if _anim_player != null and _anim_player.has_animation("pulse"):
		_anim_player.play("pulse")

func hide_marker() -> void:
	visible = false
	if _anim_player != null:
		_anim_player.stop()
