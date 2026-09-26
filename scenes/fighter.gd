extends Node2D

const MOVE_RANGE := 130.0

@onready var _body: Node2D = $Body
@onready var _arm_l: Node2D = $Body/ArmLPivot
@onready var _arm_r: Node2D = $Body/ArmRPivot

var _base_x := 0.0
var _move := 0.0
var _bob := 0.0
var _punching := false
var _blocking := false


func setup(color: Color, base_x: float, scale_factor: float, facing_left: bool) -> void:
	var arm_color := color.lightened(0.2)
	$Body/Torso.color = color
	$Body/Head.color = color.darkened(0.2)
	$Body/ArmLPivot/ArmL.color = arm_color
	$Body/ArmRPivot/ArmR.color = arm_color
	_base_x = base_x
	position.x = base_x
	scale = Vector2(scale_factor, scale_factor)
	_body.scale.x = -1.0 if facing_left else 1.0


func set_move(value: float, delta: float) -> void:
	_move = lerpf(_move, value, clampf(delta * 8.0, 0.0, 1.0))
	position.x = _base_x + _move * MOVE_RANGE


func punch(hand: String) -> void:
	if _punching or _blocking:
		return
	_punching = true
	var pivot: Node2D = _arm_l if hand == "left" else _arm_r
	var tween := create_tween()
	tween.tween_property(pivot, "rotation", -PI * 0.5, 0.07)
	tween.tween_property(pivot, "rotation", 0.0, 0.18).set_delay(0.04)
	tween.finished.connect(_on_punch_finished)


func _on_punch_finished() -> void:
	_punching = false


func set_block(value: bool) -> void:
	if value == _blocking:
		return
	_blocking = value
	var target := PI * 0.85 if value else 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_arm_l, "rotation", target, 0.12)
	tween.tween_property(_arm_r, "rotation", target, 0.12)


func _process(delta: float) -> void:
	_bob += delta
	_body.position.y = sin(_bob * 3.0) * 6.0
