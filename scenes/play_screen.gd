extends Control

const NET_INTERVAL := 1.0 / 20.0
const TILT_ENTER_DEGREES := 18.0
const TILT_EXIT_DEGREES := 10.0
const TILT_SMOOTHING := 22.0
const LOCAL_Y := 0.95
const REMOTE_Y := 0.70
const MAX_HP := 100
const JAB_DAMAGE := 5
const PUNCH_DAMAGE := 12
const CHIP_RATIO := 0.3
const RESULT_DELAY := 0.9
const ROUND_BREAK := 1.6
const ROUND_TIME := 60.0
const ROUNDS_TO_WIN := 2
const COMBO_WINDOW := 1.4
const DODGE_THRESHOLD := 0.5
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
@onready var _hud: Control = $Hud
@onready var _floor: ColorRect = $Floor
@onready var _rope_top: ColorRect = $RopeTop
@onready var _rope_mid: ColorRect = $RopeMid


func _ready() -> void:
	if OS.has_feature("web"):
		_tilt = JavaScriptBridge.get_interface("sockemTilt")
	_local.setup(Net.my_color, true)
	_remote.setup(Net.peer_color, false)
	_layout_stage()
	resized.connect(_layout_stage)
	_local.attack_started.connect(_on_attack_started)
	_hud.setup(Net.my_name, Net.my_color, Net.peer_name, Net.peer_color, $Fighters)
	_hud.set_timer(ROUND_TIME)
	_hud.set_pips(Net.local_rounds, Net.remote_rounds)
	_hud.rematch_pressed.connect(_on_rematch_pressed)
	_hud.exit_pressed.connect(_on_exit_pressed)
	_controls.tapped.connect(_on_tapped)
	_controls.held.connect(_on_held)
	_controls.block_changed.connect(_on_block_changed)
	Net.peer_message.connect(_on_peer_message)
	Net.peer_left.connect(_on_peer_left)
	Net.status_changed.connect(_on_status_changed)
	_neutral = _raw_gamma()
	Sfx.play_music("fight")


func _process(delta: float) -> void:
	_update_shake(delta)
	_hud.set_bars(_local_hp, _remote_hp, _move, _remote_move)
	_hud.set_blocking(_controls.blocking, _remote_blocking)
	if _match_over:
		return
	_update_tilt(delta)
	_controls.update(delta)
	_local.set_move(_move, delta)
	_remote.set_move(_remote_move, delta)
	_update_round_timer(delta)
	_update_combo(delta)
	_net_accumulator += delta
	if _net_accumulator >= NET_INTERVAL:
		_net_accumulator = 0.0
		_send_input()


func _input(event: InputEvent) -> void:
	if _match_over:
		return
	_controls.handle_event(event, size.x * 0.5)


func _layout_stage() -> void:
	var design_height := size.x * (1920.0 / 1080.0)
	var stage_height := minf(size.y, design_height)
	var floor_y := stage_height * 0.62 / size.y
	_floor.anchor_top = floor_y
	_floor.anchor_bottom = 1.0
	var rope_top_y := stage_height * 0.06 / size.y
	_rope_top.anchor_top = rope_top_y
	_rope_top.anchor_bottom = rope_top_y
	var rope_mid_y := stage_height * 0.14 / size.y
	_rope_mid.anchor_top = rope_mid_y
	_rope_mid.anchor_bottom = rope_mid_y
	var center := size.x * 0.5
	_local.place(Vector2(center, stage_height * LOCAL_Y))
	_remote.place(Vector2(center, stage_height * REMOTE_Y))


func _update_tilt(delta: float) -> void:
	_smoothed_gamma = lerpf(_smoothed_gamma, _raw_gamma(), clampf(delta * TILT_SMOOTHING, 0.0, 1.0))
	var value := _smoothed_gamma - _neutral
	if value > TILT_ENTER_DEGREES:
		_move = 1.0
	elif value < -TILT_ENTER_DEGREES:
		_move = -1.0
	elif absf(value) < TILT_EXIT_DEGREES:
		_move = 0.0


func _update_round_timer(delta: float) -> void:
	_round_time = maxf(_round_time - delta, 0.0)
	_hud.set_timer(_round_time)
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
		_hud.hide_combo()


func _register_combo() -> void:
	_local_combo += 1
	_combo_timer = COMBO_WINDOW
	_hud.show_combo(_local_combo)


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
	_local.play_action(kind)


func _on_attack_started(kind: String) -> void:
	Net.send({"t": Protocol.ACT, "kind": kind})
	get_tree().create_timer(_impact_delay(kind)).timeout.connect(_resolve_hit.bind(kind))


func _impact_delay(kind: String) -> float:
	return 0.05


func _resolve_hit(kind: String) -> void:
	if _match_over:
		return
	if _mutual_disengage():
		Net.send({"t": Protocol.MISS})
		_hud.show_floating_text(_remote.position + Vector2(0, -700), "MISS", Color(0.75, 0.75, 0.85), 52)
		return
	Net.send({"t": Protocol.HIT, "kind": kind})


