extends Control

const NET_INTERVAL := 1.0 / 20.0
const MAX_TILT_DEGREES := 30.0
const DEADZONE_DEGREES := 2.0
const TILT_SMOOTHING := 12.0
const ACTION_LABEL_TIME := 0.6
const IMPACT_DELAY := 0.12
const JAB_REACH := 300.0
const PUNCH_REACH := 340.0
const MAX_HP := 100
const JAB_DAMAGE := 7
const PUNCH_DAMAGE := 12
const RESULT_DELAY := 1.1

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
var _local_hp := MAX_HP
var _remote_hp := MAX_HP
var _match_over := false
var _local_rematch := false
var _remote_rematch := false

@onready var _local: Node2D = $Fighters/LocalFighter
@onready var _remote: Node2D = $Fighters/RemoteFighter
@onready var _local_name: Label = $UI/LocalPanel/LocalName
@onready var _local_chip: ColorRect = $UI/LocalPanel/LocalChip
@onready var _local_action: Label = $UI/LocalPanel/LocalAction
@onready var _local_hp_bg: ColorRect = $UI/LocalPanel/LocalHpBg
@onready var _local_hp_ghost: ColorRect = $UI/LocalPanel/LocalHpBg/LocalHpGhost
@onready var _local_hp_fill: ColorRect = $UI/LocalPanel/LocalHpBg/LocalHpFill
@onready var _local_tilt_bg: ColorRect = $UI/LocalPanel/LocalTiltBg
@onready var _local_fill: ColorRect = $UI/LocalPanel/LocalTiltBg/LocalTiltFill
@onready var _remote_name: Label = $UI/RemotePanel/RemoteName
@onready var _remote_chip: ColorRect = $UI/RemotePanel/RemoteChip
@onready var _remote_action: Label = $UI/RemotePanel/RemoteAction
@onready var _remote_hp_bg: ColorRect = $UI/RemotePanel/RemoteHpBg
@onready var _remote_hp_ghost: ColorRect = $UI/RemotePanel/RemoteHpBg/RemoteHpGhost
@onready var _remote_hp_fill: ColorRect = $UI/RemotePanel/RemoteHpBg/RemoteHpFill
@onready var _remote_tilt_bg: ColorRect = $UI/RemotePanel/RemoteTiltBg
@onready var _remote_fill: ColorRect = $UI/RemotePanel/RemoteTiltBg/RemoteTiltFill
@onready var _status: Label = $UI/StatusLabel
@onready var _exit_button: Button = $UI/ExitButton
@onready var _result: ColorRect = $UI/Result
@onready var _result_label: Label = $UI/Result/Box/ResultLabel
@onready var _rematch_button: Button = $UI/Result/Box/RematchButton
@onready var _result_exit_button: Button = $UI/Result/Box/ResultExitButton
@onready var _result_status: Label = $UI/Result/Box/ResultStatus


