extends Node

signal enemy_killed(type: String, elite: bool, pos: Vector3, gems: int)
signal super_activated(pos: Vector3, radius: float)
signal boss_part_destroyed(kind: String, pos: Vector3)
signal boss_killed(pos: Vector3)
signal cache_collected(kind: String)
