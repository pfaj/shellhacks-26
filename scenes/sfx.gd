extends Node

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const SFX_NAMES: Array[String] = ["hit", "whoosh", "block", "hurt", "bell", "ko", "win", "lose", "countdown"]
const VARIANT_SUFFIXES: Array[String] = ["", "2", "3", "4", "5"]
const EXTENSIONS: Array[String] = [".ogg", ".wav", ".mp3"]
const POOL_SIZE := 8
const MUSIC_FADE := 1.0

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music_players: Array[AudioStreamPlayer] = []
var _music_index := 0
var _current_track := ""


func _ready() -> void:
	for sound_name in SFX_NAMES:
		var variants := _load_variants(sound_name)
		if not variants.is_empty():
			_streams[sound_name] = variants
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	for i in 2:
		var music_player := AudioStreamPlayer.new()
		add_child(music_player)
		_music_players.append(music_player)
	if OS.has_feature("web"):
		var window := JavaScriptBridge.get_interface("window")
		window.sockemPauseAudio = JavaScriptBridge.create_callback(_on_web_pause)
		window.sockemResumeAudio = JavaScriptBridge.create_callback(_on_web_resume)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_set_paused(true)
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			_set_paused(false)


func _on_web_pause(_args: Array) -> void:
	_set_paused(true)


func _on_web_resume(_args: Array) -> void:
	_set_paused(false)


func _set_paused(paused: bool) -> void:
	for player in _players:
		player.stream_paused = paused
	for player in _music_players:
		player.stream_paused = paused


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
	if track == _current_track:
		return
	var stream := _load_from(MUSIC_DIR, track)
	if stream == null:
		return
	_configure_loop(stream)
	_current_track = track
	var incoming := _music_players[_music_index]
	var outgoing := _music_players[1 - _music_index]
	_music_index = 1 - _music_index
	incoming.stream = stream
	incoming.volume_db = -60.0
	incoming.play()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(incoming, "volume_db", 0.0, MUSIC_FADE)
	if outgoing.playing:
		tween.tween_property(outgoing, "volume_db", -60.0, MUSIC_FADE)
		tween.finished.connect(outgoing.stop)


func stop_music() -> void:
	_current_track = ""
	for player in _music_players:
		player.stop()


func stop_sfx() -> void:
	for player in _players:
		player.stop()


func _configure_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamMP3:
		stream.loop = true


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
