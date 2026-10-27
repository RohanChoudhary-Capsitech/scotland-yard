class_name HowToPlayPanel
extends UIController

## HowToPlayPanel — rules summary with icons. Registered in GameConfig.UI_PANELS["how_to_play"],
## opened from the Home menu and the pause menu via UIManager.push_packed().

@onready var _btn_close: Button = %BtnClose
@onready var _btn_got_it: Button = %BtnGotIt
@onready var _modal: PanelContainer = %ModalPanel

func _ready() -> void:
	super._ready()
	process_mode = Node.PROCESS_MODE_ALWAYS # usable from the pause menu
	if not _initialized:
		_initialized = true
		_on_ready()

func _on_ready() -> void:
	super._on_ready()
	if _btn_close != null and not _btn_close.pressed.is_connected(close):
		_btn_close.pressed.connect(close)
	if _btn_got_it != null and not _btn_got_it.pressed.is_connected(close):
		_btn_got_it.pressed.connect(close)
	if _modal != null and is_inside_tree():
		_modal.modulate.a = 0.0
		create_tween().tween_property(_modal, "modulate:a", 1.0, 0.18)

func close() -> void:
	if _ui_manager != null:
		_ui_manager.pop()
	else:
		queue_free()
