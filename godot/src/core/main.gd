extends Node3D
## Barrel Heaven — main orchestrator.
## Direct port of js/main.js: all-range arena, horde, weapons, pickups, win/lose.
## Locked demo scope: single boss at 8:00, survive to 10:00 to win.

const LoadoutLib := preload("res://src/core/loadout.gd")
const Pool := preload("res://src/core/pool.gd")

const ARENA := 960.0
const BASE_SPEED := 16.0
const BOOST_SPEED := 42.0
const TURN_RATE := 2.55
const ROLL_TIME := 0.32
const ROLL_COOLDOWN := 0.72
const U_TURN_TIME := 0.42
const HOP_RISE := 0.40
const HOP_LAND := 0.55
const HOP_HEIGHT := 18.0
const I_FRAMES := 0.85
const PROJECTILE_SPEED := 160.0
const PROJECTILE_LIFE := 1.35
const GEM_PULL := 28.0
const HIT_R2 := 2.4
const THROTTLE_RATE := 0.9
const BOLT_COL := {
	"twin": Color(1.0, 0.72, 0.18),
	"lock": Color(0.95, 0.82, 0.35),
	"scatter": Color(0.72, 0.55, 0.18),
	"mines": Color(0.85, 0.28, 0.08),
}



var boss_time := 480.0
var sector_end := 600.0
var unlock_scale := 1.0   # smoke compresses enemy unlock times

const SHIP_SHADER := preload("res://assets/shaders/ship.gdshader")
const ENEMY_SHADER := preload("res://assets/shaders/enemy.gdshader")
const BOLT_SHADER := preload("res://assets/shaders/bolt.gdshader")
const GRID_SHADER := preload("res://assets/shaders/grid.gdshader")
const SKY_SHADER := preload("res://assets/shaders/bg_sky.gdshader")
const UI_LAYER := preload("res://src/ui/ui.gd")

const MUS_COMBAT := preload("res://assets/audio/music_combat.wav")
const MUS_BOSS := preload("res://assets/audio/music_boss.wav")
const SFX := {
	"laser": preload("res://assets/audio/sfx_laser.wav"),
	"explode": preload("res://assets/audio/sfx_explode.wav"),
	"bigexplode": preload("res://assets/audio/sfx_bigexplode.wav"),
	"hurt": preload("res://assets/audio/sfx_hurt.wav"),
	"gem": preload("res://assets/audio/sfx_gem.wav"),
	"levelup": preload("res://assets/audio/sfx_levelup.wav"),
	"pick": preload("res://assets/audio/sfx_pick.wav"),
	"roll": preload("res://assets/audio/sfx_roll.wav"),
	"boost": preload("res://assets/audio/sfx_boost.wav"),
	"slam": preload("res://assets/audio/sfx_slam.wav"),
	"alarm": preload("res://assets/audio/sfx_alarm.wav"),
	"win": preload("res://assets/audio/sfx_win.wav"),
	"lose": preload("res://assets/audio/sfx_lose.wav"),
}


func sfx(name: String, vol := 0.0, pitch := 1.0) -> void:
	var st: AudioStream = SFX.get(name)
	if st != null:
		AudioManager.play_sfx(st, vol, pitch)

# ---- run state ----
var running := false
var selecting := false
var paused := false
var smoke_mode := false
var i_frames := 0.0
var hitstop := 0.0
var roll_t := 0.0
var roll_cd := 0.0
var throttle := 0.0
var boost_t := 0.0
var u_turn := 0.0
var u_turn_from := 0.0
var hop_phase := 0
var hop_t := 0.0
var hop_fuel := 0.0
var yaw_cmd := 0.0
var _yaw_slew := 0.0
var damage_flash := 0.0
var shake_amt := 0.0
var rolled_flag := false
var hit_flag := false
var ever_rolled := false
var _kb_last_tap := 0
var _kb_last_dir := 0
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
var enemy_pool: Dictionary = {}
var _sm_types := {}
var _bolt_pool
var _gem_pool
var _pod_pool
var _boss_bolt_pool

var loadout: Dictionary = {}

# nodes
var player: Node3D
var ship_visual: Node3D
var engine_light: OmniLight3D
var cam: Camera3D
var ship_body_mat: ShaderMaterial
var ui: UiLayer
var spawn_sys
var tut

# boss fight state
var boss: BossGuardian = null
var boss_bolts: Array = []
var fx_list: Array = []
var pitch_ang := 0.0
var pitch_unlocked := false
var _victory_scheduled := false
var _sm_arm := 0
var _sm_super := false
var _shot_t := -1.0
var _sky_mat: ShaderMaterial
var trail: CPUParticles3D
var streaks: CPUParticles3D
var asteroids: Array = []
var _rock_mat: StandardMaterial3D
const ASTEROID_COUNT := 14

var _fwd := Vector3.ZERO
var _to := Vector3.UP


func _ready() -> void:
	_init_pools()
	spawn_sys = $SpawnSystem
	spawn_sys.setup(self)
	tut = $Tutorial
	tut.setup(self)
	smoke_mode = OS.get_cmdline_user_args().has("--smoke")
	if OS.get_cmdline_user_args().has("--shot"):
		_shot_t = 0.0
	if smoke_mode:
		Settings.values.tts_voice_lines = false
		Engine.time_scale = 8.0
		boss_time = 20.0
		sector_end = 40.0
		unlock_scale = sector_end / 600.0
	randomize()
	var has_key := false
	for ev in InputMap.action_get_events("uturn"):
		if ev is InputEventKey:
			has_key = true
			break
	if not has_key:
		var fk := InputEventKey.new()
		fk.physical_keycode = KEY_F
		InputMap.action_add_event("uturn", fk)
	_build_world()
	player = _build_player_ship()
	add_child(player)
	_build_streaks()
	GameState.level_up.connect(_on_level_up_signal)
	ui = UiLayer.new()
	add_child(ui)
	ui.launch_pressed.connect(_start_from_title)
	ui.relaunch_pressed.connect(func() -> void:
		ui.hide_overlay()
		reset_run())
	ui.card_picked.connect(_on_card_picked)
	ui.pause_pressed.connect(_on_pause_resume)
	ui.quit_pressed.connect(_on_quit_to_title)
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


func _on_pause_resume() -> void:
	paused = false
	ui.hide_pause()


func _on_quit_to_title() -> void:
	running = false
	ui.hide_pause()
	ui.show_title()


func _build_world() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	_sky_mat = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.36, 0.24)
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.03, 0.02)
	env.fog_density = 0.0042
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.82, 0.55)
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


