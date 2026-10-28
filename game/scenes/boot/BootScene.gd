class_name BootScene
extends Node

## BootScene — Entry point bootstrap scene
## Initializes core services and transitions to Home.

@export var next_scene_path: String = "res://game/scenes/Home/Home.tscn"
@onready var services: Node = $GameService

func _ready() -> void:
	if services and services.logger:
		services.logger.info("Bootstrap sequence started...")
	
	# Transition to initial game scene / Home
	_transition_to_game()

func _transition_to_game() -> void:
	var save: SaveManager = services.save if services else null
	if save != null and not save.is_tutorial_completed():
		save.set_tutorial_lesson(1)
		save.set_selected_level("tutorial")
		save.set_value("detective_count", 2)
		save.set_value("seats", [
			{"id": 0, "name": "Mr. X", "type": "ai", "is_human": false},
			{"id": 1, "name": "Detective 1", "type": "human", "is_human": true},
			{"id": 2, "name": "Detective 2", "type": "ai", "is_human": false}
		])
		save.save_game()
		if services and services.scene and ResourceLoader.exists("res://game/scenes/gameplay/Match.tscn"):
			services.scene.go_to("res://game/scenes/gameplay/Match.tscn")
			return

	if services and services.scene and ResourceLoader.exists(next_scene_path):
		services.scene.go_to(next_scene_path)
	elif services and services.logger:
		services.logger.info("Bootstrap complete. Ready for gameplay scenes.")
