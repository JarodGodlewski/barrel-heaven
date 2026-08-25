extends Node
## Graphics / audio / control preferences. Persisted via Storage.

signal changed(key: String, value)

const DEFAULTS := {
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"voice_volume": 1.0,
	"quality": "auto",          # auto | high | low
	"haptics_enabled": true,
	"tts_voice_lines": true,
}

var values: Dictionary = {}


func _ready() -> void:
	values = DEFAULTS.duplicate(true)
	var saved := Storage.load_section("settings")
	for k in saved:
		if values.has(k):
			values[k] = saved[k]
	apply_audio()


func get_value(key: String):
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, val) -> void:
	if not DEFAULTS.has(key):
		return
	values[key] = val
	Storage.save_section("settings", values)
	changed.emit(key, val)
	if key.ends_with("_volume"):
		apply_audio()


func apply_audio() -> void:
	var buses := {
		"master_volume": "Master",
		"music_volume": "Music",
		"sfx_volume": "SFX",
		"voice_volume": "Voice",
	}
	for key in buses:
		var idx := AudioServer.get_bus_index(buses[key])
		if idx >= 0:
			var v: float = maxf(0.0001, float(values[key]))
			AudioServer.set_bus_volume_db(idx, linear_to_db(v))
			AudioServer.set_bus_mute(idx, float(values[key]) <= 0.001)
