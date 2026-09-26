extends Control


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	pass


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/connect_screen.tscn")
	print("Loading online match...")


func _on_tilt_test_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/tilt_test.tscn")
	print("Loading tilt test...")
