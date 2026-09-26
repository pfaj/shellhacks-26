extends Control   # full-screen; mouse_filter = MOUSE_FILTER_IGNORE

const HOLD_TIME := 0.15   # seconds before press becomes hold

enum State { IDLE, LEFT_TAP, RIGHT_TAP, LEFT_HOLD, RIGHT_HOLD, BLOCK }
enum Side { LEFT, RIGHT }

var left_touch  := -1     # touch index holding left half, -1 = none
var right_touch := -1
var hold_timer  := 0.0
var hold_fired  := false  # has the current press already become a hold?
var state       := State.IDLE

# keyboard stand-ins: A = left, D = right
var left_key_down  := false
var right_key_down := false

func _ready() -> void:
	%Player.display_name = Net.my_name
	%Player.color = Net.my_color
	%Player2.display_name = Net.peer_name
	%Player2.color = Net.peer_color
	# load player info


func _input(event: InputEvent) -> void:
	match event:
		_ when event is InputEventScreenTouch:
			_handle_touch(event)
		_ when event is InputEventKey and event.pressed and not event.echo:
			_handle_key(event.keycode, true)
		_ when event is InputEventKey and not event.pressed:
			_handle_key(event.keycode, false)

func _process(delta: float) -> void:
	if state == State.BLOCK or hold_fired or not _any_pressed():
		return
	hold_timer += delta
	if hold_timer >= HOLD_TIME:
		hold_fired = true
		_fire_hold(_active_side())

# --- input ---------------------------------------------------------------

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_press(true if event.position.x < size.x * 0.5 else false, event.index)
	else:
		_release(event.index)

func _handle_key(keycode: int, pressed: bool) -> void:
	if keycode == KEY_A:
		if pressed and not left_key_down:
			left_key_down = true
			_on_press(0)
		elif not pressed and left_key_down:
			left_key_down = false
			_on_release(1)
	elif keycode == KEY_D:
		if pressed and not right_key_down:
			right_key_down = true
			_on_press(1)
		elif not pressed and right_key_down:
			right_key_down = false
			_on_release(1)

func _press(on_left: bool, index: int) -> void:
	if on_left:
		if left_touch != -1: return
		left_touch = index
		_on_press(0)
	else:
		if right_touch != -1: return
		right_touch = index
		_on_press(1)

func _release(index: int) -> void:
	if index == left_touch:
		left_touch = -1
		_on_release(0)
	elif index == right_touch:
		right_touch = -1
		_on_release(1)

# --- shared press/release (touch + keyboard) -----------------------------

func _on_press(side: Side) -> void:
	_reset_hold()
	_refresh_state()

func _on_release(side: Side) -> void:
	if not hold_fired:
		_fire_tap(side)          # released before threshold -> tap
	_reset_hold()
	_refresh_state()

func _reset_hold() -> void:
	hold_timer = 0.0
	hold_fired = false

# --- state ---------------------------------------------------------------

func _refresh_state() -> void:
	if _both_pressed():
		_set_state(State.BLOCK)
	elif _left_pressed():
		_set_state(State.LEFT_TAP)
	elif _right_pressed():
		_set_state(State.RIGHT_TAP)
	else:
		_set_state(State.IDLE)

func _set_state(next: State) -> void:
	if next == state:
		return
	state = next
	match state:
		State.IDLE:       print("[input] idle")
		State.LEFT_TAP:   print("[input] left pressed")
		State.RIGHT_TAP:  print("[input] right pressed")
		State.BLOCK:      print("[input] block")

# --- temp actions --------------------------------------------------------

func _fire_tap(side: Side) -> void:
	print("[action] %s tap (quick action)" % _side_name(side))

func _fire_hold(side: Side) -> void:
	print("[action] %s hold (third action)" % _side_name(side))

# --- helpers -------------------------------------------------------------

func _side_name(side: Side) -> String:
	return "left" if side == Side.LEFT else "right"

func _left_pressed() -> bool:  return left_touch != -1 or left_key_down
func _right_pressed() -> bool: return right_touch != -1 or right_key_down
func _any_pressed() -> bool:   return _left_pressed() or _right_pressed()
func _both_pressed() -> bool:  return _left_pressed() and _right_pressed()

func _active_side() -> Side:
	return 0 if _left_pressed() else 1
