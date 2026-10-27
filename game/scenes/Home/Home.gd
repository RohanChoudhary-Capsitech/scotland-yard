class_name HomeScene
extends UIController

## HomeScene — Mobile-first Main Menu & Seat Setup for Scotland Yard.
## Allows selecting detective count (3–5), Tells toggle, and player seats (Mr. X + 3-5 Detectives).
## Each seat has a Human / AI toggle and editable name.
## Presets: "Play as Detectives", "Play as Mr. X", "Pass and Play".
## Saves seats via SaveManager and starts the game. At least one seat must be Human.

@onready var _btn_detectives: Button = %BtnPlayDetectives
@onready var _btn_mrx: Button = %BtnPlayMrX
@onready var _btn_pass_and_play: Button = %BtnPassAndPlay
@onready var _btn_det_3: Button = %BtnDet3
@onready var _btn_det_4: Button = %BtnDet4
@onready var _btn_det_5: Button = %BtnDet5
@onready var _chk_tells: CheckBox = %ChkTells
@onready var _btn_start: Button = %BtnStart
@onready var _lbl_warning: Label = %LblWarning
@onready var _safe_area_margin: MarginContainer = %SafeAreaMargin
@onready var _btn_how_to_play: Button = %BtnHowToPlay
@onready var _background: TextureRect = %Background
@onready var _hero: VBoxContainer = %Hero
@onready var _setup_card: PanelContainer = %SetupCard

const ICON_HUMAN := preload("res://game/assets/sprites/single/ui/icons/human.svg")
const ICON_AI := preload("res://game/assets/sprites/single/ui/icons/robot.svg")

var _seat_cards: Array[PanelContainer] = []
var _seat_name_edits: Array[LineEdit] = []
var _seat_type_buttons: Array[Button] = []

var _logger: Node
var _scene: SceneManager
var _save: Object

var _selected_detective_count: int = 4
var _tells_enabled: bool = false
var _seats: Array[Dictionary] = [] # [{ "id": int, "name": String, "type": "human"|"ai", "is_human": bool }]

var _selected_mode: String:
	get:
		return _get_preset_name_or_mixed()
	set(val):
		_apply_preset(val)

func _set_mode(preset: String) -> void:
	_apply_preset(preset)

func inject_services(registry: Node) -> void:
	if not registry:
		return
	super.inject_services(registry)
	_logger = registry.get_service(&"logger") as Node
	_scene = registry.get_service(&"scene") as SceneManager
	_save = registry.get_service(&"save")

func _on_ready() -> void:
	super._on_ready()

	if _logger:
		_logger.info("Scotland Yard HomeScene loaded.")

	_collect_seat_nodes()

	# Default initial seats
	_init_default_seats()

	# Load saved settings if available
	if _save != null:
		_selected_detective_count = int(_save.get_value("detective_count", 4))
		_tells_enabled = bool(_save.get_value("tells_enabled", false))
		var saved_seats = _save.get_value("seats", [])
		if saved_seats is Array and not saved_seats.is_empty():
			_load_saved_seats(saved_seats)
		else:
			var saved_mode: String = str(_save.get_value("match_mode", "detectives"))
			_apply_preset(saved_mode)

	_apply_safe_area()
	if get_viewport() != null:
		get_viewport().size_changed.connect(_apply_safe_area)

	# Connect Presets
	if _btn_detectives != null:
		_btn_detectives.pressed.connect(func(): _apply_preset("detectives"))
	if _btn_mrx != null:
		_btn_mrx.pressed.connect(func(): _apply_preset("mrx"))
	if _btn_pass_and_play != null:
		_btn_pass_and_play.pressed.connect(func(): _apply_preset("pass_and_play"))

	# Connect Detective Count
	if _btn_det_3 != null:
		_btn_det_3.pressed.connect(func(): _set_detective_count(3))
	if _btn_det_4 != null:
		_btn_det_4.pressed.connect(func(): _set_detective_count(4))
	if _btn_det_5 != null:
		_btn_det_5.pressed.connect(func(): _set_detective_count(5))

	# Connect Tells Toggle
	if _chk_tells != null:
		_chk_tells.toggled.connect(func(pressed: bool):
			_tells_enabled = pressed
			_update_tells_button()
		)

	# Connect Start Button
	if _btn_start != null:
		_btn_start.pressed.connect(_on_start_pressed)
	if _btn_how_to_play != null:
		_btn_how_to_play.pressed.connect(_on_how_to_play_pressed)

	# Connect Seat Toggles and Name edits
	for i in range(_seat_type_buttons.size()):
		var idx: int = i
		var btn: Button = _seat_type_buttons[idx]
		if btn != null:
			btn.pressed.connect(func(): _toggle_seat_type(idx))

	for i in range(_seat_name_edits.size()):
		var idx: int = i
		var edit: LineEdit = _seat_name_edits[idx]
		if edit != null:
			edit.text_changed.connect(func(new_text: String): _on_name_changed(idx, new_text))

	_refresh_all_ui()
	_play_intro()

