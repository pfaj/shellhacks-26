class_name Fighter
extends Node2D

const MOVE_RANGE := 130.0
const SKIN_ROOT := "res://assets/fighters/"
const EXTENSIONS: Array[String] = [".png", ".svg", ".webp"]
const LAYERS := {
	"torso": "Torso",
	"head": "Head",
	"arm_l": "ArmLeft",
	"arm_r": "ArmRight",
}

enum Action { IDLE, JAB, PUNCH, BLOCK, HURT, KO }

@onready var _lean: Node2D = $Lean
@onready var _anim: AnimationPlayer = $AnimationPlayer

var state := Action.IDLE
var _base_x := 0.0
var _move := 0.0
var _block_held := false


func _ready() -> void:
	_anim.animation_finished.connect(_on_animation_finished)


func setup(color: Color, base_x: float, scale_factor: float, facing_left: bool, skin := "default") -> void:
	_base_x = base_x
	position.x = base_x
	scale = Vector2(scale_factor, scale_factor)
	_lean.scale.x = -1.0 if facing_left else 1.0
	_apply_color(color)
	_apply_skin(skin)
	state = Action.IDLE
	_anim.play(_animation_name(Action.IDLE), 0.0)


func set_move(value: float, delta: float) -> void:
	_move = lerpf(_move, value, clampf(delta * 8.0, 0.0, 1.0))
	position.x = _base_x + _move * MOVE_RANGE
	_lean.rotation = lerpf(_lean.rotation, _move * 0.12, clampf(delta * 10.0, 0.0, 1.0))


func play_action(kind: String) -> bool:
	match kind:
		Protocol.JAB:
			return _request(Action.JAB)
		Protocol.PUNCH:
			return _request(Action.PUNCH)
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
			_set_state(Action.HURT)
			return true
		Action.KO:
			_set_state(Action.KO)
			return true
		Action.JAB, Action.PUNCH:
			if state == Action.IDLE:
				_set_state(action)
				return true
	return false


func _set_state(next: Action) -> void:
	if next == state:
		return
	state = next
	_anim.play(_animation_name(next), _blend_time(next))
	_play_sound(next)


func _on_animation_finished(_anim_name: StringName) -> void:
	if state == Action.KO:
		return
	if state == Action.JAB or state == Action.PUNCH or state == Action.HURT:
		_set_state(Action.BLOCK if _block_held else Action.IDLE)


func _animation_name(action: Action) -> String:
	match action:
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
	return "idle"


func _blend_time(action: Action) -> float:
	match action:
		Action.JAB, Action.PUNCH, Action.HURT:
			return 0.03
		Action.KO:
			return 0.1
	return 0.08


func _play_sound(action: Action) -> void:
	match action:
		Action.JAB:
			Sfx.play(Protocol.JAB, 0.05)
		Action.PUNCH:
			Sfx.play(Protocol.PUNCH, 0.05)
		Action.HURT:
			Sfx.play(Protocol.HURT, 0.05)
		Action.KO:
			Sfx.play(Protocol.KO)


func _apply_color(color: Color) -> void:
	$Lean/Rig/TorsoSlot/TorsoPlaceholder.color = color
	$Lean/Rig/HeadSlot/HeadPlaceholder.color = color.darkened(0.2)
	$Lean/Rig/HeadSlot/HeadPlaceholder/Visor.color = color.darkened(0.5)
	$Lean/Rig/ArmLeftSlot/ArmLeftPlaceholder.color = color.lightened(0.2)
	$Lean/Rig/ArmRightSlot/ArmRightPlaceholder.color = color.lightened(0.2)
	$Lean/Rig/ArmLeftSlot/ArmLeftPlaceholder/Glove.color = color.darkened(0.35)
	$Lean/Rig/ArmRightSlot/ArmRightPlaceholder/Glove.color = color.darkened(0.35)


func _apply_skin(skin: String) -> void:
	for layer in LAYERS.keys():
		var slot_name: String = LAYERS[layer]
		var sprite: Sprite2D = get_node("Lean/Rig/%sSlot/%sSprite" % [slot_name, slot_name])
		var placeholder: ColorRect = get_node("Lean/Rig/%sSlot/%sPlaceholder" % [slot_name, slot_name])
		var texture := _load_layer(skin, layer)
		sprite.texture = texture
		sprite.visible = texture != null
		placeholder.visible = texture == null


func _load_layer(skin: String, layer: String) -> Texture2D:
	for extension in EXTENSIONS:
		var path := "%s%s/%s%s" % [SKIN_ROOT, skin, layer, extension]
		if ResourceLoader.exists(path):
			return load(path)
	return null