func _mutual_disengage() -> bool:
	if absf(_move) <= DODGE_THRESHOLD or absf(_remote_move) <= DODGE_THRESHOLD:
		return false
	return signf(_move) == signf(_remote_move)


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
			_hud.set_remote_action(kind.to_upper())
		Protocol.HIT:
			_resolve_incoming_hit(str(message.get("kind", Protocol.JAB)))
		Protocol.HIT_RESULT:
			_apply_hit_result(message)
		Protocol.MISS:
			if absf(_move) > DODGE_THRESHOLD:
				_hud.show_floating_text(_local.position + Vector2(0, -760), "DODGE!", Color(0.45, 0.9, 1.0), 64)
		Protocol.REMATCH:
			_remote_rematch = true
			_hud.set_result_status("Opponent wants a rematch")
			if not _local_rematch:
				_hud.set_rematch_accept()
			_check_rematch()


func _resolve_incoming_hit(kind: String) -> void:
	if _match_over:
		return
	if _controls.blocking:
		var chip := _chip_damage(kind)
		Net.send({
			"t": Protocol.HIT_RESULT,
			"blocked": true,
			"damage": chip,
			"hp": maxi(_local_hp - chip, 0),
			"kind": kind,
		})
		_apply_local_damage(chip, true, kind)
		return
	var damage := _base_damage(kind)
	Net.send({
		"t": Protocol.HIT_RESULT,
		"blocked": false,
		"damage": damage,
		"hp": maxi(_local_hp - damage, 0),
		"kind": kind,
	})
	_apply_local_damage(damage, false, kind)


func _apply_hit_result(message: Dictionary) -> void:
	_apply_remote_damage(
		int(message.get("damage", 0)),
		bool(message.get("blocked", false)),
		str(message.get("kind", Protocol.JAB))
	)


func _apply_local_damage(damage: int, blocked: bool, kind: String) -> void:
	if damage <= 0:
		return
	_local_hp = maxi(_local_hp - damage, 0)
	_hud.show_damage(_local, damage, blocked)
	_hud.show_hit_marker(_local, blocked)
	if blocked:
		_local.block_hit()
	else:
		_hit_stop()
		_shake()
		_local_combo = 0
		_combo_timer = 0.0
		_hud.hide_combo()
		_local.play_hurt(kind)
		_hud.set_local_action("HURT")
	if _local_hp <= 0:
		_local.play_action(Protocol.KO)
		_finish_match(Result.LOSE)


func _apply_remote_damage(damage: int, blocked: bool, kind: String) -> void:
	if damage <= 0:
		return
	_remote_hp = maxi(_remote_hp - damage, 0)
	_hud.show_damage(_remote, damage, blocked)
	_hud.show_hit_marker(_remote, blocked)
	if blocked:
		_remote.block_hit()
	else:
		_hit_stop()
		_shake()
		_register_combo()
		_remote.play_hurt(kind)
		_hud.set_remote_action("HURT")
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
	_hud.hide_combo()
	_local_combo = 0
	_combo_timer = 0.0
	match result:
		Result.WIN:
			Net.local_rounds += 1
		Result.LOSE:
			Net.remote_rounds += 1
		Result.DRAW:
			pass
	_hud.set_pips(Net.local_rounds, Net.remote_rounds)
	await get_tree().create_timer(RESULT_DELAY).timeout
	if not is_inside_tree():
		return
	var won_match := Net.local_rounds >= ROUNDS_TO_WIN
	var lost_match := Net.remote_rounds >= ROUNDS_TO_WIN
	if won_match or lost_match:
		if won_match:
			Net.add_win()
		else:
			Net.add_loss()
		_hud.show_result("YOU WIN" if won_match else "YOU LOSE", _match_status(), true)
		Sfx.play("win" if won_match else "lose")
		return
	_hud.show_result(_round_text(result), _match_status(), false)
	await get_tree().create_timer(ROUND_BREAK).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/prematch_screen.tscn")


func _match_status() -> String:
	return "%d - %d\nYOU  %dW - %dL    THEM  %dW - %dL" % [Net.local_rounds, Net.remote_rounds, Net.my_wins, Net.my_losses, Net.peer_wins, Net.peer_losses]


func _round_text(result: Result) -> String:
	match result:
		Result.WIN:
			return "ROUND WON"
		Result.LOSE:
			return "ROUND LOST"
	return "DRAW"


func _on_rematch_pressed() -> void:
	if _local_rematch:
		return
	_local_rematch = true
	Net.send({"t": Protocol.REMATCH})
	_hud.set_rematch_waiting()
	_hud.set_result_status("Waiting for opponent...")
	_check_rematch()


func _check_rematch() -> void:
	if _local_rematch and _remote_rematch:
		Net.local_rounds = 0
		Net.remote_rounds = 0
		get_tree().change_scene_to_file("res://scenes/prematch_screen.tscn")


func _on_peer_left() -> void:
	_remote.play_action(Protocol.KO)
	_hud.set_status("Opponent disconnected")
	if _match_over:
		_hud.set_result_status("Opponent left the match")
		_hud.disable_rematch()


func _on_status_changed(text: String) -> void:
	if text == "Disconnected":
		_hud.set_status("Connection lost")


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


func _raw_gamma() -> float:
	if _tilt == null:
		return 0.0
	return float(_tilt.gamma)
