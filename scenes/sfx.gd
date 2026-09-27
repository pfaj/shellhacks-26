extends Node

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const AMBIENCE_DIR := "res://assets/audio/ambience/"
const SFX_NAMES: Array[String] = ["hit", "whoosh", "block", "hurt", "bell", "ko", "win", "lose", "countdown", "roundstart", "crowd_roar", "click"]
const VARIANT_SUFFIXES: Array[String] = ["", "2", "3", "4", "5"]
const EXTENSIONS: Array[String] = [".ogg", ".wav", ".mp3"]
const POOL_SIZE := 8
const MUSIC_FADE := 1.0
const MUSIC_FALLBACK := "menu"
const AMBIENCE_FADE := 1.2

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music_players: Array[AudioStreamPlayer] = []
var _music_index := 0
var _current_track := ""
var _ambience: AudioStreamPlayer
var _ambience_track := ""
var _ambience_base := -18.0
var _ambience_tween: Tween


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
	_ambience = AudioStreamPlayer.new()
	add_child(_ambience)


func play(sound: String, pitch_variation := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sound):
		return
	_play_stream(_streams[sound].pick_random(), pitch_variation, pitch)


func play_all(sound: String, pitch_variation := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sound):
		return
	for stream in _streams[sound]:
		_play_stream(stream, pitch_variation, pitch)


func click() -> void:
	play("click", 0.05, randf_range(1.0, 1.06))


func _play_stream(stream: AudioStream, pitch_variation: float, pitch: float) -> void:
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.pitch_scale = pitch + randf_range(-pitch_variation, pitch_variation)
	player.play()


func play_music(track: String) -> void:
	if track == _current_track:
		return
	var stream := _load_from(MUSIC_DIR, track)
	if stream == null:
		if not _current_track.is_empty():
			return
		track = MUSIC_FALLBACK
		stream = _load_from(MUSIC_DIR, track)
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


func play_ambience(track: String, volume_db := -18.0, fade := AMBIENCE_FADE) -> void:
	var stream := _load_from(AMBIENCE_DIR, track)
	if stream == null:
		return
	_ambience_base = volume_db
	if track == _ambience_track and _ambience.playing:
		return
	_configure_loop(stream)
	_ambience_track = track
	_ambience.stream = stream
	_ambience.volume_db = -60.0
	_ambience.play()
	_kill_ambience_tween()
	_ambience_tween = create_tween()
	_ambience_tween.tween_property(_ambience, "volume_db", volume_db, fade)


func swell_ambience(peak_db := -6.0, attack := 0.12, release := 1.6) -> void:
	if not _ambience.playing:
		return
	_kill_ambience_tween()
	_ambience_tween = create_tween()
	_ambience_tween.tween_property(_ambience, "volume_db", peak_db, attack).set_trans(Tween.TRANS_SINE)
	_ambience_tween.tween_property(_ambience, "volume_db", _ambience_base, release).set_trans(Tween.TRANS_SINE)


func stop_ambience(fade := 0.6) -> void:
	if not _ambience.playing:
		return
	_ambience_track = ""
	_kill_ambience_tween()
	_ambience_tween = create_tween()
	_ambience_tween.tween_property(_ambience, "volume_db", -60.0, fade)
	_ambience_tween.finished.connect(_ambience.stop)


func stop_sfx() -> void:
	for player in _players:
		player.stop()


func _kill_ambience_tween() -> void:
	if _ambience_tween != null and _ambience_tween.is_valid():
		_ambience_tween.kill()


func _configure_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
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
