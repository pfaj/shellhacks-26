extends Control

const NET_INTERVAL := 1.0 / 20.0
const MAX_TILT_DEGREES := 30.0
const DEADZONE_DEGREES := 1.5
const TILT_SMOOTHING := 22.0
const ACTION_LABEL_TIME := 0.6
const IMPACT_DELAY := 0.12
const JAB_REACH := 330.0
const PUNCH_REACH := 380.0
const MAX_HP := 100
const JAB_DAMAGE := 5
const PUNCH_DAMAGE := 12
const CHIP_RATIO := 0.3
const RESULT_DELAY := 0.9
const ROUND_BREAK := 1.6
const ROUND_TIME := 60.0
const ROUNDS_TO_WIN := 2
const COMBO_WINDOW := 1.4
const DODGE_THRESHOLD := 0.35
const DAMAGE_DRIFT := -100.0
const SHAKE_TIME := 0.18
const SHAKE_STRENGTH := 12.0
const HIT_STOP_TIME := 0.07
const HIT_STOP_SCALE := 0.05

enum Result { WIN, LOSE, DRAW }

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
var _round_time := ROUND_TIME
var _local_combo := 0
var _combo_timer := 0.0
var _shake_time := 0.0
var _shake_strength := 0.0
var _hit_stop_active := false

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
@onready var _time_label: Label = $UI/TimeLabel
@onready var _combo_label: Label = $UI/ComboLabel
@onready var _status: Label = $UI/StatusLabel
@onready var _exit_button: Button = $UI/ExitButton
@onready var _result: ColorRect = $UI/Result
@onready var _result_label: Label = $UI/Result/Box/ResultLabel
@onready var _rematch_button: Button = $UI/Result/Box/RematchButton
@onready var _result_exit_button: Button = $UI/Result/Box/ResultExitButton
@onready var _result_status: Label = $UI/Result/Box/ResultStatus
@onready var _local_pips: Array[ColorRect] = [
	$UI/LocalPanel/LocalRounds/LocalPip1,
	$UI/LocalPanel/LocalRounds/LocalPip2,
]
@onready var _remote_pips: Array[ColorRect] = [
	$UI/RemotePanel/RemoteRounds/RemotePip1,
	$UI/RemotePanel/RemoteRounds/RemotePip2,
]


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
	_time_label.text = str(int(ROUND_TIME))
	_update_round_pips()
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
	_update_shake(delta)
	_refresh_bars()
	if _match_over:
		_tick_action_labels(delta)
		return
	_update_tilt(delta)
	_controls.update(delta)
	_local.set_move(_move, delta)
	_remote.set_move(-_remote_move, delta)
	_update_round_timer(delta)
	_update_combo(delta)
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


func _update_round_timer(delta: float) -> void:
	_round_time = maxf(_round_time - delta, 0.0)
	_time_label.text = str(ceili(_round_time))
	_time_label.modulate = Color(1.0, 0.45, 0.45) if _round_time <= 10.0 else Color.WHITE
	if _round_time > 0.0:
		return
	if _local_hp > _remote_hp:
		_finish_match(Result.WIN)
	elif _remote_hp > _local_hp:
		_finish_match(Result.LOSE)
	else:
		_finish_match(Result.DRAW)


func _update_combo(delta: float) -> void:
	if _combo_timer <= 0.0:
		return
	_combo_timer = maxf(_combo_timer - delta, 0.0)
	if _combo_timer == 0.0:
		_local_combo = 0
		_combo_label.visible = false


func _register_combo() -> void:
	_local_combo += 1
	_combo_timer = COMBO_WINDOW
	if _local_combo < 2:
		return
	_combo_label.visible = true
	_combo_label.text = "%d HITS" % _local_combo
	_combo_label.pivot_offset = _combo_label.size * 0.5
	_combo_label.scale = Vector2(1.25, 1.25)
	create_tween().tween_property(_combo_label, "scale", Vector2.ONE, 0.12)


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
		Net.send({"t": Protocol.MISS})
		_spawn_floating_text(_remote.position + Vector2(0, -560), "MISS", Color(0.75, 0.75, 0.85), 52)
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
		Protocol.MISS:
			if _move < -DODGE_THRESHOLD:
				_spawn_floating_text(_local.position + Vector2(0, -620), "DODGE!", Color(0.45, 0.9, 1.0), 64)
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
		var chip := _chip_damage(kind)
		Net.send({"t": Protocol.HIT_RESULT, "blocked": true, "damage": chip, "hp": maxi(_local_hp - chip, 0)})
		_apply_local_damage(chip, true)
		return
	var damage := _base_damage(kind)
	Net.send({"t": Protocol.HIT_RESULT, "blocked": false, "damage": damage, "hp": maxi(_local_hp - damage, 0)})
	_apply_local_damage(damage, false)


func _apply_hit_result(message: Dictionary) -> void:
	_apply_remote_damage(int(message.get("damage", 0)), bool(message.get("blocked", false)))


func _apply_local_damage(damage: int, blocked: bool) -> void:
	if damage <= 0:
		return
	_local_hp = maxi(_local_hp - damage, 0)
	_animate_hp(true, damage)
	_spawn_damage_number(_local, damage, blocked)
	_spawn_hit_marker(_local, blocked)
	if blocked:
		_local.block_hit()
	else:
		_hit_stop()
		_shake()
		_local_combo = 0
		_combo_timer = 0.0
		_combo_label.visible = false
		_local.play_action(Protocol.HURT)
		_local_action.text = "HURT"
		_local_action_time = ACTION_LABEL_TIME
	if _local_hp <= 0:
		_local.play_action(Protocol.KO)
		_finish_match(Result.LOSE)


