class_name Fighter
extends Node2D

signal attack_started(kind: String)

const POSE_DIR := "res://assets/fighters/Shaded Bots/"
const OVERLAY_SHADER := preload("res://scenes/overlay_tint.gdshader")
const LOCAL_PREFIX := "Shellhacks_Bots_P1 "
const PEER_PREFIX := "Shellhacks_Bots_Opponent "
const FLIP := true
const LOCAL_POSES := {
	"idle_a": "Idle 1",
	"idle_b": "Idle 2",
	"jab": "Right Jab",
	"jab_l": "Right Jab",
	"jab_r": "Right Jab R",
	"punch": "Left Hook",
	"punch_l": "Left Hook L",
	"punch_r": "Left Hook",
	"block": "Block",
	"block_l": "Block L",
	"block_r": "Block R",
	"hurt_l": "Hit Left",
	"hurt_r": "Hit Right",
	"dodge_l": "Dodge L",
	"dodge_r": "Dodge R",
	"ko": "Knockout",
}
const PEER_POSES := {
	"idle_a": "Idle 1",
	"idle_b": "Idle 2",
	"jab": "L Hook",
	"jab_l": "Left Hook L",
	"jab_r": "L Hook",
	"punch": "R Jab",
	"punch_l": "R Jab",
	"punch_r": "Right Hook R",
	"block": "Block",
	"block_l": "Block L",
	"block_r": "Block R",
	"hurt_l": "Hit L",
	"hurt_r": "Hit R",
	"dodge_l": "Dodge L",
	"dodge_r": "Dodge R",
	"ko": "Knockout",
}
const LOCAL_ALIGN := {
	"idle_a": Vector2(0.5247, 0.9474),
	"idle_b": Vector2(0.4962, 0.9474),
	"jab": Vector2(0.5241, 0.9672),
	"jab_l": Vector2(0.5241, 0.9672),
	"jab_r": Vector2(0.5198, 0.9581),
	"punch": Vector2(0.4684, 0.9550),
	"punch_l": Vector2(0.4920, 0.9428),
	"punch_r": Vector2(0.4684, 0.9550),
	"block": Vector2(0.5011, 0.9505),
	"block_l": Vector2(0.5005, 0.9413),
	"block_r": Vector2(0.5059, 0.9413),
	"hurt_l": Vector2(0.5273, 0.9566),
	"hurt_r": Vector2(0.5279, 0.9566),
	"dodge_l": Vector2(0.4770, 0.9474),
	"dodge_r": Vector2(0.5091, 0.9474),
	"ko": Vector2(0.5011, 0.9535),
}
const PEER_ALIGN := {
	"idle_a": Vector2(0.4719, 0.9355),
	"idle_b": Vector2(0.4738, 0.9355),
	"jab": Vector2(0.4623, 0.9173),
	"jab_l": Vector2(0.4597, 0.9373),
	"jab_r": Vector2(0.4623, 0.9173),
	"punch": Vector2(0.5083, 0.9282),
	"punch_l": Vector2(0.5083, 0.9282),
	"punch_r": Vector2(0.5083, 0.9282),
	"block": Vector2(0.4904, 0.9282),
	"block_l": Vector2(0.4808, 0.9227),
	"block_r": Vector2(0.4904, 0.9282),
	"hurt_l": Vector2(0.5294, 0.9245),
	"hurt_r": Vector2(0.4821, 0.9264),
	"dodge_l": Vector2(0.4808, 0.9355),
	"dodge_r": Vector2(0.4904, 0.9355),
	"ko": Vector2(0.5058, 0.9391),
}
const ARTBOARD_WIDTH := 1373.0
const ARTBOARD_HEIGHT := 1930.0
const ARTBOARD_RATIO := ARTBOARD_WIDTH / ARTBOARD_HEIGHT
const LOCAL_BOT_HEIGHT := 1150.0
const PEER_BOT_HEIGHT := 950.0
const LOCAL_CONTENT_HEIGHT := 0.880
const PEER_CONTENT_HEIGHT := 0.871
const IDLE_FRAME_TIME := 0.45
const DODGE_THRESHOLD := 0.5
const MOVE_SMOOTHING := 16.0
const JAB_CHAIN_LIMIT := 2
const ATTACK_CHAIN_WINDOW := 0.6
const ATTACK_BUFFER_WINDOW := 0.3
const ATTACK_REPRIME := 0.07
const JAB_CHAIN_COOLDOWN := 0.9
const JAB_TIME := 0.2
const PUNCH_TIME := 0.55
const HURT_TIME := 0.35

enum Action { IDLE, JAB, PUNCH, BLOCK, HURT, KO }

@onready var _sprite: Sprite2D = $Sprite

var state := Action.IDLE
var _local := true
var _move := 0.0
var _block_held := false
var _cooldown := 0.0
var _chain_timer := 0.0
var _jab_count := 0
var _buffered := ""
var _buffer_timer := 0.0
var _pending_kind := ""
var _reprime_timer := 0.0
var _poses := {}
var _align := {}
var _draw_width := 0.0
var _draw_height := 0.0
var _artboard_pixel_height := ARTBOARD_HEIGHT
var _idle_frame := 0
var _idle_timer := 0.0
var _state_timer := 0.0
var _hurt_key := "hurt_r"


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
	if _reprime_timer > 0.0:
		_reprime_timer = maxf(_reprime_timer - delta, 0.0)
		if _reprime_timer == 0.0 and not _pending_kind.is_empty():
			var pending := _pending_kind
			_pending_kind = ""
			_start_attack(_action_for(pending), pending)
	if state == Action.JAB or state == Action.PUNCH or state == Action.HURT:
		_state_timer = maxf(_state_timer - delta, 0.0)
		if _state_timer == 0.0:
			_finish_action()
	_update_idle(delta)
	_refresh_pose()


