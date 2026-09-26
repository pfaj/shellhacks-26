class_name Fighter
extends Node2D

signal attack_started(kind: String)

const POSE_DIR := "res://assets/fighters/Trial Run Bots/"
const LOCAL_PREFIX := "Shellhacks_Bots_P1 "
const PEER_PREFIX := "Shellhacks_Bots_Opponent "
const LOCAL_POSES := {
	"idle_a": "Idle 1",
	"idle_b": "Idle 2",
	"jab": "Left Hook",
	"punch": "Right Jab",
	"block": "Block",
	"hurt": "Hit Right",
	"dodge_l": "Dodge L",
	"dodge_r": "Dodge R",
	"ko": "Knockout",
}
const PEER_POSES := {
	"idle_a": "Idle 1",
	"idle_b": "Idle 2",
	"jab": "L Hook",
	"punch": "R Jab",
	"block": "Block",
	"hurt": "Hit L",
	"dodge_l": "Dodge L",
	"dodge_r": "Dodge R",
	"ko": "Knockout",
}
const ARTBOARD_HEIGHT := 1929.94
const LOCAL_DRAW_HEIGHT := 1050.0
const PEER_DRAW_HEIGHT := 900.0
const WAIST_RATIO := 0.57
const WAIST_OFFSET := -60.0
const IDLE_FRAME_TIME := 0.45
const DODGE_THRESHOLD := 0.35
const MOVE_SMOOTHING := 16.0
const JAB_CHAIN_LIMIT := 2
const ATTACK_CHAIN_WINDOW := 0.6
const ATTACK_BUFFER_WINDOW := 0.3
const JAB_CHAIN_COOLDOWN := 0.9

enum Action { IDLE, JAB, PUNCH, BLOCK, HURT, KO }

@onready var _sprite: Sprite2D = $Sprite

var state := Action.IDLE
var _base_x := 0.0
var _move := 0.0
var _block_held := false
var _cooldown := 0.0
var _chain_timer := 0.0
var _jab_count := 0
var _buffered := ""
var _buffer_timer := 0.0
var _poses := {}
var _idle_frame := 0
var _idle_timer := 0.0


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _chain_timer > 0.0:
		_chain_timer = maxf(_chain_timer - delta, 0.0)
		if _chain_timer == 0.0:
			_jab_count = 0
	if _buffer_timer > 0.0:
		_buffer_timer = maxf(_buffer_timer - delta, 0.0)
		if _buffer_timer == 0.0:
			_buffered = ""
	_update_idle(delta)
	_refresh_pose()


func setup(color: Color, base_x: float, is_local: bool) -> void:
	_base_x = base_x
	position.x = base_x
	_load_poses(is_local)
	_sprite.self_modulate = color
	_sprite.centered = false
	var draw_height := LOCAL_DRAW_HEIGHT if is_local else PEER_DRAW_HEIGHT
	var factor := draw_height / ARTBOARD_HEIGHT
	_sprite.scale = Vector2(factor, factor)
	state = Action.IDLE
	_cooldown = 0.0
	_chain_timer = 0.0
	_jab_count = 0
	_buffered = ""
	_buffer_timer = 0.0
	_idle_frame = 0
	_idle_timer = 0.0
	_refresh_pose()


func set_move(value: float, delta: float) -> void:
	_move = lerpf(_move, value, clampf(delta * MOVE_SMOOTHING, 0.0, 1.0))


func play_action(kind: String) -> bool:
	match kind:
		Protocol.JAB:
			return _request_attack(Action.JAB, Protocol.JAB)
		Protocol.PUNCH:
			return _request_attack(Action.PUNCH, Protocol.PUNCH)
		Protocol.HURT:
			return _request(Action.HURT)
		Protocol.KO:
			return _request(Action.KO)
	return false


func set_block(value: bool) -> void:
	_block_held = value
	if state == Action.KO or state == Action.HURT:
		return
	if value:
		_clear_buffer()
		_set_state(Action.BLOCK)
	elif state == Action.BLOCK:
		_set_state(Action.IDLE)


func block_hit() -> void:
	Sfx.play(Protocol.BLOCK, 0.05)


func _request(action: Action) -> bool:
	match action:
		Action.HURT:
			if state == Action.KO:
				return false
			_clear_buffer()
			_set_state(Action.HURT)
			return true
		Action.KO:
			_clear_buffer()
			_set_state(Action.KO)
			return true
	return false


func _request_attack(action: Action, kind: String) -> bool:
	if _cooldown > 0.0:
		return false
	if state != Action.IDLE:
		if state != Action.HURT and state != Action.KO and state != Action.BLOCK:
			_buffered = kind
			_buffer_timer = ATTACK_BUFFER_WINDOW
		return false
	_start_attack(action, kind)
	return true


func _start_attack(action: Action, kind: String) -> void:
	if action == Action.JAB:
		_jab_count += 1
		if _jab_count >= JAB_CHAIN_LIMIT:
			_jab_count = 0
			_chain_timer = 0.0
			_cooldown = JAB_CHAIN_COOLDOWN
		else:
			_chain_timer = ATTACK_CHAIN_WINDOW
	else:
		_jab_count = 0
		_chain_timer = 0.0
	_set_state(action)
	attack_started.emit(kind)


func _clear_buffer() -> void:
	_buffered = ""
	_buffer_timer = 0.0


func _action_for(kind: String) -> Action:
	if kind == Protocol.PUNCH:
		return Action.PUNCH
	return Action.JAB


func _set_state(next: Action) -> void:
	if next == state:
		return
	state = next
	_play_sound(next)
	if next != Action.IDLE:
		_idle_timer = 0.0


func _update_idle(delta: float) -> void:
	if state != Action.IDLE or absf(_move) > DODGE_THRESHOLD:
		_idle_timer = 0.0
		return
	_idle_timer += delta
	if _idle_timer >= IDLE_FRAME_TIME:
		_idle_timer = 0.0
		_idle_frame = 1 - _idle_frame


func _refresh_pose() -> void:
	var texture: Texture2D = _poses.get(_pose_key())
	if texture != null and _sprite.texture != texture:
		_sprite.texture = texture


func _pose_key() -> String:
	match state:
		Action.JAB:
			return "jab"
		Action.PUNCH:
			return "punch"
		Action.BLOCK:
			return "block"
		Action.HURT:
			return "hurt"
		Action.KO:
			return "ko"
	if _move < -DODGE_THRESHOLD:
		return "dodge_l"
	if _move > DODGE_THRESHOLD:
		return "dodge_r"
	return "idle_a" if _idle_frame == 0 else "idle_b"


func _load_poses(is_local: bool) -> void:
	_poses.clear()
	var prefix := LOCAL_PREFIX if is_local else PEER_PREFIX
	var names: Dictionary = LOCAL_POSES if is_local else PEER_POSES
	for key in names.keys():
		var path: String = "%s%s%s.svg" % [POSE_DIR, prefix, names[key]]
		if ResourceLoader.exists(path):
			_poses[key] = load(path)


func _play_sound(action: Action) -> void:
	match action:
		Action.JAB:
			Sfx.play("whoosh", 0.05, 1.1)
		Action.PUNCH:
			Sfx.play("whoosh", 0.05, 0.92)
		Action.HURT:
			Sfx.play(Protocol.HURT, 0.05)
			Sfx.play(Protocol.HIT, 0.08)
		Action.KO:
			Sfx.play(Protocol.KO)
