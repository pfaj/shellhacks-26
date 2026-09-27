extends Control

const NET_INTERVAL := 1.0 / 20.0
const TILT_ENTER_DEGREES := 18.0
const TILT_EXIT_DEGREES := 10.0
const TILT_SMOOTHING := 22.0
const MAX_HP := 100
const JAB_DAMAGE := 5
const PUNCH_DAMAGE := 12
const CHIP_RATIO := 0.3
const RESULT_DELAY := 0.9
const ROUND_BREAK := 1.6
const ROUND_TIME := 60.0
const ROUNDS_TO_WIN := 2
const COMBO_WINDOW := 1.4
const COMBO_DAMAGE_STEP := 0.04
const COMBO_DAMAGE_MAX := 1.4
const DODGE_THRESHOLD := 0.5
const SHAKE_TIME := 0.18
const SHAKE_STRENGTH := 12.0
const HIT_STOP_TIME := 0.07
const HIT_STOP_SCALE := 0.05
const COUNTDOWN_STEPS: Array[String] = ["3", "2", "1", "FIGHT!"]
const COUNTDOWN_STEP_TIME := 0.8
const COUNTDOWN_FIGHT_TIME := 0.9
const CALIBRATION_TIME := 1.0
const TILT_DRIFT_MAX := 6.0
const TILT_DRIFT_RATE := 0.35
const COMBO_PITCH_STEP := 0.06
const COMBO_PITCH_MAX := 1.45
const PUNCH_ZOOM := 1.03
const KO_ZOOM := 1.14
const KO_ZOOM_TIME := 0.45
const SHAKE_ROTATION := 0.012
const HINT_TILT := "TILT YOUR PHONE TO DODGE"
const HINT_ACTIONS := "TAP = JAB      HOLD = PUNCH      BOTH FINGERS = BLOCK"
const HINT_TILT_TIME := 6.0
const HINT_ACTIONS_TIME := 9.0

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
var _leaving := false
var _background_wide := false
var _intro := false
var _intro_step := 0
var _intro_timer := 0.0
var _first_round := true
var _vs: VsScreen
var _vs_active := false
var _calibration_left := 0.0
var _calibration_sum := 0.0
var _calibration_count := 0
var _calibrated := false
var _hinted := false
var _hint_stage := 0
var _hint_timer := 0.0
var _jab_used := false
var _punch_used := false
var _block_used := false
var _zoom_tween: Tween

@onready var _local: Fighter = $Fighters/LocalFighter
@onready var _remote: Fighter = $Fighters/RemoteFighter
@onready var _fighters: Node2D = $Fighters
@onready var _hud: Control = $Hud
@onready var _background: TextureRect = $Background


func _ready() -> void:
	Settings.ensure()
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
	Net.peer_forfeit.connect(_on_peer_forfeit)
	Net.room_ready.connect(_on_room_ready)
	Net.peer_ready_changed.connect(_on_peer_ready_changed)
	Net.status_changed.connect(_on_status_changed)
	_neutral = _raw_gamma()
	Sfx.play_music("fight")
	Sfx.play_ambience("crowd", -20.0)
	if Net.local_mode:
		var bot := Bot.new()
		bot.game = self
		add_child(bot)
	_vs = VsScreen.new()
	_vs.setup(Net.my_color, Net.peer_color)
	add_child(_vs)
	_start_round()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Sfx.stop_sfx()
	Sfx.stop_ambience(0.4)


func _process(delta: float) -> void:
	_update_shake(delta)
	_hud.set_bars(_local_hp, _remote_hp, _move, _remote_move)
	_hud.set_blocking(_controls.blocking, _remote_blocking)
	if _intro:
		_update_calibration(delta)
		_intro_timer -= delta
		_local.set_move(0.0, delta)
		_remote.set_move(0.0, delta)
		if _intro_timer <= 0.0 and not _vs_active:
			_advance_intro()
		return
	if _match_over:
		return
	_update_tilt(delta)
	_controls.update(delta)
	_local.set_move(_move, delta)
	_remote.set_move(_remote_move, delta)
	_update_round_timer(delta)
	_update_combo(delta)
	_update_hints(delta)
	_net_accumulator += delta
	if _net_accumulator >= NET_INTERVAL:
		_net_accumulator = 0.0
		_send_input()


