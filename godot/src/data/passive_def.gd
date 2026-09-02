class_name PassiveDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var tag: String = "SYSTEM"
@export var desc: String = ""
@export var stat: String = ""
@export var per: float = 0.0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"tag": tag,
		"desc": desc,
		"stat": stat,
		"per": per,
	}