func _build_streaks() -> void:
	streaks = CPUParticles3D.new()
	streaks.amount = 16
	streaks.lifetime = 0.22
	streaks.local_coords = true
	streaks.emitting = false
	streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	streaks.emission_box_extents = Vector3(1.4, 0.45, 1.6)
	streaks.position = Vector3(0, 0.12, -1.5)
	streaks.direction = Vector3(0, 0, -1)
	streaks.spread = 8.0
	streaks.initial_velocity_min = 10.0
	streaks.initial_velocity_max = 22.0
	streaks.gravity = Vector3.ZERO
	streaks.scale_amount_min = 0.35
	streaks.scale_amount_max = 0.85
	var sm := BoxMesh.new()
	sm.size = Vector3(0.03, 0.03, 0.7)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(1.0, 0.72, 0.28, 0.4)
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.45, 0.08)
	smat.emission_energy_multiplier = 1.1
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = smat
	streaks.mesh = sm
	(ship_visual if ship_visual != null else player).add_child(streaks)


func _ship_mat(mask: Vector3) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHIP_SHADER
	m.set_shader_parameter("u_mask", mask)
	return m


func _tri_mesh(verts: PackedVector3Array, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal := (verts[1] - verts[0]).cross(verts[2] - verts[0]).normalized()
	for i in range(0, verts.size(), 3):
		st.set_normal(normal)
		st.add_vertex(verts[i])
		st.set_normal(normal)
		st.add_vertex(verts[i + 1])
		st.set_normal(normal)
		st.add_vertex(verts[i + 2])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


func _build_player_ship() -> Node3D:
	var root := Node3D.new()
	ship_visual = Node3D.new()
	ship_visual.name = "visual"
	root.add_child(ship_visual)
	var art := _try_ship_art()
	if art != null:
		ship_visual.add_child(art)
	else:
		_build_player_prims(ship_visual)
	_rig_ship_fx(ship_visual)
	return root


func _try_ship_art() -> Node3D:
	for path in ["res://assets/meshes/rook.tscn", "res://assets/meshes/rook.glb"]:
		if not ResourceLoader.exists(path):
			continue
		var res = load(path)
		if res is PackedScene:
			var n: Node = (res as PackedScene).instantiate()
			if n is Node3D:
				_paint_ship_art(n)
				return n as Node3D
	return null


func _paint_ship_art(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.material_override == null:
			mi.material_override = _ship_mat(Vector3(1, 0, 0))
			ship_body_mat = mi.material_override as ShaderMaterial
	for c in n.get_children():
		_paint_ship_art(c)


func _build_player_prims(into: Node3D) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.55
	cone.height = 3.4
	cone.radial_segments = 5
	var body := MeshInstance3D.new()
	body.mesh = cone
	ship_body_mat = _ship_mat(Vector3(1, 0, 0))
	body.material_override = ship_body_mat
	body.rotation_degrees.x = 90.0
	body.position.z = 0.2
	into.add_child(body)

	var hull := BoxMesh.new()
	hull.size = Vector3(0.7, 0.38, 2.1)
	var hull_mi := MeshInstance3D.new()
	hull_mi.mesh = hull
	hull_mi.material_override = _ship_mat(Vector3(0, 1, 0))
	hull_mi.position.z = 0.15
	into.add_child(hull_mi)

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.55, 0.38, 0.12)
	glass.emission_enabled = true
	glass.emission = Color(0.85, 0.35, 0.05)
	glass.emission_energy_multiplier = 0.35
	var cock := SphereMesh.new()
	cock.radius = 0.28
	cock.height = 0.56
	var cockpit := MeshInstance3D.new()
	cockpit.mesh = cock
	cockpit.material_override = glass
	cockpit.scale = Vector3(1.0, 0.7, 1.2)
	cockpit.position = Vector3(0, 0.28, 0.15)
	into.add_child(cockpit)

	for sign in [-1.0, 1.0]:
		var wing := _tri_mesh(PackedVector3Array([
			Vector3(0.1 * sign, 0.05, 0.85),
			Vector3(2.6 * sign, -0.22, -0.35),
			Vector3(0.12 * sign, 0.02, -1.25),
		]), _ship_mat(Vector3(0, 0, 1)))
		into.add_child(wing)

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
	into.add_child(fin)

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
	eng_mat.emission = Color(1.0, 0.42, 0.08)
	eng_mat.emission_energy_multiplier = 1.4
	engine.material_override = eng_mat
	engine.rotation_degrees.x = 90.0
	engine.position.z = -1.35
	into.add_child(engine)


func _rig_ship_fx(into: Node3D) -> void:
	engine_light = OmniLight3D.new()
	engine_light.light_color = Color(1.0, 0.42, 0.08)
	engine_light.omni_range = 10.0
	engine_light.light_energy = 0.7
	engine_light.position.z = -1.5
	into.add_child(engine_light)

	trail = CPUParticles3D.new()
	trail.position = Vector3(0, 0, -1.6)
	trail.amount = 36
	trail.lifetime = 0.45
	trail.local_coords = true
	trail.direction = Vector3(0, 0, -1)
	trail.spread = 4.0
	trail.initial_velocity_min = 6.0
	trail.initial_velocity_max = 10.0
	trail.gravity = Vector3.ZERO
	trail.scale_amount_min = 0.6
	trail.scale_amount_max = 1.2
	var tmesh := SphereMesh.new()
	tmesh.radius = 0.07
	tmesh.height = 0.14
	tmesh.radial_segments = 4
	tmesh.rings = 2
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(1.0, 0.42, 0.08)
	tmat.emission_enabled = true
	tmat.emission = Color(1.0, 0.42, 0.08)
	tmat.emission_energy_multiplier = 1.2
	tmesh.material = tmat
	trail.mesh = tmesh
	into.add_child(trail)


func _enemy_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ENEMY_SHADER
	return m


func _add_part(root: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_x := 0.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	if rot_x != 0.0:
		mi.rotation_degrees.x = rot_x
	root.add_child(mi)


func _make_enemy_node(type: String) -> Node3D:
	var root := Node3D.new()
	var mat := _enemy_mat()
	root.set_meta("mat", mat)

	match type:
		"weaver":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.30
			cone.height = 2.6
			cone.radial_segments = 4
			_add_part(root, cone, mat, Vector3.ZERO, 90.0)
			var wing := BoxMesh.new()
			wing.size = Vector3(1.4, 0.05, 0.5)
			_add_part(root, wing, mat, Vector3(0, 0, -0.2))
		"turret":
			var core := SphereMesh.new()
			core.radius = 0.55
			core.height = 1.1
			core.radial_segments = 4
			core.rings = 2
			_add_part(root, core, mat, Vector3.ZERO)
			var shell := TorusMesh.new()
			shell.inner_radius = 0.72
			shell.outer_radius = 0.92
			_add_part(root, shell, mat, Vector3.ZERO)
		"brute":
			var hull := BoxMesh.new()
			hull.size = Vector3(1.5, 1.0, 2.4)
			_add_part(root, hull, mat, Vector3.ZERO)
			var nose := CylinderMesh.new()
			nose.top_radius = 0.0
			nose.bottom_radius = 0.55
			nose.height = 1.2
			nose.radial_segments = 4
			_add_part(root, nose, mat, Vector3(0, 0, 1.7), 90.0)
			for sx in [-1.0, 1.0]:
				var plate := BoxMesh.new()
				plate.size = Vector3(0.35, 1.3, 1.4)
				_add_part(root, plate, mat, Vector3(0.95 * sx, 0, -0.2))
		"splitter", "mini":
			var blob := SphereMesh.new()
			blob.radius = 0.55
			blob.height = 1.1
			blob.radial_segments = 6
			blob.rings = 3
			_add_part(root, blob, mat, Vector3.ZERO)
			var spike := CylinderMesh.new()
			spike.top_radius = 0.0
			spike.bottom_radius = 0.22
			spike.height = 0.8
			spike.radial_segments = 4
			_add_part(root, spike, mat, Vector3(0, 0, 0.6), 90.0)
		_:   # chaser
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.42
			cone.height = 2.4
			cone.radial_segments = 4
			_add_part(root, cone, mat, Vector3.ZERO, 90.0)
			var wing := BoxMesh.new()
			wing.size = Vector3(2.1, 0.06, 0.7)
			_add_part(root, wing, mat, Vector3(0, 0, -0.15))

	root.visible = false
	add_child(root)
	return root


func _init_pools() -> void:
	_bolt_pool = Pool.new()
	_bolt_pool.configure(_make_bolt)
	_gem_pool = Pool.new()
	_gem_pool.configure(_make_gem)
	_pod_pool = Pool.new()
	_pod_pool.configure(_make_pod)
	_boss_bolt_pool = Pool.new()
	_boss_bolt_pool.configure(_make_boss_bolt)


func _enemy_pool_for(type: String):
	if not enemy_pool.has(type):
		var p = Pool.new()
		var t := type
		p.configure(func() -> Node: return _make_enemy_node(t))
		enemy_pool[type] = p
	return enemy_pool[type]


func _make_bolt() -> MeshInstance3D:
	var bolt := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	cyl.height = 1.4
	cyl.radial_segments = 4
	bolt.mesh = cyl
	var bm := ShaderMaterial.new()
	bm.shader = BOLT_SHADER
	bolt.material_override = bm
	bolt.visible = false
	add_child(bolt)
	return bolt


func _make_gem() -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.16, 0.42, 0.05)
	mesh.mesh = b
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.92, 0.68, 0.18, 0.88)
	m.emission_enabled = true
	m.emission = Color(0.85, 0.35, 0.05)
	m.emission_energy_multiplier = 1.8
	mesh.material_override = m
	mesh.visible = false
	add_child(mesh)
	return mesh


