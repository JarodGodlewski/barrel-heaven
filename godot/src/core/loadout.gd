class_name Loadout
## Direct port of js/loadout.js — hardpoints (weapons), systems (passives),
## stat recompute, evolution rules, level-up draft offers.

const WEAPON_SLOTS := 4
const PASSIVE_SLOTS := 4
const WEAPON_MAX := 5
const _Catalog := preload("res://src/data/catalog.gd")

static var WEAPONS: Dictionary = _Catalog.weapons()
static var PASSIVES: Dictionary = _Catalog.passives()


static func empty_loadout() -> Dictionary[String, Variant]:
	return {
		"weapons": [{"id": "twin", "level": 1, "cd": 0.0, "evolved": false}],
		"passives": [],
		"stats": {
			"cooldown": 1.0, "speed": 1.0, "damage": 1.0,
			"area": 1.0, "magnet": 1.0, "hp_bonus": 0,
		},
	}


static func recompute(loadout: Dictionary) -> Dictionary[String, Variant]:
	var s: Dictionary[String, Variant] = {
		"cooldown": 1.0, "speed": 1.0, "damage": 1.0,
		"area": 1.0, "magnet": 1.0, "hp_bonus": 0,
	}
	for p in loadout.passives:
		var def: Dictionary = PASSIVES.get(p.id, {})
		if def.is_empty():
			continue
		match def.stat:
			"cooldown":
				s.cooldown *= 1.0 - def.per * p.level
			"hp_bonus":
				s.hp_bonus += def.per * p.level
			_:
				s[def.stat] += def.per * p.level
	s.cooldown = maxf(0.4, s.cooldown)
	loadout.stats = s
	return s


static func can_evolve(loadout: Dictionary, weapon_id: String) -> bool:
	var w: Dictionary = _owned_weapon(loadout, weapon_id)
	var def: Dictionary = WEAPONS.get(weapon_id, {})
	if w.is_empty() or def.is_empty() or w.evolved or w.level < WEAPON_MAX:
		return false
	for p in loadout.passives:
		if p.id == def.evolve:
			return true
	return false


static func evolve(loadout: Dictionary, weapon_id: String) -> bool:
	if not can_evolve(loadout, weapon_id):
		return false
	_owned_weapon(loadout, weapon_id).evolved = true
	return true


static func first_evolvable(loadout: Dictionary) -> String:
	for w in loadout.weapons:
		if can_evolve(loadout, w.id):
			return w.id
	return ""


static func offer_three(loadout: Dictionary) -> Array:
	var pool: Array = []
	for id in WEAPONS:
		var def: Dictionary = WEAPONS[id]
		var have: Dictionary = _owned_weapon(loadout, id)
		if not have.is_empty():
			if not have.evolved and have.level < WEAPON_MAX:
				pool.append({
					"kind": "weapon", "id": id,
					"label": "%s +1" % def.name,
					"detail": "Level %d" % (have.level + 1), "tag": def.tag,
				})
		elif loadout.weapons.size() < WEAPON_SLOTS:
			pool.append({
				"kind": "weapon", "id": id,
				"label": def.name, "detail": def.desc, "tag": def.tag,
			})
	for id in PASSIVES:
		var def: Dictionary = PASSIVES[id]
		var have: Dictionary = _owned_passive(loadout, id)
		if not have.is_empty():
			if have.level < 5:
				pool.append({
					"kind": "passive", "id": id,
					"label": "%s +1" % def.name,
					"detail": "Level %d" % (have.level + 1), "tag": def.tag,
				})
		elif loadout.passives.size() < PASSIVE_SLOTS:
			pool.append({
				"kind": "passive", "id": id,
				"label": def.name, "detail": def.desc, "tag": def.tag,
			})
	for w in loadout.weapons:
		if can_evolve(loadout, w.id):
			var def: Dictionary = WEAPONS[w.id]
			pool.append({
				"kind": "evolve", "id": w.id,
				"label": def.evo_name, "detail": def.evo_desc, "tag": "EVOLVE",
			})
	if pool.is_empty():
		pool.append({
			"kind": "heal", "id": "patch",
			"label": "Field Patch", "detail": "Restore 1 hull.", "tag": "REPAIR",
		})
	var picks: Array = []
	var bag := pool.duplicate()
	while picks.size() < 3 and not bag.is_empty():
		var i := randi() % bag.size()
		picks.append(bag.pop_at(i))
	return picks


## Returns true when the choice also heals (Field Patch / first Plating pick).
static func apply_choice(loadout: Dictionary, choice: Dictionary) -> bool:
	match choice.kind:
		"weapon":
			var have := _owned_weapon(loadout, choice.id)
			if have.is_empty():
				loadout.weapons.append({"id": choice.id, "level": 1, "cd": 0.0, "evolved": false})
			else:
				have.level += 1
		"passive":
			var have := _owned_passive(loadout, choice.id)
			if have.is_empty():
				loadout.passives.append({"id": choice.id, "level": 1})
			else:
				have.level += 1
		"evolve":
			evolve(loadout, choice.id)
	recompute(loadout)
	return choice.kind == "heal" or choice.id == "plating"


static func weapon_label(w: Dictionary) -> String:
	var def: Dictionary = WEAPONS.get(w.id, {})
	if def.is_empty():
		return w.id
	return def.evo_name if w.evolved else "%s %d" % [def.name, w.level]


static func _owned_weapon(loadout: Dictionary, id: String) -> Dictionary:
	for w in loadout.weapons:
		if w.id == id:
			return w
	return {}


static func _owned_passive(loadout: Dictionary, id: String) -> Dictionary:
	for p in loadout.passives:
		if p.id == id:
			return p
	return {}
