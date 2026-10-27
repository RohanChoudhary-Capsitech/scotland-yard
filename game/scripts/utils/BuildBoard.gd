@tool
extends EditorScript

## BuildBoard — editor entry point for BoardBuilder.
## Run in Godot Editor via: Script Editor -> File -> Run (Ctrl+Shift+X).

func _run() -> void:
	BoardBuilder.build_board_scene()
