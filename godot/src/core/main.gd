extends Node3D
## Barrel Heaven — main orchestrator.
## Direct port of js/main.js: all-range arena, horde, weapons, pickups, win/lose.
## Locked demo scope: single boss at 8:00, survive to 10:00 to win.

const LoadoutLib := preload("res://src/core/loadout.gd")

const ARENA := 960.0
const BASE_SPEED := 38.0
const BOOST_SPEED := 62.0
const TURN_RATE := 2.6
const ROLL_TIME := 0.42
const ROLL_COOLDOWN := 0.55
const I_FRAMES := 0.85
const PROJECTILE_SPEED := 160.0
const PROJECTILE_LIFE := 1.35
const GEM_PULL := 28.0
const START_HORDE := 14
const MAX_HORDE := 64
const HIT_R2 := 2.4
const THROTTLE_RATE := 0.9

var boss_time := 480.0
var sector_end := 600.0

const SHIP_SHADER := preload("res://assets/shaders/ship.gdshader")
const ENEMY_SHADER := preload("res://assets/shaders/enemy.gdshader")
const BOLT_SHADER := preload("res://assets/shaders/bolt.gdshader")
const GRID_SHADER := preload("res://assets/shaders/grid.gdshader")
const SKY_SHADER := preload("res://assets/shaders/bg_sky.gdshader")
const UI_LAYER := preload("res://src/ui/ui.gd")

# ---- run state ----
var running := false
var selecting := false
var smoke_mode := false
var i_frames := 0.0
var roll_t := 0.0
var roll_cd := 0.0
var throttle := 0.0
var boost_t := 0.0
var u_turn := 0.0
var u_turn_from := 0.0
var yaw_cmd := 0.0
var damage_flash := 0.0
var shake_amt := 0.0
var rolled_flag := false
var hit_flag := false
var ever_rolled := false
var _kb_last_tap := 0
var _kb_last_dir := 0
var spawn_acc := 0.0
var hud_acc := 0.0
var boss_spawned := false
var restart_pending := false
var current_offers: Array = []

# smoke counters
var _sm_fired := 0
var _sm_max_enemies := 0
var _sm_did_xp := false
var _sm_did_evo := false
var _sm_evo_ok := false

# pools / actives
var projectiles: Array = []
var enemies: Array = []
var gems: Array = []
var pods: Array = []
var orbiters: Array = []
var caches: Array = []
var enemy_pool: Array = []
var bolt_pool: Array = []
var gem_pool: Array = []
var pod_pool: Array = []

var loadout: Dictionary = {}

# nodes
var player: Node3D
var engine_light: OmniLight3D
var cam: Camera3D
var ship_body_mat: ShaderMaterial
var ui: UiLayer

var _fwd := Vector3.ZERO
var _to := Vector3.UP


func _ready() -> void:
	smoke_mode = OS.get_cmdline_user_args().has("--smoke")
	if smoke_mode:
		Settings.values.tts_voice_lines = false
		Engine.time_scale = 8.0
		boss_time = 20.0
		sector_end = 40.0
	randomize()
	_build_world()
	player = _build_player_ship()
	add_child(player)
	GameState.level_up.connect(_on_level_up_signal)
	ui = UiLayer.new()
	add_child(ui)
	ui.launch_pressed.connect(_start_from_title)
	ui.relaunch_pressed.connect(func() -> void:
		ui.hide_overlay()
		reset_run())
	ui.card_picked.connect(_on_card_picked)
	if smoke_mode:
		reset_run()
	else:
		running = false
		ui.show_title()


func GameState_run() -> Dictionary:
	return GameState.run


func _start_from_title() -> void:
	if running:
		return
	ui.hide_overlay()
	reset_run()


func _on_card_picked(i: int) -> void:
	if selecting and i >= 0 and i < current_offers.size():
		_apply_pick(current_offers[i])


func _build_world() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.44, 0.52)
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.035, 0.063)
	env.fog_density = 0.0042
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.78, 0.89, 1.0)
	sun.light_energy = 0.85
	sun.rotation_degrees = Vector3(-52, 28, 0)
	add_child(sun)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(ARENA * 2.0, ARENA * 2.0)
	floor_mesh.mesh = plane
	var grid_mat := ShaderMaterial.new()
	grid_mat.shader = GRID_SHADER
	floor_mesh.material_override = grid_mat
	floor_mesh.position.y = -18.0
	add_child(floor_mesh)

	cam = Camera3D.new()
	cam.fov = 58.0
	cam.near = 0.1
	cam.far = 700.0
	add_child(cam)
	cam.current = true


func _ship_mat(mask: Vector3) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHIP_SHADER
	m.set_shader_parameter("u_mask", mask)
	return m


func _tri_mesh(verts: PackedVector3Array, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, verts.size(), 3):
		st.set_normal((verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i]).normalized())
		st.add_vertex(verts[i])
		st.set_normal((verts[i + 2] - verts[i + 1]).cross(verts[i] - verts[i + 1]).normalized())
		st.add_vertex(verts[i + 1])
		st.set_normal((verts[i] - verts[i + 2]).cross(verts[i + 1] - verts[i + 2]).normalized())
		st.add_vertex(verts[i + 2])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


