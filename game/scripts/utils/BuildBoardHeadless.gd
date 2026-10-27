extends SceneTree

## Headless entry point: godot --headless --path . -s res://game/scripts/utils/BuildBoardHeadless.gd

func _initialize() -> void:
	var ok := BoardBuilder.build_board_scene()
	quit(0 if ok else 1)
