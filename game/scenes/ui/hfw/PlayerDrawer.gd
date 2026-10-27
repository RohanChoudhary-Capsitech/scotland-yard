class_name PlayerDrawer
extends UIController

## PlayerDrawer — Collapsible left drawer showing all players and ticket inventories.
## Pre-places 6 PlayerRow instances (unused detectives hidden).
## Slides smoothly with a Tween; starts collapsed on mobile phones (< 500px shortest side).

const COLLAPSED_WIDTH: float = 64.0
const EXPANDED_WIDTH: float = 300.0
const LEFT_MARGIN: float = 10.0
## Drawers start open only on tablet-sized screens; phones and small windows keep the map clear.
const EXPAND_MIN_SHORT_SIDE: float = 900.0

@onready var _collapsed_view: VBoxContainer = %CollapsedView
@onready var _expanded_view: VBoxContainer = %ExpandedView
@onready var _btn_expand: Button = %BtnExpand
@onready var _btn_collapse: Button = %BtnCollapse

var _player_rows: Array[PlayerRow] = []
var _mini_avatars: Array[Button] = []

var _is_expanded: bool = false
var _slide_tween: Tween = null
var _state: SYGameState = null
var _mode: String = "detectives"
var _detective_count: int = 4

func _ready() -> void:
	super._ready()
	if not _initialized:
		_initialized = true
		_on_ready()

func _on_ready() -> void:
	super._on_ready()

	# Gather pre-placed player rows
	_player_rows.clear()
	for i in range(6):
		var row: PlayerRow = get_node_or_null("%%PlayerRow_%d" % i) as PlayerRow
		if row != null:
			row.setup(i)
			_player_rows.append(row)

	# Gather mini avatars
	_mini_avatars.clear()
	for i in range(6):
		var mini_btn: Button = get_node_or_null("%%MiniAvatar_%d" % i) as Button
		if mini_btn != null:
			mini_btn.pressed.connect(_on_mini_avatar_pressed.bind(i))
			_style_mini_avatar(mini_btn, i, false)
			_mini_avatars.append(mini_btn)

	if _btn_expand != null:
		_btn_expand.pressed.connect(expand_drawer)
	if _btn_collapse != null:
		_btn_collapse.pressed.connect(collapse_drawer)

	# Responsive initial state
	_check_initial_responsive_state()

func _check_initial_responsive_state() -> void:
	# Logical (stretched) size, so a 1080p phone counts as a phone and a tablet as a tablet.
	var win_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() != null else Vector2.ZERO
	var shortest_side: float = minf(win_size.x, win_size.y)
	if shortest_side < EXPAND_MIN_SHORT_SIDE:
		set_drawer_expanded(false, false)
	else:
		set_drawer_expanded(true, false)

func configure_match(state: SYGameState, mode: Variant, detective_count: int, player_names: Dictionary = {}) -> void:
	_state = state
	_mode = mode
	_detective_count = detective_count

	# Apply custom names if provided
	for p_id in player_names:
		set_player_name(int(p_id), str(player_names[p_id]))

	# Hide unused detective rows/mini-avatars
	for i in range(6):
		var is_used: bool = (i <= _detective_count)
		if i < _player_rows.size():
			_player_rows[i].visible = is_used
		if i < _mini_avatars.size():
			_mini_avatars[i].visible = is_used

	update_ui()

func set_player_name(p_id: int, p_name: String) -> void:
	if p_id >= 0 and p_id < _player_rows.size():
		_player_rows[p_id].set_player_name(p_name)

func update_ui(is_mrx_view: Variant = null) -> void:
	if _state == null:
		return

	var view_mode = is_mrx_view if is_mrx_view != null else _mode
	var cur_p: int = _state.current_player
	for i in range(_player_rows.size()):
		var is_used: bool = (i <= _detective_count)
		if not is_used:
			continue

		var is_active: bool = (i == cur_p)
		_player_rows[i].update_data(_state, view_mode, is_active)

		# Mini avatar highlight
		if i < _mini_avatars.size():
			var btn := _mini_avatars[i]
			_style_mini_avatar(btn, i, is_active)

func expand_drawer() -> void:
	set_drawer_expanded(true, true)

func collapse_drawer() -> void:
	set_drawer_expanded(false, true)

func toggle_drawer() -> void:
	set_drawer_expanded(not _is_expanded, true)

func set_drawer_expanded(expanded: bool, animate: bool = true) -> void:
	_is_expanded = expanded
	var target_w: float = EXPANDED_WIDTH if _is_expanded else COLLAPSED_WIDTH

	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()

	if not animate:
		custom_minimum_size.x = target_w
		offset_right = LEFT_MARGIN + target_w
		_collapsed_view.visible = not _is_expanded
		_expanded_view.visible = _is_expanded
		return

	if _is_expanded:
		_collapsed_view.visible = false
		_expanded_view.visible = true

	_slide_tween = create_tween()
	_slide_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_property(self, "custom_minimum_size:x", target_w, 0.22)
	_slide_tween.parallel().tween_property(self, "offset_right", LEFT_MARGIN + target_w, 0.22)

	_slide_tween.finished.connect(func():
		_collapsed_view.visible = not _is_expanded
		_expanded_view.visible = _is_expanded
	)

## Round player-coloured avatar; the active player gets a white ring.
func _style_mini_avatar(btn: Button, p_id: int, active: bool) -> void:
	var col: Color = Palette.player(p_id)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col.lightened(0.12) if st.begins_with("hover") else col
		sb.set_corner_radius_all(24)
		sb.corner_detail = 8
		if active:
			sb.set_border_width_all(3)
			sb.border_color = Color.WHITE
		elif st == "focus":
			sb.draw_center = false
		btn.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		btn.add_theme_color_override(c, Color.WHITE)
	btn.modulate = Color.WHITE if active else Color(1, 1, 1, 0.75)

func _on_mini_avatar_pressed(_p_id: int) -> void:
	expand_drawer()
