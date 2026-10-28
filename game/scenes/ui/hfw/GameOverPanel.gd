class_name GameOverPanel
extends UIController

## GameOverPanel — Victory/defeat popup displayed when the match concludes.
## Registered in GameConfig.UI_PANELS["game_over"], pushed via UIManager.push_packed().
## Options: Play Again (re-opens Match) and Main Menu (goes Home). Calls GameManager.reset() first.

@onready var _emblem: Panel = %Emblem
@onready var _emblem_icon: TextureRect = %EmblemIcon
@onready var _modal: PanelContainer = %ModalPanel
@onready var _lbl_winner: Label = %LblWinner
@onready var _lbl_reason: Label = %LblReason
@onready var _lbl_route: Label = get_node_or_null("%LblRoute") as Label
@onready var _btn_play_again: Button = %BtnPlayAgain
@onready var _btn_next_lesson: Button = get_node_or_null("%BtnNextLesson") as Button
@onready var _btn_home: Button = %BtnHome

var _scene: SceneManager
var _save: SaveManager

func _on_ready() -> void:
	super._on_ready()

	if get_tree() != null and get_tree().root != null:
		var registry: Node = get_tree().root.get_node_or_null("ServiceRegistry")
		if registry != null and registry.has_method("get_service"):
			_scene = registry.get_service(&"scene") as SceneManager
			_save = registry.get_service(&"save") as SaveManager

	if _btn_play_again != null:
		_btn_play_again.pressed.connect(_on_play_again_pressed)
	if _btn_next_lesson != null:
		_btn_next_lesson.pressed.connect(_on_next_lesson_pressed)
	if _btn_home != null:
		_btn_home.pressed.connect(_on_home_pressed)
	_play_entrance()

## Modal pops in, emblem bounces.
func _play_entrance() -> void:
	if _modal == null or not is_inside_tree():
		return
	_modal.pivot_offset = _modal.size * 0.5
	_modal.scale = Vector2(0.86, 0.86)
	_modal.modulate.a = 0.0
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_modal, "scale", Vector2.ONE, 0.35)
	t.parallel().tween_property(_modal, "modulate:a", 1.0, 0.2)
	if _emblem != null:
		_emblem.pivot_offset = _emblem.custom_minimum_size * 0.5
		_emblem.scale = Vector2(0.3, 0.3)
		t.tween_property(_emblem, "scale", Vector2.ONE, 0.4)

func set_result(winner: String, reason: String, route: Array = []) -> void:
	if _lbl_winner != null:
		var col: Color
		if winner == "detectives":
			_lbl_winner.text = "DETECTIVES WIN!"
			col = Color("#3BC48A")
			if _emblem_icon != null:
				_emblem_icon.texture = Palette.icon("trophy")
		else:
			_lbl_winner.text = "MR. X WINS!"
			col = Palette.player(0)
			if _emblem_icon != null:
				_emblem_icon.texture = Palette.icon("mask")
		_lbl_winner.modulate = col.lightened(0.15)
		if _emblem != null:
			var sb := (_emblem.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
			sb.bg_color = col
			sb.shadow_color = Color(col, 0.5)
			_emblem.add_theme_stylebox_override("panel", sb)

	if _lbl_reason != null:
		_lbl_reason.text = reason

	var tut_lesson: int = _save.get_tutorial_lesson() if _save != null else 0
	if tut_lesson == 1:
		if _btn_next_lesson != null:
			_btn_next_lesson.visible = true
			_btn_next_lesson.text = "Next: Play as Mr. X"
		if _btn_play_again != null:
			_btn_play_again.visible = false
		if _lbl_winner != null:
			_lbl_winner.text = "YOU CAUGHT MR. X!"
	elif tut_lesson == 2:
		if _btn_next_lesson != null:
			_btn_next_lesson.visible = false
		if _btn_play_again != null:
			_btn_play_again.visible = true
			_btn_play_again.text = "Play Neighbourhood"
		if _lbl_winner != null:
			_lbl_winner.text = "TUTORIAL COMPLETE!"
		if _save != null:
			_save.set_tutorial_completed(true)
			_save.set_selected_level("neighbourhood")

	if _lbl_route != null:
		if not route.is_empty():
			var parts: Array[String] = []
			for st in route:
				parts.append(str(st))
			_lbl_route.text = " → ".join(parts)
		else:
			_lbl_route.text = "—"

func _on_next_lesson_pressed() -> void:
	if get_tree() != null:
		get_tree().paused = false
	if _game_manager != null:
		_game_manager.reset()
	close()

	if _save != null:
		_save.set_tutorial_lesson(2)
		_save.set_selected_level("tutorial")
		_save.set_value("detective_count", 2)
		_save.set_value("seats", [
			{"id": 0, "name": "Mr. X", "type": "human", "is_human": true},
			{"id": 1, "name": "Detective 1", "type": "ai", "is_human": false},
			{"id": 2, "name": "Detective 2", "type": "ai", "is_human": false}
		])
		_save.save_game()

	if _scene != null:
		_scene.go_to("res://game/scenes/gameplay/Match.tscn")
	else:
		get_tree().change_scene_to_file("res://game/scenes/gameplay/Match.tscn")

func _on_play_again_pressed() -> void:
	if get_tree() != null:
		get_tree().paused = false
	if _game_manager != null:
		_game_manager.reset()
	close()

	if _scene != null:
		_scene.go_to("res://game/scenes/gameplay/Match.tscn")
	else:
		get_tree().change_scene_to_file("res://game/scenes/gameplay/Match.tscn")

func _on_home_pressed() -> void:
	if get_tree() != null:
		get_tree().paused = false
	if _game_manager != null:
		_game_manager.reset()
	close()

	if _scene != null:
		_scene.go_to("res://game/scenes/Home/Home.tscn")
	else:
		get_tree().change_scene_to_file("res://game/scenes/Home/Home.tscn")