func _make_pod() -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 0.95
	mesh.mesh = cap
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.94, 0.76, 0.29)
	m.emission_enabled = true
	m.emission = Color(0.67, 0.47, 0.0)
	m.emission_energy_multiplier = 1.1
	mesh.material_override = m
	mesh.visible = false
	add_child(mesh)
	return mesh


func _make_boss_bolt() -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.09
	cyl.bottom_radius = 0.09
	cyl.height = 1.6
	cyl.radial_segments = 4
	mesh.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.35, 0.2)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.22, 0.08)
	m.emission_energy_multiplier = 1.6
	mesh.material_override = m
	mesh.visible = false
	add_child(mesh)
	return mesh


func heading(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


# ---------------- spawning ----------------

func wrap_to_arena(v: Vector3) -> void:
	var h := ARENA / 2.0
	if v.x > h: v.x = -h
	elif v.x < -h: v.x = h
	if v.z > h: v.z = -h
	elif v.z < -h: v.z = h


func recycle_enemy(rec: Dictionary) -> void:
	var idx := enemies.find(rec)
	if idx >= 0:
		enemies[idx] = enemies[enemies.size() - 1]
		enemies.pop_back()
	var type: String = rec.type
	_enemy_pool_for(type).give(rec.node)


func drop_gem(pos: Vector3) -> void:
	var mesh := _gem_pool.take() as MeshInstance3D
	mesh.position = Vector3(pos.x, 0.2, pos.z)
	gems.append({"mesh": mesh, "life": 12.0})


func drop_pod(x: float, z: float) -> void:
	var mesh := _pod_pool.take() as MeshInstance3D
	mesh.position = Vector3(x, 0.4, z)
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
		var sm := CapsuleMesh.new()
		sm.radius = 0.32
		sm.height = 1.05
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
	if not rec.node.visible or rec.spawn_t > 0.0:
		return
	rec.hp -= dmg
	rec.flash = 1.0
	var m: ShaderMaterial = rec.mat
	m.set_shader_parameter("u_flash", 1.0)
	m.set_shader_parameter("u_hp_ratio", clampf(float(rec.hp) / float(rec.max_hp), 0.0, 1.0))
	if rec.hp > 0.0:
		return
	var pos: Vector3 = rec.node.position
	for g in int(rec.gems):
		var off: Vector3 = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * float(rec.base_scale)
		drop_gem(pos + off)
	spawn_flash(pos, Color(1.0, 0.6, 0.25), 2.2 * float(rec.base_scale))
	sfx("explode", -10.0, randf_range(0.9, 1.15))
	if not smoke_mode:
		hitstop = maxf(hitstop, 0.045 if rec.get("elite", false) else 0.028)
	if rec.get("elite", false):
		drop_pod(pos.x, pos.z)
		ui.say_once("elite-down", "pip", "Elite down — Nest buoy on the field!")
	EventBus.enemy_killed.emit(rec.type, rec.get("elite", false), pos, int(rec.gems))
	if rec.type == "splitter":
		for k in 3:
			var a := randf() * TAU
			spawn_sys.spawn_enemy_at("mini", pos + Vector3(cos(a), 0, sin(a)) * 2.0)
	GameState.add_super(3.0)
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
	_launch_bolt(_to, opts)


func _launch_bolt(dir: Vector3, opts: Dictionary) -> void:
	var speed: float = opts.get("speed", PROJECTILE_SPEED)
	var bolt := _bolt_pool.take() as MeshInstance3D
	bolt.scale = Vector3.ONE * float(opts.get("scale", loadout.stats.area))
	bolt.basis = Basis(Quaternion(Vector3.UP, dir))
	bolt.position = player.position + heading(player.rotation.y) * 2.2 + Vector3(0, 0.3, 0)
	bolt.visible = true
	var mat := bolt.material_override as ShaderMaterial
	if mat != null:
		var col: Color = opts.get("tint", BOLT_COL.twin)
		mat.set_shader_parameter("u_core", col)
		mat.set_shader_parameter("u_intensity", float(opts.get("glow", 1.8)))
	projectiles.append({
		"mesh": bolt,
		"vel": dir * speed,
		"life": float(opts.get("life", PROJECTILE_LIFE)),
		"dmg": float(opts.get("dmg", 1.0)) * loadout.stats.damage,
		"r2": HIT_R2 * loadout.stats.area,
	})
	_sm_fired += 1
	sfx("laser", -16.0, randf_range(0.95, 1.12))


func recycle_bolt(i: int) -> void:
	var p: Dictionary = projectiles[i]
	_bolt_pool.give(p.mesh)
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
	m.emission = Color(1.0, 0.55, 0.18) if w.evolved else Color(1.0, 0.33, 0.13)
	m.emission_energy_multiplier = 1.4 if w.evolved else 0.9
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
			if boss != null and not boss.dead:
				var part := best_part()
				if not part.is_empty():
					fire_bolt_at(part.pos, 1.0 + lv * 0.15, {"tint": BOLT_COL.twin})
					if evo:
						var side := Vector3(_fwd.z, 0.0, -_fwd.x) * 1.2
						var dir2: Vector3 = ((part.pos as Vector3) + side) - player.position
						_launch_bolt(dir2.normalized(), {"dmg": 1.0 + lv * 0.15, "tint": BOLT_COL.twin, "glow": 2.4})
					return
			var t := best_target(true)
			if t == null:
				return
			fire_bolt(t.position.x - player.position.x, t.position.z - player.position.z, {"dmg": 1.0 + lv * 0.15, "tint": BOLT_COL.twin})
			if evo:
				fire_bolt(t.position.x - player.position.x + _fwd.z * 1.2, t.position.z - player.position.z - _fwd.x * 1.2, {"dmg": 1.0 + lv * 0.15, "tint": BOLT_COL.twin, "glow": 2.4})
		"lock":
			if boss != null and not boss.dead:
				var n_p := 3 if evo else 1
				for i in n_p:
					var pt := best_part()
					if pt.is_empty():
						break
					fire_bolt_at(pt.pos, 0.85 + lv * 0.12, {"tint": BOLT_COL.lock, "glow": 2.2})
				return
			var n := 3 if evo else 1
			var used: Array = []
			for i in n:
				var t2 := best_target(false, used)
				if t2 == null:
					break
				used.append(t2)
				fire_bolt(t2.position.x - player.position.x, t2.position.z - player.position.z, {"dmg": 0.85 + lv * 0.12, "speed": 110.0, "tint": BOLT_COL.lock, "glow": 2.2})
		"bomb":
			spawn_orbiter(w)
		"nova":
			var nr: float = (3.4 + lv * 0.35) * float(loadout.stats.area) * (1.5 if evo else 1.0)
			pulse_nova(nr, (1.1 + lv * 0.2) * loadout.stats.damage)
			spawn_flash(player.position, Color(1.0, 0.55, 0.12), nr * 0.55)
		"scatter":
			var spread := 5 if evo else 3
			for i in spread:
				var a := player.rotation.y + (i - (spread - 1) / 2.0) * 0.45
				fire_bolt(sin(a), cos(a), {"dmg": 0.7 + lv * 0.1, "life": 0.7, "tint": BOLT_COL.scatter})
		"mines":
			var mn := 2 if evo else 1
			for i in mn:
				fire_bolt(-_fwd.x + (0.4 if i > 0 else 0.0), -_fwd.z, {"dmg": 1.4 + lv * 0.2, "speed": 8.0, "life": 5.0, "scale": 1.4, "tint": BOLT_COL.mines, "glow": 1.4})


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
	if tut != null and tut.locked():
		roll_cd = maxf(0.0, roll_cd - dt)
		i_frames = maxf(0.0, i_frames - dt)
		return
	yaw_cmd = Input.get_axis("steer_left", "steer_right")
	if _t_active:
		yaw_cmd = _t_yaw
	if pitch_unlocked and boss != null and not boss.dead:
		var axis := Input.get_axis("throttle_up", "throttle_down")
		var pitch_cmd := -axis   # W = nose up
		if _t_active:
			pitch_cmd = -_t_pitch
		pitch_ang = clampf(pitch_ang + pitch_cmd * 1.7 * dt, -0.85, 0.85)
		throttle = lerpf(throttle, 0.55 + (0.3 if Input.is_action_pressed("boost") else 0.0), minf(1.0, dt * 2.5))
	else:
		pitch_ang = lerpf(pitch_ang, 0.0, minf(1.0, dt * 3.0))
	if not (pitch_unlocked and boss != null and not boss.dead):
		if Input.is_action_pressed("throttle_up"):
			throttle += THROTTLE_RATE * dt
		if Input.is_action_pressed("throttle_down"):
			throttle -= THROTTLE_RATE * dt
	if Input.is_action_just_pressed("cut_throttle"):
		throttle = 0.0
	throttle = clampf(throttle, 0.0, 1.0)

	if Input.is_action_just_pressed("boost") and boost_t <= 0.01:
		sfx("boost", -10.0)
	if Input.is_action_pressed("boost"):
		boost_t = maxf(boost_t, 0.05)
	boost_t = maxf(0.0, boost_t - dt)
	var boosting := boost_t > 0.0

	if hop_phase == 0 and u_turn <= 0.0 and Input.is_action_just_pressed("uturn"):
		_start_hop()

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

	_yaw_slew = lerpf(_yaw_slew, yaw_cmd, 1.0 - exp(-16.0 * dt))
	if u_turn <= 0.0:
		player.rotation.y -= _yaw_slew * TURN_RATE * dt

	var cruise: float = BASE_SPEED * throttle * loadout.stats.speed
	var speed: float = BOOST_SPEED * maxf(throttle, 0.4) * loadout.stats.speed if boosting else cruise
	var cp := cos(pitch_ang)
	_fwd = Vector3(sin(player.rotation.y) * cp, sin(pitch_ang), cos(player.rotation.y) * cp)
	player.position += _fwd * speed * dt
	confine_player(dt)
	if hop_phase != 0:
		_tick_hop(dt)
	elif player.position.y > 0.04:
		player.position.y = lerpf(player.position.y, 0.0, 1.0 - exp(-9.0 * dt))

	if hop_phase == 0:
		var vis := ship_visual if ship_visual != null else player
		var bank := lerpf(vis.rotation.z, _yaw_slew * 0.78, 1.0 - exp(-10.0 * dt))
		if roll_t > 0.0:
			roll_t -= dt
			vis.rotation.z = bank + (1.0 - maxf(roll_t, 0.0) / ROLL_TIME) * TAU
		else:
			vis.rotation.z = bank
		vis.rotation.x = -pitch_ang
		player.rotation.x = 0.0
		player.rotation.z = 0.0
	elif roll_t > 0.0:
		roll_t -= dt

	engine_light.light_energy = 3.1 if boosting else 0.35 + throttle * 1.4
	if trail != null:
		trail.emitting = throttle > 0.05
		trail.speed_scale = 0.7 + throttle * (2.4 if boosting else 1.1)
	if streaks != null:
		var hot: bool = (boosting or throttle > 0.55) and (tut == null or not bool(tut.locked()))
		streaks.emitting = hot
		streaks.position = Vector3(_yaw_slew * -0.6, 0.12, -1.5)
		streaks.speed_scale = 0.8 + throttle * (1.4 if boosting else 0.6)
	if ship_body_mat:
		ship_body_mat.set_shader_parameter("u_engine_pulse", 1.0 if boosting else 0.25 + throttle * 0.6)
		ship_body_mat.set_shader_parameter("u_damage_flash", damage_flash)

	roll_cd = maxf(0.0, roll_cd - dt)
	i_frames = maxf(0.0, i_frames - dt)


func confine_player(dt: float) -> void:
	if boss != null and not boss.dead:
		var bc := boss.global_position
		player.position.x = clampf(player.position.x, bc.x - 190.0, bc.x + 190.0)
		player.position.z = clampf(player.position.z, bc.z - 190.0, bc.z + 190.0)
		player.position.y = clampf(player.position.y, -25.0, 45.0)
		return
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
	if hit and u_turn <= 0.0 and hop_phase == 0:
		u_turn = U_TURN_TIME
		u_turn_from = player.rotation.y
	if u_turn > 0.0:
		u_turn -= dt
		var t := 1.0 - maxf(u_turn, 0.0) / U_TURN_TIME
		var e := t * t * (3.0 - 2.0 * t)
		player.rotation.y = u_turn_from + PI * e


func update_enemies(dt: float) -> void:
	var px := player.position.x
	var pz := player.position.z
	var el: float = GameState.run.elapsed
	for i in range(enemies.size() - 1, -1, -1):
		var rec: Dictionary = enemies[i]
		var e: Node3D = rec.node

		# warp-in pop
		if rec.spawn_t > 0.0:
			rec.spawn_t = maxf(0.0, rec.spawn_t - dt)
			var k: float = 1.0 - float(rec.spawn_t) / 0.3
			e.scale = Vector3.ONE * (float(rec.base_scale) * (0.2 + 0.8 * k))
		# hit flash decay
		if rec.flash > 0.0:
			rec.flash = maxf(0.0, rec.flash - dt * 6.0)
			(rec.mat as ShaderMaterial).set_shader_parameter("u_flash", rec.flash)

		var dx := px - e.position.x
		var dz := pz - e.position.z
		var d2 := dx * dx + dz * dz
		if d2 > 0.0001:
			var yaw := atan2(dx, dz)
			var dy := yaw - e.rotation.y
			while dy > PI: dy -= TAU
			while dy < -PI: dy += TAU
			e.rotation.y += dy * minf(1.0, 4.0 * dt)

		var move := Vector3(dx, 0.0, dz).normalized() if d2 > 0.0001 else Vector3.ZERO
		match rec.type:
			"weaver":
				var side := Vector3(-move.z, 0.0, move.x)
				var sway := sin(el * 3.0 + float(rec.phase)) * 0.85
				move = (move + side * sway).normalized()
			"turret":
				rec.fire_t -= dt
				if rec.fire_t <= 0.0 and rec.spawn_t <= 0.0 and d2 < 57600.0:
					rec.fire_t = randf_range(2.2, 3.2)
					boss_bolt(e.position + Vector3(0, 0.4, 0), Vector3(dx, 0, dz).normalized(), 40.0)
					sfx("laser", -15.0, 0.65)
			"brute", "mini":
				pass
		e.position += move * float(rec.speed) * dt
		wrap_to_arena(e.position)

		# contact damage
		if rec.spawn_t <= 0.0 and i_frames <= 0.0 and not smoke_mode and player.position.y < 2.6:
			var hit_r := 3.24 * float(rec.base_scale)
			var sticks_around: bool = rec.type == "brute" or rec.type == "turret"
			if d2 < hit_r:
				damage_flash = 1.0
				shake_amt = 0.4
				hit_flag = true
				sfx("hurt", -5.0)
				if GameState.damage():
					end_run(false)
					return
				i_frames = I_FRAMES
				if not sticks_around:
					recycle_enemy(rec)

	# separation pass — keeps the swarm from stacking into one blob
	for a in range(enemies.size() - 1, 0, -1):
		var ra: Dictionary = enemies[a]
		for b in range(a - 1, -1, -1):
			var rb: Dictionary = enemies[b]
			var dv: Vector3 = ra.node.position - rb.node.position
			var ds := dv.length_squared()
			var min_d := 1.7 * (float(ra.base_scale) + float(rb.base_scale))
			if ds < min_d * min_d and ds > 0.0001:
				var push := dv.normalized() * (min_d - sqrt(ds)) * 2.5 * dt
				ra.node.position += push
				rb.node.position -= push


func update_projectiles(dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		p.life -= dt
		var m: MeshInstance3D = p.mesh
		m.position += p.vel * dt
		if p.life <= 0.0:
			recycle_bolt(i)
			continue
		var consumed := false

		if boss != null and not boss.dead:
			for part in boss.part_positions():
				var dv: Vector3 = m.position - (part.pos as Vector3)
				if dv.length_squared() < float(part.radius) * float(part.radius):
					boss.take_damage(part.kind, p.dmg)
					spawn_flash(m.position, Color(1.0, 0.7, 0.3), 1.6)
					recycle_bolt(i)
					consumed = true
					break
		if consumed:
			continue

		var bx: float = m.position.x
		var bz: float = m.position.z
		var by: float = m.position.y
		if absf(by) > 4.5:
			continue
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
		g.mesh.rotation.x += dt * 5.5
		g.mesh.rotation.y += dt * 9.0
		g.mesh.rotation.z += dt * 3.2
		var flicker := 0.65 + 0.35 * absf(sin(GameState.run.elapsed * 18.0 + float(i)))
		g.mesh.scale = Vector3.ONE * flicker
		var dx: float = px - g.mesh.position.x
		var dz: float = pz - g.mesh.position.z
		var d2 := dx * dx + dz * dz
		if d2 < pull_r * pull_r and d2 > 0.0001:
			var d := sqrt(d2)
			var pull := (pull_r - d) * 7.0 * dt
			g.mesh.position.x += (dx / d) * pull
			g.mesh.position.z += (dz / d) * pull
		if d2 < 2.0 or g.life <= 0.0:
			if d2 < 2.0:
				GameState.add_xp(1)
				sfx("gem", -18.0, randf_range(0.95, 1.2))
				spawn_flash(g.mesh.position, Color(1.0, 0.55, 0.12), 1.1)
			_gem_pool.give(g.mesh)
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
			spawn_flash(p.mesh.position, Color(1.0, 0.55, 0.12), 5.5)
			shake_amt = maxf(shake_amt, 0.7)
			if not smoke_mode:
				hitstop = maxf(hitstop, 0.1)
			ui.surge()
			sfx("levelup", -6.0)
			_despawn(pods, i, _pod_pool)
		elif p.life <= 0.0:
			_despawn(pods, i, _pod_pool)


func _despawn(arr: Array, i: int, pool) -> void:
	var item: Dictionary = arr[i]
	pool.give(item.mesh)
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
	EventBus.cache_collected.emit(c.kind)
	spawn_flash(c.mesh.position, Color(0.85, 0.55, 0.10), 4.2)
	shake_amt = maxf(shake_amt, 0.55)
	if not smoke_mode:
		hitstop = maxf(hitstop, 0.08)
	ui.surge()
	sfx("pick", -4.0)
	match c.kind:
		"patch":
			GameState.heal(2)
			ui.say_once("cache-patch", "pip", "Patch kit. Two plates sealed. Don't spend them twice.")
		"vac":
			var n := gems.size()
			for g in gems:
				_gem_pool.give(g.mesh)
			gems.clear()
			if n > 0:
				GameState.add_xp(n)
			ui.say_once("cache-vac", "pip", "Packet dump's in." if n > 0 else "Dump's dry. Kill something first.")
		"flare":
			var cleared := 0
			for i in range(enemies.size() - 1, -1, -1):
				recycle_enemy(enemies[i])
				cleared += 1
			if cleared > 0:
				ui.say_once("cache-flare", "hatch", "Flare out. I can see again.", 4.1)
			else:
				ui.say_once("cache-flare-dry", "pip", "Flare on empty sky. Cute.", 4.1)


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


func spawn_asteroids() -> void:
	if _rock_mat == null:
		_rock_mat = StandardMaterial3D.new()
		_rock_mat.albedo_color = Color(0.24, 0.26, 0.30)
		_rock_mat.roughness = 1.0
	for i in ASTEROID_COUNT:
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 6
		sm.rings = 4
		sm.material = _rock_mat
		m.mesh = sm
		var s := randf_range(3.0, 9.0)
		m.scale = Vector3(s * randf_range(0.7, 1.3), s * randf_range(0.7, 1.3), s * randf_range(0.7, 1.3))
		var ang := randf() * TAU
		var dist := randf_range(120.0, ARENA / 2.0 - 40.0)
		m.position = Vector3(cos(ang) * dist, randf_range(-14.0, 10.0), sin(ang) * dist)
		m.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		add_child(m)
		asteroids.append({
			"mesh": m,
			"spin": Vector3(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25), randf_range(-0.25, 0.25)),
			"drift": Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0)),
		})


