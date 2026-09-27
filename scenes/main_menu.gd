extends Control

const ACCENT := Color("2f81f7")

@onready var _logo: Head = $Margin/VBox/Logo
@onready var _banner: Button = $Margin/VBox/RejoinBanner
@onready var _dot: Panel = $Margin/VBox/IdentityRow/ColorDot
@onready var _name: Label = $Margin/VBox/IdentityRow/NameLabel
@onready var _wins: Label = $Margin/VBox/IdentityRow/WinsLabel
@onready var _losses: Label = $Margin/VBox/IdentityRow/LossesLabel
@onready var _play: Button = $Margin/VBox/PlayButton


func _ready() -> void:
	Sfx.play_music("menu")
	_logo.apply_color(ACCENT)
	_style_dot(Net.my_color)
	_name.text = Net.my_name
	_wins.text = "%dW" % Net.my_wins
	_losses.text = "%dL" % Net.my_losses
	_banner.visible = not Net.last_room.is_empty() and Net.had_match
	if _banner.visible:
		_banner.text = "REJOIN  %s" % Net.last_room
	_style_button(_play, ACCENT, Color(0, 0, 0, 0))
	_style_button(_banner, Color(0, 0, 0, 0), ACCENT)


func _on_rejoin_pressed() -> void:
	Net.rejoin()
	get_tree().change_scene_to_file("res://scenes/connect_screen.tscn")


func _on_play_online_pressed() -> void:
	Net.local_mode = false
	get_tree().change_scene_to_file("res://scenes/connect_screen.tscn")


func _on_practice_pressed() -> void:
	Net.local_mode = true
	Net.reset_ready()
	Net.local_rounds = 0
	Net.remote_rounds = 0
	Net.peer_name = "BOT"
	Net.peer_wins = 0
	Net.peer_losses = 0
	Net.peer_color = _bot_color()
	get_tree().change_scene_to_file("res://scenes/play_screen.tscn")


func _style_dot(color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(22)
	_dot.add_theme_stylebox_override("panel", style)


func _style_button(button: Button, bg: Color, border: Color) -> void:
	button.add_theme_stylebox_override("normal", _flat(bg, border))
	button.add_theme_stylebox_override("hover", _flat(bg.lightened(0.12), border))
	button.add_theme_stylebox_override("pressed", _flat(bg.darkened(0.2), border))
	button.add_theme_stylebox_override("focus", _flat(bg, border))


func _flat(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(18)
	style.content_margin_left = 48.0
	style.content_margin_right = 48.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	if border.a > 0.0:
		style.set_border_width_all(4)
		style.border_color = border
	return style


func _bot_color() -> Color:
	return Color("2f81f7") if Net.my_color.r > 0.5 else Color("e5424a")
