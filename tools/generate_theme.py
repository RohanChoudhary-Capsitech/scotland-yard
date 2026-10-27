"""Writes game/assets/Theme.tres — the single UI theme (design tokens + type variations).
Run from the project root: python3 tools/generate_theme.py
"""
INK = (0.055, 0.078, 0.141)
SURF = (0.094, 0.125, 0.212)
SURF2 = (0.133, 0.173, 0.275)
TEXT = (0.957, 0.965, 0.984)
MUTED = (0.592, 0.639, 0.741)
GOLD = (1.0, 0.761, 0.239)
GOLD_D = (0.85, 0.58, 0.10)
LINE = (1, 1, 1, 0.10)

subs, props = [], []

def col(c, a=1.0):
    if len(c) == 4:
        a = c[3]
    return "Color(%.3f, %.3f, %.3f, %.3f)" % (c[0], c[1], c[2], a)

def box(bg, r=14, border=0, bcol=LINE, lip=0, lipcol=None, m=(16, 10, 16, 10), shadow=0, sh_a=0.35, top_off=0):
    sid = "sb%d" % len(subs)
    lines = ['[sub_resource type="StyleBoxFlat" id="%s"]' % sid,
             "content_margin_left = %.1f" % m[0], "content_margin_top = %.1f" % (m[1] + top_off),
             "content_margin_right = %.1f" % m[2], "content_margin_bottom = %.1f" % m[3],
             "bg_color = %s" % (col(bg) if len(bg) == 4 else col(bg, 1.0))]
    if border:
        lines += ["border_width_left = %d" % border, "border_width_top = %d" % border,
                  "border_width_right = %d" % border, "border_width_bottom = %d" % (border + lip),
                  "border_color = %s" % col(bcol)]
    elif lip:
        lines += ["border_width_bottom = %d" % lip, "border_color = %s" % col(lipcol or (0, 0, 0, 0.35))]
    lines += ["corner_radius_top_left = %d" % r, "corner_radius_top_right = %d" % r,
              "corner_radius_bottom_right = %d" % r, "corner_radius_bottom_left = %d" % r,
              "corner_detail = 6", "anti_aliasing_size = 1.2"]
    if shadow:
        lines += ["shadow_color = Color(0, 0, 0, %.2f)" % sh_a, "shadow_size = %d" % shadow, "shadow_offset = Vector2(0, %d)" % max(2, shadow // 4)]
    subs.append("\n".join(lines))
    return 'SubResource("%s")' % sid

def empty():
    sid = "sb%d" % len(subs)
    subs.append('[sub_resource type="StyleBoxEmpty" id="%s"]' % sid)
    return 'SubResource("%s")' % sid

def p(k, v):
    props.append("%s = %s" % (k, v))

def button(t, bg, hover, pressed, fc, lip, lipcol, r=14, m=(16, 10, 16, 10), border=0, bcol=LINE, fc_hover=None, toggled=None):
    p(t + "/styles/normal", box(bg, r, border, bcol, lip, lipcol, m))
    p(t + "/styles/hover", box(hover, r, border, bcol, lip, lipcol, m))
    p(t + "/styles/pressed", box(pressed, r, border, bcol, 1 if lip else 0, lipcol, m, top_off=(lip - 1) if lip else 0))
    p(t + "/styles/hover_pressed", box(pressed, r, border, bcol, 1 if lip else 0, lipcol, m, top_off=(lip - 1) if lip else 0))
    p(t + "/styles/disabled", box(tuple(list(bg[:3]) + [0.35]), r, border, bcol, lip, (0, 0, 0, 0.15), m))
    p(t + "/styles/focus", box((0, 0, 0, 0), r, 2, (GOLD[0], GOLD[1], GOLD[2], 0.8), 0, None, (0, 0, 0, 0)))
    for k in ("font_color", "font_focus_color"):
        p(t + "/colors/" + k, col(fc))
    for k in ("font_hover_color", "font_pressed_color", "font_hover_pressed_color"):
        p(t + "/colors/" + k, col(fc_hover or fc))
    for k in ("icon_normal_color", "icon_focus_color"):
        p(t + "/colors/" + k, col(fc))
    for k in ("icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"):
        p(t + "/colors/" + k, col(fc_hover or fc))
    p(t + "/colors/font_disabled_color", col(fc, 0.4))
    p(t + "/colors/icon_disabled_color", col(fc, 0.4))
    if toggled:
        tb, tbc, tfc = toggled
        p(t + "/styles/pressed", box(tb, r, 2, tbc, 0, None, m))
        p(t + "/styles/hover_pressed", box(tb, r, 2, tbc, 0, None, m))
        for k in ("font_pressed_color", "font_hover_pressed_color", "icon_pressed_color", "icon_hover_pressed_color"):
            p(t + "/colors/" + k, col(tfc))

def variation(t, base):
    p(t + "/base_type", '&"%s"' % base)

ext = [
    ('FontFile', 'res://game/assets/fonts/Inter-SemiBold.ttf', 'f_semi'),
    ('FontFile', 'res://game/assets/fonts/Inter-Bold.ttf', 'f_bold'),
    ('FontFile', 'res://game/assets/fonts/InterDisplay-Black.ttf', 'f_black'),
    ('Texture2D', 'res://game/assets/sprites/single/ui/icons/toggle_on.svg', 't_on'),
    ('Texture2D', 'res://game/assets/sprites/single/ui/icons/toggle_off.svg', 't_off'),
]
E = lambda i: 'ExtResource("%s")' % i

p("default_font", E("f_semi"))
p("default_font_size", 16)

# Labels
p("Label/colors/font_color", col(TEXT))
p("Label/colors/font_shadow_color", "Color(0, 0, 0, 0)")
for name, font, size, color in [
    ("LabelTitle", "f_black", 44, TEXT), ("LabelHeading", "f_bold", 20, TEXT),
    ("LabelCaps", "f_bold", 12, MUTED), ("LabelMuted", "f_semi", 14, MUTED),
    ("LabelNumber", "f_black", 22, TEXT), ("LabelGold", "f_bold", 15, GOLD),
]:
    variation(name, "Label")
    p(name + "/fonts/font", E(font))
    p(name + "/font_sizes/font_size", size)
    p(name + "/colors/font_color", col(color))

# Panels
glass = box((INK[0], INK[1], INK[2], 0.92), 20, 1, LINE, 0, None, (14, 12, 14, 12), shadow=18)
p("PanelContainer/styles/panel", glass)
p("Panel/styles/panel", glass)
for name, sb in [
    ("PanelCard", box(SURF, 16, 1, LINE, 0, None, (12, 10, 12, 10))),
    ("PanelChip", box((1, 1, 1, 0.07), 10, 0, LINE, 0, None, (8, 3, 9, 3))),
    ("PanelModal", box((INK[0], INK[1], INK[2], 0.98), 26, 1, (1, 1, 1, 0.14), 0, None, (28, 24, 28, 24), shadow=40, sh_a=0.55)),
    ("PanelBar", box((INK[0], INK[1], INK[2], 0.90), 18, 1, LINE, 0, None, (10, 6, 10, 6), shadow=14)),
    ("PanelBadge", box(GOLD, 999, 0, LINE, 0, None, (14, 5, 14, 5))),
]:
    variation(name, "PanelContainer")
    p(name + "/styles/panel", sb)

# Buttons
p("Button/fonts/font", E("f_bold"))
p("Button/font_sizes/font_size", 16)
p("Button/constants/h_separation", 8)
p("Button/constants/icon_max_width", 22)
button("Button", SURF2, (0.17, 0.22, 0.34), (0.11, 0.15, 0.24), TEXT, 3, (0.03, 0.05, 0.10, 0.9))
variation("ButtonPrimary", "Button")
button("ButtonPrimary", GOLD, (1.0, 0.82, 0.40), (0.95, 0.70, 0.20), (0.11, 0.08, 0.02), 4, GOLD_D, r=16, m=(22, 12, 22, 12))
p("ButtonPrimary/font_sizes/font_size", 19)
p("ButtonPrimary/fonts/font", E("f_black"))
variation("ButtonGhost", "Button")
button("ButtonGhost", (0, 0, 0, 0), (1, 1, 1, 0.08), (1, 1, 1, 0.12), MUTED, 0, None, fc_hover=TEXT)
variation("ButtonIcon", "Button")
button("ButtonIcon", SURF2, (0.17, 0.22, 0.34), (0.11, 0.15, 0.24), TEXT, 3, (0.03, 0.05, 0.10, 0.9), r=14, m=(10, 9, 10, 9))
variation("ButtonPill", "Button")
button("ButtonPill", SURF, (0.14, 0.18, 0.29), (0.12, 0.15, 0.25), MUTED, 0, None, r=999, m=(16, 9, 16, 9), border=1, bcol=(1, 1, 1, 0.12),
       fc_hover=TEXT, toggled=((GOLD[0], GOLD[1], GOLD[2], 0.16), GOLD, GOLD))
for name, c in [("ButtonTaxi", (0.961, 0.773, 0.259)), ("ButtonBus", (0.231, 0.769, 0.541)),
                ("ButtonMetro", (0.910, 0.271, 0.478)), ("ButtonBlack", (0.10, 0.11, 0.15))]:
    variation(name, "Button")
    dark = tuple(x * 0.68 for x in c)
    fc = (0.08, 0.08, 0.10) if name in ("ButtonTaxi", "ButtonBus") else TEXT
    button(name, c, tuple(min(1, x * 1.1 + 0.03) for x in c), tuple(x * 0.92 for x in c), fc, 4, dark, r=16, m=(14, 10, 14, 10))

# CheckBox as a toggle switch
p("CheckBox/icons/checked", E("t_on"))
p("CheckBox/icons/unchecked", E("t_off"))
p("CheckBox/icons/checked_disabled", E("t_on"))
p("CheckBox/icons/unchecked_disabled", E("t_off"))
p("CheckBox/constants/h_separation", 12)
p("CheckBox/fonts/font", E("f_bold"))
for st in ("normal", "pressed", "hover", "hover_pressed", "disabled"):
    p("CheckBox/styles/" + st, box(SURF, 14, 1, LINE, 0, None, (14, 8, 16, 8)))
p("CheckBox/styles/focus", empty())
for k in ("font_color", "font_hover_color", "font_focus_color"):
    p("CheckBox/colors/" + k, col(MUTED))
for k in ("font_pressed_color", "font_hover_pressed_color"):
    p("CheckBox/colors/" + k, col(TEXT))

# Inputs
p("LineEdit/styles/normal", box(SURF, 12, 1, LINE, 0, None, (12, 8, 12, 8)))
p("LineEdit/styles/focus", box(SURF2, 12, 2, GOLD, 0, None, (12, 8, 12, 8)))
p("LineEdit/colors/font_color", col(TEXT))
p("LineEdit/colors/caret_color", col(GOLD))
p("LineEdit/colors/selection_color", col(GOLD, 0.35))
p("LineEdit/font_sizes/font_size", 15)

# Scrollbars
p("VScrollBar/styles/scroll", box((1, 1, 1, 0.04), 4, 0, LINE, 0, None, (2, 2, 2, 2)))
p("VScrollBar/styles/grabber", box((1, 1, 1, 0.22), 4, 0, LINE, 0, None, (2, 2, 2, 2)))
p("VScrollBar/styles/grabber_highlight", box((1, 1, 1, 0.32), 4, 0, LINE, 0, None, (2, 2, 2, 2)))
p("VScrollBar/styles/grabber_pressed", box(GOLD, 4, 0, LINE, 0, None, (2, 2, 2, 2)))

out = ['[gd_resource type="Theme" format=3 uid="uid://dx4dq8bcnbcie"]', ""]
for t, path, i in ext:
    out.append('[ext_resource type="%s" path="%s" id="%s"]' % (t, path, i))
out.append("")
for s in subs:
    out += [s, ""]
out.append("[resource]")
out += props
open("game/assets/Theme.tres", "w").write("\n".join(out) + "\n")
print("Theme.tres: %d styleboxes, %d properties" % (len(subs), len(props)))
