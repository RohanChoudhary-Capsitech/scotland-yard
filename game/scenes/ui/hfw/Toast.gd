class_name Toast
extends UIController

## Toast — Notification toast that slides / fades in under the TopBar.
## Displays important game alerts like reveals, player skipped, etc.

@onready var _lbl_message: Label = %LblMessage
@onready var _anim_player: AnimationPlayer = %AnimationPlayer

var _bus: Node

func _on_ready() -> void:
	super._on_ready()
	visible = false

	if _bus == null and get_tree() != null and get_tree().root != null:
		var registry: Node = get_tree().root.get_node_or_null("ServiceRegistry")
		if registry != null and registry.has_method("get_service"):
			_bus = registry.get_service(&"bus") as Node

	if _bus != null and _bus.has_signal("toast_requested"):
		_bus.toast_requested.connect(show_toast)

func set_bus(bus: Node) -> void:
	_bus = bus
	if _bus != null and _bus.has_signal("toast_requested"):
		if not _bus.toast_requested.is_connected(show_toast):
			_bus.toast_requested.connect(show_toast)

func show_toast(msg: String) -> void:
	if _lbl_message != null:
		_lbl_message.text = msg
	if _anim_player != null:
		_anim_player.stop()
		_anim_player.play("fade")
