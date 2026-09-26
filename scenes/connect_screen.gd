extends Control

@onready var _create_button: Button = $Margin/Column/CreateButton
@onready var _code_input: LineEdit = $Margin/Column/JoinRow/CodeInput
@onready var _join_button: Button = $Margin/Column/JoinRow/JoinButton
@onready var _status: Label = $Margin/Column/Status
@onready var _profile_label: Label = $Margin/Column/ProfileLabel
@onready var _back_button: Button = $Margin/Column/BackButton


func _ready() -> void:
	Sfx.play_music("menu")
	_profile_label.text = "PLAYING AS  %s" % Net.my_name
	_create_button.pressed.connect(_on_create_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_code_input.text_changed.connect(_on_code_changed)
	Net.status_changed.connect(_on_status_changed)
	Net.joined.connect(_on_joined)
	Net.room_full.connect(_on_room_full)
	var room := _room_from_url()
	if not room.is_empty():
		_code_input.text = room
		_on_join_pressed()


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
	get_tree().change_scene_to_file("res://scenes/lobby_screen.tscn")


func _on_status_changed(text: String) -> void:
	_status.text = text


func _on_room_full() -> void:
	_status.text = "That room is already full"


func _on_code_changed(new_text: String) -> void:
	var upper := new_text.to_upper()
	if upper != new_text:
		_code_input.text = upper
		_code_input.caret_column = upper.length()


func _on_back_pressed() -> void:
	Net.leave()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _room_from_url() -> String:
	if not OS.has_feature("web"):
		return ""
	return str(JavaScriptBridge.eval("sockemGetRoom()"))