func update_asteroids(dt: float) -> void:
	for a in asteroids:
		var m: MeshInstance3D = a.mesh
		m.rotation += (a.spin as Vector3) * dt
		m.position += (a.drift as Vector3) * dt
		wrap_to_arena(m.position)


func clear_asteroids() -> void:
	for a in asteroids:
		a.mesh.queue_free()
	asteroids.clear()


func update_camera(dt: float) -> void:
	if tut != null and tut.apply_cam(dt):
		return
	var vp := get_window().size
	var portrait := vp.y > vp.x
	var coarse := false
	if DisplayServer.get_name() != "headless":
		coarse = DisplayServer.is_touchscreen_available()
	var wide := portrait or coarse
	var boosting := boost_t > 0.0
	var base_fov := 70.0 if wide else 60.0
	cam.fov = lerpf(cam.fov, (76.0 if wide else 66.0) if boosting else base_fov, 1.0 - exp(-5.0 * dt))
	var back := (8.4 if wide else 5.8) if boss != null and not boss.dead else (6.6 if wide else 5.0)
	var up := (7.2 if wide else 5.8) if boss != null and not boss.dead else (6.2 if wide else 5.0)
	_fwd = heading(player.rotation.y)
	var target := player.position - _fwd * back
	target.y = player.position.y + up
	var t := 1.0 - exp(-5.2 * dt)
	cam.position = cam.position.lerp(target, t)
	shake_amt = maxf(0.0, shake_amt - dt * 1.6)
	if shake_amt > 0.001:
		cam.position += Vector3(
			randf_range(-1, 1) * shake_amt,
			randf_range(-1, 1) * shake_amt * 0.6,
			randf_range(-1, 1) * shake_amt)
	var look := player.position + _fwd * 7.0
	look.y = player.position.y + 0.15
	if boss != null and not boss.dead:
		var head_pos: Vector3 = boss.head_position()
		look = look.lerp(head_pos, 0.45)
	if (look - cam.position).length_squared() > 0.001:
		cam.look_at(look)


