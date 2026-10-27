class_name TravelLogDrawer
extends UIController

## TravelLogDrawer — Collapsible right drawer containing Mr. X's 24-round travel log.
## Pre-places 24 LogSlot instances in a responsive grid.
## Slides with a Tween; starts collapsed on mobile phones (< 500px shortest side).

const COLLAPSED_WIDTH: float = 64.0
const EXPANDED_WIDTH: float = 290.0
const RIGHT_MARGIN: float = 10.0
const EXPAND_MIN_SHORT_SIDE: float = 900.0

@onready var _collapsed_view: VBoxContainer = %CollapsedView
@onready var _expanded_view: VBoxContainer = %ExpandedView
@onready var _btn_expand: Button = %BtnExpand
@onready var _btn_collapse: Button = %BtnCollapse
@onready var _lbl_last_ticket: Label = %LblLastTicket
@onready var _last_ticket_icon: TextureRect = %LastTicketIcon

var _log_slots: Array[LogSlot] = []
var _is_expanded: bool = false
var _slide_tween: Tween = null
var _state: SYGameState = null
var _mode: Variant = "detectives"

func _ready() -> void:
	super._ready()
	if not _initialized:
		_initialized = true
		_on_ready()

func _on_ready() -> void:
	super._on_ready()

	# Gather pre-placed log slots
	_log_slots.clear()
	var grid: GridContainer = get_node_or_null("%Grid") as GridContainer
	for i in range(1, 25):
		var slot: LogSlot = null
		if grid != null:
			slot = grid.get_node_or_null("LogSlot_%d" % i) as LogSlot
		if slot == null:
			slot = get_node_or_null("%%LogSlot_%d" % i) as LogSlot
		if slot != null:
			slot.setup(i)
			_log_slots.append(slot)

	if _btn_expand != null:
		_btn_expand.pressed.connect(expand_drawer)
	if _btn_collapse != null:
		_btn_collapse.pressed.connect(collapse_drawer)

	_check_initial_responsive_state()

func _check_initial_responsive_state() -> void:
	# Logical (stretched) size, so a 1080p phone counts as a phone and a tablet as a tablet.
	var win_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() != null else Vector2.ZERO
	var shortest_side: float = minf(win_size.x, win_size.y)
	if shortest_side < EXPAND_MIN_SHORT_SIDE:
		set_drawer_expanded(false, false)
	else:
		set_drawer_expanded(true, false)

func configure_match(state: SYGameState, mode: Variant) -> void:
	_state = state
	_mode = mode
	update_ui()

func update_ui(is_mrx_view: Variant = null) -> void:
	if _state == null:
		return

	var show_mrx: bool = false
	if is_mrx_view != null:
		if is_mrx_view is bool:
			show_mrx = is_mrx_view
		elif is_mrx_view is String:
			show_mrx = (is_mrx_view == "mrx")
	elif _mode is bool:
		show_mrx = _mode
	elif _mode is String:
		show_mrx = (_mode == "mrx")
	if _state.game_over:
		show_mrx = true

	var log_entries: Array = _state.mrx_move_log
	var last_entry: Dictionary = log_entries.back() if not log_entries.is_empty() else {}

	# Update collapsed badge
	if _lbl_last_ticket != null:
		if last_entry.is_empty():
			_lbl_last_ticket.text = "—"
			if _last_ticket_icon != null:
				_last_ticket_icon.texture = null
		else:
			var t: String = str(last_entry.get("ticket", ""))
			_lbl_last_ticket.text = "R%d" % last_entry.get("round", 1)
			if _last_ticket_icon != null:
				_last_ticket_icon.texture = Palette.icon(t)
				_last_ticket_icon.modulate = Palette.ticket(t)

	# Map entries by round number
	var entries_by_round: Dictionary = {}
	for entry in log_entries:
		if entry is Dictionary and entry.has("round"):
			entries_by_round[int(entry["round"])] = entry

	# Update 24 pre-placed slots
	for i in range(24):
		var r_num: int = i + 1
		if i < _log_slots.size():
			var slot := _log_slots[i]
			var entry: Dictionary = {}
			if entries_by_round.has(r_num):
				entry = entries_by_round[r_num]
			elif i < log_entries.size():
				entry = log_entries[i]

			if not entry.is_empty():
				var ticket: String = str(entry.get("ticket", "taxi"))
				var station: int = int(entry.get("station", 0))
				var revealed: bool = bool(entry.get("revealed", false))
				slot.set_entry(ticket, station, revealed, show_mrx)
			else:
				slot.clear_entry()

func expand_drawer() -> void:
	set_drawer_expanded(true, true)

func collapse_drawer() -> void:
	set_drawer_expanded(false, true)

func toggle_drawer() -> void:
	set_drawer_expanded(not _is_expanded, true)

func set_drawer_expanded(expanded: bool, animate: bool = true) -> void:
	_is_expanded = expanded
	var target_w: float = EXPANDED_WIDTH if _is_expanded else COLLAPSED_WIDTH
	var target_left: float = -(target_w + RIGHT_MARGIN)

	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()

	if not animate:
		custom_minimum_size.x = target_w
		offset_left = target_left
		_collapsed_view.visible = not _is_expanded
		_expanded_view.visible = _is_expanded
		return

	if _is_expanded:
		_collapsed_view.visible = false
		_expanded_view.visible = true

	_slide_tween = create_tween()
	_slide_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_property(self, "custom_minimum_size:x", target_w, 0.22)
	_slide_tween.parallel().tween_property(self, "offset_left", target_left, 0.22)

	_slide_tween.finished.connect(func():
		_collapsed_view.visible = not _is_expanded
		_expanded_view.visible = _is_expanded
	)
