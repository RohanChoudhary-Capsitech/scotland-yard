class_name LogSlot
extends PanelContainer

## LogSlot — Displays a single round's entry in Mr. X's travel log.
## Highlighted with a gold border on reveal rounds (3, 8, 13, 18, 24).
## Station is ONLY shown if revealed or in Mr. X mode.

const REVEAL_ROUNDS: Array[int] = [3, 8, 13, 18, 24]

@export var round_number: int = 1

@onready var _lbl_round: Label = %LblRound
@onready var _ticket_icon: TextureRect = %TicketIcon
@onready var _lbl_station: Label = %LblStation

var _is_reveal_round: bool = false

func _ready() -> void:
	setup(round_number)

func setup(round_num: int) -> void:
	round_number = round_num
	_is_reveal_round = (round_number in REVEAL_ROUNDS)

	if _lbl_round != null:
		_lbl_round.text = "R%d" % round_number

	_apply_border_style(false)

func _apply_border_style(has_entry: bool) -> void:
	var base_style := get_theme_stylebox("panel") as StyleBoxFlat
	if base_style == null:
		return
	var style := base_style.duplicate() as StyleBoxFlat

	if _is_reveal_round:
		style.set_border_width_all(2)
		style.border_color = Color(Palette.GOLD, 0.95) # gold reveal border
		style.bg_color = Color(Palette.GOLD, 0.12 if has_entry else 0.06)
	elif has_entry:
		style.set_border_width_all(1)
		style.border_color = Color(1, 1, 1, 0.16)
		style.bg_color = Color(1, 1, 1, 0.08)
	else:
		style.set_border_width_all(0)
		style.bg_color = Color(1, 1, 1, 0.03)

	add_theme_stylebox_override("panel", style)

func clear_entry() -> void:
	if _ticket_icon != null:
		_ticket_icon.texture = Palette.icon("eye") if _is_reveal_round else null
		_ticket_icon.modulate = Color(Palette.GOLD, 0.5)
	if _lbl_station != null:
		_lbl_station.text = "Reveal" if _is_reveal_round else "?"
		_lbl_station.modulate = Palette.GOLD if _is_reveal_round else Color(Palette.MUTED, 0.6)
	_apply_border_style(false)

func set_entry(ticket: String, station_id: int, revealed: bool, is_mrx_mode: bool) -> void:
	_apply_border_style(true)

	if _ticket_icon != null:
		_ticket_icon.texture = Palette.icon(ticket)
		_ticket_icon.modulate = Palette.ticket(ticket)

	if _lbl_station != null:
		if revealed:
			_lbl_station.text = "Stn %d" % station_id
			_lbl_station.modulate = Palette.GOLD
		elif is_mrx_mode:
			_lbl_station.text = "Stn %d" % station_id
			_lbl_station.modulate = Color.WHITE
		else:
			# Non-reveal round in Detective mode: NEVER reveal station
			_lbl_station.text = "Hidden"
			_lbl_station.modulate = Palette.MUTED
