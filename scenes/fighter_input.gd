class_name FighterInput
extends RefCounted

signal tapped(side: int)
signal held(side: int)
signal block_changed(blocking: bool)

const HOLD_TIME := 0.15
enum Side { LEFT, RIGHT }

var blocking := false

var _left_touch := -1
var _right_touch := -1
var _left_key := false
var _right_key := false
var _hold_timer := 0.0
var _hold_fired := false
var _left_block_used := false
var _right_block_used := false


func handle_event(event: InputEvent, half_width: float) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.position.x < half_width, event.index)
		else:
			_release(event.index)
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event.keycode, true)
	elif event is InputEventKey and not event.pressed:
		_key(event.keycode, false)


static func keyboard_lean() -> float:
	if Input.is_key_pressed(KEY_LEFT):
		return 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		return -1.0
	return 0.0


func update(delta: float) -> void:
	if blocking or _hold_fired or not _any_pressed():
		return
	_hold_timer += delta
	if _hold_timer >= HOLD_TIME:
		_hold_fired = true
		held.emit(_active_side())


func reset() -> void:
	_left_touch = -1
	_right_touch = -1
	_left_key = false
	_right_key = false
	_left_block_used = false
	_right_block_used = false
	_reset_hold()
	_set_blocking(false)


func _press(on_left: bool, index: int) -> void:
	if on_left:
		if _left_touch != -1:
			return
		_left_touch = index
	else:
		if _right_touch != -1:
			return
		_right_touch = index
	_reset_hold()
	_refresh_block()


func _release(index: int) -> void:
	var side := -1
	if index == _left_touch:
		_left_touch = -1
		side = Side.LEFT
	elif index == _right_touch:
		_right_touch = -1
		side = Side.RIGHT
	else:
		return
	_finish_press(side)


func _key(keycode: int, pressed: bool) -> void:
	var is_left := keycode == KEY_A
	var is_right := keycode == KEY_D
	if not is_left and not is_right:
		return
	if pressed:
		if is_left and not _left_key:
			_left_key = true
			_reset_hold()
			_refresh_block()
		elif is_right and not _right_key:
			_right_key = true
			_reset_hold()
			_refresh_block()
	elif is_left and _left_key:
		_left_key = false
		_finish_press(Side.LEFT)
	elif is_right and _right_key:
		_right_key = false
		_finish_press(Side.RIGHT)


func _finish_press(side: int) -> void:
	var suppressed := _consume_block(side)
	if not _hold_fired and not suppressed:
		tapped.emit(side)
	_reset_hold()
	_refresh_block()


func _consume_block(side: int) -> bool:
	if side == Side.LEFT:
		var used := _left_block_used
		_left_block_used = false
		return used
	var used := _right_block_used
	_right_block_used = false
	return used


func _refresh_block() -> void:
	var both := _left_pressed() and _right_pressed()
	if both:
		_left_block_used = true
		_right_block_used = true
	_set_blocking(both)


func _set_blocking(value: bool) -> void:
	if value == blocking:
		return
	blocking = value
	block_changed.emit(blocking)


func _reset_hold() -> void:
	_hold_timer = 0.0
	_hold_fired = false


func _left_pressed() -> bool:
	return _left_touch != -1 or _left_key


func _right_pressed() -> bool:
	return _right_touch != -1 or _right_key


func _any_pressed() -> bool:
	return _left_pressed() or _right_pressed()


func _active_side() -> int:
	return Side.LEFT if _left_pressed() else Side.RIGHT
