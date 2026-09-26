extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$MarginContainer/HBoxContainer/ColorRect/MarginContainer/HBoxContainer/VBoxContainer/LineEdit.text = get_random_username()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func get_random_username() -> String:
	# Pick a random index based on the size of the array
	var random_index = randi() % usernames.size()
	return usernames[random_index]
	
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
