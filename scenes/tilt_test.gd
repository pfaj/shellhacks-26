extends Control

const MAX_TILT_DEGREES := 30.0
const DEADZONE_DEGREES := 2.0
const SMOOTHING := 12.0

@onready var _status: Label = $Status
@onready var _marker: ColorRect = $Marker
@onready var _calibrate_button: Button = $CalibrateButton
@onready var _back_button: Button = $BackButton

var _tilt: JavaScriptObject = null
var _neutral := 0.0
var _smoothed_gamma := 0.0
var _taps := 0


func _ready() -> void:
	if OS.has_feature("web"):
		_tilt = JavaScriptBridge.get_interface("sockemTilt")
	_calibrate_button.pressed.connect(_on_calibrate_pressed)
	_back_button.pressed.connect(_on_back_pressed)


func _process(delta: float) -> void:
	var gamma := 0.0
	if _tilt != null:
		gamma = float(_tilt.gamma)
	_smoothed_gamma = lerpf(_smoothed_gamma, gamma, clampf(delta * SMOOTHING, 0.0, 1.0))
	var value := _smoothed_gamma - _neutral
	if absf(value) < DEADZONE_DEGREES:
		value = 0.0
	var travel := maxf(size.x * 0.5 - 80.0, 1.0)
	var offset := clampf(value / MAX_TILT_DEGREES, -1.0, 1.0) * travel
	_marker.position.x = size.x * 0.5 + offset - _marker.size.x * 0.5
	_marker.position.y = size.y * 0.5 - _marker.size.y * 0.5
	_status.text = _status_text(gamma, value)


func _status_text(gamma: float, value: float) -> String:
	var lines: PackedStringArray = []
	if not OS.has_feature("web"):
		lines.append("Not running in a browser - tilt unavailable.")
		lines.append("Taps: %d" % _taps)
		return "\n".join(lines)
	if _tilt == null:
		lines.append("Tilt bridge missing. Is head_include set on the export preset?")
		lines.append("Taps: %d" % _taps)
		return "\n".join(lines)
	lines.append("permission: %s" % str(_tilt.permission))
	lines.append("ready: %s" % str(_tilt.ready))
	lines.append("alpha %6.1f   beta %6.1f   gamma %6.1f" % [float(_tilt.alpha), float(_tilt.beta), float(_tilt.gamma)])
	lines.append("gamma %6.1f   neutral %6.1f   value %6.1f" % [gamma, _neutral, value])
	if str(_tilt.error) != "":
		lines.append("error: %s" % str(_tilt.error))
	lines.append("Taps: %d" % _taps)
	return "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_taps += 1
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_taps += 1


func _on_calibrate_pressed() -> void:
	_neutral = _smoothed_gamma


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
