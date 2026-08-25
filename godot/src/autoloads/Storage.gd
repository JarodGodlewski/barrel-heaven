extends Node
## JSON persistence under user:// with section helpers.
## Steam Cloud sync hooks in here Week 5 (GodotSteam).

const SAVE_PATH := "user://meta.json"

var _cache: Dictionary = {}


func _ready() -> void:
	_cache = _read_disk()


func _read_disk() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


func load_section(section: String) -> Dictionary:
	return _cache.get(section, {})


func save_section(section: String, data: Dictionary) -> void:
	_cache[section] = data
	flush()


func flush() -> void:
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Storage: cannot open %s for write" % tmp)
		return
	f.store_string(JSON.stringify(_cache, "\t"))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SAVE_PATH))


func wipe() -> void:
	_cache.clear()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
