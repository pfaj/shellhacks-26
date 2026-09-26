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
@onready var _qr: TextureRect = $Margin/Column/QrTexture
@onready var _qr_hint: Label = $Margin/Column/QrHint
@onready var _fighters: HBoxContainer = $Margin/Column/Fighters
@onready var _name_input: LineEdit = $Margin/Column/Fighters/LeftPanel/NameInput
@onready var _color_row: HBoxContainer = $Margin/Column/Fighters/LeftPanel/ColorRow
@onready var _ready_button: Button = $Margin/Column/Fighters/LeftPanel/ReadyButton
@onready var _right_color: ColorRect = $Margin/Column/Fighters/RightPanel/RightColor
@onready var _right_name: Label = $Margin/Column/Fighters/RightPanel/RightName
@onready var _right_ready: Label = $Margin/Column/Fighters/RightPanel/RightReady
@onready var _back_button: Button = $Margin/Column/BackButton

var _selected := 0


func _ready() -> void:
	_room_label.text = "ROOM  %s" % Net.room_code
	_status.text = "Waiting for opponent..."
	_qr.texture = _make_qr_texture(_join_url())
	_name_input.text = Net.my_name
	_selected = _closest_swatch(Net.my_color)
	_build_swatches()
	_refresh_swatches()
	_right_name.text = Net.peer_name
	_right_color.color = Net.peer_color
	_refresh_peer_ready(Net.peer_ready)
	_ready_button.pressed.connect(_on_ready_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_name_input.text_changed.connect(_on_name_changed)
	Net.status_changed.connect(_on_status_changed)
	Net.room_ready.connect(_on_room_ready)
	Net.peer_profile.connect(_on_peer_profile)
	Net.peer_ready_changed.connect(_on_peer_ready_changed)
	Net.peer_left.connect(_on_peer_left)
	if Net.peer_connected:
		_on_room_ready()
	else:
		_show_waiting()


func _show_waiting() -> void:
	_qr.visible = true
	_qr_hint.visible = true
	_fighters.visible = false
	_ready_button.disabled = true
	_ready_button.text = "READY"
	Net.reset_ready()


func _on_room_ready() -> void:
	_qr.visible = false
	_qr_hint.visible = false
	_fighters.visible = true
	_ready_button.disabled = false
	_refresh_peer_ready(Net.peer_ready)
	_status.text = "Set your name and color, then ready up"


func _on_name_changed(new_text: String) -> void:
	if new_text.strip_edges().is_empty():
		return
	Net.save_profile(new_text, SWATCHES[_selected])
	Net.broadcast_profile()


func _on_swatch_pressed(index: int) -> void:
	_selected = index
	_refresh_swatches()
	Net.save_profile(_name_input.text, SWATCHES[_selected])
	Net.broadcast_profile()


func _on_ready_pressed() -> void:
	Net.send_ready(not Net.my_ready)
	_ready_button.text = "CANCEL READY" if Net.my_ready else "READY"
	_check_both_ready()


func _on_peer_profile(peer_name: String, peer_color: Color) -> void:
	_right_name.text = peer_name
	_right_color.color = peer_color


func _on_peer_ready_changed(value: bool) -> void:
	_refresh_peer_ready(value)
	_check_both_ready()


func _refresh_peer_ready(value: bool) -> void:
	_right_ready.text = "READY" if value else "NOT READY"
	_right_ready.modulate = Color(0.3, 1.0, 0.4) if value else Color(1, 1, 1, 0.6)


func _check_both_ready() -> void:
	if Net.my_ready and Net.peer_ready:
		get_tree().change_scene_to_file("res://scenes/prematch_screen.tscn")


func _on_peer_left() -> void:
	_status.text = "Opponent left - waiting for a new opponent..."
	_show_waiting()


func _on_status_changed(text: String) -> void:
	_status.text = text


func _on_back_pressed() -> void:
	Net.leave()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _build_swatches() -> void:
	for i in SWATCHES.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(84, 84)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_swatch_pressed.bind(i))
		_color_row.add_child(button)


func _refresh_swatches() -> void:
	for i in _color_row.get_child_count():
		var button: Button = _color_row.get_child(i)
		var style := StyleBoxFlat.new()
		style.bg_color = SWATCHES[i]
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		if i == _selected:
			style.border_width_left = 8
			style.border_width_top = 8
			style.border_width_right = 8
			style.border_width_bottom = 8
			style.border_color = Color.WHITE
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
	var data_url := str(JavaScriptBridge.eval("sockemQRPng(%s, 512)" % JSON.stringify(url)))
	var prefix := "data:image/png;base64,"
	if not data_url.begins_with(prefix):
		return null
	var png := Marshalls.base64_to_raw(data_url.trim_prefix(prefix))
	var image := Image.new()
	if image.load_png_from_buffer(png) != OK:
		return null
	return ImageTexture.create_from_image(image)
