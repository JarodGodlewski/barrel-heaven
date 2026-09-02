class_name WeaponDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var tag: String = "HARDPOINT"
@export var desc: String = ""
@export var interval: float = 0.3
@export var evolve: String = ""
@export var evo_name: String = ""
@export var evo_desc: String = ""


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"tag": tag,
		"desc": desc,
		"interval": interval,
		"evolve": evolve,
		"evo_name": evo_name,
		"evo_desc": evo_desc,
	}
