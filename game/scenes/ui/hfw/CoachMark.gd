class_name CoachMark
extends Control

## CoachMark — First-time player guided tutorial overlay.
## Pre-built in editor (no runtime node creation, no custom _draw).
## Dims the screen using 4 shades to cut a transparent highlight hole around the target,
## blocking touches outside the cutout while passing through expected taps to the target.
## Includes structured bubble: Title (2-4 words), Step Counter ("Step 4 / 15"),
## Body (max 2 short sentences), "Why?" expander, Back and Next buttons,
## persistent "Skip tutorial" button, floating "Show me" recenter button, and Confirm bubble.

signal next_pressed
signal back_pressed
signal skip_pressed
signal show_me_pressed

@onready var _top_shade: ColorRect = %TopShade
@onready var _bottom_shade: ColorRect = %BottomShade
@onready var _left_shade: ColorRect = %LeftShade
@onready var _right_shade: ColorRect = %RightShade
@onready var _target_highlight: Panel = %TargetHighlight
@onready var _text_bubble: PanelContainer = %TextBubble
@onready var _lbl_title: Label = %LblTitle
@onready var _lbl_step_counter: Label = %LblStepCounter
@onready var _lbl_text: Label = %LblText
@onready var _why_container: VBoxContainer = %WhyContainer
@onready var _btn_why: Button = %BtnWhy
@onready var _lbl_why: Label = %LblWhy
@onready var _btn_back: Button = %BtnBack
@onready var _btn_next: Button = %BtnNext
@onready var _btn_skip: Button = %BtnSkip
@onready var _btn_show_me: Button = %BtnShowMe
@onready var _confirm_bubble: PanelContainer = %ConfirmBubble
@onready var _lbl_confirm: Label = %LblConfirm

var _tracked_node: Node = null
var _custom_target_size: Vector2 = Vector2.ZERO
var _current_rect: Rect2 = Rect2()
var _pulse_tween: Tween = null
var _confirm_tween: Tween = null
var _is_showing: bool = false

func _ready() -> void:
	_ensure_nodes()
	if _btn_next != null and not _btn_next.pressed.is_connected(_on_next_pressed):
		_btn_next.pressed.connect(_on_next_pressed)
	if _btn_back != null and not _btn_back.pressed.is_connected(_on_back_pressed):
		_btn_back.pressed.connect(_on_back_pressed)
	if _btn_skip != null and not _btn_skip.pressed.is_connected(_on_skip_pressed):
		_btn_skip.pressed.connect(_on_skip_pressed)
	if _btn_show_me != null and not _btn_show_me.pressed.is_connected(_on_show_me_pressed):
		_btn_show_me.pressed.connect(_on_show_me_pressed)
	if _btn_why != null and not _btn_why.pressed.is_connected(_on_why_pressed):
		_btn_why.pressed.connect(_on_why_pressed)

	hide_coach_mark()

func _ensure_nodes() -> void:
	if _top_shade == null:
		_top_shade = get_node_or_null("%TopShade") as ColorRect
	if _bottom_shade == null:
		_bottom_shade = get_node_or_null("%BottomShade") as ColorRect
	if _left_shade == null:
		_left_shade = get_node_or_null("%LeftShade") as ColorRect
	if _right_shade == null:
		_right_shade = get_node_or_null("%RightShade") as ColorRect
	if _target_highlight == null:
		_target_highlight = get_node_or_null("%TargetHighlight") as Panel
	if _text_bubble == null:
		_text_bubble = get_node_or_null("%TextBubble") as PanelContainer
	if _lbl_title == null:
		_lbl_title = get_node_or_null("%LblTitle") as Label
	if _lbl_step_counter == null:
		_lbl_step_counter = get_node_or_null("%LblStepCounter") as Label
	if _lbl_text == null:
		_lbl_text = get_node_or_null("%LblText") as Label
	if _why_container == null:
		_why_container = get_node_or_null("%WhyContainer") as VBoxContainer
	if _btn_why == null:
		_btn_why = get_node_or_null("%BtnWhy") as Button
	if _lbl_why == null:
		_lbl_why = get_node_or_null("%LblWhy") as Label
	if _btn_back == null:
		_btn_back = get_node_or_null("%BtnBack") as Button
	if _btn_next == null:
		_btn_next = get_node_or_null("%BtnNext") as Button
	if _btn_skip == null:
		_btn_skip = get_node_or_null("%BtnSkip") as Button
	if _btn_show_me == null:
		_btn_show_me = get_node_or_null("%BtnShowMe") as Button
	if _confirm_bubble == null:
		_confirm_bubble = get_node_or_null("%ConfirmBubble") as PanelContainer
	if _lbl_confirm == null:
		_lbl_confirm = get_node_or_null("%LblConfirm") as Label

