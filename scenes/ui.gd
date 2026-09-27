class_name Ui
extends RefCounted

const ACCENT := Color("2f81f7")
const WIN := Color("4ade80")
const LOSS := Color("f87171")


static func flat(bg: Color, border := Color(0, 0, 0, 0), radius := 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.content_margin_left = 48.0
	style.content_margin_right = 48.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	if border.a > 0.0:
		style.set_border_width_all(4)
		style.border_color = border
	return style


static func style_button(button: Button, bg: Color, border := Color(0, 0, 0, 0)) -> void:
	button.add_theme_stylebox_override("normal", flat(bg, border))
	button.add_theme_stylebox_override("hover", flat(bg.lightened(0.12), border))
	button.add_theme_stylebox_override("pressed", flat(bg.darkened(0.2), border))
	button.add_theme_stylebox_override("focus", flat(bg, border))


static func attach_head(chip: ColorRect, color: Color) -> Head:
	chip.color = Color(0, 0, 0, 0)
	var head := Head.new()
	head.set_anchors_preset(Control.PRESET_FULL_RECT)
	head.apply_color(color)
	chip.add_child(head)
	return head
