extends Control

const NET_INTERVAL := 1.0 / 20.0
const MAX_TILT_DEGREES := 30.0
const DEADZONE_DEGREES := 2.0
const TILT_SMOOTHING := 12.0
const ACTION_LABEL_TIME := 0.6
const TILT_BAR_WIDTH := 320.0
const IMPACT_DELAY := 0.12
const JAB_REACH := 300.0
const PUNCH_REACH := 340.0

var _tilt: JavaScriptObject = null
var _neutral := 0.0
var _smoothed_gamma := 0.0
var _move := 0.0
var _remote_move := 0.0
var _remote_blocking := false
var _net_accumulator := 0.0
var _local_action_time := 0.0
var _remote_action_time := 0.0
var _controls := FighterInput.new()

@onready var _local: Node2D = $Fighters/LocalFighter
@onready var _remote: Node2D = $Fighters/RemoteFighter
@onready var _local_name: Label = $UI/LocalPanel/LocalName
@onready var _local_chip: ColorRect = $UI/LocalPanel/LocalChip
@onready var _local_action: Label = $UI/LocalPanel/LocalAction
@onready var _local_fill: ColorRect = $UI/LocalPanel/LocalTiltBg/LocalTiltFill
@onready var _remote_name: Label = $UI/RemotePanel/RemoteName
@onready var _remote_chip: ColorRect = $UI/RemotePanel/RemoteChip
@onready var _remote_action: Label = $UI/RemotePanel/RemoteAction
@onready var _remote_fill: ColorRect = $UI/RemotePanel/RemoteTiltBg/RemoteTiltFill
@onready var _status: Label = $UI/StatusLabel
@onready var _exit_button: Button = $UI/ExitButton


func _ready() -> void:
	if OS.has_feature("web"):
		_tilt = JavaScriptBridge.get_interface("sockemTilt")
	_local.setup(Net.my_color, 360.0, 1.15, false)
	_remote.setup(Net.peer_color, 730.0, 0.95, true)
	_local_name.text = Net.my_name
	_remote_name.text = Net.peer_name
	_local_chip.color = Net.my_color
	_remote_chip.color = Net.peer_color
	_neutral = _raw_gamma()
	_controls.tapped.connect(_on_tapped)
	_controls.held.connect(_on_held)
	_controls.block_changed.connect(_on_block_changed)
	_exit_button.pressed.connect(_on_exit_pressed)
	Net.peer_message.connect(_on_peer_message)
	Net.peer_left.connect(_on_peer_left)
	Net.status_changed.connect(_on_status_changed)
	Sfx.play_music("fight")


func _process(delta: float) -> void:
	_update_tilt(delta)
	_controls.update(delta)
	_local.set_move(_move, delta)
	_remote.set_move(_remote_move, delta)
	_local_fill.size.x = maxf((_move * 0.5 + 0.5) * TILT_BAR_WIDTH, 0.0)
	_remote_fill.size.x = maxf((_remote_move * 0.5 + 0.5) * TILT_BAR_WIDTH, 0.0)
	_net_accumulator += delta
	if _net_accumulator >= NET_INTERVAL:
		_net_accumulator = 0.0
		_send_input()
	_tick_action_labels(delta)


func _input(event: InputEvent) -> void:
	_controls.handle_event(event, size.x * 0.5)


func _update_tilt(delta: float) -> void:
	_smoothed_gamma = lerpf(_smoothed_gamma, _raw_gamma(), clampf(delta * TILT_SMOOTHING, 0.0, 1.0))
	var value := _smoothed_gamma - _neutral
	if absf(value) < DEADZONE_DEGREES:
		value = 0.0
	_move = clampf(value / MAX_TILT_DEGREES, -1.0, 1.0)


func _on_tapped(side: int) -> void:
	_land_action(Protocol.JAB if side == FighterInput.Side.LEFT else Protocol.PUNCH)


func _on_held(side: int) -> void:
	_on_tapped(side)


func _on_block_changed(blocking: bool) -> void:
	_local.set_block(blocking)
	_send_input()


func _land_action(kind: String) -> void:
	if not _local.play_action(kind):
		return
	_local_action.text = kind.to_upper()
	_local_action_time = ACTION_LABEL_TIME
	Net.send({"t": Protocol.ACT, "kind": kind})
	get_tree().create_timer(IMPACT_DELAY).timeout.connect(_resolve_hit.bind(kind))


func _resolve_hit(kind: String) -> void:
	var reach := PUNCH_REACH if kind == Protocol.PUNCH else JAB_REACH
	if absf(_local.position.x - _remote.position.x) > reach:
		return
	Net.send({"t": Protocol.HIT, "kind": kind})


func _send_input() -> void:
	Net.send({"t": Protocol.INPUT, "move": _move, "block": _controls.blocking})


func _on_peer_message(message: Dictionary) -> void:
	match str(message.get("t", "")):
		Protocol.INPUT:
			_remote_move = clampf(float(message.get("move", 0.0)), -1.0, 1.0)
			_remote_blocking = bool(message.get("block", false))
			_remote.set_block(_remote_blocking)
		Protocol.ACT:
			var kind := str(message.get("kind", Protocol.JAB))
			_remote.play_action(kind)
			_remote_action.text = kind.to_upper()
			_remote_action_time = ACTION_LABEL_TIME
		Protocol.HIT:
			_resolve_incoming_hit()
		Protocol.HIT_RESULT:
			if bool(message.get("blocked", false)):
				_remote.block_hit()
			else:
				_remote.play_action(Protocol.HURT)
				_remote_action.text = "HURT"
				_remote_action_time = ACTION_LABEL_TIME


func _resolve_incoming_hit() -> void:
	if _controls.blocking:
		_local.block_hit()
		Net.send({"t": Protocol.HIT_RESULT, "blocked": true})
	else:
		_local.play_action(Protocol.HURT)
		_local_action.text = "HURT"
		_local_action_time = ACTION_LABEL_TIME
		Net.send({"t": Protocol.HIT_RESULT, "blocked": false})


func _tick_action_labels(delta: float) -> void:
	if _controls.blocking:
		_local_action.text = "BLOCK"
	elif _local_action_time > 0.0:
		_local_action_time -= delta
		if _local_action_time <= 0.0:
			_local_action.text = ""
	if _remote_blocking:
		_remote_action.text = "BLOCK"
	elif _remote_action_time > 0.0:
		_remote_action_time -= delta
		if _remote_action_time <= 0.0:
			_remote_action.text = ""


func _on_peer_left() -> void:
	_remote.play_action(Protocol.KO)
	_status.text = "Opponent disconnected"


func _on_status_changed(text: String) -> void:
	if text == "Disconnected":
		_status.text = "Connection lost"


func _on_exit_pressed() -> void:
	Sfx.stop_music()
	Net.leave()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _raw_gamma() -> float:
	if _tilt == null:
		return 0.0
	return float(_tilt.gamma)
