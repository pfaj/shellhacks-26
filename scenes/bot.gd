class_name Bot
extends Node

const INPUT_INTERVAL := 0.1
const MOVE_MIN := 0.35
const MOVE_MAX := 1.0
const BLOCK_MIN := 0.5
const BLOCK_MAX := 1.4
const BLOCK_CHANCE := 0.3
const ATTACK_MIN := 0.7
const ATTACK_MAX := 1.6
const PUNCH_CHANCE := 0.35

var game = null

var _move := 0.0
var _blocking := false
var _input_timer := 0.0
var _move_timer := 0.0
var _block_timer := 0.0
var _attack_timer := 0.0


func _ready() -> void:
	Net.local_message.connect(_on_local_message)
	_move_timer = randf_range(0.2, MOVE_MAX)
	_block_timer = randf_range(0.3, BLOCK_MAX)
	_attack_timer = randf_range(0.6, ATTACK_MAX)
	_send_input()


func _process(delta: float) -> void:
	if game != null and not game.is_round_live():
		return
	_input_timer += delta
	_move_timer -= delta
	_block_timer -= delta
	_attack_timer -= delta
	if _move_timer <= 0.0:
		_move_timer = randf_range(MOVE_MIN, MOVE_MAX)
		_move = [-1.0, 0.0, 0.0, 1.0].pick_random()
	if _block_timer <= 0.0:
		_block_timer = randf_range(BLOCK_MIN, BLOCK_MAX)
		_blocking = randf() < BLOCK_CHANCE
	if _input_timer >= INPUT_INTERVAL:
		_input_timer = 0.0
		_send_input()
	if _attack_timer <= 0.0:
		_attack_timer = randf_range(ATTACK_MIN, ATTACK_MAX)
		_try_attack()


func _send_input() -> void:
	Net.inject_peer({"t": Protocol.INPUT, "move": _move, "block": _blocking})


func _try_attack() -> void:
	var kind := Protocol.PUNCH if randf() < PUNCH_CHANCE else Protocol.JAB
	Net.inject_peer({"t": Protocol.ACT, "kind": kind})
	if not game.remote_is_attacking():
		return
	get_tree().create_timer(game.impact_delay(kind)).timeout.connect(_resolve_attack.bind(kind))


func _resolve_attack(kind: String) -> void:
	if game == null or not game.is_round_live():
		return
	if game.mutual_disengage():
		Net.inject_peer({"t": Protocol.MISS})
	else:
		Net.inject_peer({"t": Protocol.HIT, "kind": kind})


func _on_local_message(message: Dictionary) -> void:
	match str(message.get("t", "")):
		Protocol.HIT:
			Net.inject_peer(game.bot_defense_result(str(message.get("kind", Protocol.JAB))))
		Protocol.REMATCH:
			Net.inject_peer({"t": Protocol.REMATCH})