func _build_player_ship() -> Node3D:
	var root := Node3D.new()

	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.55
	cone.height = 3.4
	cone.radial_segments = 5
	var body := MeshInstance3D.new()
	body.mesh = cone
	ship_body_mat = _ship_mat(Vector3(1, 0, 0))
	body.material_override = ship_body_mat
	body.rotation_degrees.x = 90.0   # nose toward +Z (our heading convention)
	body.position.z = 0.2
	root.add_child(body)

	var hull := BoxMesh.new()
	hull.size = Vector3(0.7, 0.38, 2.1)
	var hull_mi := MeshInstance3D.new()
	hull_mi.mesh = hull
	hull_mi.material_override = _ship_mat(Vector3(0, 1, 0))
	hull_mi.position.z = 0.15
	root.add_child(hull_mi)

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.49, 0.91, 1.0)
	glass.emission_enabled = true
	glass.emission = Color(0.23, 0.66, 0.75)
	glass.emission_energy_multiplier = 0.35
	var cock := SphereMesh.new()
	cock.radius = 0.28
	cock.height = 0.56
	var cockpit := MeshInstance3D.new()
	cockpit.mesh = cock
	cockpit.material_override = glass
	cockpit.scale = Vector3(1.0, 0.7, 1.2)
	cockpit.position = Vector3(0, 0.28, 0.15)
	root.add_child(cockpit)

	for sign in [-1.0, 1.0]:
		var wing := _tri_mesh(PackedVector3Array([
			Vector3(0.1 * sign, 0.05, 0.85),
			Vector3(2.6 * sign, -0.22, -0.35),
			Vector3(0.12 * sign, 0.02, -1.25),
		]), _ship_mat(Vector3(0, 0, 1)))
		root.add_child(wing)

	var fin_cone := CylinderMesh.new()
	fin_cone.top_radius = 0.0
	fin_cone.bottom_radius = 0.16
	fin_cone.height = 0.9
	fin_cone.radial_segments = 3
	var fin := MeshInstance3D.new()
	fin.mesh = fin_cone
	fin.material_override = _ship_mat(Vector3(0, 0, 1))
	fin.rotation_degrees.x = -69.0
	fin.position = Vector3(0, 0.45, -0.85)
	root.add_child(fin)

	var eng := CylinderMesh.new()
	eng.top_radius = 0.16
	eng.bottom_radius = 0.22
	eng.height = 0.35
	eng.radial_segments = 6
	var engine := MeshInstance3D.new()
	engine.mesh = eng
	var eng_mat := StandardMaterial3D.new()
	eng_mat.albedo_color = Color(0.07, 0.09, 0.13)
	eng_mat.emission_enabled = true
	eng_mat.emission = Color(0.24, 0.88, 0.76)
	eng_mat.emission_energy_multiplier = 1.4
	engine.material_override = eng_mat
	engine.rotation_degrees.x = 90.0
	engine.position.z = -1.35
	root.add_child(engine)

	engine_light = OmniLight3D.new()
	engine_light.light_color = Color(0.24, 0.88, 0.76)
	engine_light.omni_range = 10.0
	engine_light.light_energy = 0.7
	engine_light.position.z = -1.5
	root.add_child(engine_light)

	return root


func _enemy_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ENEMY_SHADER
	return m


func _make_enemy_node() -> Node3D:
	var root := Node3D.new()
	var mat := _enemy_mat()

	var body_cone := CylinderMesh.new()
	body_cone.top_radius = 0.0
	body_cone.bottom_radius = 0.42
	body_cone.height = 2.4
	body_cone.radial_segments = 4
	var body := MeshInstance3D.new()
	body.mesh = body_cone
	body.material_override = mat
	body.rotation_degrees.x = 90.0
	root.add_child(body)

	var wing_box := BoxMesh.new()
	wing_box.size = Vector3(2.1, 0.06, 0.7)
	var wing := MeshInstance3D.new()
	wing.mesh = wing_box
	wing.material_override = mat
	wing.position.z = -0.15
	root.add_child(wing)

	root.visible = false
	add_child(root)
	return root


