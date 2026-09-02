extends Node3D
class_name BossGuardian
## The Guardian of the Well — monkey-robot bullet-hell boss.
## Andross rules: both arms must die before the core shield drops.
## Owns its attack patterns; emits bolts through main.boss_bolt().

const ARM_HP := 160.0
const CORE_HP := 300.0
const ARM_RADIUS := 7.0
const CORE_RADIUS := 9.0
const HEAD_Y := 15.0

var main: Node3D
var parts := {}                 # kind -> {node, hp, max, radius, alive}
var arms_alive := 2
var core_vulnerable := false
var dead := false
var attack_t := 3.5             # intro grace before first pattern
var slam_t := 11.0
var spiral_left := 0.0
var spiral_angle := 0.0
var spiral_tick := 0.0
var rings: Array = []           # {mesh, r, speed}
var bob := randf() * TAU

var _armor_mat: StandardMaterial3D
var _dark_mat: StandardMaterial3D
var _chest_disc: MeshInstance3D


func setup(m: Node3D) -> void:
	main = m
	_armor_mat = StandardMaterial3D.new()
	_armor_mat.albedo_color = Color(0.16, 0.18, 0.22)
	_armor_mat.metallic = 0.6
	_armor_mat.roughness = 0.5
	_dark_mat = StandardMaterial3D.new()
	_dark_mat.albedo_color = Color(0.09, 0.10, 0.13)
	_dark_mat.metallic = 0.4
	_build_body()


func _mesh(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func _build_body() -> void:
	var torso := CapsuleMesh.new()
	torso.radius = 5.0
	torso.height = 19.0
	_mesh(torso, _armor_mat, Vector3(0, 4, 0))

	var chest := SphereMesh.new()
	chest.radius = 2.2
	chest.height = 4.4
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = Color(1.0, 0.25, 0.15)
	disc_mat.emission_enabled = true
	disc_mat.emission = Color(1.0, 0.2, 0.1)
	disc_mat.emission_energy_multiplier = 1.1
	_chest_disc = _mesh(chest, disc_mat, Vector3(0, 6, 4.4))
	parts["chest_disc_mat"] = disc_mat   # stash for shield swap

	var head := SphereMesh.new()
	head.radius = 5.2
	head.height = 10.4
	_mesh(head, _armor_mat, Vector3(0, HEAD_Y, 0))

	var muzzle := SphereMesh.new()
	muzzle.radius = 2.8
	muzzle.height = 5.6
	var muzzle_mat := StandardMaterial3D.new()
	muzzle_mat.albedo_color = Color(0.55, 0.42, 0.30)
	_mesh(muzzle, muzzle_mat, Vector3(0, HEAD_Y - 1.6, 4.2))

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.15, 0.1)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.1, 0.05)
	eye_mat.emission_energy_multiplier = 1.6
	for sx in [-1.6, 1.6]:
		var eye := SphereMesh.new()
		eye.radius = 0.75
		eye.height = 1.5
		_mesh(eye, eye_mat, Vector3(sx, HEAD_Y + 1.8, 4.6))

	for side in [["armL", -1.0], ["armR", 1.0]]:
		var s: float = side[1]
		var shoulder := SphereMesh.new()
		shoulder.radius = 2.6
		shoulder.height = 5.2
		_mesh(shoulder, _armor_mat, Vector3(8.5 * s, 10.0, 0))

		var upper := CylinderMesh.new()
		upper.top_radius = 1.7
		upper.bottom_radius = 1.5
		upper.height = 9.0
		var up_mi := _mesh(upper, _dark_mat, Vector3(12.5 * s, 5.0, 0))
		up_mi.rotation_degrees.z = -70.0 * s

		var elbow := SphereMesh.new()
		elbow.radius = 1.9
		elbow.height = 3.8
		_mesh(elbow, _dark_mat, Vector3(16.0 * s, 2.5, 0))

		var fore := CylinderMesh.new()
		fore.top_radius = 1.45
		fore.bottom_radius = 1.3
		fore.height = 8.0
		var fo_mi := _mesh(fore, _dark_mat, Vector3(18.5 * s, -2.5, 0))
		fo_mi.rotation_degrees.z = -15.0 * s

		var fist := BoxMesh.new()
		fist.size = Vector3(3.4, 3.4, 3.4)
		var fist_mat := StandardMaterial3D.new()
		fist_mat.albedo_color = Color(0.20, 0.23, 0.28)
		fist_mat.metallic = 0.7
		fist_mat.emission_enabled = true
		fist_mat.emission = Color(1.0, 0.45, 0.1)
		fist_mat.emission_energy_multiplier = 0.5
		_mesh(fist, fist_mat, Vector3(19.5 * s, -7.0, 0))

		parts[side[0]] = {
			"node": _make_part_anchor(Vector3(17.0 * s, 0.0, 0.0)),
			"hp": ARM_HP, "max": ARM_HP, "radius": ARM_RADIUS, "alive": true,
		}

	parts["core"] = {
		"node": _make_part_anchor(Vector3(0, 5, 0)),
		"hp": CORE_HP, "max": CORE_HP, "radius": CORE_RADIUS, "alive": true,
	}


