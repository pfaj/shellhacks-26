extends Control


func _ready() -> void:
	Sfx.play_music("menu")
	$MarginContainer/VBoxContainer/WinsLabel.text = "LIFETIME  %dW - %dL" % [Net.my_wins, Net.my_losses]
	var rejoin: Button = $MarginContainer/VBoxContainer/RejoinButton
	rejoin.visible = not Net.last_room.is_empty() and Net.had_match
	if rejoin.visible:
		rejoin.text = "REJOIN  %s" % Net.last_room


func _on_rejoin_pressed() -> void:
	Net.rejoin()
	get_tree().change_scene_to_file("res://scenes/connect_screen.tscn")


func _on_play_online_pressed() -> void:
	Net.local_mode = false
	get_tree().change_scene_to_file("res://scenes/connect_screen.tscn")


func _on_play_local_pressed() -> void:
	Net.local_mode = true
	Net.reset_ready()
	Net.local_rounds = 0
	Net.remote_rounds = 0
	Net.peer_name = "BOT"
	Net.peer_wins = 0
	Net.peer_losses = 0
	Net.peer_color = _bot_color()
	get_tree().change_scene_to_file("res://scenes/play_screen.tscn")


func _bot_color() -> Color:
	return Color("2f81f7") if Net.my_color.r > 0.5 else Color("e5424a")


func _on_tilt_test_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/tilt_test.tscn")
