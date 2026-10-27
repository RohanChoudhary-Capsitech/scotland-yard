class_name InGameHUD
extends CanvasLayer

## InGameHUD — Root HUD controller hosting all in-game mobile UI panels.
## Applies DisplayServer.get_display_safe_area() margins for phone notches.
## Empty areas use MOUSE_FILTER_IGNORE so the map stays scrollable.
## Panels use MOUSE_FILTER_STOP so touches on UI never reach the map.

@onready var _root_margin: MarginContainer = %RootMargin
@onready var _hud_container: Control = %HUDContainer
@onready var top_bar: TopBar = %TopBar
@onready var player_drawer: PlayerDrawer = %PlayerDrawer
@onready var travel_log_drawer: TravelLogDrawer = %TravelLogDrawer
@onready var ticket_picker: TicketPicker = %TicketPicker
@onready var toast: Toast = %Toast

var _state: SYGameState
var _mode: Variant = "detectives"
var _detective_count: int = 4
var _bus: Node
var _is_mrx_view: bool = false
var _player_names: Dictionary = {}

func _ready() -> void:
	_ensure_components_ready()
	if get_viewport() != null:
		get_viewport().size_changed.connect(apply_safe_area)
	apply_safe_area()

func _ensure_components_ready() -> void:
	if top_bar != null and not top_bar._initialized:
		top_bar.inject_dependencies(null, null, null)
	if player_drawer != null and not player_drawer._initialized:
		player_drawer.inject_dependencies(null, null, null)
	if travel_log_drawer != null and not travel_log_drawer._initialized:
		travel_log_drawer.inject_dependencies(null, null, null)
	if ticket_picker != null and not ticket_picker._initialized:
		ticket_picker.inject_dependencies(null, null, null)
	if toast != null and not toast._initialized:
		toast.inject_dependencies(null, null, null)

func apply_safe_area() -> void:
	if _root_margin == null:
		_root_margin = get_node_or_null("%RootMargin") as MarginContainer
	if _root_margin == null:
		return

	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()
	# Notch insets only make sense when the window fills the screen (phones); skip in desktop windows.
	if window_size != DisplayServer.screen_get_size():
		safe_area = Rect2i(Vector2i.ZERO, window_size)
	var vp_rect := _root_margin.get_viewport_rect()

	if safe_area.size.x > 0 and safe_area.size.y > 0 and window_size.x > 0 and window_size.y > 0:
		var scale_x: float = vp_rect.size.x / float(window_size.x)
		var scale_y: float = vp_rect.size.y / float(window_size.y)
		var left_margin: float = float(safe_area.position.x) * scale_x
		var top_margin: float = float(safe_area.position.y) * scale_y
		var right_margin: float = float(window_size.x - safe_area.end.x) * scale_x
		var bottom_margin: float = float(window_size.y - safe_area.end.y) * scale_y

		_root_margin.add_theme_constant_override("margin_left", int(maxf(0.0, left_margin)))
		_root_margin.add_theme_constant_override("margin_top", int(maxf(0.0, top_margin)))
		_root_margin.add_theme_constant_override("margin_right", int(maxf(0.0, right_margin)))
		_root_margin.add_theme_constant_override("margin_bottom", int(maxf(0.0, bottom_margin)))
	else:
		_root_margin.add_theme_constant_override("margin_left", 0)
		_root_margin.add_theme_constant_override("margin_top", 0)
		_root_margin.add_theme_constant_override("margin_right", 0)
		_root_margin.add_theme_constant_override("margin_bottom", 0)

func configure_hud(state: SYGameState, mode: Variant, detective_count: int, bus: Node, player_names: Dictionary = {}) -> void:
	_state = state
	_mode = mode
	_detective_count = detective_count
	_bus = bus
	_player_names = player_names
	_is_mrx_view = (mode == "mrx")

	if top_bar != null:
		top_bar.set_bus(_bus)
		top_bar.set_player_names(_player_names)
		top_bar.update_round(_state.round)
		top_bar.update_turn(_state.current_player)

	if player_drawer != null:
		player_drawer.configure_match(_state, _mode, _detective_count, _player_names)

	if travel_log_drawer != null:
		travel_log_drawer.configure_match(_state, _mode)

	if toast != null:
		toast.set_bus(_bus)

func set_mrx_view(active: bool) -> void:
	_is_mrx_view = active
	update_hud()

func update_hud(is_mrx_view: Variant = null) -> void:
	if _state == null:
		return

	if is_mrx_view != null:
		_is_mrx_view = bool(is_mrx_view)

	if top_bar != null:
		top_bar.update_round(_state.round)
		top_bar.update_turn(_state.current_player)

	if player_drawer != null:
		player_drawer.update_ui(_is_mrx_view)

	if travel_log_drawer != null:
		travel_log_drawer.update_ui(_is_mrx_view)
