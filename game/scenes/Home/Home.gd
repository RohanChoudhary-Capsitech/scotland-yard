class_name HomeScene
extends UIController

## HomeScene — Main Menu for Scotland Yard.
## Allows selecting game mode ("Play as Detectives" or "Play as Mr. X")
## and detective count (3–5, default 4).

@onready var _btn_detectives: Button = %BtnPlayDetectives
@onready var _btn_mrx: Button = %BtnPlayMrX
@onready var _btn_det_3: Button = %BtnDet3
@onready var _btn_det_4: Button = %BtnDet4
@onready var _btn_det_5: Button = %BtnDet5

var _logger: Node
var _scene: SceneManager
var _save: SaveManager
var _selected_detective_count: int = 4

func inject_services(registry: Node) -> void:
	if not registry:
		return
	super.inject_services(registry)
	_logger = registry.get_service(&"logger") as Node
	_scene = registry.get_service(&"scene") as SceneManager
	_save = registry.get_service(&"save") as SaveManager

func _on_ready() -> void:
	if _logger:
		_logger.info("Scotland Yard HomeScene loaded.")

	if _save != null:
		_selected_detective_count = int(_save.get_value("detective_count", 4))

	_update_detective_buttons()

	if _btn_det_3:
		_btn_det_3.pressed.connect(func(): _set_detective_count(3))
	if _btn_det_4:
		_btn_det_4.pressed.connect(func(): _set_detective_count(4))
	if _btn_det_5:
		_btn_det_5.pressed.connect(func(): _set_detective_count(5))

	if _btn_detectives:
		_btn_detectives.pressed.connect(_on_play_detectives_pressed)
	if _btn_mrx:
		_btn_mrx.pressed.connect(_on_play_mrx_pressed)

func _set_detective_count(count: int) -> void:
	_selected_detective_count = count
	if _save != null:
		_save.set_value("detective_count", _selected_detective_count)
		_save.save_game()
	_update_detective_buttons()

func _update_detective_buttons() -> void:
	if _btn_det_3:
		_btn_det_3.disabled = (_selected_detective_count == 3)
	if _btn_det_4:
		_btn_det_4.disabled = (_selected_detective_count == 4)
	if _btn_det_5:
		_btn_det_5.disabled = (_selected_detective_count == 5)

func _on_play_detectives_pressed() -> void:
	if _save != null:
		_save.set_value("match_mode", "detectives")
		_save.set_value("detective_count", _selected_detective_count)
		_save.save_game()

	if _scene != null:
		_scene.go_to("res://game/scenes/gameplay/Match.tscn")

func _on_play_mrx_pressed() -> void:
	if _save != null:
		_save.set_value("match_mode", "mrx")
		_save.set_value("detective_count", _selected_detective_count)
		_save.save_game()

	if _scene != null:
		_scene.go_to("res://game/scenes/gameplay/Match.tscn")
