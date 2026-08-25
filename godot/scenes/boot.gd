extends Node3D
## Boot smoke — verifies the full autoload chain at real runtime.
## Replaced by Main.tscn in Week 2.


func _ready() -> void:
	print("BOOT: storage=%s settings=%s audio=%s state=%s" % [
		Storage != null, Settings != null, AudioManager != null, GameState != null
	])
	Storage.save_section("meta", {"version": 7})
	var back := Storage.load_section("meta")
	if int(back.get("version", 0)) != 7:
		push_error("storage round-trip failed")
		get_tree().quit(1)
		return
	Settings.set_value("sfx_volume", 0.5)
	if not is_equal_approx(float(Settings.values.sfx_volume), 0.5):
		push_error("settings persist failed")
		get_tree().quit(1)
		return
	GameState.new_run()
	for i in 12:
		GameState.add_xp(2)
	if GameState.run.level < 3:
		push_error("level-up math failed")
		get_tree().quit(1)
		return
	print("BOOT SMOKE OK")
	get_tree().quit(0)