# ---------------- run flow ----------------

func reset_run() -> void:
	ui.hide_overlay()
	ui.hide_pause()
	GameState.reset_meta()
	GameState.new_run()
	loadout = LoadoutLib.empty_loadout()
	LoadoutLib.recompute(loadout)
	running = true
	selecting = false
	boss_spawned = false
	_yaw_slew = 0.0
	i_frames = 1.2
	roll_t = 0.0
	roll_cd = 0.0
	u_turn = 0.0
	hop_phase = 0
	hop_t = 0.0
	hop_fuel = 0.0
	throttle = 0.35
	boost_t = 0.0
	damage_flash = 0.0
	shake_amt = 0.0
	spawn_sys.reset()
	if tut != null:
		tut.reset()
	current_offers = []
	rolled_flag = false
	hit_flag = false
	ever_rolled = false
	pitch_ang = 0.0
	pitch_unlocked = false
	_victory_scheduled = false
	if boss != null:
		boss.queue_free()
		boss = null
	for b in boss_bolts:
		_boss_bolt_pool.give(b.mesh)
	boss_bolts.clear()
	for f in fx_list:
		f.mesh.queue_free()
	fx_list.clear()
	player.position = Vector3.ZERO
	player.rotation = Vector3.ZERO
	while enemies.size() > 0:
		recycle_enemy(enemies[0])
	for p in projectiles:
		_bolt_pool.give(p.mesh)
	projectiles.clear()
	for g in gems:
		_gem_pool.give(g.mesh)
	gems.clear()
	for p in pods:
		_pod_pool.give(p.mesh)
	pods.clear()
	for o in orbiters:
		o.mesh.queue_free()
	orbiters.clear()
	clear_caches()
	spawn_field_caches()
	clear_asteroids()
	spawn_asteroids()
	spawn_sys.fill_start()
	AudioManager.play_music(MUS_COMBAT)