func heading(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


# ---------------- spawning ----------------

func wrap_to_arena(v: Vector3) -> void:
	var h := ARENA / 2.0
	if v.x > h: v.x = -h
	elif v.x < -h: v.x = h
	if v.z > h: v.z = -h
	elif v.z < -h: v.z = h


func spawn_enemy(boss := false) -> void:
	var node: Node3D = enemy_pool.pop_back() if enemy_pool.size() > 0 else _make_enemy_node()
	var ang := randf() * TAU
	var dist := 55.0 if boss else 70.0 + randf() * 50.0
	node.position = player.position + Vector3(cos(ang), 0, sin(ang)) * dist
	wrap_to_arena(node.position)
	node.scale = Vector3.ONE * (2.35 if boss else 0.85)
	var rec := {
		"node": node,
		"boss": boss,
		"drop_pod": boss,
		"hp": (26.0 + GameState.run.elapsed * 0.35) if boss else 2.0 + float(int(GameState.run.elapsed / 40.0)),
		"speed": 9.0 if boss else 16.0 + randf() * 10.0 + minf(14.0, GameState.run.elapsed * 0.15),
	}
	if boss:
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 1.28
		ring_mesh.outer_radius = 1.42
		var ring_mat := StandardMaterial3D.new()
		ring_mat.albedo_color = Color(0.94, 0.76, 0.29)
		ring_mat.emission_enabled = true
		ring_mat.emission = Color(1.0, 0.67, 0.2)
		ring_mat.emission_energy_multiplier = 0.85
		var ring := MeshInstance3D.new()
		ring.mesh = ring_mesh
		ring.material_override = ring_mat
		ring.name = "AceRing"
		node.add_child(ring)
	node.visible = true
	enemies.append(rec)


func recycle_enemy(rec: Dictionary) -> void:
	var idx := enemies.find(rec)
	if idx >= 0:
		enemies[idx] = enemies[enemies.size() - 1]
		enemies.pop_back()
	rec.node.visible = false
	var ring: Node = rec.node.get_node_or_null("AceRing")
	if ring:
		ring.queue_free()
	enemy_pool.append(rec.node)


func desired_horde() -> int:
	var wave := 1 + int(GameState.run.elapsed / 18.0)
	return mini(MAX_HORDE, START_HORDE + wave * 5 + int(GameState.run.elapsed / 10.0))


func drop_gem(pos: Vector3) -> void:
	var mesh: MeshInstance3D = gem_pool.pop_back() if gem_pool.size() > 0 else null
	if mesh == null:
		mesh = MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.35
		s.height = 0.7
		s.radial_segments = 4
		s.rings = 2
		mesh.mesh = s
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.4, 0.94, 1.0)
		m.emission_enabled = true
		m.emission = Color(0.13, 0.53, 0.67)
		m.emission_energy_multiplier = 0.8
		mesh.material_override = m
		add_child(mesh)
	mesh.position = Vector3(pos.x, 0.2, pos.z)
	mesh.visible = true
	gems.append({"mesh": mesh, "life": 12.0})


func drop_pod(x: float, z: float) -> void:
	var mesh: MeshInstance3D = pod_pool.pop_back() if pod_pool.size() > 0 else null
	if mesh == null:
		mesh = MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3.ONE * 0.7
		mesh.mesh = b
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.94, 0.76, 0.29)
		m.emission_enabled = true
		m.emission = Color(0.67, 0.47, 0.0)
		m.emission_energy_multiplier = 0.7
		mesh.material_override = m
		add_child(mesh)
	mesh.position = Vector3(x, 0.4, z)
	mesh.visible = true
	pods.append({"mesh": mesh, "life": 22.0})


func spawn_field_caches() -> void:
	var spots := [
		{"x": 0.0, "z": 88.0, "kind": "patch", "col": Color(0.49, 1.0, 0.69)},
		{"x": 88.0, "z": 0.0, "kind": "vac", "col": Color(0.53, 0.83, 1.0)},
		{"x": 0.0, "z": -88.0, "kind": "flare", "col": Color(1.0, 0.88, 0.54)},
		{"x": -88.0, "z": 0.0, "kind": "patch", "col": Color(0.49, 1.0, 0.69)},
	]
	for s in spots:
		var mesh := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.55
		sm.height = 1.1
		sm.radial_segments = 6
		sm.rings = 3
		mesh.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = s.col
		m.emission_enabled = true
		m.emission = s.col * 0.6
		m.emission_energy_multiplier = 0.7
		mesh.material_override = m
		mesh.position = Vector3(s.x, 0.6, s.z)
		add_child(mesh)
		caches.append({"mesh": mesh, "kind": s.kind, "taken": false})


func clear_caches() -> void:
	for c in caches:
		c.mesh.queue_free()
	caches.clear()


func hurt_enemy(rec: Dictionary, dmg: float) -> void:
	if not rec.node.visible:
		return
	rec.hp -= dmg
	if rec.hp > 0.0:
		return
	drop_gem(rec.node.position)
	if rec.drop_pod:
		drop_pod(rec.node.position.x, rec.node.position.z)
	recycle_enemy(rec)
	GameState.add_kill()


# ---------------- weapons ----------------

func best_target(prefer_front := true, exclude: Array = []) -> Node3D:
	_fwd = heading(player.rotation.y)
	var best: Node3D = null
	var best_score := INF
	for rec in enemies:
		var e: Node3D = rec.node
		if exclude.has(e):
			continue
		var dvec := e.position - player.position
		var d2 := dvec.x * dvec.x + dvec.z * dvec.z
		if d2 < 0.01:
			continue
		var d := sqrt(d2)
		var facing := (_fwd.x * dvec.x + _fwd.z * dvec.z) / d
		var score := d * (0.45 if prefer_front and facing > 0.15 else 1.25)
		if score < best_score:
			best_score = score
			best = e
	return best


