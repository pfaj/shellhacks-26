extends Control

const POLL_INTERVAL := 2.0

@onready var _title: Label = $Margin/Column/Title
@onready var _status: Label = $Margin/Column/Status
@onready var _auto_button: Button = $Margin/Column/AutoButton
@onready var _room_list: VBoxContainer = $Margin/Column/ListScroll/RoomList
@onready var _back_button: Button = $Margin/Column/BackButton
@onready var _http: HTTPRequest = $RoomsRequest

var _poll_timer := 0.0
var _signature := ""


func _ready() -> void:
	Sfx.play_music("menu")
	_title.add_theme_color_override("font_color", Ui.ACCENT)
	Ui.style_button(_auto_button, Color(0, 0, 0, 0), Ui.ACCENT)
	Ui.style_button(_back_button, Color(0, 0, 0, 0), Ui.ACCENT)
	_auto_button.toggle_mode = true
	_auto_button.button_pressed = Net.spectate_auto
	_refresh_auto_label()
	_auto_button.toggled.connect(_on_auto_toggled)
	_back_button.pressed.connect(_on_back_pressed)
	_http.request_completed.connect(_on_rooms_response)
	_status.text = "Looking for live fights..."
	_fetch()


func _process(delta: float) -> void:
	_poll_timer += delta
	if _poll_timer >= POLL_INTERVAL:
		_poll_timer = 0.0
		_fetch()


func _fetch() -> void:
	_http.request(_rooms_url())


func _rooms_url() -> String:
	var base := Net.RELAY_URL.trim_suffix("/ws")
	if base.begins_with("wss://"):
		base = "https://%s" % base.trim_prefix("wss://")
	return "%s/rooms" % base


func _on_rooms_response(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if code != 200:
		return
	var rooms = JSON.parse_string(body.get_string_from_utf8())
	if typeof(rooms) != TYPE_ARRAY:
		return
	if rooms.is_empty():
		_status.text = "No live fights yet - start one on two phones"
		if _signature != "":
			_signature = ""
			_clear_list()
		return
	rooms.sort_custom(func(a, b): return int(a.get("at", 0)) > int(b.get("at", 0)))
	_status.text = "%d live room%s" % [rooms.size(), "" if rooms.size() == 1 else "s"]
	if Net.spectate_auto:
		_watch(str(rooms[0].get("code", "")))
		return
	var signature := ""
	for room in rooms:
		signature += "%s|%s|%s;" % [room.get("code", ""), room.get("names", []), room.get("colors", [])]
	if signature == _signature:
		return
	_signature = signature
	_clear_list()
	for room in rooms:
		_add_room(room)


func _add_room(room: Dictionary) -> void:
	var names: Array = room.get("names", [])
	var match_name := " vs ".join(names) if names.size() > 0 else "waiting for players"
	var live := int(room.get("present", 0)) >= 2
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 130)
	button.add_theme_font_size_override("font_size", 40)
	button.text = "ROOM %s    %s" % [room.get("code", "?"), match_name]
	if not live:
		button.modulate = Color(1, 1, 1, 0.6)
	Ui.style_button(button, Ui.ACCENT if live else Color(0, 0, 0, 0), Color(0, 0, 0, 0) if live else Ui.ACCENT)
	button.pressed.connect(_watch.bind(str(room.get("code", ""))))
	_room_list.add_child(button)


func _clear_list() -> void:
	for child in _room_list.get_children():
		child.queue_free()


func _watch(code: String) -> void:
	if code.is_empty():
		return
	Net.spectate_room = code
	Fx.goto("res://scenes/spectate_view.tscn")


func _on_auto_toggled(pressed: bool) -> void:
	Net.spectate_auto = pressed
	_refresh_auto_label()
	_fetch()


func _refresh_auto_label() -> void:
	_auto_button.text = "AUTO-FOLLOW: ON" if Net.spectate_auto else "AUTO-FOLLOW: OFF"


func _on_back_pressed() -> void:
	Net.spectate_auto = false
	Fx.goto("res://scenes/main_menu.tscn")