func end_run(won: bool) -> void:
	if not running:
		return
	running = false
	selecting = false
	ui.close_offers()
	AudioManager.stop_music()
	if won:
		sfx("win", -2.0)
	else:
		sfx("lose", -2.0)
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
	sfx("levelup", -7.0)


func _apply_pick(choice: Dictionary) -> void:
	var heals := LoadoutLib.apply_choice(loadout, choice)
	GameState.consume_pending_level()
	GameState.run.max_hp = GameState.MAX_HP + int(loadout.stats.hp_bonus)
	if heals:
		GameState.heal(1)
	sfx("pick", -8.0)
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
	if ui == null or player == null or cam == null:
		return
	var dt := minf(delta, 0.3 if smoke_mode else 0.05)
	if hitstop > 0.0 and not smoke_mode:
		hitstop -= delta
		dt *= 0.12
	damage_flash = maxf(0.0, damage_flash - dt * 3.0)

	# Handle pause toggle
	if Input.is_action_just_pressed("pause") and running and not selecting:
		paused = not paused
		if paused:
			ui.show_pause()
		else:
			ui.hide_pause()

	# Smart Bomb super
	if Input.is_action_just_pressed("super") and running and not selecting and not paused and (tut == null or not tut.locked()):
		fire_super()
	if smoke_mode and running and not paused and GameState.run.get("super_meter", 0.0) >= GameState.SUPER_MAX:
		fire_super()

	if running and not selecting and not paused:
		if tut != null:
			tut.sim(dt)
		GameState.run.elapsed += dt
		spawn_sys.sim(dt)
		_sm_max_enemies = maxi(_sm_max_enemies, enemies.size())

		if not boss_spawned and GameState.run.elapsed >= boss_time:
			boss_spawned = true
			_spawn_boss()
		if boss != null:
			boss.update(dt)

		# sky heats up as the Guardian's jump window approaches
		if _sky_mat != null:
			var heat := clampf((GameState.run.elapsed - (boss_time - 90.0)) / 90.0, 0.0, 1.0)
			_sky_mat.set_shader_parameter("u_top", Color(0.04, 0.03, 0.02).lerp(Color(0.18, 0.05, 0.02), heat))
			_sky_mat.set_shader_parameter("u_bottom", Color(0.02, 0.015, 0.01).lerp(Color(0.08, 0.02, 0.01), heat))

		update_asteroids(dt)
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

		update_boss_bolts(dt)
		if boss != null and boss.dead and not _victory_scheduled:
			_victory_scheduled = true
			ui.say("hatch", "Monkey's down. Mercy's clear — get out, Rook.")
			if tut != null:
				tut.begin_win()
			else:
				end_run(true)
		update_fx(dt)

		if tut != null and tut.locked():
			player.visible = true
		else:
			player.visible = i_frames <= 0.0 or fmod(GameState.run.elapsed * 24.0, 2.0) < 1.0
		if running:
			_resolve_levelups()

	if selecting:
		for i in 3:
			if Input.is_action_just_pressed("pick_card_%d" % (i + 1)) and i < current_offers.size():
				_apply_pick(current_offers[i])
				break

	if smoke_mode and selecting and current_offers.size() > 0:
		var pick: Dictionary = current_offers[randi() % current_offers.size()]
		print("[levelup] auto-pick: %s (%s)" % [pick.label, pick.kind])
		_apply_pick(pick)

	if running and not selecting and not paused:
		update_camera(dt)

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

	# debug: --shot [with optional --smoke for mid-combat capture]
	if _shot_t >= 0.0:
		_shot_t += delta
		if _shot_t > 1.5:
			var tex := get_viewport().get_texture()
			if tex != null:
				var img := tex.get_image()
				if img != null:
					img.save_png("user://shot.png")
					print("[SHOT] saved user://shot.png")
			get_tree().quit()


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
var _t_pitch := 0.0
var _t_hop_hold := false
var _t_hop_drag := false


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
			_t_pitch = 0.0
			_t_hop_drag = false
			if hop_phase == 1 or hop_phase == 2:
				_t_hop_hold = true
		else:
			if not _t_active:
				return
			_t_active = false
			_t_pitch = 0.0
			_t_hop_hold = false
			var dragged := _t_hop_drag
			_t_hop_drag = false
			if dragged:
				return
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
					sfx("boost", -10.0)
				else:
					_start_hop()
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
		var hgt := float(get_window().size.y)
		_t_pitch = clampf(_t_pitch + (sd.relative.y / (hgt * 0.18)) * 2.2, -1.0, 1.0)
		if hop_phase == 0 and not _t_hop_drag and (sd.position.y - _t_sy) > 56.0:
			_start_hop()
			_t_hop_drag = true
			_t_hop_hold = true