## Menu intro: hero and setup card slide in, background drifts slowly.
func _play_intro() -> void:
	if not is_inside_tree():
		return
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _hero != null:
		_hero.modulate.a = 0.0
		_hero.position.x -= 40.0
		t.tween_property(_hero, "modulate:a", 1.0, 0.5)
		t.parallel().tween_property(_hero, "position:x", _hero.position.x + 40.0, 0.6)
	if _setup_card != null:
		_setup_card.modulate.a = 0.0
		t.parallel().tween_property(_setup_card, "modulate:a", 1.0, 0.5).set_delay(0.12)
	if _background != null:
		var drift := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.tween_property(_background, "position", _background.position + Vector2(-50, -24), 14.0)
		drift.tween_property(_background, "position", _background.position, 14.0)

func _on_how_to_play_pressed() -> void:
	var path: String = GameConfig.UI_PANELS.get("how_to_play", "")
	if _ui_manager != null and not path.is_empty():
		_ui_manager.push_packed(load(path))

func _collect_seat_nodes() -> void:
	_seat_cards.clear()
	_seat_name_edits.clear()
	_seat_type_buttons.clear()

	for i in range(6):
		var card = get_node_or_null("%SeatCard_" + str(i)) as PanelContainer
		var edit = get_node_or_null("%TxtName" + str(i)) as LineEdit
		var btn = get_node_or_null("%BtnType" + str(i)) as Button

		_seat_cards.append(card)
		_seat_name_edits.append(edit)
		_seat_type_buttons.append(btn)

func _init_default_seats() -> void:
	_seats.clear()
	_seats.append({"id": 0, "name": "Mr. X", "type": "ai", "is_human": false})
	for d in range(1, 6):
		_seats.append({"id": d, "name": "Detective %d" % d, "type": "human", "is_human": true})

func _load_saved_seats(saved: Array) -> void:
	for i in range(mini(_seats.size(), saved.size())):
		var s = saved[i]
		if s is Dictionary:
			var s_name: String = str(s.get("name", _seats[i]["name"]))
			var s_type: String = str(s.get("type", _seats[i]["type"]))
			var is_h: bool = (s_type == "human" or s.get("is_human", false))
			_seats[i]["name"] = s_name
			_seats[i]["type"] = "human" if is_h else "ai"
			_seats[i]["is_human"] = is_h

func _apply_preset(preset: String) -> void:
	if preset == "mrx":
		# Mr. X = Human, Detectives = AI
		_seats[0]["type"] = "human"
		_seats[0]["is_human"] = true
		for d in range(1, 6):
			_seats[d]["type"] = "ai"
			_seats[d]["is_human"] = false
	elif preset == "pass_and_play":
		# All Human
		_seats[0]["type"] = "human"
		_seats[0]["is_human"] = true
		for d in range(1, 6):
			_seats[d]["type"] = "human"
			_seats[d]["is_human"] = true
	else:
		# Play as Detectives: Mr. X = AI, Detectives = Human
		_seats[0]["type"] = "ai"
		_seats[0]["is_human"] = false
		for d in range(1, 6):
			_seats[d]["type"] = "human"
			_seats[d]["is_human"] = true

	_refresh_all_ui()

func _toggle_seat_type(idx: int) -> void:
	if idx < 0 or idx >= _seats.size():
		return
	var cur_type: String = _seats[idx]["type"]
	var new_type: String = "ai" if cur_type == "human" else "human"
	_seats[idx]["type"] = new_type
	_seats[idx]["is_human"] = (new_type == "human")
	_refresh_all_ui()

func _on_name_changed(idx: int, new_name: String) -> void:
	if idx >= 0 and idx < _seats.size():
		_seats[idx]["name"] = new_name

func _set_detective_count(count: int) -> void:
	_selected_detective_count = count
	_refresh_all_ui()

func _apply_safe_area() -> void:
	if _safe_area_margin == null:
		return
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()
	# Notch insets only make sense when the window fills the screen (phones); skip in desktop windows.
	if window_size != DisplayServer.screen_get_size():
		safe_area = Rect2i(Vector2i.ZERO, window_size)
	var vp_rect := _safe_area_margin.get_viewport_rect()

	if safe_area.size.x > 0 and safe_area.size.y > 0 and window_size.x > 0 and window_size.y > 0:
		var scale_x: float = vp_rect.size.x / float(window_size.x)
		var scale_y: float = vp_rect.size.y / float(window_size.y)
		_safe_area_margin.add_theme_constant_override("margin_left", int(maxf(0.0, float(safe_area.position.x) * scale_x)))
		_safe_area_margin.add_theme_constant_override("margin_top", int(maxf(0.0, float(safe_area.position.y) * scale_y)))
		_safe_area_margin.add_theme_constant_override("margin_right", int(maxf(0.0, float(window_size.x - safe_area.end.x) * scale_x)))
		_safe_area_margin.add_theme_constant_override("margin_bottom", int(maxf(0.0, float(window_size.y - safe_area.end.y) * scale_y)))

