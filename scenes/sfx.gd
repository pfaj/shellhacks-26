extends Node

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const SFX_NAMES: Array[String] = ["hit", "whoosh", "block", "hurt", "bell", "ko", "win", "lose"]
const VARIANT_SUFFIXES: Array[String] = ["", "2", "3", "4", "5"]
const EXTENSIONS: Array[String] = [".ogg", ".wav", ".mp3"]
const POOL_SIZE := 8

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer


func _ready() -> void:
	for sound_name in SFX_NAMES:
		var variants := _load_variants(sound_name)
		if not variants.is_empty():
			_streams[sound_name] = variants
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_music = AudioStreamPlayer.new()
	add_child(_music)


func play(sound: String, pitch_variation := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sound):
		return
	var variants: Array = _streams[sound]
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = variants.pick_random()
	player.pitch_scale = pitch + randf_range(-pitch_variation, pitch_variation)
	player.play()


func play_music(track: String) -> void:
	var stream := _load_from(MUSIC_DIR, track)
	if stream == null:
		return
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music.stop()


func _load_variants(base_name: String) -> Array:
	var variants: Array = []
	for suffix in VARIANT_SUFFIXES:
		var stream := _load_from(SFX_DIR, base_name + suffix)
		if stream != null:
			variants.append(stream)
	return variants


func _load_from(directory: String, base_name: String) -> AudioStream:
	for extension in EXTENSIONS:
		var path := directory + base_name + extension
		if ResourceLoader.exists(path):
			return load(path)
	return null
