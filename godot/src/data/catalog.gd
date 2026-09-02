extends RefCounted

static var _enemies: Dictionary = {}
static var _weapons: Dictionary = {}
static var _passives: Dictionary = {}
static var _loaded := false


static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	for path in [
		"res://resources/enemies/chaser.tres",
		"res://resources/enemies/weaver.tres",
		"res://resources/enemies/turret.tres",
		"res://resources/enemies/splitter.tres",
		"res://resources/enemies/brute.tres",
		"res://resources/enemies/mini.tres",
	]:
		var res = load(path)
		_enemies[String(res.id)] = res.to_dict()
	for path in [
		"res://resources/weapons/twin.tres",
		"res://resources/weapons/lock.tres",
		"res://resources/weapons/bomb.tres",
		"res://resources/weapons/nova.tres",
		"res://resources/weapons/scatter.tres",
		"res://resources/weapons/mines.tres",
	]:
		var res = load(path)
		_weapons[String(res.id)] = res.to_dict()
	for path in [
		"res://resources/passives/coolant.tres",
		"res://resources/passives/afterburner.tres",
		"res://resources/passives/plating.tres",
		"res://resources/passives/scoop.tres",
		"res://resources/passives/gyro.tres",
		"res://resources/passives/targeting.tres",
	]:
		var res = load(path)
		_passives[String(res.id)] = res.to_dict()


static func enemies() -> Dictionary:
	ensure()
	return _enemies


static func weapons() -> Dictionary:
	ensure()
	return _weapons


static func passives() -> Dictionary:
	ensure()
	return _passives