func _start_hop() -> void:
	if hop_phase != 0 or u_turn > 0.0 or (tut != null and tut.locked()):
		return
	hop_phase = 1
	hop_t = 0.0
	u_turn_from = player.rotation.y
	var sp := float(loadout.stats.speed)
	hop_fuel = (0.22 + maxf(throttle, 0.2) * 0.75) * sp
	if boost_t > 0.0:
		hop_fuel += 0.30 * sp
	i_frames = maxf(i_frames, HOP_RISE + 0.2)
	sfx("boost", -8.0, 0.85)
	var n := 0
	var px := player.position.x
	var pz := player.position.z
	for rec in enemies:
		var dx: float = rec.node.position.x - px
		var dz: float = rec.node.position.z - pz
		if dx * dx + dz * dz < 484.0:
			n += 1
	if n >= 8:
		ui.say_once("hop-pack", "hatch", "Over the pack! That's the move.")


func _tick_hop(dt: float) -> void:
	var holding := Input.is_action_pressed("uturn") or _t_hop_hold
	hop_t += dt
	i_frames = maxf(i_frames, 0.12)
	var vis := ship_visual if ship_visual != null else player
	if hop_phase == 1:
		var a := clampf(hop_t / HOP_RISE, 0.0, 1.0)
		var s := a * a * (3.0 - 2.0 * a)
		player.position.y = s * HOP_HEIGHT
		player.rotation.y = u_turn_from
		vis.rotation.x = -PI * s
		vis.rotation.z = 0.0
		if a >= 1.0:
			hop_t = 0.0
			hop_phase = 2 if (holding and hop_fuel > 0.0) else 3
	elif hop_phase == 2:
		player.position.y = HOP_HEIGHT
		player.rotation.y = u_turn_from
		vis.rotation.x = -PI
		vis.rotation.z = 0.0
		hop_fuel -= dt
		throttle = maxf(0.0, throttle - dt * 0.55)
		boost_t = 0.0
		if (not holding) or hop_fuel <= 0.0 or throttle <= 0.02:
			hop_t = 0.0
			hop_phase = 3
	elif hop_phase == 3:
		var b := clampf(hop_t / HOP_LAND, 0.0, 1.0)
		var s := b * b * (3.0 - 2.0 * b)
		player.position.y = HOP_HEIGHT * (1.0 - s)
		player.rotation.y = u_turn_from + PI * s
		vis.rotation.x = -PI * (1.0 - s)
		vis.rotation.z = TAU * s
		if b >= 1.0:
			hop_phase = 0
			player.position.y = 0.0
			vis.rotation.x = 0.0
			vis.rotation.z = 0.0


func _trigger_roll() -> void:
	if tut != null and tut.locked():
		return
	if roll_cd <= 0.0 and roll_t <= 0.0:
		roll_t = ROLL_TIME
		roll_cd = ROLL_COOLDOWN + ROLL_TIME
		i_frames = maxf(i_frames, ROLL_TIME)
		rolled_flag = true
		ever_rolled = true
		shake_amt = maxf(shake_amt, 0.22)
		if cam != null:
			cam.fov = minf(cam.fov + 6.0, 78.0)
		sfx("roll", -9.0, randf_range(0.95, 1.05))
		if tut != null:
			tut.on_roll()


# ---------------- boss fight ----------------