func _input(event: InputEvent) -> void:
	if not is_round_live():
		return
	_controls.handle_event(event, size.x * 0.5)


func _layout_stage() -> void:
	var wide := size.x > size.y
	if wide != _background_wide or _background.texture == null:
		_background_wide = wide
		_background.texture = load(Arena.background_path(wide))
	Arena.layout(size, _local, _remote)


func _update_calibration(delta: float) -> void:
	if _calibration_left <= 0.0:
		return
	var raw := _raw_gamma()
	_calibration_sum += raw
	_calibration_count += 1
	_calibration_left = maxf(_calibration_left - delta, 0.0)
	if _calibration_left == 0.0 and _calibration_count > 0:
		_neutral = _calibration_sum / float(_calibration_count)
		_smoothed_gamma = _neutral
		_calibrated = true


func _update_tilt(delta: float) -> void:
	var keyboard := FighterInput.keyboard_lean()
	if keyboard != 0.0:
		_move = keyboard
		return
	var raw := _raw_gamma()
	_smoothed_gamma = lerpf(_smoothed_gamma, raw, clampf(delta * TILT_SMOOTHING, 0.0, 1.0))
	if _calibrated and absf(raw - _neutral) < TILT_DRIFT_MAX:
		_neutral = lerpf(_neutral, raw, clampf(delta * TILT_DRIFT_RATE, 0.0, 1.0))
	var value := (_smoothed_gamma - _neutral) * Settings.tilt_sensitivity
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
	_hud.set_combo_ratio(_combo_timer / COMBO_WINDOW)
	if _combo_timer == 0.0:
		_local_combo = 0
		_hud.hide_combo()


func _register_combo() -> void:
	_local_combo += 1
	_combo_timer = COMBO_WINDOW
	_hud.show_combo(_local_combo, combo_multiplier(_local_combo))


func _update_hints(delta: float) -> void:
	if _hint_stage == 0:
		return
	_hint_timer = maxf(_hint_timer - delta, 0.0)
	if _hint_stage == 1 and (absf(_move) > DODGE_THRESHOLD or _hint_timer == 0.0):
		_hint_stage = 2
		_hint_timer = HINT_ACTIONS_TIME
		_hud.show_hint(HINT_ACTIONS)
	elif _hint_stage == 2 and (_hint_timer == 0.0 or (_jab_used and _punch_used and _block_used)):
		_hint_stage = 0
		_hud.hide_hint()


func _begin_hints() -> void:
	if _hinted:
		return
	_hinted = true
	_hint_stage = 1
	_hint_timer = HINT_TILT_TIME
	_hud.show_hint(HINT_TILT)


func _on_tapped(side: int) -> void:
	if side == FighterInput.Side.LEFT:
		_jab_used = true
	else:
		_punch_used = true
	_land_action(Protocol.JAB if side == FighterInput.Side.LEFT else Protocol.PUNCH)


func _on_held(side: int) -> void:
	_on_tapped(side)


func _on_block_changed(blocking: bool) -> void:
	if blocking:
		_block_used = true
	_local.set_block(blocking)
	_send_input()


func _land_action(kind: String) -> void:
	if not is_round_live():
		return
	_local.play_action(kind)


func _on_attack_started(kind: String) -> void:
	Net.send({"t": Protocol.ACT, "kind": kind})
	get_tree().create_timer(impact_delay(kind)).timeout.connect(_resolve_hit.bind(kind))


func impact_delay(kind: String) -> float:
	return 0.05


