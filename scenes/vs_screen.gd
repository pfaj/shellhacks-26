class_name VsScreen
extends Control

var _wipe: Wipe
var _content: Control
var _local_head: Head
var _remote_head: Head
var _label: Label
var _local_color := Color.WHITE
var _peer_color := Color.WHITE


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if get_parent() is Control:
		size = (get_parent() as Control).size
	_wipe = Wipe.new()
	add_child(_wipe)
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_local_head = Head.new()
	_content.add_child(_local_head)
	_remote_head = Head.new()
	_content.add_child(_remote_head)
	_label = Label.new()
	_label.text = "VS"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 150)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 14)
	_content.add_child(_label)
	resized.connect(_layout)
	_layout()
	_apply_colors()


func setup(local_color: Color, peer_color: Color) -> void:
	_local_color = local_color
	_peer_color = peer_color
	if _wipe != null:
		_apply_colors()


func play(covered: bool) -> void:
	show()
	_layout()
	if covered:
		_wipe.place_covered()
	else:
		await _wipe.cover()
	_content.modulate.a = 0.0
	var tween := _content.create_tween().set_parallel(true)
	tween.tween_property(_content, "modulate:a", 1.0, 0.25)
	Ui.pop(_local_head, 1.25)
	Ui.pop(_remote_head, 1.25)
	Ui.pop(_label, 1.25)
	await get_tree().create_timer(0.85).timeout
	var fade := _content.create_tween()
	fade.tween_property(_content, "modulate:a", 0.0, 0.2)
	await fade.finished
	await _wipe.reveal()
	hide()


func _apply_colors() -> void:
	_wipe.setup(_peer_color, _local_color)
	_local_head.apply_color(_local_color)
	_remote_head.apply_color(_peer_color)


func _layout() -> void:
	var stage := _stage_size()
	var head_size := minf(stage.x, stage.y) * 0.4
	_place(_local_head, Vector2(stage.x * 0.29, stage.y * 0.5), head_size)
	_place(_remote_head, Vector2(stage.x * 0.71, stage.y * 0.5), head_size)
	_label.position = Vector2(0.0, stage.y * 0.5 - 100.0)
	_label.size = Vector2(stage.x, 200.0)


func _stage_size() -> Vector2:
	var stage := size
	if (stage.x <= 0.0 or stage.y <= 0.0) and get_parent() is Control:
		stage = (get_parent() as Control).size
	return stage


func _place(node: Control, center: Vector2, head_size: float) -> void:
	node.size = Vector2(head_size, head_size)
	node.position = center - node.size * 0.5