func _ready() -> void:
	if OS.has_feature("web"):
		_tilt = JavaScriptBridge.get_interface("sockemTilt")
	_local.setup(Net.my_color, 360.0, 1.15, false)
	_remote.setup(Net.peer_color, 730.0, 0.95, true)
	_local_name.text = Net.my_name
	_remote_name.text = Net.peer_name
	_local_chip.color = Net.my_color
	_remote_chip.color = Net.peer_color
	_local_hp_fill.color = Net.my_color
	_remote_hp_fill.color = Net.peer_color
	_neutral = _raw_gamma()
	_controls.tapped.connect(_on_tapped)
	_controls.held.connect(_on_held)
	_controls.block_changed.connect(_on_block_changed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_rematch_button.pressed.connect(_on_rematch_pressed)
	_result_exit_button.pressed.connect(_on_exit_pressed)
	Net.peer_message.connect(_on_peer_message)
	Net.peer_left.connect(_on_peer_left)
	Net.status_changed.connect(_on_status_changed)
	Sfx.play_music("fight")


func _process(delta: float) -> void:
	_refresh_bars()
	if _match_over:
		_tick_action_labels(delta)
		return
	_update_tilt(delta)
	_controls.update(delta)
	_local.set_move(_move, delta)
	_remote.set_move(-_remote_move, delta)
	_net_accumulator += delta
	if _net_accumulator >= NET_INTERVAL:
		_net_accumulator = 0.0
		_send_input()
	_tick_action_labels(delta)


func _input(event: InputEvent) -> void:
	if _match_over:
		return
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
	if _match_over:
		return
	if not _local.play_action(kind):
		return
	_local_action.text = kind.to_upper()
	_local_action_time = ACTION_LABEL_TIME
	Net.send({"t": Protocol.ACT, "kind": kind})
	get_tree().create_timer(IMPACT_DELAY).timeout.connect(_resolve_hit.bind(kind))


func _resolve_hit(kind: String) -> void:
	if _match_over:
		return
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
			_resolve_incoming_hit(str(message.get("kind", Protocol.JAB)))
		Protocol.HIT_RESULT:
			_apply_hit_result(message)
		Protocol.REMATCH:
			_remote_rematch = true
			_result_status.text = "Opponent wants a rematch"
			if not _local_rematch:
				_rematch_button.text = "ACCEPT"
			_check_rematch()


func _resolve_incoming_hit(kind: String) -> void:
	if _match_over:
		return
	if _controls.blocking:
		_local.block_hit()
		Net.send({"t": Protocol.HIT_RESULT, "blocked": true, "damage": 0, "hp": _local_hp})
		return
	_local.play_action(Protocol.HURT)
	_local_action.text = "HURT"
	_local_action_time = ACTION_LABEL_TIME
	var damage := PUNCH_DAMAGE if kind == Protocol.PUNCH else JAB_DAMAGE
	_local_hp = maxi(_local_hp - damage, 0)
	_animate_hp(true, damage)
	Net.send({"t": Protocol.HIT_RESULT, "blocked": false, "damage": damage, "hp": _local_hp})
	if _local_hp <= 0:
		_local.play_action(Protocol.KO)
		_finish_match(false)


func _apply_hit_result(message: Dictionary) -> void:
	if bool(message.get("blocked", false)):
		_remote.block_hit()
		return
	var damage := int(message.get("damage", 0))
	_remote_hp = int(message.get("hp", _remote_hp))
	_animate_hp(false, damage)
	_remote.play_action(Protocol.HURT)
	_remote_action.text = "HURT"
	_remote_action_time = ACTION_LABEL_TIME
	if _remote_hp <= 0:
		_remote.play_action(Protocol.KO)
		_finish_match(true)


func _finish_match(won: bool) -> void:
	if _match_over:
		return
	_match_over = true
	_controls.reset()
	await get_tree().create_timer(RESULT_DELAY).timeout
	if not is_inside_tree():
		return
	_result.visible = true
	_result_label.text = "YOU WIN" if won else "YOU LOSE"
	Sfx.play("win" if won else "lose")
	_rematch_button.disabled = false
	_rematch_button.text = "REMATCH"
	_result_status.text = ""


func _on_rematch_pressed() -> void:
	if _local_rematch:
		return
	_local_rematch = true
	Net.send({"t": Protocol.REMATCH})
	_rematch_button.text = "WAITING..."
	_result_status.text = "Waiting for opponent..."
	_check_rematch()


func _check_rematch() -> void:
	if _local_rematch and _remote_rematch:
		get_tree().change_scene_to_file("res://scenes/prematch_screen.tscn")


func _on_peer_left() -> void:
	_remote.play_action(Protocol.KO)
	_status.text = "Opponent disconnected"
	if _match_over:
		_result_status.text = "Opponent left the match"
		_rematch_button.disabled = true


func _on_status_changed(text: String) -> void:
	if text == "Disconnected":
		_status.text = "Connection lost"


func _on_exit_pressed() -> void:
	Sfx.stop_music()
	Net.leave()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _refresh_bars() -> void:
	var tilt_width := _local_tilt_bg.size.x
	_local_fill.offset_left = 0.0
	_local_fill.offset_right = (_move * 0.5 + 0.5) * tilt_width
	_remote_fill.offset_left = 0.0
	_remote_fill.offset_right = (-_remote_move * 0.5 + 0.5) * tilt_width
	_apply_hp_fill(_local_hp_bg, _local_hp_fill, _local_hp, false)
	_apply_hp_fill(_remote_hp_bg, _remote_hp_fill, _remote_hp, true)


func _apply_hp_fill(bg: ColorRect, fill: ColorRect, hp: int, from_right: bool) -> void:
	var width := bg.size.x
	var value := clampf(float(hp) / MAX_HP, 0.0, 1.0) * width
	if from_right:
		fill.offset_left = width - value
		fill.offset_right = width
	else:
		fill.offset_left = 0.0
		fill.offset_right = value


func _animate_hp(local: bool, damage: int) -> void:
	var bg: ColorRect = _local_hp_bg if local else _remote_hp_bg
	var ghost: ColorRect = _local_hp_ghost if local else _remote_hp_ghost
	var hp := _local_hp if local else _remote_hp
	var from_right := not local
	var width := bg.size.x
	var old_value := clampf(float(mini(hp + damage, MAX_HP)) / MAX_HP, 0.0, 1.0) * width
	var new_value := clampf(float(hp) / MAX_HP, 0.0, 1.0) * width
	if from_right:
		ghost.offset_left = width - old_value
		ghost.offset_right = width
	else:
		ghost.offset_left = 0.0
		ghost.offset_right = old_value
	var tween := create_tween()
	tween.set_parallel(true)
	if from_right:
		tween.tween_property(ghost, "offset_left", width - new_value, 0.35).set_delay(0.25)
	else:
		tween.tween_property(ghost, "offset_right", new_value, 0.35).set_delay(0.25)
	bg.pivot_offset = bg.size * 0.5
	bg.scale = Vector2(1.16, 1.16)
	tween.tween_property(bg, "scale", Vector2.ONE, 0.18)


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


func _raw_gamma() -> float:
	if _tilt == null:
		return 0.0
	return float(_tilt.gamma)
