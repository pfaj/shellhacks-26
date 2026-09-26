extends Node

var _requested := false


func _input(event: InputEvent) -> void:
	if _requested:
		return
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif event is InputEventMouseButton and event.pressed:
		pressed = true
	if not pressed:
		return
	_requested = true
	if OS.has_feature("web"):
		JavaScriptBridge.eval("sockemStartTilt()")
