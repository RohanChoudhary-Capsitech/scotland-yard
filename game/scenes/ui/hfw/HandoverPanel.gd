class_name HandoverPanel
extends UIController

## HandoverPanel — Full-screen opaque panel used during Pass-and-Play handovers.
## Ensures Mr. X's secret position and tokens are completely hidden while passing the device.
## Registered in GameConfig.UI_PANELS["handover"], pushed via UIManager.push_packed().

signal handed_over

@onready var _emblem: Panel = %Emblem
@onready var _emblem_icon: TextureRect = %EmblemIcon
@onready var _lbl_title: Label = %LblTitle
@onready var _lbl_subtitle: Label = %LblSubtitle
@onready var _btn_start: Button = %BtnStart

var _target_player_name: String = ""
var _is_mrx: bool = false

func _ready() -> void:
	super._ready()
	if not _initialized:
		_initialized = true
		_on_ready()

func _on_ready() -> void:
	super._on_ready()
	if _btn_start != null and not _btn_start.pressed.is_connected(_on_start_pressed):
		_btn_start.pressed.connect(_on_start_pressed)
	if not _target_player_name.is_empty():
		_refresh_ui()

func setup_handover(player_name: String, is_mrx: bool = false) -> void:
	_target_player_name = player_name
	_is_mrx = is_mrx
	_refresh_ui()

func _refresh_ui() -> void:
	if _btn_start != null and not _btn_start.pressed.is_connected(_on_start_pressed):
		_btn_start.pressed.connect(_on_start_pressed)

	if _emblem_icon != null:
		_emblem_icon.texture = Palette.icon("mask") if _is_mrx else Palette.icon("phone")
	if _emblem != null:
		var sb := (_emblem.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.bg_color = Palette.player(0) if _is_mrx else Palette.player(1)
		_emblem.add_theme_stylebox_override("panel", sb)

	if _lbl_title != null:
		_lbl_title.text = "Pass the phone to\n%s" % _target_player_name

	if _lbl_subtitle != null:
		if _is_mrx:
			_lbl_subtitle.text = "Keep the screen hidden from the detectives!"
			_lbl_subtitle.modulate = Palette.GOLD
		else:
			_lbl_subtitle.text = "Mr. X has moved. Coordinate your search!"
			_lbl_subtitle.modulate = Color(0.75, 0.87, 1.0)

	if _btn_start != null:
		_btn_start.text = "I'm %s, start my turn" % _target_player_name

func _on_start_pressed() -> void:
	handed_over.emit()
	close()

func close() -> void:
	if _ui_manager != null:
		_ui_manager.pop()
	else:
		queue_free()