func fire_bolt(dx: float, dz: float, opts: Dictionary = {}) -> void:
	_to = Vector3(dx, 0.0, dz)
	if _to.length_squared() < 0.0001:
		_to = heading(player.rotation.y)
	else:
		_to = _to.normalized()
	var speed: float = opts.get("speed", PROJECTILE_SPEED)
	var bolt: MeshInstance3D = bolt_pool.pop_back() if bolt_pool.size() > 0 else null
	if bolt == null:
		bolt = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.05
		cyl.height = 1.4
		cyl.radial_segments = 4
		bolt.mesh = cyl
		var bm := ShaderMaterial.new()
		bm.shader = BOLT_SHADER
		bolt.material_override = bm
		add_child(bolt)
	bolt.scale = Vector3.ONE * float(opts.get("scale", loadout.stats.area))
	bolt.basis = Basis(Quaternion(Vector3.UP, _to))
	bolt.position = player.position + _to * 2.2
	bolt.visible = true
	projectiles.append({
		"mesh": bolt,
		"vx": _to.x * speed,
		"vz": _to.z * speed,
		"life": float(opts.get("life", PROJECTILE_LIFE)),
		"dmg": float(opts.get("dmg", 1.0)) * loadout.stats.damage,
		"r2": HIT_R2 * loadout.stats.area,
	})
	_sm_fired += 1


func recycle_bolt(i: int) -> void:
	var p: Dictionary = projectiles[i]
	p.mesh.visible = false
	bolt_pool.append(p.mesh)
	projectiles[i] = projectiles[projectiles.size() - 1]
	projectiles.pop_back()


func pulse_nova(radius: float, dmg: float) -> void:
	var r2 := radius * radius
	for i in range(enemies.size() - 1, -1, -1):
		var rec: Dictionary = enemies[i]
		var dv: Vector3 = rec.node.position - player.position
		if dv.x * dv.x + dv.z * dv.z < r2:
			hurt_enemy(rec, dmg)


func spawn_orbiter(w: Dictionary) -> void:
	var mesh := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.28
	s.height = 0.56
	s.radial_segments = 6
	s.rings = 3
	mesh.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.53, 0.27)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.33, 0.13)
	m.emission_energy_multiplier = 0.9
	mesh.material_override = m
	add_child(mesh)
	orbiters.append({
		"mesh": mesh,
		"angle": randf() * TAU,
		"radius": 3.2 * loadout.stats.area * (1.45 if w.evolved else 1.0),
		"speed": 2.4 + w.level * 0.25,
		"dmg": (0.55 + w.level * 0.12) * loadout.stats.damage,
		"life": 999.0 if w.evolved else 6.0,
	})


func fire_weapon(w: Dictionary) -> void:
	var def: Dictionary = LoadoutLib.WEAPONS[w.id]
	if def.is_empty():
		return
	var lv: int = w.level
	var evo: bool = w.evolved
	_fwd = heading(player.rotation.y)
	match w.id:
		"twin":
			var t := best_target(true)
			if t == null:
				return
			fire_bolt(t.position.x - player.position.x, t.position.z - player.position.z, {"dmg": 1.0 + lv * 0.15})
			if evo:
				fire_bolt(t.position.x - player.position.x + _fwd.z * 1.2, t.position.z - player.position.z - _fwd.x * 1.2, {"dmg": 1.0 + lv * 0.15})
		"lock":
			var n := 3 if evo else 1
			var used: Array = []
			for i in n:
				var t2 := best_target(false, used)
				if t2 == null:
					break
				used.append(t2)
				fire_bolt(t2.position.x - player.position.x, t2.position.z - player.position.z, {"dmg": 0.85 + lv * 0.12, "speed": 110.0})
		"bomb":
			spawn_orbiter(w)
		"nova":
			pulse_nova((3.4 + lv * 0.35) * loadout.stats.area * (1.5 if evo else 1.0), (1.1 + lv * 0.2) * loadout.stats.damage)
		"scatter":
			var spread := 5 if evo else 3
			for i in spread:
				var a := player.rotation.y + (i - (spread - 1) / 2.0) * 0.45
				fire_bolt(sin(a), cos(a), {"dmg": 0.7 + lv * 0.1, "life": 0.7})
		"mines":
			var mn := 2 if evo else 1
			for i in mn:
				fire_bolt(-_fwd.x + (0.4 if i > 0 else 0.0), -_fwd.z, {"dmg": 1.4 + lv * 0.2, "speed": 8.0, "life": 5.0, "scale": 1.4})


func tick_weapons(dt: float) -> void:
	for w in loadout.weapons:
		w.cd -= dt
		if w.cd > 0.0:
			continue
		var def: Dictionary = LoadoutLib.WEAPONS[w.id]
		w.cd = float(def.get("interval", 0.3)) * loadout.stats.cooldown
		fire_weapon(w)


# ---------------- updates ----------------

