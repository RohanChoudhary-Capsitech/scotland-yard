class_name PlayerRow
extends PanelContainer

## PlayerRow — Displays a single player's avatar, position, and ticket chips.
## Enforces hidden-movement: Mr. X's real position is NEVER shown in Detective mode.

@export var player_id: int = 1

@onready var _avatar_badge: PanelContainer = %AvatarBadge
@onready var _lbl_avatar: Label = %LblAvatar
@onready var _lbl_name: Label = %LblName
@onready var _lbl_station: Label = %LblStation
@onready var _lbl_taxi: Label = %LblTaxi
@onready var _lbl_bus: Label = %LblBus
@onready var _lbl_ug: Label = %LblUG
@onready var _chip_black: PanelContainer = %ChipBlack
@onready var _lbl_black: Label = %LblBlack
@onready var _chip_double: PanelContainer = %ChipDouble
@onready var _lbl_double: Label = %LblDouble
@onready var _chip_close_eyes: PanelContainer = get_node_or_null("%ChipCloseEyes") as PanelContainer
@onready var _lbl_close_eyes: Label = get_node_or_null("%LblCloseEyes") as Label

var custom_name: String = ""

func _ready() -> void:
	_apply_avatar_style()

func setup(p_id: int) -> void:
	player_id = p_id
	_apply_avatar_style()

func set_player_name(p_name: String) -> void:
	custom_name = p_name
	if _lbl_name != null:
		_lbl_name.text = p_name

func configure_row(p_id: int, p_name: String = "", _color: Color = Color.WHITE, _is_active: bool = false, _show_details: bool = false) -> void:
	setup(p_id)
	if not p_name.is_empty():
		set_player_name(p_name)

func update_row(state: SYGameState, is_mrx_view: bool = false, is_active: bool = false) -> void:
	update_data(state, is_mrx_view, is_active)

func _apply_avatar_style() -> void:
	if _avatar_badge == null:
		return
	var col: Color = Palette.player(player_id)
	var style := _avatar_badge.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		var new_style := style.duplicate() as StyleBoxFlat
		new_style.bg_color = col
		_avatar_badge.add_theme_stylebox_override("panel", new_style)

	if _lbl_avatar != null:
		_lbl_avatar.text = "X" if player_id == 0 else "D%d" % player_id

	if _lbl_name != null:
		if not custom_name.is_empty():
			_lbl_name.text = custom_name
		else:
			_lbl_name.text = "Mr. X" if player_id == 0 else "Detective %d" % player_id

func update_data(state: SYGameState, mode: Variant, is_active: bool) -> void:
	if state == null:
		return

	# 1. Active row highlight
	var base_style := get_theme_stylebox("panel") as StyleBoxFlat
	if base_style != null:
		var row_style := base_style.duplicate() as StyleBoxFlat
		if is_active:
			row_style.set_border_width_all(2)
			row_style.border_color = Palette.player(player_id)
			row_style.bg_color = Color(Palette.player(player_id), 0.14)
		else:
			row_style.set_border_width_all(0)
			row_style.bg_color = Color(1, 1, 1, 0.04)
		add_theme_stylebox_override("panel", row_style)

	# 2. Location (Hidden-movement rule strictly enforced)
	# Mr. X's real position is shown ONLY while a Human Mr. X is taking his turn or at game over
	var show_mrx: bool = false
	if mode is bool:
		show_mrx = mode
	elif mode is String:
		show_mrx = (mode == "mrx" or mode == "human_mrx_turn")
	if state.game_over:
		show_mrx = true

	if _lbl_station != null:
		if player_id == 0:
			if not show_mrx:
				# Detectives view: NEVER read state.positions[0]!
				if state.last_revealed_position > 0:
					_lbl_station.text = "Last: Stn %d" % state.last_revealed_position
					_lbl_station.modulate = Palette.GOLD
				else:
					_lbl_station.text = "Hidden"
					_lbl_station.modulate = Color.WHITE
			else:
				# Mr. X view (or game over): show own station
				_lbl_station.text = "Stn %d" % state.positions.get(0, 0)
				_lbl_station.modulate = Color.WHITE
		else:
			# Detectives are always visible
			_lbl_station.text = "Stn %d" % state.positions.get(player_id, 0)
			_lbl_station.modulate = Color.WHITE

	# 3. Tickets
	var tickets: Dictionary = state.tickets.get(player_id, {})
	if _lbl_taxi != null:
		_lbl_taxi.text = "%d" % tickets.get("taxi", 0)
	if _lbl_bus != null:
		_lbl_bus.text = "%d" % tickets.get("bus", 0)
	if _lbl_ug != null:
		_lbl_ug.text = "%d" % tickets.get("underground", 0)

	if player_id == 0:
		if _chip_black != null:
			_chip_black.visible = true
		if _lbl_black != null:
			_lbl_black.text = "%d" % tickets.get("black", 0)
		if _chip_double != null:
			_chip_double.visible = true
		if _lbl_double != null:
			var d_count: int = tickets.get("double", tickets.get("double_move", 0))
			_lbl_double.text = "%d" % d_count
		if _chip_close_eyes != null:
			_chip_close_eyes.visible = true
		if _lbl_close_eyes != null:
			var ce_count: int = state.close_eyes_cards if state != null else 0
			_lbl_close_eyes.text = "%d" % ce_count
	else:
		if _chip_black != null:
			_chip_black.visible = false
		if _chip_double != null:
			_chip_double.visible = false
		if _chip_close_eyes != null:
			_chip_close_eyes.visible = false
