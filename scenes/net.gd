extends Node

signal status_changed(text: String)
signal joined()
signal room_ready()
signal room_full()
signal peer_left()
signal peer_profile(peer_name: String, peer_color: Color)
signal peer_ready_changed(value: bool)
signal peer_message(message: Dictionary)

const RELAY_URL := "wss://sockem-relay.bdebiase2.workers.dev/ws"

var my_name := "Player"
var my_color := Color(0.9, 0.26, 0.29)
var my_wins := 0
var my_losses := 0
var my_ready := false
var peer_name := "Opponent"
var peer_color := Color(0.25, 0.55, 0.95)
var peer_wins := 0
var peer_losses := 0
var peer_ready := false
var peer_connected := false
var room_code := ""
var my_slot := -1
var local_rounds := 0
var remote_rounds := 0

var _socket := WebSocketPeer.new()
var _active := false


func _ready() -> void:
	set_process(false)
	_load_profile()


func host() -> void:
	_start(_make_code())


func join(code: String) -> void:
	_start(code.strip_edges().to_upper())


func leave() -> void:
	_active = false
	set_process(false)
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()
	room_code = ""
	my_slot = -1
	reset_ready()
	peer_connected = false
	local_rounds = 0
	remote_rounds = 0
	peer_wins = 0
	peer_losses = 0


func send(message: Dictionary) -> void:
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text(JSON.stringify(message))


func send_ready(value: bool) -> void:
	my_ready = value
	send({"t": Protocol.SET_READY, "value": value})


func reset_ready() -> void:
	my_ready = false
	peer_ready = false


func save_profile(new_name: String, new_color: Color) -> void:
	my_name = new_name.strip_edges()
	if my_name.is_empty():
		my_name = "Player"
	my_color = new_color
	_save_profile()


func add_win() -> void:
	my_wins += 1
	_save_profile()


func add_loss() -> void:
	my_losses += 1
	_save_profile()


func broadcast_profile() -> void:
	send({
		"t": Protocol.PROFILE,
		"name": my_name,
		"color": my_color.to_html(false),
		"wins": my_wins,
		"losses": my_losses,
	})


func _save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "name", my_name)
	config.set_value("profile", "color", my_color)
	config.set_value("profile", "wins", my_wins)
	config.set_value("profile", "losses", my_losses)
	config.save("user://profile.cfg")


func _load_profile() -> void:
	var config := ConfigFile.new()
	if config.load("user://profile.cfg") != OK:
		return
	my_name = str(config.get_value("profile", "name", my_name))
	my_color = config.get_value("profile", "color", my_color)
	my_wins = int(config.get_value("profile", "wins", 0))
	my_losses = int(config.get_value("profile", "losses", 0))


func _start(code: String) -> void:
	room_code = code
	peer_connected = false
	peer_wins = 0
	peer_losses = 0
	reset_ready()
	local_rounds = 0
	remote_rounds = 0
	_socket = WebSocketPeer.new()
	var err := _socket.connect_to_url("%s?room=%s" % [RELAY_URL, code])
	if err != OK:
		status_changed.emit("Connection failed (%d)" % err)
		return
	_active = true
	set_process(true)
	status_changed.emit("Connecting...")


func _process(_delta: float) -> void:
	if not _active:
		return
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			while _socket.get_available_packet_count() > 0:
				_handle_packet(_socket.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED:
			_active = false
			set_process(false)
			status_changed.emit("Disconnected")


func _handle_packet(text: String) -> void:
	var message = JSON.parse_string(text)
	if typeof(message) != TYPE_DICTIONARY:
		return
	match str(message.get("t", "")):
		Protocol.JOINED:
			my_slot = int(message.get("slot", -1))
			status_changed.emit("Waiting for opponent...")
			broadcast_profile()
			joined.emit()
		Protocol.PEER_JOINED:
			broadcast_profile()
		Protocol.READY:
			peer_connected = true
			broadcast_profile()
			room_ready.emit()
		Protocol.PEER_LEFT:
			peer_connected = false
			reset_ready()
			peer_left.emit()
		Protocol.ROOM_FULL:
			room_full.emit()
		Protocol.PROFILE:
			peer_name = str(message.get("name", "Opponent"))
			peer_color = Color.html(str(message.get("color", "ff4444")))
			peer_wins = int(message.get("wins", 0))
			peer_losses = int(message.get("losses", 0))
			peer_profile.emit(peer_name, peer_color)
		Protocol.SET_READY:
			peer_ready = bool(message.get("value", false))
			peer_ready_changed.emit(peer_ready)
		_:
			peer_message.emit(message)


func _make_code() -> String:
	var code := ""
	for i in 4:
		code += "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"[randi() % 32]
	return code