func _process(_delta: float) -> void:
	if not _is_showing or not is_visible_in_tree():
		return

	if _tracked_node != null and is_instance_valid(_tracked_node):
		var target_rect := _calculate_node_rect(_tracked_node, _custom_target_size)
		if target_rect != _current_rect:
			_update_shades_and_highlight(target_rect)

func is_active() -> bool:
	return _is_showing and visible

func get_current_target_rect() -> Rect2:
	return _current_rect

## Configures the text bubble content (title, body, optional why expander, step counter, navigation buttons).
func set_step_content(
	title: String,
	body: String,
	why: String = "",
	step_num: int = 0,
	total_steps: int = 0,
	show_back: bool = false,
	show_next: bool = true
) -> void:
	_ensure_nodes()
	if _lbl_title != null:
		_lbl_title.text = title
		_lbl_title.visible = not title.is_empty()
	if _lbl_step_counter != null:
		if step_num > 0 and total_steps > 0:
			_lbl_step_counter.text = "Step %d / %d" % [step_num, total_steps]
			_lbl_step_counter.visible = true
		else:
			_lbl_step_counter.visible = false
	if _lbl_text != null:
		_lbl_text.text = body
	if _why_container != null:
		if why.is_empty():
			_why_container.visible = false
		else:
			_why_container.visible = true
			if _lbl_why != null:
				_lbl_why.text = why
				_lbl_why.visible = false
			if _btn_why != null:
				_btn_why.text = "Why does this matter? ▾"
	if _btn_back != null:
		_btn_back.visible = show_back
	if _btn_next != null:
		_btn_next.visible = show_next

## Shows CoachMark targeting a specific 2D Node (Station, Token) or UI Control.
func show_target_node(target: Node, text: String, show_next: bool = false, custom_size: Vector2 = Vector2.ZERO) -> void:
	_ensure_nodes()
	_tracked_node = target
	_custom_target_size = custom_size
	_is_showing = true
	visible = true

	if _lbl_text != null and (_lbl_text.text.is_empty() or not text.is_empty()):
		_lbl_text.text = text
	if _btn_next != null:
		_btn_next.visible = show_next
	if _text_bubble != null:
		_text_bubble.visible = true

	var rect := _calculate_node_rect(target, custom_size)
	_update_shades_and_highlight(rect)
	_start_pulse_animation()

## Shows CoachMark targeting an explicit canvas Rect2.
func show_target_rect(rect: Rect2, text: String, show_next: bool = false) -> void:
	_ensure_nodes()
	_tracked_node = null
	_custom_target_size = Vector2.ZERO
	_is_showing = true
	visible = true

	if _lbl_text != null and (_lbl_text.text.is_empty() or not text.is_empty()):
		_lbl_text.text = text
	if _btn_next != null:
		_btn_next.visible = show_next
	if _text_bubble != null:
		_text_bubble.visible = true

	_update_shades_and_highlight(rect)
	_start_pulse_animation()

## Shows full screen dim with a centered text bubble.
func show_fullscreen_message(text: String, show_next: bool = true) -> void:
	_ensure_nodes()
	_tracked_node = null
	_custom_target_size = Vector2.ZERO
	_is_showing = true
	visible = true

	var vp_size: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	if vp_size == Vector2.ZERO:
		vp_size = Vector2(1280, 720)

	if _top_shade != null:
		_top_shade.position = Vector2.ZERO
		_top_shade.size = vp_size
	if _bottom_shade != null:
		_bottom_shade.size = Vector2.ZERO
	if _left_shade != null:
		_left_shade.size = Vector2.ZERO
	if _right_shade != null:
		_right_shade.size = Vector2.ZERO

	if _target_highlight != null:
		_target_highlight.visible = false

	if _lbl_text != null and (_lbl_text.text.is_empty() or not text.is_empty()):
		_lbl_text.text = text
	if _btn_next != null:
		_btn_next.visible = show_next
	if _text_bubble != null:
		_text_bubble.visible = true
		_text_bubble.reset_size()
		var b_size := _text_bubble.size
		if b_size == Vector2.ZERO:
			b_size = Vector2(360, 140)
		_text_bubble.position = (vp_size - b_size) * 0.5

## Shows temporary floating confirm bubble (e.g. after moving or picking a ticket).
func show_confirm_message(text: String, duration: float = 1.8) -> void:
	_ensure_nodes()
	if _confirm_bubble == null or _lbl_confirm == null or text.is_empty():
		return
	if _confirm_tween != null and _confirm_tween.is_valid():
		_confirm_tween.kill()

	_lbl_confirm.text = text
	_confirm_bubble.visible = true
	_confirm_bubble.modulate.a = 0.0

	_confirm_tween = create_tween()
	_confirm_tween.tween_property(_confirm_bubble, "modulate:a", 1.0, 0.2)
	_confirm_tween.tween_interval(duration)
	_confirm_tween.tween_property(_confirm_bubble, "modulate:a", 0.0, 0.3)
	_confirm_tween.tween_callback(func(): _confirm_bubble.visible = false)

