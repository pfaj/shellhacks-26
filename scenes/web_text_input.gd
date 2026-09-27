class_name WebTextInput
extends RefCounted

static var _target: LineEdit
static var _callback: JavaScriptObject


static func attach(line_edit: LineEdit) -> void:
	if not OS.has_feature("web"):
		return
	_target = line_edit
	line_edit.virtual_keyboard_enabled = false
	if _callback == null:
		_callback = JavaScriptBridge.create_callback(_on_text_changed)
		JavaScriptBridge.get_interface("window").clankerTextChanged = _callback
	line_edit.tree_exiting.connect(detach)


static func refresh() -> void:
	if not OS.has_feature("web") or _target == null:
		return
	var rect := _target.get_global_rect()
	var viewport := _target.get_viewport_rect().size
	JavaScriptBridge.get_interface("window").clankerRegisterTextInput(
		rect.position.x, rect.position.y, rect.size.x, rect.size.y,
		viewport.x, viewport.y, _target.max_length, _target.text
	)


static func detach() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.get_interface("window").clankerUnregisterTextInput()
	_target = null


static func _on_text_changed(args: Array) -> void:
	if _target == null or args.is_empty():
		return
	_target.text = str(args[0])
