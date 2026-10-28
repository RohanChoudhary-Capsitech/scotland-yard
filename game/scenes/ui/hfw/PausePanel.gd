class_name PausePanel
extends UIController

## PausePanel — Resume / How to play / Main menu. Pauses the tree through GameManager while open.
## Registered in GameConfig.UI_PANELS["pause"], opened by Match on GameBus.pause_requested.

@onready var _btn_resume: Button = %BtnResume
@onready var _btn_rules: Button = %BtnRules
@onready var _btn_replay_tutorial: Button = get_node_or_null("%BtnReplayTutorial") as Button
@onready var _btn_quit: Button = %BtnQuit

func _ready() -> void:
	super._ready()
	process_mode = Node.PROCESS_MODE_ALWAYS # keeps buttons working while the tree is paused
	if not _initialized:
		_initialized = true
		_on_ready()

func _on_ready() -> void:
	super._on_ready()
	if _game_manager != null:
		_game_manager.pause()
	if _btn_resume != null and not _btn_resume.pressed.is_connected(_on_resume):
		_btn_resume.pressed.connect(_on_resume)
	if _btn_rules != null and not _btn_rules.pressed.is_connected(_on_rules):
		_btn_rules.pressed.connect(_on_rules)
	if _btn_replay_tutorial != null and not _btn_replay_tutorial.pressed.is_connected(_on_replay_tutorial):
		_btn_replay_tutorial.pressed.connect(_on_replay_tutorial)
	if _btn_quit != null and not _btn_quit.pressed.is_connected(_on_quit):
		_btn_quit.pressed.connect(_on_quit)

func _on_resume() -> void:
	if _game_manager != null:
		_game_manager.resume()
	close()

func _on_rules() -> void:
	var path: String = GameConfig.UI_PANELS.get("how_to_play", "")
	if _ui_manager != null and not path.is_empty():
		_ui_manager.push_packed(load(path))

func _on_replay_tutorial() -> void:
	if _game_manager != null:
		_game_manager.resume()
		_game_manager.reset()
	if get_tree() != null:
		get_tree().paused = false
	close()

	var registry: Node = get_tree().root.get_node_or_null("ServiceRegistry") if get_tree() != null and get_tree().root != null else null
	var save: SaveManager = registry.get_service(&"save") as SaveManager if registry != null and registry.has_method("get_service") else null
	if save != null:
		save.set_tutorial_lesson(1)
		save.set_selected_level("tutorial")
		save.set_value("detective_count", 2)
		save.set_value("seats", [
			{"id": 0, "name": "Mr. X", "type": "ai", "is_human": false},
			{"id": 1, "name": "Detective 1", "type": "human", "is_human": true},
			{"id": 2, "name": "Detective 2", "type": "ai", "is_human": false}
		])
		save.save_game()

	var scene: SceneManager = registry.get_service(&"scene") as SceneManager if registry != null and registry.has_method("get_service") else null
	if scene != null:
		scene.go_to("res://game/scenes/gameplay/Match.tscn")
	elif get_tree() != null:
		get_tree().change_scene_to_file("res://game/scenes/gameplay/Match.tscn")

func _on_quit() -> void:
	if _game_manager != null:
		_game_manager.resume() # must unpause before leaving gameplay
		_game_manager.reset()
	if get_tree() != null:
		get_tree().paused = false
	close()
	var registry: Node = get_tree().root.get_node_or_null("ServiceRegistry") if get_tree() != null and get_tree().root != null else null
	var scene: SceneManager = registry.get_service(&"scene") as SceneManager if registry != null and registry.has_method("get_service") else null
	if scene != null:
		scene.go_to("res://game/scenes/Home/Home.tscn")
	elif get_tree() != null:
		get_tree().change_scene_to_file("res://game/scenes/Home/Home.tscn")

func close() -> void:
	if _ui_manager != null:
		_ui_manager.pop()
	else:
		queue_free()
