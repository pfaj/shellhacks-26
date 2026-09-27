extends Control

signal rematch_pressed()
signal exit_pressed()

const MAX_HP := 100
const PUNCH_DAMAGE := 12
const ACTION_LABEL_TIME := 0.6
const DAMAGE_DRIFT := -100.0

var _world: Node2D = null
var _last_local_hp := -1
var _last_remote_hp := -1
var _local_action_time := 0.0
var _remote_action_time := 0.0
var _local_blocking := false
var _remote_blocking := false

@onready var _local_name: Label = $LocalPanel/LocalName
@onready var _local_chip: ColorRect = $LocalPanel/LocalChip
@onready var _local_action: Label = $LocalPanel/LocalAction
@onready var _local_hp_bg: ColorRect = $LocalPanel/LocalHpBg
@onready var _local_hp_ghost: ColorRect = $LocalPanel/LocalHpBg/LocalHpGhost
@onready var _local_hp_fill: ColorRect = $LocalPanel/LocalHpBg/LocalHpFill
@onready var _local_tilt_bg: ColorRect = $LocalPanel/LocalTiltBg
@onready var _local_tilt_fill: ColorRect = $LocalPanel/LocalTiltBg/LocalTiltFill
@onready var _local_pips: Array[ColorRect] = [
	$LocalPanel/LocalRounds/LocalPip1,
	$LocalPanel/LocalRounds/LocalPip2,
]
@onready var _remote_name: Label = $RemotePanel/RemoteName
@onready var _remote_chip: ColorRect = $RemotePanel/RemoteChip
@onready var _remote_action: Label = $RemotePanel/RemoteAction
@onready var _remote_hp_bg: ColorRect = $RemotePanel/RemoteHpBg
@onready var _remote_hp_ghost: ColorRect = $RemotePanel/RemoteHpBg/RemoteHpGhost
@onready var _remote_hp_fill: ColorRect = $RemotePanel/RemoteHpBg/RemoteHpFill
@onready var _remote_tilt_bg: ColorRect = $RemotePanel/RemoteTiltBg
@onready var _remote_tilt_fill: ColorRect = $RemotePanel/RemoteTiltBg/RemoteTiltFill
@onready var _remote_pips: Array[ColorRect] = [
	$RemotePanel/RemoteRounds/RemotePip1,
	$RemotePanel/RemoteRounds/RemotePip2,
]
@onready var _time_label: Label = $TimeLabel
@onready var _combo_label: Label = $ComboLabel
@onready var _countdown: Label = $Countdown
@onready var _status: Label = $StatusLabel
@onready var _result: ColorRect = $Result
@onready var _result_label: Label = $Result/Box/ResultLabel
@onready var _result_status: Label = $Result/Box/ResultStatus
@onready var _rematch_button: Button = $Result/Box/RematchButton
@onready var _result_exit_button: Button = $Result/Box/ResultExitButton
@onready var _exit_button: Button = $ExitButton


func _ready() -> void:
	_rematch_button.pressed.connect(_on_rematch_pressed)
	_result_exit_button.pressed.connect(_on_exit_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)


func _process(delta: float) -> void:
	if _local_blocking:
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


func setup(local_name: String, local_color: Color, peer_name: String, peer_color: Color, world: Node2D) -> void:
	_world = world
	_local_name.text = local_name
	_remote_name.text = peer_name
	_local_chip.color = local_color
	_remote_chip.color = peer_color
	_local_hp_fill.color = local_color
	_remote_hp_fill.color = peer_color
	_local_tilt_fill.color = local_color
	_remote_tilt_fill.color = peer_color


func set_bars(local_hp: int, remote_hp: int, local_move: float, remote_move: float) -> void:
	var tilt_width := _local_tilt_bg.size.x
	_local_tilt_fill.offset_left = 0.0
	_local_tilt_fill.offset_right = (local_move * 0.5 + 0.5) * tilt_width
	_remote_tilt_fill.offset_left = 0.0
	_remote_tilt_fill.offset_right = (remote_move * 0.5 + 0.5) * tilt_width
	_update_hp(true, local_hp)
	_update_hp(false, remote_hp)


func set_timer(seconds: float) -> void:
	_time_label.text = str(ceili(maxf(seconds, 0.0)))
	_time_label.modulate = Color(1.0, 0.45, 0.45) if seconds <= 10.0 else Color.WHITE


func set_pips(local_rounds: int, remote_rounds: int) -> void:
	for i in _local_pips.size():
		_local_pips[i].color = _local_hp_fill.color if i < local_rounds else Color(1, 1, 1, 0.2)
	for i in _remote_pips.size():
		_remote_pips[i].color = _remote_hp_fill.color if i < remote_rounds else Color(1, 1, 1, 0.2)


func set_local_action(text: String) -> void:
	_local_action.text = text
	_local_action_time = ACTION_LABEL_TIME


func set_remote_action(text: String) -> void:
	_remote_action.text = text
	_remote_action_time = ACTION_LABEL_TIME


func set_blocking(local: bool, remote: bool) -> void:
	_local_blocking = local
	_remote_blocking = remote


func show_combo(count: int) -> void:
	if count < 2:
		hide_combo()
		return
	_combo_label.visible = true
	_combo_label.text = "%d HITS" % count
	_combo_label.pivot_offset = _combo_label.size * 0.5
	_combo_label.scale = Vector2(1.25, 1.25)
	create_tween().tween_property(_combo_label, "scale", Vector2.ONE, 0.12)


