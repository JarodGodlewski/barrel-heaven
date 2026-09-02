extends GameSystem

const GameCatalog := preload("res://src/data/catalog.gd")

const START_HORDE := 14
const MAX_HORDE := 64
const SPAWN_INTERVAL := 0.4
const WEIGHT_RAMP := 30.0
const WEIGHT_FLOOR := 0.15

var _main
var spawn_acc := 0.0
var swell_left := 0.0
var swell_done := false


func setup(main: Node) -> void:
	_main = main


func reset() -> void:
	spawn_acc = 0.0
	swell_left = 0.0
	swell_done = false


func fill_start() -> void:
	for i in START_HORDE:
		spawn_enemy()


func sim(dt: float) -> void:
	var e: float = GameState.run.elapsed
	var swell_at: float = 270.0 * float(_main.unlock_scale)
	if not swell_done and not _main.smoke_mode and e >= swell_at and _main.boss == null:
		swell_done = true
		swell_left = 22.0
		spawn_enemy("brute")
		var last: Dictionary = _main.enemies[_main.enemies.size() - 1]
		_force_elite(last)
		_main.ui.say("kite", "Curtain's thickening, Rook. Pretty, isn't it?")
		_main.ui.say("hatch", "That's the swell. Roll when it kisses the hull.")
		_main.shake_amt = maxf(_main.shake_amt, 0.45)
		_main.ui.surge()
	if swell_left > 0.0:
		swell_left -= dt
	spawn_acc += dt
	if spawn_acc > SPAWN_INTERVAL and _main.boss == null:
		spawn_acc = 0.0
		var want := desired_horde()
		while _main.enemies.size() < want:
			spawn_enemy()


func desired_horde() -> int:
	var wave := 1 + int(GameState.run.elapsed / 18.0)
	var extra := 16 if swell_left > 0.0 else 0
	return mini(MAX_HORDE, START_HORDE + wave * 5 + int(GameState.run.elapsed / 10.0) + extra)


func pick_enemy_type() -> String:
	var e: float = GameState.run.elapsed
	var total := 0.0
	var weights := {}
	var types: Dictionary = GameCatalog.enemies()
	for id in types:
		var def: Dictionary = types[id]
		var w: float = def.weight
		var unlock_at: float = float(def.unlock) * _main.unlock_scale
		if w <= 0.0 or e < unlock_at:
			continue
		w *= clampf((e - unlock_at) / WEIGHT_RAMP, WEIGHT_FLOOR, 1.0)
		weights[id] = w
		total += w
	if total <= 0.0:
		return "chaser"
	var roll := randf() * total
	for id in weights:
		roll -= weights[id]
		if roll <= 0.0:
			return id
	return "chaser"


func spawn_enemy(type := "") -> void:
	if type == "":
		type = pick_enemy_type()
	var def: Dictionary = GameCatalog.enemies()[type]
	var node := _main._enemy_pool_for(type).take() as Node3D
	var ang := randf() * TAU
	var dist := 70.0 + randf() * 50.0
	node.position = _main.player.position + Vector3(cos(ang), 0, sin(ang)) * dist
	_main.wrap_to_arena(node.position)
	var elapsed: float = GameState.run.elapsed
	var hp: float = def.hp + float(int(elapsed / 40.0))
	var speed: float = def.speed + randf() * 4.0 + minf(10.0, elapsed * 0.10)
	var base_scale: float = def.scale
	var elite: bool = type != "mini" and randf() < 0.05
	if elite:
		hp *= 3.0
		base_scale *= 1.35
		speed *= 0.9
	node.scale = Vector3.ONE * (base_scale * 0.2)
	var mat2: ShaderMaterial = node.get_meta("mat")
	mat2.set_shader_parameter("u_body", def.body)
	mat2.set_shader_parameter("u_accent", Color(1.0, 0.80, 0.25) if elite else def.accent)
	mat2.set_shader_parameter("u_hp_ratio", 1.0)
	mat2.set_shader_parameter("u_flash", 0.0)
	node.visible = true
	var rec := {
		"node": node,
		"mat": mat2,
		"type": type,
		"hp": hp,
		"max_hp": hp,
		"speed": speed,
		"gems": int(def.gems) + (2 if elite else 0),
		"base_scale": base_scale,
		"elite": elite,
		"flash": 0.0,
		"spawn_t": 0.3,
		"phase": randf() * TAU,
		"fire_t": randf_range(1.2, 2.6),
	}
	_main.enemies.append(rec)
	_main._sm_types[type] = true


func spawn_enemy_at(type: String, pos: Vector3) -> void:
	var before: int = _main.enemies.size()
	spawn_enemy(type)
	if _main.enemies.size() > before:
		var rec: Dictionary = _main.enemies[_main.enemies.size() - 1]
		rec.node.position = pos
		_main.wrap_to_arena(rec.node.position)


func _force_elite(rec: Dictionary) -> void:
	if rec.get("elite", false) or rec.type == "mini":
		return
	rec.elite = true
	rec.hp *= 3.0
	rec.max_hp = rec.hp
	rec.base_scale *= 1.35
	rec.gems = int(rec.gems) + 2
	rec.node.scale = Vector3.ONE * (float(rec.base_scale) * 0.2)
	(rec.mat as ShaderMaterial).set_shader_parameter("u_accent", Color(1.0, 0.80, 0.25))
