class_name TicketPicker
extends UIController

## TicketPicker — Bottom popup allowing players to select their transport ticket
## when multiple transit links connect to the tapped station.
## Includes large touch-friendly buttons and Mr. X's Double Move toggle.

signal ticket_chosen(ticket: String, use_double_move: bool)
signal picker_cancelled
signal close_eyes_requested

@onready var _panel: PanelContainer = %Panel
@onready var _lbl_title: Label = %LblTitle
@onready var _btn_taxi: Button = %BtnTaxi
@onready var _btn_bus: Button = %BtnBus
@onready var _btn_ug: Button = %BtnUnderground
@onready var _btn_black: Button = %BtnBlack
@onready var _chk_double_move: CheckBox = %ChkDoubleMove
@onready var _btn_close_eyes: Button = %BtnCloseEyes
@onready var _btn_cancel: Button = %BtnCancel

var btn_black: Button:
	get: return _btn_black

var chk_double_move: CheckBox:
	get: return _chk_double_move

var btn_taxi: Button:
	get: return _btn_taxi

var btn_bus: Button:
	get: return _btn_bus

var _target_station: int = 0
var _anim_tween: Tween = null

func _ready() -> void:
	super._ready()
	if not _initialized:
		_initialized = true
		_on_ready()

func _on_ready() -> void:
	super._on_ready()
	visible = false

	if _btn_taxi != null:
		_btn_taxi.pressed.connect(_on_ticket_pressed.bind("taxi"))
	if _btn_bus != null:
		_btn_bus.pressed.connect(_on_ticket_pressed.bind("bus"))
	if _btn_ug != null:
		_btn_ug.pressed.connect(_on_ticket_pressed.bind("underground"))
	if _btn_black != null:
		_btn_black.pressed.connect(_on_ticket_pressed.bind("black"))
	if _btn_close_eyes != null:
		_btn_close_eyes.pressed.connect(_on_close_eyes_pressed)
	if _btn_cancel != null:
		_btn_cancel.pressed.connect(cancel_picker)

func open_picker(target_station: int, legal_tickets: Array[String], is_mrx: bool, can_double_move: bool, close_eyes_cards: int = 0) -> void:
	_target_station = target_station

	if _lbl_title != null:
		_lbl_title.text = "Travel to Station %d" % target_station

	if _btn_taxi != null:
		_btn_taxi.visible = legal_tickets.has("taxi")
	if _btn_bus != null:
		_btn_bus.visible = legal_tickets.has("bus")
	if _btn_ug != null:
		_btn_ug.visible = legal_tickets.has("underground")
	if _btn_black != null:
		_btn_black.visible = legal_tickets.has("black") and is_mrx

	if _chk_double_move != null:
		_chk_double_move.visible = is_mrx and can_double_move
		_chk_double_move.button_pressed = false

	if _btn_close_eyes != null:
		if not _btn_close_eyes.pressed.is_connected(_on_close_eyes_pressed):
			_btn_close_eyes.pressed.connect(_on_close_eyes_pressed)
		_btn_close_eyes.visible = is_mrx and close_eyes_cards > 0
		_btn_close_eyes.text = "Close eyes · %d" % close_eyes_cards

	visible = true
	modulate.a = 0.0
	position.y += 20.0

	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()

	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	_anim_tween.parallel().tween_property(self, "position:y", position.y - 20.0, 0.18)

func close_picker() -> void:
	if not visible:
		return

	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()

	_anim_tween = create_tween()
	_anim_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	_anim_tween.finished.connect(func(): visible = false)

func cancel_picker() -> void:
	close_picker()
	picker_cancelled.emit()

func _on_ticket_pressed(ticket: String) -> void:
	var use_double: bool = _chk_double_move.button_pressed if (_chk_double_move != null and _chk_double_move.visible) else false
	close_picker()
	ticket_chosen.emit(ticket, use_double)

func _on_close_eyes_pressed() -> void:
	visible = false
	close_eyes_requested.emit()
	if _btn_close_eyes != null:
		_btn_close_eyes.visible = false
