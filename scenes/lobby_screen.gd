extends Control

const SWATCHES: Array[Color] = [
	Color("e5424a"),
	Color("f2862a"),
	Color("f2d02a"),
	Color("3fb950"),
	Color("2f81f7"),
	Color("a371f7"),
]

@onready var _room_label: Label = $Margin/Column/RoomLabel
@onready var _status: Label = $Margin/Column/Status
@onready var _qr_card: Panel = $Margin/Column/QrCard
@onready var _qr: TextureRect = $Margin/Column/QrCard/QrTexture
@onready var _qr_hint: Label = $Margin/Column/QrHint
@onready var _fighters: HBoxContainer = $Margin/Column/Fighters
@onready var _left_chip: ColorRect = $Margin/Column/Fighters/LeftPanel/LeftColor
@onready var _name_input: LineEdit = $Margin/Column/Fighters/LeftPanel/NameInput
@onready var _color_row: GridContainer = $Margin/Column/Fighters/LeftPanel/ColorRow
@onready var _left_ready: Label = $Margin/Column/Fighters/LeftPanel/LeftReady
@onready var _versus: Label = $Margin/Column/Fighters/Versus/VersusLabel
@onready var _right_chip: ColorRect = $Margin/Column/Fighters/RightPanel/RightColor
@onready var _right_name: Label = $Margin/Column/Fighters/RightPanel/RightName
@onready var _right_ready: Label = $Margin/Column/Fighters/RightPanel/RightReady
@onready var _ready_button: Button = $Margin/Column/ReadyButton
@onready var _back_button: Button = $Margin/Column/BackButton

var _selected := 0
var _left_portrait: Head
var _right_portrait: Head
var _bobbing := false
var _going := false


