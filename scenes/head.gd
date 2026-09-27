class_name Head
extends TextureRect

const HEAD_SHADER := preload("res://scenes/overlay_tint.gdshader")
const HEAD_TEXTURE := preload("res://assets/branding/Shellhacks_Bots_Robot Head.svg")

var _tint := Color.WHITE
var _shader_material: ShaderMaterial


func _ready() -> void:
	texture = HEAD_TEXTURE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material().set_shader_parameter("tint", _tint)


func apply_color(color: Color) -> void:
	_tint = color
	if is_inside_tree():
		_material().set_shader_parameter("tint", color)


func _material() -> ShaderMaterial:
	if _shader_material == null:
		_shader_material = ShaderMaterial.new()
		_shader_material.shader = HEAD_SHADER
		_shader_material.set_shader_parameter("base_gain", 0.72)
		material = _shader_material
	return _shader_material
