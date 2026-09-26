extends Control


func _ready() -> void:
	Sfx.play_music("menu")
	$MarginContainer/VBoxContainer/WinsLabel.text = "LIFETIME  %dW - %dL" % [Net.my_wins, Net.my_losses]


func _process(delta: float) -> void:
	pass


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/connect_screen.tscn")
	print("Loading online match...")


func _on_tilt_test_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/tilt_test.tscn")
	print("Loading tilt test...")