## Shows or hides the floating recenter "Show me" button.
func set_show_me_visible(is_visible: bool) -> void:
	_ensure_nodes()
	if _btn_show_me != null:
		_btn_show_me.visible = is_visible

## Hides CoachMark completely.
func hide_coach_mark() -> void:
	_ensure_nodes()
	_is_showing = false
	_tracked_node = null
	visible = false
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	if _btn_show_me != null:
		_btn_show_me.visible = false

func _calculate_node_rect(node: Node, custom_size: Vector2) -> Rect2:
	if node is Control:
		return (node as Control).get_global_rect()
	elif node is CanvasItem:
		var origin := (node as CanvasItem).get_global_transform_with_canvas().origin
		var sz := custom_size if custom_size != Vector2.ZERO else Vector2(76, 76)
		return Rect2(origin - sz * 0.5, sz)
	return Rect2(Vector2.ZERO, Vector2.ZERO)

func _update_shades_and_highlight(r: Rect2) -> void:
	_ensure_nodes()
	_current_rect = r
	var vp_size: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	if vp_size == Vector2.ZERO:
		vp_size = Vector2(1280, 720)

	var rx: float = clampf(r.position.x, 0.0, vp_size.x)
	var ry: float = clampf(r.position.y, 0.0, vp_size.y)
	var rw: float = clampf(r.size.x, 0.0, vp_size.x - rx)
	var rh: float = clampf(r.size.y, 0.0, vp_size.y - ry)

	if _top_shade != null:
		_top_shade.position = Vector2.ZERO
		_top_shade.size = Vector2(vp_size.x, ry)

	if _bottom_shade != null:
		_bottom_shade.position = Vector2(0.0, ry + rh)
		_bottom_shade.size = Vector2(vp_size.x, maxf(0.0, vp_size.y - (ry + rh)))

	if _left_shade != null:
		_left_shade.position = Vector2(0.0, ry)
		_left_shade.size = Vector2(rx, rh)

	if _right_shade != null:
		_right_shade.position = Vector2(rx + rw, ry)
		_right_shade.size = Vector2(maxf(0.0, vp_size.x - (rx + rw)), rh)

	if _target_highlight != null:
		var pad := 6.0
		_target_highlight.visible = true
		_target_highlight.position = Vector2(rx - pad, ry - pad)
		_target_highlight.size = Vector2(rw + pad * 2.0, rh + pad * 2.0)

	if _text_bubble != null and _text_bubble.visible:
		_reposition_text_bubble(Rect2(rx, ry, rw, rh), vp_size)

func _reposition_text_bubble(r: Rect2, vp_size: Vector2) -> void:
	_text_bubble.reset_size()
	var b_size := _text_bubble.size
	if b_size.x <= 0 or b_size.y <= 0:
		b_size = Vector2(360, 140)

	var by: float
	if r.position.y > 200.0:
		by = r.position.y - b_size.y - 14.0
	else:
		by = r.position.y + r.size.y + 14.0

	by = clampf(by, 16.0, vp_size.y - b_size.y - 16.0)

	var bx: float = r.position.x + (r.size.x - b_size.x) * 0.5
	bx = clampf(bx, 20.0, vp_size.x - b_size.x - 20.0)

	_text_bubble.position = Vector2(bx, by)

func _start_pulse_animation() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	if _target_highlight == null:
		return

	_target_highlight.modulate.a = 0.55
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_target_highlight, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(_target_highlight, "modulate:a", 0.55, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_why_pressed() -> void:
	if _lbl_why == null:
		return
	_lbl_why.visible = not _lbl_why.visible
	if _btn_why != null:
		_btn_why.text = "Why does this matter? ▴" if _lbl_why.visible else "Why does this matter? ▾"

	var vp_size: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	if vp_size == Vector2.ZERO:
		vp_size = Vector2(1280, 720)
	if _current_rect.size != Vector2.ZERO:
		_reposition_text_bubble(_current_rect, vp_size)
	elif _text_bubble != null:
		_text_bubble.reset_size()
		var b_size := _text_bubble.size
		if b_size == Vector2.ZERO:
			b_size = Vector2(360, 140)
		_text_bubble.position = (vp_size - b_size) * 0.5

func _on_next_pressed() -> void:
	next_pressed.emit()

func _on_back_pressed() -> void:
	back_pressed.emit()

func _on_skip_pressed() -> void:
	skip_pressed.emit()

func _on_show_me_pressed() -> void:
	show_me_pressed.emit()
