extends CanvasLayer

const FADE_TIME := 0.18
const FLASH_TIME := 0.12
const VIGNETTE_SHADER := preload("res://scenes/vignette.gdshader")

var _fade: ColorRect
var _flash: ColorRect
var _vignette: ColorRect
var _vignette_material: ShaderMaterial
var _vignette_tween: Tween
var _busy := false


func _ready() -> void:
	layer = 100
	_fade = _full_rect(Color(0, 0, 0, 1))
	add_child(_fade)
	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = VIGNETTE_SHADER
	_vignette = _full_rect(Color(1, 1, 1, 1))
	_vignette.material = _vignette_material
	add_child(_vignette)
	_flash = _full_rect(Color(1, 1, 1, 0))
	add_child(_flash)
	create_tween().tween_property(_fade, "color:a", 0.0, FADE_TIME)


func goto(path: String) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	await tween.finished
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	create_tween().tween_property(_fade, "color:a", 0.0, FADE_TIME)
	_busy = false


func flash(strength: float) -> void:
	_flash.color.a = strength
	create_tween().tween_property(_flash, "color:a", 0.0, FLASH_TIME)


func vignette(strength: float, duration := 0.4) -> void:
	_vignette_material.set_shader_parameter("strength", strength)
	if _vignette_tween != null and _vignette_tween.is_valid():
		_vignette_tween.kill()
	_vignette_tween = create_tween()
	_vignette_tween.tween_method(_set_vignette_strength, strength, 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_vignette_strength(value: float) -> void:
	_vignette_material.set_shader_parameter("strength", value)


func _full_rect(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