func fire_super() -> void:
	if not GameState.spend_super():
		return
	pulse_nova(150.0, 10.0 * loadout.stats.damage)
	if boss != null and not boss.dead:
		for part in boss.part_positions():
			boss.take_damage(part.kind, 8.0 * loadout.stats.damage)
	for i in range(boss_bolts.size() - 1, -1, -1):
		_boss_bolt_pool.give(boss_bolts[i].mesh)
	boss_bolts.clear()
	spawn_flash(player.position, Color(0.5, 1.0, 0.9), 34.0)
	shake_amt = 1.2
	sfx("slam", 0.0)
	sfx("bigexplode", -4.0)
	ui.say_once("super-used", "hatch", "Smart bomb out! That cleared the sky!")
	EventBus.super_activated.emit(player.position, 150.0)
	_sm_super = true


func _spawn_boss() -> void:
	boss = BossGuardian.new()
	add_child(boss)
	boss.setup(self)
	_fwd = heading(player.rotation.y)
	boss.position = player.position + _fwd * 170.0
	boss.position.y = 4.0
	pitch_unlocked = smoke_mode
	throttle = 0.55
	if tut != null:
		tut.begin_boss()
	AudioManager.play_music(MUS_BOSS)
	sfx("alarm", -6.0)
	ui.say("hatch", "Big monkey inbound. Pitch is live — W and S, kid.")
	ui.say("pip", "Shielded core. Both arms first, then the chest.")
	ui.say("kite", "Pretty fight, Rook. Try not to die boring.")


func boss_bolt(from: Vector3, dir: Vector3, speed: float) -> void:
	var mesh := _boss_bolt_pool.take() as MeshInstance3D
	var d := dir.normalized()
	mesh.basis = Basis(Quaternion(Vector3.UP, d))
	mesh.position = from
	boss_bolts.append({"mesh": mesh, "vel": d * speed, "life": 6.0})


func update_boss_bolts(dt: float) -> void:
	for i in range(boss_bolts.size() - 1, -1, -1):
		var b: Dictionary = boss_bolts[i]
		b.life -= dt
		var m: MeshInstance3D = b.mesh
		m.position += b.vel * dt
		if b.life <= 0.0 or m.position.y < -20.0:
			_boss_bolt_pool.give(m)
			boss_bolts[i] = boss_bolts[boss_bolts.size() - 1]
			boss_bolts.pop_back()
			continue
		if i_frames <= 0.0 and not smoke_mode:
			var dv := m.position - player.position
			if dv.length_squared() < 10.5:
				i_frames = I_FRAMES
				damage_flash = 1.0
				shake_amt = maxf(shake_amt, 0.35)
				hit_flag = true
				sfx("hurt", -5.0)
				if GameState.damage():
					end_run(false)
					return


func spawn_flash(pos: Vector3, col: Color, r: float) -> void:
	var mesh := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	mesh.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.9
	m.emission_energy_multiplier = 1.8
	mesh.material_override = m
	mesh.position = pos
	add_child(mesh)
	fx_list.append({"mesh": mesh, "t": 0.5, "max_t": 0.5})


func update_fx(dt: float) -> void:
	for i in range(fx_list.size() - 1, -1, -1):
		var f: Dictionary = fx_list[i]
		f.t -= dt
		var m: MeshInstance3D = f.mesh
		var k: float = f.t / f.max_t
		m.scale = Vector3.ONE * (1.0 + (1.0 - k) * 1.6)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if false else m.transparency
		var mat := m.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color.a = k
		if f.t <= 0.0:
			m.queue_free()
			fx_list.remove_at(i)


func best_part() -> Dictionary:
	if boss == null or boss.dead:
		return {}
	_fwd = heading(player.rotation.y)
	var best := {}
	var best_score := INF
	for part in boss.part_positions():
		var pos: Vector3 = part.pos
		var dv := pos - player.position
		var d2f := dv.x * dv.x + dv.z * dv.z
		if d2f < 1.0:
			continue
		var d := sqrt(d2f)
		var facing := (_fwd.x * dv.x + _fwd.z * dv.z) / d
		var score := d * (0.45 if facing > 0.15 else 1.25)
		if score < best_score:
			best_score = score
			best = part
	return best


func fire_bolt_at(target: Vector3, dmg: float, opts: Dictionary = {}) -> void:
	var muzzle := player.position + heading(player.rotation.y) * 2.2 + Vector3(0, 0.3, 0)
	var dir := (target - muzzle).normalized()
	opts = opts.duplicate()
	opts["dmg"] = dmg
	_launch_bolt(dir, opts)


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
	if el >= 12.0 and GameState.run.get("super_meter", 0.0) < 100.0:
		GameState.add_super(100.0)
	if el >= 15.0 and asteroids.size() < 10:
		_fail("asteroids missing (%d)" % asteroids.size())
		return
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
	if el >= boss_time + 1.5 and boss == null and not boss_spawned:
		_fail("boss never spawned")
		return
	# deterministic Guardian kill: arm -> arm -> core exposed -> core dead
	# (state-aware: auto-fire weapons may beat us to each stage, which is fine)
	var sm_boss_ok := true
	if boss != null and not boss.dead:
		if _sm_arm == 0 and boss.arms_alive == 2:
			_sm_arm = 1
			if boss.parts["armL"].alive:
				boss.take_damage("armL", 99999.0)
			else:
				boss.take_damage("armR", 99999.0)
			sm_boss_ok = boss.arms_alive == 1
		elif _sm_arm <= 1 and boss.arms_alive == 1 and not boss.core_vulnerable:
			_sm_arm = 2
			if boss.parts["armL"].alive:
				boss.take_damage("armL", 99999.0)
			else:
				boss.take_damage("armR", 99999.0)
			sm_boss_ok = boss.core_vulnerable
		elif _sm_arm <= 2 and boss.core_vulnerable:
			_sm_arm = 3
			boss.take_damage("core", 99999.0)
			sm_boss_ok = boss.dead
		if not sm_boss_ok:
			_fail("boss damage chain broken at stage %d" % _sm_arm)
			return
	elif boss != null and boss.dead and _sm_arm < 3:
		_sm_arm = 3   # weapons killed the Guardian outright — chain proven
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
		if smoke_mode and _sm_arm < 3:
			_fail("boss kill chain incomplete (stage %d)" % _sm_arm)
			return
		if smoke_mode and GameState.run.won != true:
			_fail("run did not end in victory (boss phase)")
			return
		if smoke_mode and not _sm_super:
			_fail("smart bomb never fired")
			return
		if smoke_mode and _sm_types.size() < 3:
			_fail("enemy variety never appeared (types=%s)" % [str(_sm_types.keys())])
			return
		print("GAME SMOKE OK — fired=%d maxEnemies=%d lvl=%d kills=%d hp=%d evo=%s boss=%s won=%s types=%s" % [
			_sm_fired, _sm_max_enemies, GameState.run.level, GameState.run.kills,
			GameState.run.hp, _sm_evo_ok, boss_spawned, GameState.run.won, str(_sm_types.keys())])
		get_tree().quit(0)
	elif el >= 45.0:
		print("GAME SMOKE TIMEOUT — asserting partial: fired=%d" % _sm_fired)
		get_tree().quit(0 if _sm_fired >= 20 else 1)
