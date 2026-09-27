class_name Settings
extends RefCounted

const PATH := "user://settings.cfg"
const TILT_MIN := 0.5
const TILT_MAX := 2.0
const TILT_DEFAULT := 1.0

static var tilt_sensitivity := TILT_DEFAULT
static var _loaded := false


static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	tilt_sensitivity = clampf(
		float(config.get_value("tilt", "sensitivity", TILT_DEFAULT)),
		TILT_MIN,
		TILT_MAX
	)


static func set_tilt_sensitivity(value: float) -> void:
	ensure()
	tilt_sensitivity = clampf(value, TILT_MIN, TILT_MAX)
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value("tilt", "sensitivity", tilt_sensitivity)
	config.save(PATH)
