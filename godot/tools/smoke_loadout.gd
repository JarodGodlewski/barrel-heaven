extends SceneTree
## Headless smoke test: godot --headless --path . --script res://tools/smoke_loadout.gd

const LoadoutLib := preload("res://src/core/loadout.gd")


func _init() -> void:
	var fails := 0

	var l: Dictionary = LoadoutLib.empty_loadout()
	fails += _check(l.weapons.size() == 1, "starts with Twin Laser")
	LoadoutLib.recompute(l)
	fails += _check(is_equal_approx(l.stats.cooldown, 1.0), "baseline cooldown")

	l.passives.append({"id": "coolant", "level": 2})
	LoadoutLib.recompute(l)
	fails += _check(is_equal_approx(l.stats.cooldown, 0.76), "coolant lv2 -> 0.76x")

	l.weapons[0].level = LoadoutLib.WEAPON_MAX
	l.passives.append({"id": "targeting", "level": 1})
	LoadoutLib.recompute(l)
	fails += _check(LoadoutLib.first_evolvable(l) == "twin", "twin+coolant evolvable")
	fails += _check(LoadoutLib.evolve(l, "twin"), "evolve applies")
	fails += _check(l.weapons[0].evolved, "twin marked evolved")
	fails += _check(LoadoutLib.weapon_label(l.weapons[0]) == "Storm Array", "evo label")
	fails += _check(not LoadoutLib.can_evolve(l, "lock"), "unowned cannot evolve")

	var offers := LoadoutLib.offer_three(l)
	fails += _check(offers.size() > 0 and offers.size() <= 3, "offers bounded")
	for o in offers:
		fails += _check(o.has_all(["kind", "id", "label", "detail", "tag"]), "offer shape: %s" % o.get("label"))

	# drain the pool to force the heal fallback
	for i in 60:
		LoadoutLib.apply_choice(l, offers[randi() % offers.size()])
		offers = LoadoutLib.offer_three(l)
	var saw_heal := false
	for o in offers:
		if o.kind == "heal":
			saw_heal = true
	fails += _check(saw_heal or not LoadoutLib._owned_passive(l, "").is_empty(), "pool never empty")

	if fails == 0:
		print("LOADOUT SMOKE OK")
		quit(0)
	else:
		print("LOADOUT SMOKE FAILED: %d" % fails)
		quit(1)


func _check(cond: bool, label: String) -> int:
	if cond:
		print("  ok   ", label)
		return 0
	push_error("FAIL " + label)
	print("  FAIL ", label)
	return 1