func _apply_remote_damage(damage: int, blocked: bool) -> void:
	if damage <= 0:
		return
	_remote_hp = maxi(_remote_hp - damage, 0)
	_animate_hp(false, damage)
	_spawn_damage_number(_remote, damage, blocked)
	_spawn_hit_marker(_remote, blocked)
	if blocked:
		_remote.block_hit()
	else:
		_hit_stop()
		_shake()
		_register_combo()
		_remote.play_action(Protocol.HURT)
		_remote_action.text = "HURT"
		_remote_action_time = ACTION_LABEL_TIME
	if _remote_hp <= 0:
		_remote.play_action(Protocol.KO)
		_finish_match(Result.WIN)


func _base_damage(kind: String) -> int:
	return PUNCH_DAMAGE if kind == Protocol.PUNCH else JAB_DAMAGE


func _chip_damage(kind: String) -> int:
	return ceili(_base_damage(kind) * CHIP_RATIO)


func _finish_match(result: Result) -> void:
	if _match_over:
		return
	_match_over = true
	_controls.reset()
	_combo_label.visible = false
	_local_combo = 0
	_combo_timer = 0.0
	match result:
		Result.WIN:
			Net.local_rounds += 1
		Result.LOSE:
			Net.remote_rounds += 1
		Result.DRAW:
			pass
	_update_round_pips()
	await get_tree().create_timer(RESULT_DELAY).timeout
	if not is_inside_tree():
		return
	_result.visible = true
	var won_match := Net.local_rounds >= ROUNDS_TO_WIN
	var lost_match := Net.remote_rounds >= ROUNDS_TO_WIN
	_result_status.text = "%d - %d" % [Net.local_rounds, Net.remote_rounds]
	if won_match or lost_match:
		_result_label.text = "YOU WIN" if won_match else "YOU LOSE"
		Sfx.play("win" if won_match else "lose")
		_rematch_button.disabled = false
		_rematch_button.text = "REMATCH"
		return
	_result_label.text = _round_text(result)
	_rematch_button.disabled = true
	await get_tree().create_timer(ROUND_BREAK).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/prematch_screen.tscn")


func _round_text(result: Result) -> String:
	match result:
		Result.WIN:
			return "ROUND WON"
		Result.LOSE:
			return "ROUND LOST"
	return "DRAW"


func _update_round_pips() -> void:
	for i in _local_pips.size():
		_local_pips[i].color = Net.my_color if i < Net.local_rounds else Color(1, 1, 1, 0.2)
	for i in _remote_pips.size():
		_remote_pips[i].color = Net.peer_color if i < Net.remote_rounds else Color(1, 1, 1, 0.2)


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
		Net.local_rounds = 0
		Net.remote_rounds = 0
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


func _shake() -> void:
	_shake_time = SHAKE_TIME
	_shake_strength = SHAKE_STRENGTH


func _update_shake(delta: float) -> void:
	if _shake_time <= 0.0:
		return
	_shake_time = maxf(_shake_time - delta, 0.0)
	if _shake_time <= 0.0:
		position = Vector2.ZERO
		return
	var amount := _shake_strength * (_shake_time / SHAKE_TIME)
	position = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))


func _hit_stop() -> void:
	if _hit_stop_active:
		return
	_hit_stop_active = true
	Engine.time_scale = HIT_STOP_SCALE
	await get_tree().create_timer(HIT_STOP_TIME, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stop_active = false


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


func _spawn_damage_number(victim: Node2D, damage: int, blocked := false) -> void:
	var heavy := damage >= PUNCH_DAMAGE
	var font_size := 44 if blocked else (76 if heavy else 58)
	var color := Color(0.85, 0.85, 0.9) if blocked else (Color(1.0, 0.45, 0.2) if heavy else Color(1.0, 0.9, 0.35))
	_spawn_floating_text(victim.position + Vector2(0, -540), str(damage), color, font_size)


func _spawn_floating_text(origin: Vector2, text: String, color: Color, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(260, 90)
	label.pivot_offset = label.size * 0.5
	label.position = origin - label.size * 0.5
	label.scale = Vector2(0.4, 0.4)
	$Fighters.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.08)
	tween.tween_property(label, "scale", Vector2.ONE, 0.08)
	tween.tween_property(label, "position:y", label.position.y + DAMAGE_DRIFT, 0.55).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


func _spawn_hit_marker(victim: Node2D, blocked: bool) -> void:
	var marker := Node2D.new()
	marker.position = victim.position + Vector2(0, -300)
	var color := Color(0.65, 0.9, 1.0) if blocked else Color(1.0, 0.95, 0.5)
	var length := 64.0 if blocked else 92.0
	for i in 4:
		var pivot := Node2D.new()
		pivot.rotation = PI * 0.25 + i * PI * 0.5
		var bar := ColorRect.new()
		bar.color = color
		bar.size = Vector2(length, 12.0)
		bar.position = Vector2(-length * 0.5, -6.0)
		pivot.add_child(bar)
		marker.add_child(pivot)
	marker.scale = Vector2(0.4, 0.4)
	$Fighters.add_child(marker)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(marker, "scale", Vector2(1.6, 1.6), 0.18)
	tween.tween_property(marker, "modulate:a", 0.0, 0.18).set_delay(0.06)
	tween.finished.connect(marker.queue_free)
	victim.modulate = Color(1.7, 1.6, 1.6)
	create_tween().tween_property(victim, "modulate", Color.WHITE, 0.15)


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