func _make_part_anchor(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	return n


# ---------------- damage ----------------

func take_damage(kind: String, dmg: float) -> void:
	if dead or not parts.has(kind):
		return
	var p: Dictionary = parts[kind]
	if not p.alive:
		return
	if kind == "core":
		if not core_vulnerable:
			dmg *= 0.12
			if randf() < 0.06:
				main.ui.say_once("core-shielded", "hatch", "It's shrugging it off! The arms — take the arms!")
		p.hp -= dmg
		if p.hp <= 0.0:
			die()
	else:
		p.hp -= dmg
		if p.hp <= 0.0:
			p.alive = false
			arms_alive -= 1
			var flash_pos: Vector3 = (p.node as Node3D).global_position
			p.node.get_parent().remove_child(p.node)   # stop hit detection
			EventBus.boss_part_destroyed.emit(kind, flash_pos)
			main.spawn_flash(flash_pos, Color(1.0, 0.5, 0.1), 14.0)
			main.shake_amt = maxf(main.shake_amt, 0.8)
			main.sfx("bigexplode", -3.0)
			main.sfx("slam", -8.0)
			match kind:
				"armL":
					main.ui.say_once("armL-down", "hatch", "Left arm's off! It's furious!", 3.4)
				"armR":
					main.ui.say_once("armR-down", "hatch", "Other arm's gone! Core's exposed — light it up!")
			if arms_alive <= 0:
				core_vulnerable = true
				var disc: StandardMaterial3D = parts["chest_disc_mat"]
				disc.emission = Color(0.2, 1.0, 0.5)
				disc.albedo_color = Color(0.2, 1.0, 0.5)
				main.ui.say_once("core-open", "pip", "Shield's down. Hit the chest, Rook.")
				main.sfx("alarm", -5.0)


func die() -> void:
	if dead:
		return
	dead = true
	EventBus.boss_killed.emit(global_position)
	main.spawn_flash(global_position + Vector3(0, 6, 0), Color(1.0, 0.85, 0.3), 40.0)
	main.spawn_flash(global_position + Vector3(0, 12, 0), Color(1.0, 0.4, 0.1), 26.0)
	main.shake_amt = 1.4
	main.sfx("bigexplode", 0.0)
	main.sfx("slam", -3.0)
	visible = false


func bar_data() -> Dictionary:
	return {
		"armL": _ratio("armL"),
		"armR": _ratio("armR"),
		"core": _ratio("core"),
		"vulnerable": core_vulnerable,
		"dead": dead,
	}


func _ratio(kind: String) -> float:
	if not parts.has(kind):
		return 0.0
	var p: Dictionary = parts[kind]
	return clampf(float(p.hp) / float(p.max), 0.0, 1.0)


func part_positions() -> Array:
	var out: Array = []
	for kind in ["armL", "armR", "core"]:
		var p: Dictionary = parts[kind]
		if not p.alive:
			continue
		out.append({"kind": kind, "pos": (p.node as Node3D).global_position, "radius": p.radius})
	return out


func head_position() -> Vector3:
	return global_position + Vector3(0, HEAD_Y, 0)


# ---------------- update / attacks ----------------

func update(dt: float) -> void:
	if dead:
		return
	bob += dt
	var px: float = main.player.position.x
	var pz: float = main.player.position.z
	var target_yaw := atan2(px - global_position.x, pz - global_position.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, dt * 0.8))
	position.y = 4.0 + sin(bob * 0.9) * 2.0

	attack_t -= dt
	slam_t -= dt
	var enraged := core_vulnerable

	if spiral_left > 0.0:
		spiral_left -= dt
		spiral_tick -= dt
		if spiral_tick <= 0.0:
			spiral_tick = 0.07
			spiral_angle += 0.55
			for off in [0.0, PI]:
				var dir := Vector3(sin(spiral_angle + off), 0.0, cos(spiral_angle + off))
				main.boss_bolt(core_pos(), dir, 34.0)
	elif attack_t <= 0.0:
		attack_t = (1.5 if enraged else 2.3) + randf() * 0.7
		_pick_attack(enraged)

	if slam_t <= 0.0:
		slam_t = 8.0 if not enraged else 6.0
		_slam_ring()

	_update_rings(dt)


