class_name Ui
extends RefCounted

const ACCENT := Color("2f81f7")
const WIN := Color("4ade80")
const LOSS := Color("f87171")

static var wipe_covered := false


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
	press_pop(button)


static func press_pop(button: Button) -> void:
	if button.has_meta("juiced"):
		return
	button.set_meta("juiced", true)
	button.button_down.connect(_press_pop.bind(button, 0.95))
	button.button_up.connect(_press_pop.bind(button, 1.0))


static func _press_pop(button: Button, value: float) -> void:
	if value < 1.0:
		Sfx.click()
	button.pivot_offset = button.size * 0.5
	button.create_tween().tween_property(button, "scale", Vector2(value, value), 0.08).set_ease(Tween.EASE_OUT)


static func pop(node: Control, peak := 1.25) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(peak, peak)
	node.create_tween().tween_property(node, "scale", Vector2.ONE, 0.16).set_ease(Tween.EASE_OUT)


static func attach_head(chip: ColorRect, color: Color) -> Head:
	chip.color = Color(0, 0, 0, 0)
	var head := Head.new()
	head.set_anchors_preset(Control.PRESET_FULL_RECT)
	head.apply_color(color)
	chip.add_child(head)
	return head
