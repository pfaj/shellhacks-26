extends Control

@onready var _left_color: ColorRect = $Margin/Column/Fighters/LeftPanel/LeftColor
@onready var _left_name: Label = $Margin/Column/Fighters/LeftPanel/LeftName
@onready var _right_color: ColorRect = $Margin/Column/Fighters/RightPanel/RightColor
@onready var _right_name: Label = $Margin/Column/Fighters/RightPanel/RightName
@onready var _countdown: Label = $Margin/Column/Countdown
@onready var _status: Label = $Margin/Column/Status
@onready var _leave_button: Button = $Margin/Column/LeaveButton
@onready var _timer: Timer = $CountdownTimer

const STEPS: Array[String] = ["3", "2", "1", "FIGHT!"]

var _step := 0
var _running := true


func _ready() -> void:
	Sfx.play_music("fight")
	_left_color.color = Net.my_color
	_left_name.text = Net.my_name
	_right_color.color = Net.peer_color
	_right_name.text = Net.peer_name
	_leave_button.pressed.connect(_on_leave_pressed)
	_timer.timeout.connect(_on_countdown_timeout)
	Net.peer_profile.connect(_on_peer_profile)
	Net.peer_left.connect(_on_peer_left)
	_status.text = "Get ready..."
	_timer.start()


func _exit_tree() -> void:
	Sfx.stop_sfx()


func _on_peer_profile(peer_name: String, peer_color: Color) -> void:
	_right_name.text = peer_name
	_right_color.color = peer_color


func _on_peer_left() -> void:
	if not _running:
		return
	_running = false
	_timer.stop()
	Sfx.stop_sfx()
	_countdown.text = ""
	_status.text = "Opponent left the match"


func _on_countdown_timeout() -> void:
	if _step >= STEPS.size():
		_timer.stop()
		if _running:
			get_tree().change_scene_to_file("res://scenes/play_screen.tscn")
		return
	if _step == 0:
		Sfx.play("countdown")
	_countdown.text = STEPS[_step]
	_step += 1
	if _step >= STEPS.size():
		_timer.wait_time = 0.9
		_timer.start()


func _on_leave_pressed() -> void:
	_running = false
	Net.leave()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