func core_pos() -> Vector3:
	return (parts["core"].node as Node3D).global_position


func arm_pos(side: int) -> Vector3:
	var kind := "armL" if side < 0 else "armR"
	var p: Dictionary = parts[kind]
	if not p.alive:
		return core_pos()
	return (p.node as Node3D).global_position


func _pick_attack(enraged: bool) -> void:
	var roll := randi() % 100
	if arms_alive == 2:
		if roll < 40:
			_radial(24 if enraged else 18, 30.0)
		elif roll < 75:
			_sweep(-1)
			_sweep(1)
		else:
			_aimed_burst(3, 52.0)
			if enraged:
				_start_spiral()
	elif arms_alive == 1:
		if roll < 45:
			_radial(20, 34.0)
		elif roll < 80:
			_aimed_burst(4, 56.0)
		else:
			_sweep(1 if parts["armL"].alive == false else -1)
	else:
		if roll < 35:
			_radial(30, 38.0)
		elif roll < 65:
			_aimed_burst(5, 60.0)
			_radial(12, 26.0)
		else:
			_start_spiral()


func _radial(n: int, speed: float) -> void:
	var from := core_pos()
	var tilt := randf_range(-0.12, 0.12)
	for i in n:
		var a := float(i) / n * TAU
		var dir := Vector3(sin(a), tilt * sin(a * 3.0), cos(a)).normalized()
		main.boss_bolt(from, dir, speed)


func _aimed_burst(count: int, speed: float) -> void:
	var from := head_position()
	var pp: Vector3 = main.player.position
	var pv: Vector3 = main.heading(main.player.rotation.y) * (main.throttle * 38.0)
	for i in count:
		var t := 0.35 + i * 0.22
		var predicted := pp + pv * t
		var dir := (predicted - from).normalized()
		dir += Vector3(randf_range(-0.05, 0.05), randf_range(-0.04, 0.04), randf_range(-0.05, 0.05))
		main.boss_bolt(from, dir.normalized(), speed * (1.0 - 0.04 * i))


func _sweep(side: int) -> void:
	if arms_alive == 0:
		return
	var kind := "armL" if side < 0 else "armR"
	if not parts[kind].alive:
		return
	var from := arm_pos(side)
	var to_player: Vector3 = main.player.position - from
	var base_yaw := atan2(to_player.x, to_player.z)
	for i in 7:
		var a := base_yaw + (-0.9 + 0.3 * i)
		main.boss_bolt(from, Vector3(sin(a), 0.0, cos(a)), 30.0)


func _start_spiral() -> void:
	spiral_left = 2.2
	spiral_tick = 0.0


func _slam_ring() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.78
	torus.outer_radius = 1.22
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.35, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.25, 0.08)
	mat.emission_energy_multiplier = 1.0
	var mesh := MeshInstance3D.new()
	mesh.mesh = torus
	mesh.material_override = mat
	mesh.rotation_degrees.x = 90.0
	mesh.position = core_pos()
	main.add_child(mesh)
	rings.append({"mesh": mesh, "r": 6.0, "speed": 42.0})
	main.sfx("slam", -6.0)


func _update_rings(dt: float) -> void:
	var pp: Vector3 = main.player.position
	for i in range(rings.size() - 1, -1, -1):
		var ring: Dictionary = rings[i]
		ring.r += ring.speed * dt
		var m: MeshInstance3D = ring.mesh
		m.scale = Vector3.ONE * ring.r
		if ring.r > 150.0:
			m.queue_free()
			rings.remove_at(i)
			continue
		if main.i_frames <= 0.0 and not main.smoke_mode:
			var band: float = ring.r * 0.22 + 1.5
			var dy: float = absf(pp.y - m.position.y)
			if dy < band:
				var flat := Vector2(pp.x - m.position.x, pp.z - m.position.z).length()
				if absf(flat - ring.r) < band:
					if main.GameState.damage():
						main.end_run(false)