func _ready() -> void:
	Sfx.play_music("menu")
	_room_label.text = "ROOM  %s" % Net.room_code
	_room_label.add_theme_color_override("font_color", Ui.ACCENT)
	_status.text = "Waiting for opponent..."
	_qr.texture = _make_qr_texture(_join_url())
	_style_qr_card()
	_name_input.text = Net.my_name
	_selected = _closest_swatch(Net.my_color)
	_left_portrait = Ui.attach_head(_left_chip, SWATCHES[_selected])
	_build_swatches()
	_refresh_swatches()
	_right_name.text = Net.peer_name
	_right_portrait = Ui.attach_head(_right_chip, Net.peer_color)
	Ui.style_button(_ready_button, Ui.ACCENT)
	Ui.style_button(_back_button, Color(0, 0, 0, 0), Ui.ACCENT)
	_refresh_my_ready()
	_refresh_peer_ready(Net.peer_ready)
	_ready_button.pressed.connect(_on_ready_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_name_input.text_changed.connect(_on_name_changed)
	Net.status_changed.connect(_on_status_changed)
	Net.room_ready.connect(_on_room_ready)
	Net.peer_profile.connect(_on_peer_profile)
	Net.peer_ready_changed.connect(_on_peer_ready_changed)
	Net.peer_left.connect(_on_peer_left)
	_play_intro()
	if Net.peer_connected:
		_on_room_ready()
	else:
		_show_waiting()
	if OS.has_feature("web"):
		WebTextInput.attach(_name_input)
		WebTextInput.refresh.call_deferred()


func _show_waiting() -> void:
	_qr_card.visible = true
	_qr_hint.visible = true
	_fighters.visible = false
	_ready_button.visible = false
	Net.reset_ready()
	_refresh_my_ready()
	Ui.pop(_qr_card, 1.05)


func _on_room_ready() -> void:
	_qr_card.visible = false
	_qr_hint.visible = false
	_fighters.visible = true
	_ready_button.visible = true
	if OS.has_feature("web"):
		WebTextInput.refresh.call_deferred()
	_refresh_peer_ready(Net.peer_ready)
	_status.text = "Set your name and color, then ready up"
	_bob_portraits()


func _on_name_changed(new_text: String) -> void:
	if new_text.strip_edges().is_empty():
		return
	Net.save_profile(new_text, SWATCHES[_selected])
	Net.broadcast_profile()


func _on_swatch_pressed(index: int) -> void:
	_selected = index
	_refresh_swatches()
	_left_portrait.apply_color(SWATCHES[index])
	Ui.pop(_left_portrait, 1.12)
	Net.save_profile(_name_input.text, SWATCHES[_selected])
	Net.broadcast_profile()


func _on_ready_pressed() -> void:
	Net.send_ready(not Net.my_ready)
	_refresh_my_ready()
	_check_both_ready()


func _on_peer_profile(peer_name: String, peer_color: Color) -> void:
	_right_name.text = peer_name
	_right_portrait.apply_color(peer_color)
	Ui.pop(_right_portrait, 1.12)


func _on_peer_ready_changed(value: bool) -> void:
	_refresh_peer_ready(value)
	_check_both_ready()


func _refresh_my_ready() -> void:
	_left_ready.text = "READY" if Net.my_ready else "NOT READY"
	_left_ready.modulate = Ui.WIN if Net.my_ready else Color(1, 1, 1, 0.6)
	_ready_button.text = "CANCEL READY" if Net.my_ready else "READY"
	Ui.style_button(_ready_button, Ui.WIN if Net.my_ready else Ui.ACCENT)
	Ui.pop(_left_ready, 1.18)


func _refresh_peer_ready(value: bool) -> void:
	_right_ready.text = "READY" if value else "NOT READY"
	_right_ready.modulate = Ui.WIN if value else Color(1, 1, 1, 0.6)
	Ui.pop(_right_ready, 1.18)


func _check_both_ready() -> void:
	if Net.my_ready and Net.peer_ready:
		_start_match()


func _start_match() -> void:
	if _going:
		return
	_going = true
	var wipe := Wipe.new()
	wipe.setup(Net.my_color, Net.peer_color)
	add_child(wipe)
	await wipe.cover()
	Ui.wipe_covered = true
	get_tree().change_scene_to_file("res://scenes/play_screen.tscn")


func _on_peer_left() -> void:
	_status.text = "Opponent left - waiting for a new opponent..."
	_show_waiting()


func _on_status_changed(text: String) -> void:
	_status.text = text


func _on_back_pressed() -> void:
	Net.leave()
	Fx.goto("res://scenes/main_menu.tscn")


func _style_qr_card() -> void:
	var style := Ui.flat(Color(1, 1, 1), Color(0, 0, 0, 0), 30)
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 24
	_qr_card.add_theme_stylebox_override("panel", style)


func _play_intro() -> void:
	await get_tree().process_frame
	var items: Array[Control] = [_room_label, _status]
	if _fighters.visible:
		items.append(_fighters)
	else:
		items.append(_qr_card)
	for i in items.size():
		var item := items[i]
		item.modulate.a = 0.0
		item.create_tween().tween_property(item, "modulate:a", 1.0, 0.4).set_delay(i * 0.08)
	_pulse_versus()


func _bob_portraits() -> void:
	if _bobbing:
		return
	_bobbing = true
	_bob(_left_portrait)
	_bob(_right_portrait)


func _bob(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	var tween := node.create_tween().set_loops()
	tween.tween_property(node, "position:y", -9.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "position:y", 0.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _pulse_versus() -> void:
	_versus.pivot_offset = _versus.size * 0.5
	var tween := _versus.create_tween().set_loops()
	tween.tween_property(_versus, "scale", Vector2(1.12, 1.12), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_versus, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _build_swatches() -> void:
	for i in SWATCHES.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(110, 110)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_swatch_pressed.bind(i))
		Ui.press_pop(button)
		var head := Head.new()
		head.set_anchors_preset(Control.PRESET_FULL_RECT)
		head.offset_left = 10.0
		head.offset_top = 10.0
		head.offset_right = -10.0
		head.offset_bottom = -10.0
		head.apply_color(SWATCHES[i])
		button.add_child(head)
		_color_row.add_child(button)


func _refresh_swatches() -> void:
	for i in _color_row.get_child_count():
		var button: Button = _color_row.get_child(i)
		var style := Ui.flat(Color(0, 0, 0, 0), Color.WHITE if i == _selected else Color(0, 0, 0, 0), 14)
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, style)


func _closest_swatch(color: Color) -> int:
	var best := 0
	var best_distance := INF
	for i in SWATCHES.size():
		var distance := absf(SWATCHES[i].r - color.r) + absf(SWATCHES[i].g - color.g) + absf(SWATCHES[i].b - color.b)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best


func _join_url() -> String:
	if not OS.has_feature("web"):
		return ""
	var base := str(JavaScriptBridge.eval("window.location.origin + window.location.pathname"))
	return "%s?room=%s" % [base, Net.room_code]


func _make_qr_texture(url: String) -> Texture2D:
	if not OS.has_feature("web") or url.is_empty():
		return null
	var data_url := str(JavaScriptBridge.eval("clankerQRPng(%s, 512)" % JSON.stringify(url)))
	var prefix := "data:image/png;base64,"
	if not data_url.begins_with(prefix):
		return null
	var png := Marshalls.base64_to_raw(data_url.trim_prefix(prefix))
	var image := Image.new()
	if image.load_png_from_buffer(png) != OK:
		return null
	return ImageTexture.create_from_image(image)
