extends Node

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const SFX_NAMES: Array[String] = ["jab", "punch", "block", "hurt", "whoosh", "bell", "ko", "win", "lose"]
const EXTENSIONS: Array[String] = [".ogg", ".wav", ".mp3"]
const POOL_SIZE := 8

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer


func _ready() -> void:
	for sound_name in SFX_NAMES:
		var stream := _load_from(SFX_DIR, sound_name)
		if stream != null:
			_streams[sound_name] = stream
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_music = AudioStreamPlayer.new()
	add_child(_music)


func play(sound: String, pitch_variation := 0.0) -> void:
	if not _streams.has(sound):
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[sound]
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


func play_music(track: String) -> void:
	var stream := _load_from(MUSIC_DIR, track)
	if stream == null:
		return
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music.stop()


func _load_from(directory: String, base_name: String) -> AudioStream:
	for extension in EXTENSIONS:
		var path := directory + base_name + extension
		if ResourceLoader.exists(path):
			return load(path)
	return null
