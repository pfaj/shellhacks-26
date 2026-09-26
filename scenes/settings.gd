extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$MarginContainer/HBoxContainer/ColorRect/MarginContainer/HBoxContainer/UsernameSection/LineEdit.text = get_random_username()
	$MarginContainer/HBoxContainer/ColorRect/MarginContainer/HBoxContainer/ColorSelect/LineEdit.color=random_color


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func get_random_username() -> String:
	# Pick a random index based on the size of the array
	var random_index = randi() % usernames.size()
	return usernames[random_index]
	
	

var random_color: Color = [Color.RED, Color.BLUE, Color.ORANGE, Color.YELLOW, Color.DODGER_BLUE].pick_random()
var usernames: Array[String] = [
	"ShadowNinja",
	"Cosmic_Dust",
	"PixelWizard",
	"LunaRogue",
	"NeonByte",
	"CyberSamurai",
	"StarGazer99",
	"IronBear",
	"GlitchFox",
	"Mystic_Echo",
	"QuantumLeap",
	"ZeroCool",
	"BlazeRunner",
	"FrostBite",
	"CronoTime"
]


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	pass # Replace with function body.
