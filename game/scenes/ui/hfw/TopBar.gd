class_name TopBar
extends UIController

## TopBar — Mobile-friendly in-game top navigation & status bar.
## Displays: Round count, next reveal round, whose turn, Focus button, and Pause button.

const REVEAL_ROUNDS: Array[int] = [3, 8, 13, 18, 24]

@onready var _lbl_round: Label = %LblRound
@onready var _lbl_next_reveal: Label = %LblNextReveal
@onready var _lbl_turn: Label = %LblTurn
@onready var _turn_badge: PanelContainer = %TurnBadge
@onready var _btn_focus: Button = %BtnFocus
@onready var _btn_pause: Button = %BtnPause
@onready var _progress: ProgressBar = %Progress
@onready var _turn_icon: TextureRect = %TurnIcon
@onready var _turn_icon_bg: Panel = %TurnIconBg
@onready var _lbl_turn_caps: Label = %LblTurnCaps
@onready var _reveal_icon: TextureRect = %RevealIcon

var _bus: Node
var _current_round: int = 1
var _player_names: Dictionary = {}

func inject_services(registry: Node) -> void:
	if not registry:
		return
	super.inject_services(registry)
	_bus = registry.get_service(&"bus") as Node

func set_bus(bus: Node) -> void:
	_bus = bus
	_connect_bus_signals()

func _ready() -> void:
	super._ready()
	if not _initialized:
		_initialized = true
		_on_ready()

func _on_ready() -> void:
	super._on_ready()
	if _bus == null and get_tree() != null and get_tree().root != null:
		var registry: Node = get_tree().root.get_node_or_null("ServiceRegistry")
		if registry != null and registry.has_method("get_service"):
			_bus = registry.get_service(&"bus") as Node

	_connect_bus_signals()

	if _btn_focus != null:
		_btn_focus.pressed.connect(_on_focus_pressed)
	if _btn_pause != null:
		_btn_pause.pressed.connect(_on_pause_pressed)

	update_round(1)
	update_turn(0)

func _connect_bus_signals() -> void:
	if _bus == null:
		return
	if not _bus.round_changed.is_connected(_on_round_changed):
		_bus.round_changed.connect(_on_round_changed)
	if not _bus.turn_started.is_connected(_on_turn_started):
		_bus.turn_started.connect(_on_turn_started)

func _on_round_changed(r: int) -> void:
	update_round(r)

func _on_turn_started(p: int) -> void:
	update_turn(p)

func update_round(r: int) -> void:
	_current_round = r
	if _lbl_round != null:
		_lbl_round.text = "%d / 24" % r
	if _progress != null:
		_progress.value = r

	if _lbl_next_reveal != null:
		var next_rev: int = -1
		for rev in REVEAL_ROUNDS:
			if rev >= r:
				next_rev = rev
				break

		if next_rev == r:
			_lbl_next_reveal.text = "This round!"
			_lbl_next_reveal.modulate = Palette.RED
		elif next_rev > 0:
			_lbl_next_reveal.text = "Round %d" % next_rev
			_lbl_next_reveal.modulate = Color.WHITE
		else:
			_lbl_next_reveal.text = "Final round"
			_lbl_next_reveal.modulate = Color.WHITE
		if _reveal_icon != null:
			_reveal_icon.modulate = Palette.RED if next_rev == r else Palette.GOLD

func update_turn(player_index: int) -> void:
	if _lbl_turn == null:
		return

	var p_name: String = _player_names.get(player_index, "Mr. X" if player_index == 0 else "Detective %d" % player_index)
	_lbl_turn.text = p_name
	if _lbl_turn_caps != null:
		_lbl_turn_caps.text = "MR. X IS MOVING" if player_index == 0 else "NOW PLAYING"

	var col: Color = Palette.player(player_index)
	if _turn_icon != null:
		_turn_icon.texture = Palette.player_icon(player_index)
	if _turn_icon_bg != null:
		var dot := StyleBoxFlat.new()
		dot.bg_color = col
		dot.set_corner_radius_all(17)
		_turn_icon_bg.add_theme_stylebox_override("panel", dot)
	if _turn_badge != null:
		var style := _turn_badge.get_theme_stylebox("panel") as StyleBoxFlat
		if style != null:
			var new_style := style.duplicate() as StyleBoxFlat
			new_style.border_color = col
			new_style.set_border_width_all(2)
			_turn_badge.add_theme_stylebox_override("panel", new_style)
	if is_inside_tree() and _turn_badge != null:
		_turn_badge.pivot_offset = _turn_badge.size * 0.5
		var pop := create_tween()
		pop.tween_property(_turn_badge, "scale", Vector2(1.08, 1.08), 0.09)
		pop.tween_property(_turn_badge, "scale", Vector2.ONE, 0.14)

func set_player_names(names: Dictionary) -> void:
	_player_names = names

func _on_focus_pressed() -> void:
	if _bus != null and _bus.has_signal("focus_requested"):
		_bus.focus_requested.emit()

func _on_pause_pressed() -> void:
	if _bus != null and _bus.has_signal("pause_requested"):
		_bus.pause_requested.emit()
