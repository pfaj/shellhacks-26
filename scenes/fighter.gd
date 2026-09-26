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

@onready var _lean: Node2D = $Lean
@onready var _anim: AnimationPlayer = $AnimationPlayer

var _base_x := 0.0
var _move := 0.0
var _blocking := false


func _ready() -> void:
	_anim.animation_finished.connect(_on_animation_finished)


func setup(color: Color, base_x: float, scale_factor: float, facing_left: bool, skin := "default") -> void:
	_base_x = base_x
	position.x = base_x
	scale = Vector2(scale_factor, scale_factor)
	_lean.scale.x = -1.0 if facing_left else 1.0
	_apply_color(color)
	_apply_skin(skin)
	_anim.play("idle")


func set_move(value: float, delta: float) -> void:
	_move = lerpf(_move, value, clampf(delta * 8.0, 0.0, 1.0))
	position.x = _base_x + _move * MOVE_RANGE
	_lean.rotation = lerpf(_lean.rotation, _move * 0.12, clampf(delta * 10.0, 0.0, 1.0))


func play_action(kind: String) -> void:
	if _blocking and kind != "hurt":
		return
	match kind:
		"jab":
			_anim.play("jab", 0.03)
			Sfx.play("jab", 0.05)
		"punch":
			_anim.play("punch", 0.03)
			Sfx.play("punch", 0.05)
		"hurt":
			_anim.play("hurt", 0.03)
			Sfx.play("hurt", 0.05)
		"ko":
			_anim.play("ko", 0.1)
			Sfx.play("ko")


func set_block(value: bool) -> void:
	if value == _blocking:
		return
	_blocking = value
	if value:
		_anim.play("block", 0.08)
		Sfx.play("block", 0.05)
	else:
		_anim.play("idle", 0.08)


func _on_animation_finished(anim_name: StringName) -> void:
	if str(anim_name) == "ko":
		return
	if _blocking:
		_anim.play("block", 0.05)
	else:
		_anim.play("idle", 0.08)


func _apply_color(color: Color) -> void:
	$Lean/Rig/TorsoSlot/TorsoPlaceholder.color = color
	$Lean/Rig/HeadSlot/HeadPlaceholder.color = color.darkened(0.2)
	$Lean/Rig/ArmLeftSlot/ArmLeftPlaceholder.color = color.lightened(0.2)
	$Lean/Rig/ArmRightSlot/ArmRightPlaceholder.color = color.lightened(0.2)


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