func hide_combo() -> void:
	_combo_label.visible = false


func set_status(text: String) -> void:
	_status.text = text


func set_countdown(text: String) -> void:
	_countdown.visible = true
	_countdown.text = text
	_countdown.modulate = Ui.ACCENT if text == "FIGHT!" else Color.WHITE
	_countdown.pivot_offset = _countdown.size * 0.5 if _countdown.size.x > 0.0 else Vector2(420, 260)
	_countdown.scale = Vector2(1.3, 1.3)
	create_tween().tween_property(_countdown, "scale", Vector2.ONE, 0.16).set_ease(Tween.EASE_OUT)


func hide_countdown() -> void:
	_countdown.visible = false


func show_result(title: String, status: String, can_rematch: bool) -> void:
	_result.visible = true
	_result_label.text = title
	_result_status.text = status
	_rematch_button.visible = can_rematch
	_rematch_button.disabled = not can_rematch
	_rematch_button.text = "REMATCH"


func hide_result() -> void:
	_result.visible = false


func set_result_status(text: String) -> void:
	_result_status.text = text


func set_rematch_waiting() -> void:
	_rematch_button.text = "WAITING..."


func set_rematch_accept() -> void:
	_rematch_button.text = "ACCEPT"


func disable_rematch() -> void:
	_rematch_button.disabled = true


func show_damage(victim: Node2D, damage: int, blocked: bool, local: bool) -> void:
	if damage <= 0 or victim == null:
		return
	var heavy := damage >= PUNCH_DAMAGE
	var font_size := 44 if blocked else (76 if heavy else 58)
	var color := Color(0.85, 0.85, 0.9) if blocked else (Color(1.0, 0.45, 0.2) if heavy else Color(1.0, 0.9, 0.35))
	var side_x := 150.0 if local else size.x - 150.0
	show_floating_text(Vector2(side_x, victim.position.y - 700.0), str(damage), color, font_size)


func show_floating_text(origin: Vector2, text: String, color: Color, font_size: int) -> void:
	if _world == null:
		return
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
	_world.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.08)
	tween.tween_property(label, "scale", Vector2.ONE, 0.08)
	tween.tween_property(label, "position:y", label.position.y + DAMAGE_DRIFT, 0.55).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


func flash_hit(victim: Node2D) -> void:
	if victim == null:
		return
	victim.modulate = Color(1.7, 1.6, 1.6)
	create_tween().tween_property(victim, "modulate", Color.WHITE, 0.15)


func _update_hp(local: bool, hp: int) -> void:
	var last := _last_local_hp if local else _last_remote_hp
	if local:
		_last_local_hp = hp
	else:
		_last_remote_hp = hp
	if last < 0 or hp > last:
		_apply_fill(local, hp)
		_apply_ghost(local, hp)
		return
	if hp == last:
		return
	_apply_fill(local, hp)
	_animate_hp(local, last, hp)


func _apply_fill(local: bool, hp: int) -> void:
	var bg: ColorRect = _local_hp_bg if local else _remote_hp_bg
	var fill: ColorRect = _local_hp_fill if local else _remote_hp_fill
	var value := clampf(float(hp) / MAX_HP, 0.0, 1.0) * bg.size.x
	if local:
		fill.offset_left = 0.0
		fill.offset_right = value
	else:
		fill.offset_left = bg.size.x - value
		fill.offset_right = bg.size.x


func _apply_ghost(local: bool, hp: int) -> void:
	var bg: ColorRect = _local_hp_bg if local else _remote_hp_bg
	var ghost: ColorRect = _local_hp_ghost if local else _remote_hp_ghost
	var value := clampf(float(hp) / MAX_HP, 0.0, 1.0) * bg.size.x
	if local:
		ghost.offset_left = 0.0
		ghost.offset_right = value
	else:
		ghost.offset_left = bg.size.x - value
		ghost.offset_right = bg.size.x


func _animate_hp(local: bool, old_hp: int, new_hp: int) -> void:
	var bg: ColorRect = _local_hp_bg if local else _remote_hp_bg
	var ghost: ColorRect = _local_hp_ghost if local else _remote_hp_ghost
	var width := bg.size.x
	var old_value := clampf(float(old_hp) / MAX_HP, 0.0, 1.0) * width
	var new_value := clampf(float(new_hp) / MAX_HP, 0.0, 1.0) * width
	if local:
		ghost.offset_left = 0.0
		ghost.offset_right = old_value
	else:
		ghost.offset_left = width - old_value
		ghost.offset_right = width
	var tween := create_tween()
	tween.set_parallel(true)
	if local:
		tween.tween_property(ghost, "offset_right", new_value, 0.35).set_delay(0.25)
	else:
		tween.tween_property(ghost, "offset_left", width - new_value, 0.35).set_delay(0.25)
	bg.pivot_offset = bg.size * 0.5
	bg.scale = Vector2(1.16, 1.16)
	tween.tween_property(bg, "scale", Vector2.ONE, 0.18)


func _on_rematch_pressed() -> void:
	rematch_pressed.emit()


func _on_exit_pressed() -> void:
	exit_pressed.emit()
