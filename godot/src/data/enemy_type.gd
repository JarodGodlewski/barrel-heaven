class_name EnemyTypeResource
extends Resource

@export var id: String = ""
@export var hp: float = 2.0
@export var speed: float = 16.0
@export var scale: float = 0.85
@export var gems: int = 1
@export var body: Color = Color(0.55, 0.18, 0.18)
@export var accent: Color = Color(0.90, 0.25, 0.20)
@export var unlock: float = 0.0
@export var weight: float = 10.0


func to_dict() -> Dictionary:
	return {
		"hp": hp,
		"speed": speed,
		"scale": scale,
		"gems": gems,
		"body": body,
		"accent": accent,
		"unlock": unlock,
		"weight": weight,
	}
