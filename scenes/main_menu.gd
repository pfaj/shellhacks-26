extends Control

@onready var _logo: TextureRect = $Margin/VBox/Logo
@onready var _banner: Button = $Margin/VBox/RejoinBanner
@onready var _identity: HBoxContainer = $Margin/VBox/IdentityRow
@onready var _dot: Panel = $Margin/VBox/IdentityRow/ColorDot
@onready var _name: Label = $Margin/VBox/IdentityRow/NameLabel
@onready var _wins: Label = $Margin/VBox/IdentityRow/WinsLabel
@onready var _losses: Label = $Margin/VBox/IdentityRow/LossesLabel
@onready var _hint: Label = $Margin/VBox/HintLabel
@onready var _play: Button = $Margin/VBox/PlayButton
@onready var _practice: Button = $Margin/VBox/PracticeButton
@onready var _spectate: Button = $Margin/VBox/SpectateButton

var _tilt_row: HBoxContainer


func _ready() -> void:
	Sfx.play_music("menu")
	Settings.ensure()
	_style_dot(Net.my_color)
	_name.text = Net.my_name
	_wins.text = "%dW" % Net.my_wins
	_losses.text = "%dL" % Net.my_losses
	_banner.visible = not Net.last_room.is_empty() and Net.had_match
	if _banner.visible:
		_banner.text = "REJOIN  %s" % Net.last_room
	Ui.style_button(_play, Ui.ACCENT)
	Ui.style_button(_practice, Color(0, 0, 0, 0), Ui.ACCENT)
	Ui.style_button(_banner, Color(0, 0, 0, 0), Ui.ACCENT)
	Ui.style_button(_spectate, Color(0, 0, 0, 0), Ui.ACCENT)
	_build_tilt_row()
	if _auto_spectate():
		Net.spectate_auto = true
		Fx.goto("res://scenes/spectate_screen.tscn")
		return
	_play_intro()


func _on_rejoin_pressed() -> void:
	Net.rejoin()
	Fx.goto("res://scenes/connect_screen.tscn")


func _on_play_online_pressed() -> void:
	Net.local_mode = false
	Ui.wipe_covered = false
	Fx.goto("res://scenes/connect_screen.tscn")


func _on_practice_pressed() -> void:
	Net.local_mode = true
	Ui.wipe_covered = false
	Net.reset_ready()
	Net.local_rounds = 0
	Net.remote_rounds = 0
	Net.peer_name = "BOT"
	Net.peer_wins = 0
	Net.peer_losses = 0
	Net.peer_color = _bot_color()
	Fx.goto("res://scenes/play_screen.tscn")


func _on_spectate_pressed() -> void:
	Net.spectate_auto = false
	Fx.goto("res://scenes/spectate_screen.tscn")


func _auto_spectate() -> bool:
	if not OS.has_feature("web"):
		return false
	return str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('spectate')")) == "auto"


func _build_tilt_row() -> void:
	_tilt_row = HBoxContainer.new()
	_tilt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tilt_row.add_theme_constant_override("separation", 24)
	var label := Label.new()
	label.text = "TILT SENSITIVITY"
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	_tilt_row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = Settings.TILT_MIN
	slider.max_value = Settings.TILT_MAX
	slider.step = 0.1
	slider.value = Settings.tilt_sensitivity
	slider.custom_minimum_size = Vector2(360, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tilt_row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(110, 0)
	value_label.add_theme_font_size_override("font_size", 28)
	value_label.add_theme_color_override("font_color", Ui.ACCENT)
	value_label.text = "%.1fx" % Settings.tilt_sensitivity
	_tilt_row.add_child(value_label)
	slider.value_changed.connect(_on_tilt_changed.bind(value_label))
	_hint.add_sibling(_tilt_row)
	_hint.get_parent().move_child(_tilt_row, _hint.get_index())


func _on_tilt_changed(value: float, value_label: Label) -> void:
	Settings.set_tilt_sensitivity(value)
	value_label.text = "%.1fx" % Settings.tilt_sensitivity


func _play_intro() -> void:
	await get_tree().process_frame
	var items: Array[Control] = [_identity, _tilt_row, _hint, _play, _practice, _spectate]
	if _banner.visible:
		items.insert(0, _banner)
	_fade_slide(_logo, 0.0)
	var index := 1
	for item in items:
		_fade_slide(item, index * 0.07)
		index += 1
	_start_logo_breath()
	if _banner.visible:
		_pulse(_banner)


func _fade_slide(item: Control, delay: float) -> void:
	item.modulate.a = 0.0
	var tween := item.create_tween().set_parallel(true)
	tween.tween_property(item, "modulate:a", 1.0, 0.35).set_delay(delay)
	tween.tween_property(item, "position:y", item.position.y, 0.45).from(item.position.y + 46.0).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _start_logo_breath() -> void:
	_logo.pivot_offset = _logo.size * 0.5
	var tween := _logo.create_tween().set_loops()
	tween.tween_interval(0.6)
	tween.tween_property(_logo, "scale", Vector2(1.035, 1.035), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_logo, "scale", Vector2.ONE, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _pulse(button: Button) -> void:
	var tween := button.create_tween().set_loops()
	tween.tween_property(button, "modulate:a", 0.7, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(button, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)


func _style_dot(color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(22)
	_dot.add_theme_stylebox_override("panel", style)


func _bot_color() -> Color:
	return Color("2f81f7") if Net.my_color.r > 0.5 else Color("e5424a")
