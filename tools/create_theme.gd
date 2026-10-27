extends SceneTree

func _init() -> void:
	var theme := Theme.new()

	# 1. Colors
	var panel_bg := Color(0.141, 0.114, 0.259, 0.92) # #241D42 @ 92%
	var btn_normal_bg := Color(0.21, 0.17, 0.38, 1.0) # #352C61
	var btn_hover_bg := Color(0.27, 0.22, 0.48, 1.0) # #45387A
	var btn_pressed_bg := Color(0.16, 0.13, 0.30, 1.0) # #29214D
	var btn_disabled_bg := Color(0.11, 0.09, 0.20, 0.6)

	# 2. Panel StyleBoxFlat (16px rounded with soft shadow)
	var panel_box := StyleBoxFlat.new()
	panel_box.bg_color = panel_bg
	panel_box.set_corner_radius_all(16)
	panel_box.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	panel_box.shadow_size = 8
	panel_box.shadow_offset = Vector2(0, 3)
	panel_box.content_margin_left = 14
	panel_box.content_margin_right = 14
	panel_box.content_margin_top = 10
	panel_box.content_margin_bottom = 10

	theme.set_stylebox("panel", "Panel", panel_box)
	theme.set_stylebox("panel", "PanelContainer", panel_box)

	# 3. Pill Button Styles (24px radius, min 48px touch friendly)
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = btn_normal_bg
	btn_normal.set_corner_radius_all(24)
	btn_normal.content_margin_left = 18
	btn_normal.content_margin_right = 18
	btn_normal.content_margin_top = 12
	btn_normal.content_margin_bottom = 12
	btn_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.2)
	btn_normal.shadow_size = 4
	btn_normal.shadow_offset = Vector2(0, 2)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = btn_hover_bg
	btn_hover.set_corner_radius_all(24)
	btn_hover.content_margin_left = 18
	btn_hover.content_margin_right = 18
	btn_hover.content_margin_top = 12
	btn_hover.content_margin_bottom = 12
	btn_hover.border_width_left = 1
	btn_hover.border_width_right = 1
	btn_hover.border_width_top = 1
	btn_hover.border_width_bottom = 1
	btn_hover.border_color = Color(0.65, 0.58, 0.98, 0.7)

	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = btn_pressed_bg
	btn_pressed.set_corner_radius_all(24)
	btn_pressed.content_margin_left = 18
	btn_pressed.content_margin_right = 18
	btn_pressed.content_margin_top = 12
	btn_pressed.content_margin_bottom = 12

	var btn_disabled := StyleBoxFlat.new()
	btn_disabled.bg_color = btn_disabled_bg
	btn_disabled.set_corner_radius_all(24)
	btn_disabled.content_margin_left = 18
	btn_disabled.content_margin_right = 18
	btn_disabled.content_margin_top = 12
	btn_disabled.content_margin_bottom = 12

	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("disabled", "Button", btn_disabled)

	# 4. Font sizes and colors
	theme.set_font_size("font_size", "Button", 16)
	theme.set_font_size("font_size", "Label", 16)
	theme.set_color("font_color", "Button", Color(1, 1, 1, 1))
	theme.set_color("font_color", "Label", Color(0.95, 0.95, 0.98, 1))

	var err := ResourceSaver.save(theme, "res://game/assets/Theme.tres")
	if err == OK:
		print("Theme.tres saved successfully!")
		quit(0)
	else:
		printerr("Failed to save Theme.tres: %d" % err)
		quit(1)