func setup(color: Color, is_local: bool) -> void:
	_local = is_local
	_load_poses(is_local)
	_align = LOCAL_ALIGN if is_local else PEER_ALIGN
	var material := ShaderMaterial.new()
	material.shader = OVERLAY_SHADER
	material.set_shader_parameter("tint", color)
	_sprite.material = material
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.centered = false
	_sprite.flip_h = FLIP
	var bot_height := LOCAL_BOT_HEIGHT if is_local else PEER_BOT_HEIGHT
	var content_height := LOCAL_CONTENT_HEIGHT if is_local else PEER_CONTENT_HEIGHT
	_draw_height = bot_height / content_height
	_draw_width = _draw_height * ARTBOARD_RATIO
	var factor := _draw_height / _artboard_pixel_height
	_sprite.scale = Vector2(factor, factor)
	state = Action.IDLE
	_cooldown = 0.0
	_chain_timer = 0.0
	_jab_count = 0
	_buffered = ""
	_buffer_timer = 0.0
	_pending_kind = ""
	_reprime_timer = 0.0
	_state_timer = 0.0
	_idle_frame = 0
	_idle_timer = 0.0
	_hurt_key = "hurt_r"
	_refresh_pose()


func place(new_position: Vector2) -> void:
	position = new_position


func set_art_height(height: float) -> void:
	_draw_height = height
	_draw_width = _draw_height * ARTBOARD_RATIO
	var factor := _draw_height / _artboard_pixel_height
	_sprite.scale = Vector2(factor, factor)
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
			return play_hurt(Protocol.JAB)
		Protocol.KO:
			return _request(Action.KO)
	return false


func play_hurt(kind: String) -> bool:
	var jab := kind == Protocol.JAB
	_hurt_key = "hurt_r" if jab == _local else "hurt_l"
	return _request(Action.HURT)


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


func _finish_action() -> void:
	if not _buffered.is_empty() and _buffer_timer > 0.0:
		var kind := _buffered
		_clear_buffer()
		if _cooldown <= 0.0:
			_set_state(Action.IDLE)
			_pending_kind = kind
			_reprime_timer = ATTACK_REPRIME
			return
	_set_state(Action.BLOCK if _block_held else Action.IDLE)


func _clear_buffer() -> void:
	_buffered = ""
	_buffer_timer = 0.0
	_pending_kind = ""
	_reprime_timer = 0.0


func _action_for(kind: String) -> Action:
	if kind == Protocol.PUNCH:
		return Action.PUNCH
	return Action.JAB


func _set_state(next: Action) -> void:
	if next == state:
		return
	state = next
	_state_timer = _state_time(next)
	_play_sound(next)
	if next != Action.IDLE:
		_idle_timer = 0.0


func _state_time(action: Action) -> float:
	match action:
		Action.JAB:
			return JAB_TIME
		Action.PUNCH:
			return PUNCH_TIME
		Action.HURT:
			return HURT_TIME
	return 0.0


func _update_idle(delta: float) -> void:
	if state != Action.IDLE or absf(_move) > DODGE_THRESHOLD:
		_idle_timer = 0.0
		return
	_idle_timer += delta
	if _idle_timer >= IDLE_FRAME_TIME:
		_idle_timer = 0.0
		_idle_frame = 1 - _idle_frame


func _refresh_pose() -> void:
	var key := _pose_key()
	var texture: Texture2D = _poses.get(key)
	if texture != null and _sprite.texture != texture:
		_sprite.texture = texture
	var alignment: Vector2 = _align.get(key, _neutral_align(key))
	var offset_x := -(1.0 - alignment.x) * _draw_width if FLIP else -alignment.x * _draw_width
	_sprite.position = Vector2(offset_x, -alignment.y * _draw_height)


func _neutral_align(key: String) -> Vector2:
	return _align.get(key.trim_suffix("_l").trim_suffix("_r"), Vector2(0.5, 0.95))


func _pose_key() -> String:
	match state:
		Action.JAB:
			return "jab" + _lane_suffix()
		Action.PUNCH:
			return "punch" + _lane_suffix()
		Action.BLOCK:
			return "block" + _lane_suffix()
		Action.HURT:
			return _hurt_key
		Action.KO:
			return "ko"
	if _move < -DODGE_THRESHOLD:
		return "dodge_r" if _local else "dodge_l"
	if _move > DODGE_THRESHOLD:
		return "dodge_l" if _local else "dodge_r"
	return "idle_a" if _idle_frame == 0 else "idle_b"


func _lane_suffix() -> String:
	if _move > DODGE_THRESHOLD:
		return "_l" if _local else "_r"
	if _move < -DODGE_THRESHOLD:
		return "_r" if _local else "_l"
	return ""


func _load_poses(is_local: bool) -> void:
	_poses.clear()
	var prefix := LOCAL_PREFIX if is_local else PEER_PREFIX
	var names: Dictionary = LOCAL_POSES if is_local else PEER_POSES
	for key in names.keys():
		var path: String = "%s%s%s.svg" % [POSE_DIR, prefix, names[key]]
		if ResourceLoader.exists(path):
			var texture: Texture2D = load(path)
			_poses[key] = texture
			_artboard_pixel_height = texture.get_height()


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