func _resolve_hit(kind: String) -> void:
	if not is_round_live():
		return
	if mutual_disengage():
		Net.send({"t": Protocol.MISS})
		_hud.show_floating_text(_remote.position + Vector2(0, -700), "MISS", Color(0.75, 0.75, 0.85), 52)
		return
	Net.send({"t": Protocol.HIT, "kind": kind, "combo": _local_combo})


func mutual_disengage() -> bool:
	if absf(_move) <= DODGE_THRESHOLD or absf(_remote_move) <= DODGE_THRESHOLD:
		return false
	return signf(_move) == signf(_remote_move)


func remote_is_attacking() -> bool:
	return _remote.state == Fighter.Action.JAB or _remote.state == Fighter.Action.PUNCH


func is_match_over() -> bool:
	return _match_over


func is_round_live() -> bool:
	return not _intro and not _match_over


func bot_defense_result(kind: String) -> Dictionary:
	var blocked := _remote_blocking
	var base := _chip_damage(kind) if blocked else _base_damage(kind)
	var damage := _scaled_damage(base, _local_combo)
	return {
		"t": Protocol.HIT_RESULT,
		"blocked": blocked,
		"damage": damage,
		"kind": kind,
	}


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
			_resolve_incoming_hit(str(message.get("kind", Protocol.JAB)), int(message.get("combo", 0)))
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


func _resolve_incoming_hit(kind: String, combo: int) -> void:
	if not is_round_live():
		return
	if _controls.blocking:
		var chip := _scaled_damage(_chip_damage(kind), combo)
		Net.send({
			"t": Protocol.HIT_RESULT,
			"blocked": true,
			"damage": chip,
			"hp": maxi(_local_hp - chip, 0),
			"kind": kind,
		})
		_apply_local_damage(chip, true, kind, combo)
		return
	var damage := _scaled_damage(_base_damage(kind), combo)
	Net.send({
		"t": Protocol.HIT_RESULT,
		"blocked": false,
		"damage": damage,
		"hp": maxi(_local_hp - damage, 0),
		"kind": kind,
	})
	_apply_local_damage(damage, false, kind, combo)


func _apply_hit_result(message: Dictionary) -> void:
	_apply_remote_damage(
		int(message.get("damage", 0)),
		bool(message.get("blocked", false)),
		str(message.get("kind", Protocol.JAB))
	)


func _apply_local_damage(damage: int, blocked: bool, kind: String, combo := 0) -> void:
	if damage <= 0:
		return
	_local_hp = maxi(_local_hp - damage, 0)
	_hud.show_damage(_local, damage, blocked, true)
	_hud.flash_hit(_local)
	_hud.show_impact(_local, kind == Protocol.PUNCH and not blocked, blocked)
	if blocked:
		_local.knockback(0.35)
		_local.block_hit()
	else:
		_hit_stop()
		_shake()
		_local.knockback(1.0)
		Sfx.swell_ambience(-8.0, 0.08, 0.9)
		if kind == Protocol.PUNCH:
			Fx.vignette(0.4, 0.35)
		Fx.flash(0.18 if kind == Protocol.PUNCH else 0.08)
		_local_combo = 0
		_combo_timer = 0.0
		_hud.hide_combo()
		_local.play_hurt(kind, _combo_pitch(combo))
		_hud.set_local_action("HURT")
	if _local_hp <= 0:
		_local.play_action(Protocol.KO)
		_ko_moment(_local)
		_finish_match(Result.LOSE)


