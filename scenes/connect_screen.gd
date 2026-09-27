extends Control

@onready var _title: Label = $Margin/Column/Title
@onready var _create_button: Button = $Margin/Column/CreateButton
@onready var _code_input: LineEdit = $Margin/Column/JoinRow/CodeInput
@onready var _join_button: Button = $Margin/Column/JoinRow/JoinButton
@onready var _status: Label = $Margin/Column/Status
@onready var _profile_label: Label = $Margin/Column/ProfileLabel
@onready var _back_button: Button = $Margin/Column/BackButton


func _ready() -> void:
	Sfx.play_music("menu")
	Net.local_mode = false
	_profile_label.text = "PLAYING AS  %s" % Net.my_name
	_title.add_theme_color_override("font_color", Ui.ACCENT)
	Ui.style_button(_create_button, Ui.ACCENT)
	Ui.style_button(_join_button, Color(0, 0, 0, 0), Ui.ACCENT)
	Ui.style_button(_back_button, Color(0, 0, 0, 0), Ui.ACCENT)
	_create_button.pressed.connect(_on_create_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_code_input.text_changed.connect(_on_code_changed)
	Net.status_changed.connect(_on_status_changed)
	Net.joined.connect(_on_joined)
	Net.room_full.connect(_on_room_full)
	_play_intro()
	var room := _room_from_url()
	if not room.is_empty():
		_code_input.text = room
		_on_join_pressed()
	if OS.has_feature("web"):
		WebTextInput.attach(_code_input)
		WebTextInput.refresh.call_deferred()


func _play_intro() -> void:
	await get_tree().process_frame
	var items: Array[Control] = [_profile_label, _create_button, _join_button, _back_button]
	for i in items.size():
		var item := items[i]
		item.modulate.a = 0.0
		item.create_tween().tween_property(item, "modulate:a", 1.0, 0.35).set_delay(0.1 + i * 0.07)
	_title.modulate.a = 0.0
	_title.create_tween().tween_property(_title, "modulate:a", 1.0, 0.45)


func _on_create_pressed() -> void:
	_status.text = "Creating room..."
	Net.host()


func _on_join_pressed() -> void:
	var code := _code_input.text.strip_edges().to_upper()
	if code.length() < 4:
		_status.text = "Enter the 4-letter room code"
		return
	_status.text = "Joining %s..." % code
	Net.join(code)


func _on_joined() -> void:
	Fx.goto("res://scenes/lobby_screen.tscn")


func _on_status_changed(text: String) -> void:
	_status.text = text
	_status.modulate.a = 0.35
	_status.create_tween().tween_property(_status, "modulate:a", 1.0, 0.25)


func _on_room_full() -> void:
	_status.text = "That room is already full"


func _on_code_changed(new_text: String) -> void:
	var upper := new_text.to_upper()
	if upper != new_text:
		_code_input.text = upper
		_code_input.caret_column = upper.length()


func _on_back_pressed() -> void:
	Net.leave()
	Fx.goto("res://scenes/main_menu.tscn")


func _room_from_url() -> String:
	if not OS.has_feature("web"):
		return ""
	return str(JavaScriptBridge.eval("sockemGetRoom()"))
