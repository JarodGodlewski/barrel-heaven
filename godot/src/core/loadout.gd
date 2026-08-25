class_name Loadout
## Direct port of js/loadout.js — hardpoints (weapons), systems (passives),
## stat recompute, evolution rules, level-up draft offers.

const WEAPON_SLOTS := 4
const PASSIVE_SLOTS := 4
const WEAPON_MAX := 5

const WEAPONS := {
	"twin": {
		"id": "twin", "name": "Twin Laser", "tag": "HARDPOINT",
		"desc": "Paired cannons. Favors what's in front of you.",
		"interval": 0.16, "evolve": "coolant",
		"evo_name": "Storm Array", "evo_desc": "A wall of bolts. The Well goes white.",
	},
	"lock": {
		"id": "lock", "name": "Lock-On", "tag": "HARDPOINT",
		"desc": "Homing slugs. Hatch would approve of the computer.",
		"interval": 0.42, "evolve": "targeting",
		"evo_name": "Swarm Lock", "evo_desc": "Three seekers. They do not miss often.",
	},
	"bomb": {
		"id": "bomb", "name": "Smart Charge", "tag": "HARDPOINT",
		"desc": "Charges orbit the hull and chew whatever gets close.",
		"interval": 1.1, "evolve": "gyro",
		"evo_name": "Halo Charge", "evo_desc": "A ring that never stops.",
	},
	"nova": {
		"id": "nova", "name": "Nova Pulse", "tag": "HARDPOINT",
		"desc": "Shock the air around the ship.",
		"interval": 1.35, "evolve": "plating",
		"evo_name": "Shock Halo", "evo_desc": "A bigger bite. Hull sings.",
	},
	"scatter": {
		"id": "scatter", "name": "Scatter Banks", "tag": "HARDPOINT",
		"desc": "Side guns. Good when they come from everywhere.",
		"interval": 0.38, "evolve": "afterburner",
		"evo_name": "Crossfire", "evo_desc": "A fan of light. Nothing is a six anymore.",
	},
	"mines": {
		"id": "mines", "name": "Mine Rack", "tag": "HARDPOINT",
		"desc": "Drops mines in your wake.",
		"interval": 0.85, "evolve": "scoop",
		"evo_name": "Minefield", "evo_desc": "The trail behind you is a problem for them.",
	},
}

const PASSIVES := {
	"coolant": {
		"id": "coolant", "name": "Coolant Loop", "tag": "SYSTEM",
		"desc": "Hardpoints cycle faster.", "stat": "cooldown", "per": 0.12,
	},
	"afterburner": {
		"id": "afterburner", "name": "Afterburner", "tag": "SYSTEM",
		"desc": "More speed. More of the map.", "stat": "speed", "per": 0.10,
	},
	"plating": {
		"id": "plating", "name": "Hull Plating", "tag": "SYSTEM",
		"desc": "+1 max hull and a patch.", "stat": "hp_bonus", "per": 1.0,
	},
	"scoop": {
		"id": "scoop", "name": "Mote Scoop", "tag": "SYSTEM",
		"desc": "Pull XP motes from farther out.", "stat": "magnet", "per": 0.22,
	},
	"gyro": {
		"id": "gyro", "name": "Gyro Rig", "tag": "SYSTEM",
		"desc": "Bolts and pulses hit a wider cone.", "stat": "area", "per": 0.14,
	},
	"targeting": {
		"id": "targeting", "name": "Targeting Core", "tag": "SYSTEM",
		"desc": "Everything hits harder.", "stat": "damage", "per": 0.18,
	},
}


static func empty_loadout() -> Dictionary:
	return {
		"weapons": [{"id": "twin", "level": 1, "cd": 0.0, "evolved": false}],
		"passives": [],
		"stats": {
			"cooldown": 1.0, "speed": 1.0, "damage": 1.0,
			"area": 1.0, "magnet": 1.0, "hp_bonus": 0,
		},
	}


static func recompute(loadout: Dictionary) -> Dictionary:
	var s := {
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