func _refresh_all_ui() -> void:
	_update_detective_buttons()
	_update_seat_cards()
	_update_preset_buttons()
	_update_tells_button()
	_validate_seats()

func _update_detective_buttons() -> void:
	if _btn_det_3 != null:
		_btn_det_3.set_pressed_no_signal(_selected_detective_count == 3)
	if _btn_det_4 != null:
		_btn_det_4.set_pressed_no_signal(_selected_detective_count == 4)
	if _btn_det_5 != null:
		_btn_det_5.set_pressed_no_signal(_selected_detective_count == 5)

func _update_seat_cards() -> void:
	for i in range(6):
		var is_active: bool = (i <= _selected_detective_count)
		if i < _seat_cards.size() and _seat_cards[i] != null:
			_seat_cards[i].visible = is_active

		if is_active and i < _seats.size():
			if i < _seat_name_edits.size() and _seat_name_edits[i] != null:
				if _seat_name_edits[i].text != _seats[i]["name"]:
					_seat_name_edits[i].text = _seats[i]["name"]

			if i < _seat_type_buttons.size() and _seat_type_buttons[i] != null:
				var is_human: bool = _seats[i]["is_human"]
				_seat_type_buttons[i].text = "Human" if is_human else "AI"
				_seat_type_buttons[i].icon = ICON_HUMAN if is_human else ICON_AI
				_seat_type_buttons[i].toggle_mode = true
				_seat_type_buttons[i].set_pressed_no_signal(is_human)

func _update_preset_buttons() -> void:
	var mrx_human: bool = _seats[0]["is_human"]
	var any_det_human: bool = false
	var all_det_human: bool = true

	for d in range(1, _selected_detective_count + 1):
		if _seats[d]["is_human"]:
			any_det_human = true
		else:
			all_det_human = false

	var is_det_preset: bool = (not mrx_human and all_det_human)
	var is_mrx_preset: bool = (mrx_human and not any_det_human)
	var is_pap_preset: bool = (mrx_human and all_det_human)

	if _btn_detectives != null:
		_btn_detectives.set_pressed_no_signal(is_det_preset)
	if _btn_mrx != null:
		_btn_mrx.set_pressed_no_signal(is_mrx_preset)
	if _btn_pass_and_play != null:
		_btn_pass_and_play.set_pressed_no_signal(is_pap_preset)

func _update_tells_button() -> void:
	if _chk_tells != null:
		_chk_tells.set_pressed_no_signal(_tells_enabled)
		_chk_tells.text = "Spotlight tells: ON" if _tells_enabled else "Spotlight tells: OFF"

func _validate_seats() -> void:
	var human_count: int = 0
	for i in range(_selected_detective_count + 1):
		if _seats[i]["is_human"]:
			human_count += 1

	var has_human: bool = (human_count >= 1)
	if _btn_start != null:
		_btn_start.disabled = not has_human
	if _lbl_warning != null:
		_lbl_warning.visible = not has_human

func _get_active_seats() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for i in range(_selected_detective_count + 1):
		# Sync text from line edit if modified
		if i < _seat_name_edits.size() and _seat_name_edits[i] != null:
			var txt = _seat_name_edits[i].text.strip_edges()
			if not txt.is_empty():
				_seats[i]["name"] = txt
		res.append(_seats[i].duplicate())
	return res

func _get_preset_name_or_mixed() -> String:
	var mrx_human: bool = _seats[0]["is_human"]
	var any_det_human: bool = false
	var all_det_human: bool = true

	for d in range(1, _selected_detective_count + 1):
		if _seats[d]["is_human"]:
			any_det_human = true
		else:
			all_det_human = false

	if not mrx_human and all_det_human:
		return "detectives"
	elif mrx_human and not any_det_human:
		return "mrx"
	elif mrx_human and all_det_human:
		return "pass_and_play"
	return "mixed"

func _on_start_pressed() -> void:
	var active_seats := _get_active_seats()

	# Validate at least one human
	var human_found: bool = false
	for s in active_seats:
		if s.get("is_human", false):
			human_found = true
			break
	if not human_found:
		return

	if _save != null:
		_save.set_value("seats", active_seats)
		_save.set_value("detective_count", _selected_detective_count)
		_save.set_value("tells_enabled", _tells_enabled)
		_save.set_value("match_mode", _get_preset_name_or_mixed())
		_save.save_game()

	if _scene != null:
		_scene.go_to("res://game/scenes/gameplay/Match.tscn")
	else:
		get_tree().change_scene_to_file("res://game/scenes/gameplay/Match.tscn")
