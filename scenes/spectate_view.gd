extends Control

const RECONNECT_DELAY := 2.0
const RECONNECT_LIMIT := 4
const IDLE_JUMP := 10.0
const ROUND_BREAK := 2.2
const MAX_HP := 100

var _socket := WebSocketPeer.new()
var _reconnecting := false
var _reconnect_timer := 0.0
var _reconnect_attempts := 0
var _leaving := false
var _last_message := 0.0
var _background_wide := false

var _names := ["PLAYER 1", "PLAYER 2"]
var _colors := [Color("e5424a"), Color("2f81f7")]
var _fighters: Array[Fighter] = []
var _hp := [MAX_HP, MAX_HP]
var _rounds := [0, 0]
var _move := [0.0, 0.0]
var _blocking := [false, false]

@onready var _background: TextureRect = $Background
@onready var _hud: Control = $Hud


func _ready() -> void:
	if Net.spectate_room.is_empty():
		Fx.goto("res://scenes/spectate_screen.tscn")
		return
	_fighters = [$Fighters/LocalFighter, $Fighters/RemoteFighter]
	for slot in 2:
		_fighters[slot].setup(_colors[slot], slot == 0)
	_layout_stage()
	resized.connect(_layout_stage)
	_hud.setup(_names[0], _colors[0], _names[1], _colors[1], $Fighters)
	_hud.set_pips(0, 0)
	_hud.play_intro()
	_hud.exit_pressed.connect(_on_exit_pressed)
	$Hud/ExitButton.text = "EXIT SPECTATE"
	$Hud/TimeLabel.visible = false
	_last_message = _now()
	_hud.set_status("Connecting to room %s..." % Net.spectate_room)
	_connect()


func _exit_tree() -> void:
	_socket.close()


func _process(delta: float) -> void:
	if _fighters.is_empty():
		return
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			_reconnect_attempts = 0
			while _socket.get_available_packet_count() > 0:
				_handle_packet(_socket.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED:
			_handle_closed(delta)
	for slot in 2:
		_fighters[slot].set_move(_move[slot], delta)
	_hud.set_bars(_hp[0], _hp[1], _move[0], _move[1])
	_hud.set_blocking(_blocking[0], _blocking[1])
	if Net.spectate_auto and not _leaving and _now() - _last_message > IDLE_JUMP:
		_leave_to("res://scenes/spectate_screen.tscn")


func _connect() -> void:
	_socket = WebSocketPeer.new()
	var url := "%s?room=%s&role=spec" % [Net.RELAY_URL, Net.spectate_room]
	if _socket.connect_to_url(url) != OK:
		_hud.set_status("Could not reach room %s" % Net.spectate_room)
		return
	_reconnecting = false


func _handle_closed(delta: float) -> void:
	if _reconnecting:
		_reconnect_timer -= delta
		if _reconnect_timer <= 0.0:
			_connect()
		return
	if _reconnect_attempts >= RECONNECT_LIMIT:
		_hud.set_status("Room %s ended" % Net.spectate_room)
		return
	_reconnect_attempts += 1
	_reconnecting = true
	_reconnect_timer = RECONNECT_DELAY
	_hud.set_status("Reconnecting to room %s..." % Net.spectate_room)


func _handle_packet(text: String) -> void:
	var message = JSON.parse_string(text)
	if typeof(message) != TYPE_DICTIONARY:
		return
	_last_message = _now()
	var slot := int(message.get("slot", -1))
	match str(message.get("t", "")):
		Protocol.PROFILE:
			if slot >= 0:
				_apply_profile(slot, message)
		Protocol.INPUT:
			if slot >= 0:
				_move[slot] = clampf(float(message.get("move", 0.0)), -1.0, 1.0)
				_blocking[slot] = bool(message.get("block", false))
		Protocol.ACT:
			if slot >= 0:
				var kind := str(message.get("kind", Protocol.JAB))
				_fighters[slot].play_action(kind)
				_set_action(slot, kind.to_upper())
		Protocol.HIT_RESULT:
			if slot >= 0:
				_apply_hit(slot, message)
		Protocol.MISS:
			if slot >= 0:
				_hud.show_floating_text(_fighters[slot].position + Vector2(0, -700), "MISS", Color(0.75, 0.75, 0.85), 52)
		Protocol.ROUND_END:
			if slot >= 0:
				_round_won(slot)
		Protocol.SPECTATE_STATE:
			_apply_state(message)
		Protocol.JOINED:
			_hud.set_status("Watching room %s" % Net.spectate_room)
		Protocol.PEER_LEFT:
			_hud.set_status("A player disconnected - waiting...")
		Protocol.PEER_JOINED:
			_hud.set_status("Watching room %s" % Net.spectate_room)


func _apply_profile(slot: int, message: Dictionary) -> void:
	_names[slot] = str(message.get("name", _names[slot]))
	_colors[slot] = Color.html(str(message.get("color", "ffffff")))
	_fighters[slot].setup(_colors[slot], slot == 0)
	_hud.setup(_names[0], _colors[0], _names[1], _colors[1], $Fighters)


func _apply_hit(slot: int, message: Dictionary) -> void:
	var damage := int(message.get("damage", 0))
	var blocked := bool(message.get("blocked", false))
	var kind := str(message.get("kind", Protocol.JAB))
	_hp[slot] = int(message.get("hp", _hp[slot]))
	_hud.show_damage(_fighters[slot], damage, blocked, slot == 0)
	_hud.flash_hit(_fighters[slot])
	if blocked:
		_fighters[slot].block_hit()
	else:
		_fighters[slot].play_hurt(kind)
		_set_action(slot, "HURT")
		Fx.flash(0.12 if damage < 10 else 0.2)
	if _hp[slot] <= 0:
		_fighters[slot].play_action(Protocol.KO)
		_hud.show_ko()
		Fx.flash(0.3)


func _round_won(slot: int) -> void:
	_rounds[slot] += 1
	_hud.set_pips(_rounds[0], _rounds[1])
	_hud.show_result("%s TAKES THE ROUND" % _names[slot].to_upper(), "", false)
	await get_tree().create_timer(ROUND_BREAK).timeout
	if not is_inside_tree():
		return
	_hud.hide_result()
	_hp = [MAX_HP, MAX_HP]


func _apply_state(message: Dictionary) -> void:
	var hp = message.get("hp", {})
	var rounds = message.get("rounds", {})
	if typeof(hp) == TYPE_DICTIONARY:
		for slot in 2:
			var key := str(slot)
			if hp.has(key):
				_hp[slot] = int(hp[key])
	if typeof(rounds) == TYPE_DICTIONARY:
		for slot in 2:
			var key := str(slot)
			if rounds.has(key):
				_rounds[slot] = int(rounds[key])
	_hud.set_pips(_rounds[0], _rounds[1])


func _set_action(slot: int, text: String) -> void:
	if slot == 0:
		_hud.set_local_action(text)
	else:
		_hud.set_remote_action(text)


func _layout_stage() -> void:
	var wide := size.x > size.y
	if wide != _background_wide or _background.texture == null:
		_background_wide = wide
		_background.texture = load(Arena.background_path(wide))
	Arena.layout(size, _fighters[0], _fighters[1])


func _on_exit_pressed() -> void:
	if Net.spectate_auto:
		_leave_to("res://scenes/spectate_screen.tscn")
	else:
		Net.spectate_auto = false
		_leave_to("res://scenes/main_menu.tscn")


func _leave_to(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	Fx.goto(path)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