func _apply_remote_damage(damage: int, blocked: bool, kind: String) -> void:
	if damage <= 0:
		return
	_remote_hp = maxi(_remote_hp - damage, 0)
	_hud.show_damage(_remote, damage, blocked, false)
	_hud.flash_hit(_remote)
	_hud.show_impact(_remote, kind == Protocol.PUNCH and not blocked, blocked)
	if blocked:
		_remote.knockback(-0.35)
		_remote.block_hit()
	else:
		_hit_stop()
		_shake()
		_remote.knockback(-1.0)
		Sfx.swell_ambience(-8.0, 0.08, 0.9)
		if kind == Protocol.PUNCH:
			Fx.vignette(0.4, 0.35)
		Fx.flash(0.18 if kind == Protocol.PUNCH else 0.08)
		_register_combo()
		_remote.play_hurt(kind, _combo_pitch(_local_combo))
		_hud.set_remote_action("HURT")
		if _remote_hp > 0:
			_punch_zoom()
	if _remote_hp <= 0:
		_remote.play_action(Protocol.KO)
		_ko_moment(_remote)
		_finish_match(Result.WIN)


func _combo_pitch(combo: int) -> float:
	return clampf(1.0 + COMBO_PITCH_STEP * maxi(combo, 0), 1.0, COMBO_PITCH_MAX)


func _base_damage(kind: String) -> int:
	return PUNCH_DAMAGE if kind == Protocol.PUNCH else JAB_DAMAGE


func _chip_damage(kind: String) -> int:
	return ceili(_base_damage(kind) * CHIP_RATIO)


func combo_multiplier(combo: int) -> float:
	return minf(1.0 + COMBO_DAMAGE_STEP * maxi(combo, 0), COMBO_DAMAGE_MAX)


func _scaled_damage(base: int, combo: int) -> int:
	return maxi(1, int(roundf(base * combo_multiplier(combo))))


func _finish_match(result: Result) -> void:
	if _match_over:
		return
	_match_over = true
	_controls.reset()
	_hud.hide_combo()
	_hud.hide_hint()
	_hint_stage = 0
	_local_combo = 0
	_combo_timer = 0.0
	match result:
		Result.WIN:
			Net.local_rounds += 1
			Net.send({"t": Protocol.ROUND_END})
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
		Sfx.play("crowd_roar")
		Sfx.swell_ambience(-2.0, 0.2, 2.4)
		return
	_hud.show_result(_round_text(result), _match_status(), false)
	Sfx.play("roundstart")
	Sfx.swell_ambience(-10.0, 0.1, 1.2)
	await get_tree().create_timer(ROUND_BREAK).timeout
	if is_inside_tree():
		_start_round()


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
		_start_round()


func _start_round() -> void:
	_match_over = false
	_local_rematch = false
	_remote_rematch = false
	_local_hp = MAX_HP
	_remote_hp = MAX_HP
	_round_time = ROUND_TIME
	_local_combo = 0
	_combo_timer = 0.0
	_move = 0.0
	_remote_move = 0.0
	_remote_blocking = false
	_hud.hide_combo()
	_hud.hide_result()
	_hud.hide_ko()
	_hud.set_status("")
	_hud.set_timer(ROUND_TIME)
	_hud.set_pips(Net.local_rounds, Net.remote_rounds)
	_local.reset_round()
	_remote.reset_round()
	_controls.reset()
	_stage_reset()
	_intro = true
	_intro_step = -1
	_intro_timer = 0.0
	if _first_round:
		_first_round = false
		_calibration_left = CALIBRATION_TIME
		_calibration_sum = 0.0
		_calibration_count = 0
		_run_vs_intro()
	else:
		_advance_intro()


func _run_vs_intro() -> void:
	_vs_active = true
	_hud.play_intro()
	await _vs.play(Ui.wipe_covered)
	Ui.wipe_covered = false
	_vs_active = false
	_advance_intro()


