extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label


var display_name: String = "":
	set(value):
		if display_name != value:
			display_name = value
			label.text = value
var color: Color = Color.WHITE:
	set(value):
		if color != value:
			color = value
			
			var gradient = Gradient.new()
			var gradient_texture = GradientTexture2D.new()
			gradient.set_color(0, value)
			gradient.set_color(1, value)
			gradient_texture.gradient = gradient
			
			sprite.texture = gradient_texture
