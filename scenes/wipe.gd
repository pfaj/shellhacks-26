class_name Wipe
extends Control

var _left: Polygon2D
var _right: Polygon2D
var _left_color := Color.WHITE
var _right_color := Color.WHITE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if get_parent() is Control:
		size = (get_parent() as Control).size
	_left = Polygon2D.new()
	_right = Polygon2D.new()
	add_child(_left)
	add_child(_right)
	resized.connect(_update_shapes)
	_update_shapes()


func setup(left_color: Color, right_color: Color) -> void:
	_left_color = left_color
	_right_color = right_color
	if _left != null:
		_left.color = left_color
		_right.color = right_color


func place_hidden() -> void:
	var w := _span().x
	_left.position = Vector2(-w, 0.0)
	_right.position = Vector2(w, 0.0)


func place_covered() -> void:
	_left.position = Vector2.ZERO
	_right.position = Vector2.ZERO


func cover(time := 0.4) -> void:
	_update_shapes()
	place_hidden()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_left, "position", Vector2.ZERO, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_right, "position", Vector2.ZERO, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func reveal(time := 0.4) -> void:
	_update_shapes()
	var w := _span().x
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_left, "position", Vector2(-w, 0.0), time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_right, "position", Vector2(w, 0.0), time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _span() -> Vector2:
	var w := size.x
	var h := size.y
	if (w <= 0.0 or h <= 0.0) and get_parent() is Control:
		w = (get_parent() as Control).size.x
		h = (get_parent() as Control).size.y
	return Vector2(w, h)


func _update_shapes() -> void:
	var span := _span()
	_left.color = _left_color
	_right.color = _right_color
	_left.polygon = PackedVector2Array([Vector2(0, 0), Vector2(span.x, 0), Vector2(0, span.y)])
	_right.polygon = PackedVector2Array([Vector2(span.x, 0), Vector2(span.x, span.y), Vector2(0, span.y)])