func _advance_intro() -> void:
	_intro_step += 1
	if _intro_step >= COUNTDOWN_STEPS.size():
		_intro = false
		_hud.hide_countdown()
		_begin_hints()
		return
	if _intro_step == 0:
		Sfx.play("countdown")
	elif _intro_step == COUNTDOWN_STEPS.size() - 1:
		Sfx.play("roundstart")
		Sfx.swell_ambience(-6.0, 0.05, 1.2)
	_hud.set_countdown(COUNTDOWN_STEPS[_intro_step])
	_intro_timer = COUNTDOWN_FIGHT_TIME if _intro_step == COUNTDOWN_STEPS.size() - 1 else COUNTDOWN_STEP_TIME


func _on_peer_left() -> void:
	_remote.play_action(Protocol.KO)
	_hud.set_status("Opponent disconnected - waiting for reconnect...")
	if _match_over:
		_hud.set_result_status("Opponent left the match")
		_hud.disable_rematch()


func _on_peer_forfeit() -> void:
	if _match_over:
		return
	_match_over = true
	_controls.reset()
	_hud.hide_combo()
	_hud.hide_hint()
	_hint_stage = 0
	Net.add_win()
	_remote.play_action(Protocol.KO)
	_hud.show_result("YOU WIN", "Opponent forfeited", false)
	Sfx.play("win")


func _on_room_ready() -> void:
	if not _leaving and not Net.local_mode:
		_hud.set_status("Opponent reconnected")


func _on_peer_ready_changed(value: bool) -> void:
	if value:
		_return_to_lobby()


func _return_to_lobby() -> void:
	if Net.local_mode or _leaving:
		return
	_leaving = true
	Net.local_rounds = 0
	Net.remote_rounds = 0
	Fx.goto("res://scenes/lobby_screen.tscn")


func _on_status_changed(text: String) -> void:
	if text == "Disconnected" or text.begins_with("Connection lost"):
		_hud.set_status(text)


func _on_exit_pressed() -> void:
	Sfx.stop_music()
	Net.leave(not _match_over)
	Fx.goto("res://scenes/main_menu.tscn")


func _shake() -> void:
	_shake_time = SHAKE_TIME
	_shake_strength = SHAKE_STRENGTH


func _ko_moment(victim: Node2D) -> void:
	_hud.show_ko()
	_hud.show_impact(victim, true)
	Fx.flash(0.35)
	Fx.vignette(0.6, 1.2)
	_zoom_stage(victim.position, KO_ZOOM, KO_ZOOM_TIME)
	Sfx.play("crowd_roar")
	Sfx.swell_ambience(-2.0, 0.25, 2.6)
	await get_tree().create_timer(0.12, true, false, true).timeout
	if not is_inside_tree():
		return
	Engine.time_scale = 0.4
	await get_tree().create_timer(0.5, true, false, true).timeout
	Engine.time_scale = 1.0


func _punch_zoom() -> void:
	_kill_zoom_tween()
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(_fighters, "scale", Vector2.ONE * PUNCH_ZOOM, 0.06)
	_zoom_tween.tween_property(_fighters, "scale", Vector2.ONE, 0.16)


func _zoom_stage(focus: Vector2, zoom: float, time: float) -> void:
	_kill_zoom_tween()
	_zoom_tween = create_tween().set_parallel(true)
	_zoom_tween.tween_property(_fighters, "scale", Vector2.ONE * zoom, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(_fighters, "position", focus * (1.0 - zoom), time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _stage_reset() -> void:
	_kill_zoom_tween()
	_fighters.scale = Vector2.ONE
	_fighters.position = Vector2.ZERO
	_fighters.rotation = 0.0


func _kill_zoom_tween() -> void:
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()


func _update_shake(delta: float) -> void:
	if _shake_time <= 0.0:
		return
	_shake_time = maxf(_shake_time - delta, 0.0)
	if _shake_time <= 0.0:
		position = Vector2.ZERO
		_fighters.rotation = 0.0
		return
	var amount := _shake_strength * (_shake_time / SHAKE_TIME)
	position = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
	_fighters.rotation = randf_range(-SHAKE_ROTATION, SHAKE_ROTATION) * (_shake_time / SHAKE_TIME)


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