func update_player(dt: float) -> void:
	yaw_cmd = Input.get_axis("steer_left", "steer_right")
	if _t_active:
		yaw_cmd = _t_yaw
	if Input.is_action_pressed("throttle_up"):
		throttle += THROTTLE_RATE * dt
	if Input.is_action_pressed("throttle_down"):
		throttle -= THROTTLE_RATE * dt
	if Input.is_action_just_pressed("cut_throttle"):
		throttle = 0.0
	throttle = clampf(throttle, 0.0, 1.0)

	if Input.is_action_pressed("boost"):
		boost_t = maxf(boost_t, 0.05)
	boost_t = maxf(0.0, boost_t - dt)
	var boosting := boost_t > 0.0

	if u_turn <= 0.0 and Input.is_action_just_pressed("uturn"):
		u_turn = 0.42
		u_turn_from = player.rotation.y

	if (Input.is_action_just_pressed("roll")):
		_trigger_roll()

	yaw_cmd = clampf(yaw_cmd, -1.0, 1.0)

	for dir_action in ["steer_left", "steer_right"]:
		if Input.is_action_just_pressed(dir_action):
			var dir := -1 if dir_action == "steer_left" else 1
			var now := Time.get_ticks_msec()
			if dir == _kb_last_dir and now - _kb_last_tap < 260:
				_trigger_roll()
			_kb_last_tap = now
			_kb_last_dir = dir

	if u_turn <= 0.0:
		player.rotation.y -= yaw_cmd * TURN_RATE * dt

	var cruise: float = BASE_SPEED * throttle * loadout.stats.speed
	var speed: float = BOOST_SPEED * maxf(throttle, 0.4) * loadout.stats.speed if boosting else cruise
	_fwd = heading(player.rotation.y)
	player.position += _fwd * speed * dt
	confine_player(dt)

	var bank := lerpf(player.rotation.z, -yaw_cmd * 0.55, 1.0 - exp(-8.0 * dt))
	if roll_t > 0.0:
		roll_t -= dt
		player.rotation.z = bank + (1.0 - maxf(roll_t, 0.0) / ROLL_TIME) * TAU
	else:
		player.rotation.z = bank
	player.rotation.x = lerpf(player.rotation.x, -throttle * 0.12, 1.0 - exp(-8.0 * dt))

	engine_light.light_energy = 3.1 if boosting else 0.35 + throttle * 1.4
	if ship_body_mat:
		ship_body_mat.set_shader_parameter("u_engine_pulse", 1.0 if boosting else 0.25 + throttle * 0.6)
		ship_body_mat.set_shader_parameter("u_damage_flash", damage_flash)

	roll_cd = maxf(0.0, roll_cd - dt)
	i_frames = maxf(0.0, i_frames - dt)


func confine_player(dt: float) -> void:
	var h := ARENA / 2.0 - 6.0
	var p := player.position
	var hit := false
	if p.x > h:
		p.x = h; hit = true
	elif p.x < -h:
		p.x = -h; hit = true
	if p.z > h:
		p.z = h; hit = true
	elif p.z < -h:
		p.z = -h; hit = true
	if hit and u_turn <= 0.0:
		u_turn = 0.42
		u_turn_from = player.rotation.y
	if u_turn > 0.0:
		u_turn -= dt
		var t := 1.0 - maxf(u_turn, 0.0) / 0.42
		var e := t * t * (3.0 - 2.0 * t)
		player.rotation.y = u_turn_from + PI * e


func update_enemies(dt: float) -> void:
	var px := player.position.x
	var pz := player.position.z
	for i in range(enemies.size() - 1, -1, -1):
		var rec: Dictionary = enemies[i]
		var e: Node3D = rec.node
		var dx := px - e.position.x
		var dz := pz - e.position.z
		var d2 := dx * dx + dz * dz
		if d2 > 0.0001:
			var yaw := atan2(dx, dz)
			var dy := yaw - e.rotation.y
			while dy > PI: dy -= TAU
			while dy < -PI: dy += TAU
			e.rotation.y += dy * minf(1.0, 4.0 * dt)
		_fwd = heading(e.rotation.y)
		e.position += _fwd * float(rec.speed) * dt
		wrap_to_arena(e.position)

		var hit_r := 16.0 if rec.boss else 3.24
		if d2 < hit_r and i_frames <= 0.0 and not smoke_mode:
			damage_flash = 1.0
			shake_amt = 0.4
			hit_flag = true
			if GameState.damage():
				end_run(false)
				return
			i_frames = I_FRAMES
			if not rec.boss:
				recycle_enemy(rec)


