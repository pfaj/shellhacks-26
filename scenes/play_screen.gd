extends Control

const HOLD_TIME := 0.15
const NET_INTERVAL := 1.0 / 20.0
const MAX_TILT_DEGREES := 30.0
const DEADZONE_DEGREES := 2.0
const TILT_SMOOTHING := 12.0
const ACTION_LABEL_TIME := 0.6
const TILT_BAR_WIDTH := 320.0

enum State { IDLE, LEFT_TAP, RIGHT_TAP, LEFT_HOLD, RIGHT_HOLD, BLOCK }
enum Side { LEFT, RIGHT }

var left_touch := -1
var right_touch := -1
var hold_timer := 0.0
var hold_fired := false
var state := State.IDLE
var left_key_down := false
var right_key_down := false

var _tilt: JavaScriptObject = null
var _neutral := 0.0
var _smoothed_gamma := 0.0
var _move := 0.0
var _remote_move := 0.0
var _remote_blocking := false
var _net_accumulator := 0.0
var _local_action_time := 0.0
var _remote_action_time := 0.0

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
	_exit_button.pressed.connect(_on_exit_pressed)
	Net.peer_message.connect(_on_peer_message)
	Net.peer_left.connect(_on_peer_left)
	Net.status_changed.connect(_on_status_changed)
	Sfx.play_music("fight")


func _process(delta: float) -> void:
	_update_tilt(delta)
	_update_hold(delta)
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
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode, true)
	elif event is InputEventKey and not event.pressed:
		_handle_key(event.keycode, false)


func _update_tilt(delta: float) -> void:
	_smoothed_gamma = lerpf(_smoothed_gamma, _raw_gamma(), clampf(delta * TILT_SMOOTHING, 0.0, 1.0))
	var value := _smoothed_gamma - _neutral
	if absf(value) < DEADZONE_DEGREES:
		value = 0.0
	_move = clampf(value / MAX_TILT_DEGREES, -1.0, 1.0)


func _update_hold(delta: float) -> void:
	if state == State.BLOCK or hold_fired or not _any_pressed():
		return
	hold_timer += delta
	if hold_timer >= HOLD_TIME:
		hold_fired = true
		_fire_hold(_active_side())


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_press(true if event.position.x < size.x * 0.5 else false, event.index)
	else:
		_release(event.index)


func _handle_key(keycode: int, pressed: bool) -> void:
	if keycode == KEY_A:
		if pressed and not left_key_down:
			left_key_down = true
			_on_press(0)
		elif not pressed and left_key_down:
			left_key_down = false
			_on_release(0)
	elif keycode == KEY_D:
		if pressed and not right_key_down:
			right_key_down = true
			_on_press(1)
		elif not pressed and right_key_down:
			right_key_down = false
			_on_release(1)


func _press(on_left: bool, index: int) -> void:
	if on_left:
		if left_touch != -1:
			return
		left_touch = index
		_on_press(0)
	else:
		if right_touch != -1:
			return
		right_touch = index
		_on_press(1)


func _release(index: int) -> void:
	if index == left_touch:
		left_touch = -1
		_on_release(0)
	elif index == right_touch:
		right_touch = -1
		_on_release(1)


func _on_press(_side: Side) -> void:
	_reset_hold()
	_refresh_state()


func _on_release(side: Side) -> void:
	if not hold_fired:
		_fire_tap(side)
	_reset_hold()
	_refresh_state()


func _reset_hold() -> void:
	hold_timer = 0.0
	hold_fired = false


func _refresh_state() -> void:
	if _both_pressed():
		_set_state(State.BLOCK)
	elif _left_pressed():
		_set_state(State.LEFT_TAP)
	elif _right_pressed():
		_set_state(State.RIGHT_TAP)
	else:
		_set_state(State.IDLE)


func _set_state(next: State) -> void:
	if next == state:
		return
	state = next
	_local.set_block(state == State.BLOCK)
	_send_input()


func _fire_tap(side: Side) -> void:
	_land_action(side)


func _fire_hold(side: Side) -> void:
	_land_action(side)


func _land_action(side: Side) -> void:
	var kind := "jab" if side == Side.LEFT else "punch"
	_local.play_action(kind)
	_local_action.text = kind.to_upper()
	_local_action_time = ACTION_LABEL_TIME
	Net.send({"t": "act", "kind": kind})


func _send_input() -> void:
	Net.send({"t": "input", "move": _move, "block": state == State.BLOCK})


func _on_peer_message(message: Dictionary) -> void:
	match str(message.get("t", "")):
		"input":
			_remote_move = clampf(float(message.get("move", 0.0)), -1.0, 1.0)
			_remote_blocking = bool(message.get("block", false))
			_remote.set_block(_remote_blocking)
		"act":
			var kind := str(message.get("kind", "jab"))
			_remote.play_action(kind)
			_remote_action.text = kind.to_upper()
			_remote_action_time = ACTION_LABEL_TIME


func _tick_action_labels(delta: float) -> void:
	if state == State.BLOCK:
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
	_remote.play_action("ko")
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


func _left_pressed() -> bool:
	return left_touch != -1 or left_key_down


func _right_pressed() -> bool:
	return right_touch != -1 or right_key_down


func _any_pressed() -> bool:
	return _left_pressed() or _right_pressed()


func _both_pressed() -> bool:
	return _left_pressed() and _right_pressed()


func _active_side() -> Side:
	return 0 if _left_pressed() else 1