func update_projectiles(dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		p.life -= dt
		p.mesh.position.x += p.vx * dt
		p.mesh.position.z += p.vz * dt
		if p.life <= 0.0:
			recycle_bolt(i)
			continue
		var bx: float = p.mesh.position.x
		var bz: float = p.mesh.position.z
		var dead := false
		for j in range(enemies.size() - 1, -1, -1):
			var rec: Dictionary = enemies[j]
			var dx: float = bx - rec.node.position.x
			var dz: float = bz - rec.node.position.z
			if dx * dx + dz * dz < HIT_R2:
				rec.hp -= 1.0
				recycle_bolt(i)
				hurt_enemy(rec, p.dmg)
				dead = true
				break
		if dead:
			continue


func update_gems(dt: float) -> void:
	var px := player.position.x
	var pz := player.position.z
	var pull_r: float = GEM_PULL * loadout.stats.magnet
	for i in range(gems.size() - 1, -1, -1):
		var g: Dictionary = gems[i]
		g.life -= dt
		g.mesh.rotation.y += dt * 3.0
		var dx: float = px - g.mesh.position.x
		var dz: float = pz - g.mesh.position.z
		var d2 := dx * dx + dz * dz
		if d2 < pull_r * pull_r and d2 > 0.0001:
			var d := sqrt(d2)
			var pull := (pull_r - d) * 4.0 * dt
			g.mesh.position.x += (dx / d) * pull
			g.mesh.position.z += (dz / d) * pull
		if d2 < 2.0 or g.life <= 0.0:
			if d2 < 2.0:
				GameState.add_xp(1)
			g.mesh.visible = false
			gem_pool.append(g.mesh)
			gems[i] = gems[gems.size() - 1]
			gems.pop_back()


func update_pods(dt: float) -> void:
	var px := player.position.x
	var pz := player.position.z
	var pull_r: float = 36.0 * loadout.stats.magnet
	for i in range(pods.size() - 1, -1, -1):
		var p: Dictionary = pods[i]
		p.life -= dt
		p.mesh.rotation.x += dt * 1.4
		p.mesh.rotation.y += dt * 2.0
		var dx: float = px - p.mesh.position.x
		var dz: float = pz - p.mesh.position.z
		var d2 := dx * dx + dz * dz
		if d2 < pull_r * pull_r and d2 > 0.0001:
			var d := sqrt(d2)
			p.mesh.position.x += (dx / d) * 10.0 * dt
			p.mesh.position.z += (dz / d) * 10.0 * dt
		if d2 < 3.2:
			var ready_id := LoadoutLib.first_evolvable(loadout)
			if ready_id != "":
				LoadoutLib.evolve(loadout, ready_id)
				ui.say_once("evo-" + ready_id, "pip", "%s online. Don't waste it." % LoadoutLib.WEAPONS[ready_id].evo_name)
			else:
				GameState.add_xp(14)
			_despawn(pods, i, pod_pool)
		elif p.life <= 0.0:
			_despawn(pods, i, pod_pool)


func _despawn(arr: Array, i: int, pool: Array) -> void:
	var item: Dictionary = arr[i]
	item.mesh.visible = false
	pool.append(item.mesh)
	arr[i] = arr[arr.size() - 1]
	arr.pop_back()


func update_caches(dt: float) -> void:
	var px := player.position.x
	var pz := player.position.z
	for c in caches:
		if c.taken:
			continue
		c.mesh.rotation.y += dt * 1.6
		c.mesh.position.y = 0.55 + sin(GameState.run.elapsed * 2.4) * 0.12
		var dx: float = px - c.mesh.position.x
		var dz: float = pz - c.mesh.position.z
		if dx * dx + dz * dz < 4.5:
			collect_cache(c)


func collect_cache(c: Dictionary) -> void:
	if c.taken:
		return
	c.taken = true
	c.mesh.visible = false
	match c.kind:
		"patch":
			GameState.heal(2)
			ui.say_once("cache-patch", "pip", "Patch kit. Two plates sealed. Don't spend them twice.")
		"vac":
			var n := gems.size()
			for g in gems:
				g.mesh.visible = false
				gem_pool.append(g.mesh)
			gems.clear()
			if n > 0:
				GameState.add_xp(n)
			ui.say_once("cache-vac", "pip", "Scoop's full. That's a lot of light." if n > 0 else "Scoop's dry. Kill something first.")
		"flare":
			var cleared := 0
			for i in range(enemies.size() - 1, -1, -1):
				if enemies[i].boss:
					continue
				recycle_enemy(enemies[i])
				cleared += 1
			if cleared > 0:
				ui.say_once("cache-flare", "juno", "Flare out. I can see again.", 4.1)
			else:
				ui.say_once("cache-flare-dry", "juno", "You wasted a flare on empty sky.", 4.1)


func update_orbiters(dt: float) -> void:
	for i in range(orbiters.size() - 1, -1, -1):
		var o: Dictionary = orbiters[i]
		o.life -= dt
		o.angle += o.speed * dt
		o.mesh.position = Vector3(
			player.position.x + sin(o.angle) * o.radius,
			0.3,
			player.position.z + cos(o.angle) * o.radius
		)
		for j in range(enemies.size() - 1, -1, -1):
			var rec: Dictionary = enemies[j]
			var dx: float = o.mesh.position.x - rec.node.position.x
			var dz: float = o.mesh.position.z - rec.node.position.z
			if dx * dx + dz * dz < 2.2:
				hurt_enemy(rec, o.dmg * dt * 8.0)
		if o.life <= 0.0:
			o.mesh.queue_free()
			orbiters.remove_at(i)


func update_camera(dt: float) -> void:
	var vp := get_window().size
	var portrait := vp.y > vp.x
	var coarse := false
	if DisplayServer.get_name() != "headless":
		coarse = DisplayServer.is_touchscreen_available()
	var wide := portrait or coarse
	cam.fov = 72.0 if wide else 55.0
	var back := 13.5 if wide else 8.4
	var up := 3.6 if wide else 2.35
	_fwd = heading(player.rotation.y)
	var target := player.position - _fwd * back
	target.y = player.position.y + up
	var t := 1.0 - exp(-10.0 * dt)
	cam.position = cam.position.lerp(target, t)
	shake_amt = maxf(0.0, shake_amt - dt * 1.6)
	if shake_amt > 0.001:
		cam.position += Vector3(
			randf_range(-1, 1) * shake_amt,
			randf_range(-1, 1) * shake_amt * 0.6,
			randf_range(-1, 1) * shake_amt)
	var look := player.position + _fwd * 22.0
	look.y = player.position.y + 0.35
	if (look - cam.position).length_squared() > 0.001:
		cam.look_at(look)


# ---------------- run flow ----------------

func reset_run() -> void:
	GameState.reset_meta()
	GameState.new_run()
	loadout = LoadoutLib.empty_loadout()
	LoadoutLib.recompute(loadout)
	running = true
	selecting = false
	boss_spawned = false
	i_frames = 1.2
	roll_t = 0.0
	roll_cd = 0.0
	u_turn = 0.0
	throttle = 0.35
	boost_t = 0.0
	damage_flash = 0.0
	shake_amt = 0.0
	spawn_acc = 0.0
	current_offers = []
	rolled_flag = false
	hit_flag = false
	ever_rolled = false
	player.position = Vector3.ZERO
	player.rotation = Vector3.ZERO
	while enemies.size() > 0:
		recycle_enemy(enemies[0])
	for p in projectiles:
		p.mesh.visible = false
		bolt_pool.append(p.mesh)
	projectiles.clear()
	for g in gems:
		g.mesh.visible = false
		gem_pool.append(g.mesh)
	gems.clear()
	for p in pods:
		p.mesh.visible = false
		pod_pool.append(p.mesh)
	pods.clear()
	for o in orbiters:
		o.mesh.queue_free()
	orbiters.clear()
	clear_caches()
	spawn_field_caches()
	for i in START_HORDE:
		spawn_enemy()
	ui.start_mission()


func end_run(won: bool) -> void:
	running = false
	selecting = false
	ui.close_offers()
	GameState.end_run(won)
	ui.show_result(won, GameState.run.level, GameState.run.kills, int(GameState.run.elapsed))
	if won:
		print("[mission] MERCY IS AWAY — Lv %d · %d kills · %ds" % [GameState.run.level, GameState.run.kills, int(GameState.run.elapsed)])
	else:
		ui.comms_triggers({"dead": true})
		print("[mission] HULL LOST — Lv %d · %d kills · %ds" % [GameState.run.level, GameState.run.kills, int(GameState.run.elapsed)])


func _on_level_up_signal(_pending: int) -> void:
	pass  # handled in _process gate


func _resolve_levelups() -> void:
	if selecting or GameState.run.pending_levels <= 0:
		return
	selecting = true
	current_offers = LoadoutLib.offer_three(loadout)
	ui.open_offers(current_offers)


func _apply_pick(choice: Dictionary) -> void:
	var heals := LoadoutLib.apply_choice(loadout, choice)
	GameState.consume_pending_level()
	GameState.run.max_hp = GameState.MAX_HP + int(loadout.stats.hp_bonus)
	if heals:
		GameState.heal(1)
	print("[levelup] picked: %s (%s)" % [choice.label, choice.kind])
	if GameState.run.pending_levels > 0:
		current_offers = LoadoutLib.offer_three(loadout)
		ui.open_offers(current_offers)
	else:
		current_offers = []
		ui.close_offers()
		selecting = false


# ---------------- main loop ----------------

func _process(delta: float) -> void:
	var dt := minf(delta, 0.3 if smoke_mode else 0.05)
	damage_flash = maxf(0.0, damage_flash - dt * 3.0)

	if running and not selecting:
		GameState.run.elapsed += dt
		spawn_acc += dt
		if spawn_acc > 0.4:
			spawn_acc = 0.0
			var want := desired_horde()
			while enemies.size() < want:
				spawn_enemy()
		_sm_max_enemies = maxi(_sm_max_enemies, enemies.size())

		if not boss_spawned and GameState.run.elapsed >= boss_time:
			boss_spawned = true
			spawn_enemy(true)
			ui.say("vicar", "Ace on the Well. Mercy is jumping — finish this.")

		tick_weapons(dt)
		update_player(dt)
		update_enemies(dt)
		update_projectiles(dt)
		update_gems(dt)
		update_pods(dt)
		update_orbiters(dt)
		update_caches(dt)

		if running and GameState.run.elapsed >= sector_end:
			end_run(true)

		player.visible = i_frames <= 0.0 or fmod(GameState.run.elapsed * 24.0, 2.0) < 1.0
		if running:
			_resolve_levelups()
	else:
		player.rotation.y += dt * 0.25

	if selecting:
		for i in 3:
			if Input.is_action_just_pressed("pick_card_%d" % (i + 1)) and i < current_offers.size():
				_apply_pick(current_offers[i])
				break

	if smoke_mode and selecting and current_offers.size() > 0:
		var pick: Dictionary = current_offers[randi() % current_offers.size()]
		print("[levelup] auto-pick: %s (%s)" % [pick.label, pick.kind])
		_apply_pick(pick)

	update_camera(dt if running and not selecting else dt * 0.6)

	if not GameState.run.is_empty():
		ui.comms_triggers({
			"elapsed": GameState.run.get("elapsed", 0.0),
			"wave": 1 + int(GameState.run.get("elapsed", 0.0) / 18.0),
			"kills": GameState.run.get("kills", 0),
			"hp": GameState.run.get("hp", GameState.MAX_HP),
			"just_rolled": rolled_flag,
			"just_hit": hit_flag,
			"ever_rolled": ever_rolled,
			"dead": false,
		})
	rolled_flag = false
	hit_flag = false
	ui.poll(dt, self)
	_smoke_checks()


# ---------------- touch gestures (one finger) ----------------
# Port of js/main.js touchstart/move/end: drag steer, flick up boost,
# flick down u-turn, flick side roll, double-tap throttle cut.

var _t_active := false
var _t_sx := 0.0
var _t_sy := 0.0
var _t_px := 0.0
var _t_py := 0.0
var _t_start := 0
var _t_last_tap := 0
var _t_yaw := 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.index != 0:
			return
		if st.pressed:
			_t_active = true
			_t_sx = st.position.x
			_t_sy = st.position.y
			_t_px = _t_sx
			_t_py = _t_sy
			_t_start = Time.get_ticks_msec()
			_t_yaw = 0.0
		else:
			if not _t_active:
				return
			_t_active = false
			var w := float(get_window().size.x)
			var dx := _t_px - _t_sx
			var dy := _t_py - _t_sy
			var dist := sqrt(dx * dx + dy * dy)
			var held := Time.get_ticks_msec() - _t_start
			var now := Time.get_ticks_msec()
			if held < 240 and dist > 40.0:
				if absf(dx) > absf(dy) * 1.25:
					_trigger_roll()
				elif dy < 0.0:
					boost_t = maxf(boost_t, 0.55)
				else:
					if u_turn <= 0.0:
						u_turn = 0.42
						u_turn_from = player.rotation.y
			elif held < 220 and dist < 22.0:
				if now - _t_last_tap < 280:
					throttle = 0.0
				_t_last_tap = now
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index != 0 or not _t_active:
			return
		var w := float(get_window().size.x)
		_t_yaw = clampf((sd.relative.x / (w * 0.18)) * 2.2, -1.0, 1.0)


func _trigger_roll() -> void:
	if roll_cd <= 0.0 and roll_t <= 0.0:
		roll_t = ROLL_TIME
		roll_cd = ROLL_COOLDOWN + ROLL_TIME
		i_frames = maxf(i_frames, ROLL_TIME + 0.08)
		rolled_flag = true
		ever_rolled = true


# ---------------- smoke harness ----------------

func _fail(msg: String) -> void:
	push_error("GAME SMOKE FAILED: " + msg)
	print("GAME SMOKE FAILED: " + msg)
	get_tree().quit(1)


func _smoke_checks() -> void:
	if not smoke_mode:
		return
	var el: float = GameState.run.elapsed
	if el >= 5.0 and not _sm_did_xp:
		_sm_did_xp = true
		GameState.add_xp(20)
	if el >= 7.0 and GameState.run.pending_levels == 0 and GameState.run.level < 2:
		_fail("no level-up by 7s (xp=%d lvl=%d)" % [GameState.run.xp, GameState.run.level])
		return
	if el >= 9.0 and not _sm_did_evo:
		_sm_did_evo = true
		loadout.passives.append({"id": "coolant", "level": 1})
		loadout.weapons[0].level = LoadoutLib.WEAPON_MAX
		LoadoutLib.recompute(loadout)
		if LoadoutLib.first_evolvable(loadout) != "twin":
			_fail("twin should be evolvable")
			return
		LoadoutLib.evolve(loadout, "twin")
		_sm_evo_ok = LoadoutLib.weapon_label(loadout.weapons[0]) == "Storm Array"
		if not _sm_evo_ok:
			_fail("evolution label wrong")
			return
	if el >= 30.0 or GameState.run.elapsed >= sector_end or not running:
		if _sm_fired < 20:
			_fail("weapons barely fired (%d)" % _sm_fired)
			return
		if _sm_max_enemies < 10:
			_fail("horde never scaled (max %d)" % _sm_max_enemies)
			return
		if smoke_mode and not boss_spawned:
			_fail("boss never spawned by end of quick timeline")
			return
		print("GAME SMOKE OK — fired=%d maxEnemies=%d lvl=%d kills=%d hp=%d evo=%s boss=%s won=%s" % [
			_sm_fired, _sm_max_enemies, GameState.run.level, GameState.run.kills,
			GameState.run.hp, _sm_evo_ok, boss_spawned, GameState.run.won])
		get_tree().quit(0)
	elif el >= 45.0:
		print("GAME SMOKE TIMEOUT — asserting partial: fired=%d" % _sm_fired)
		get_tree().quit(0 if _sm_fired >= 20 else 1)
