extends GameSystem

var _main
var cine := ""
var cine_t := 0.0
var cine_max := 1.0
var taught_perfect := false


func setup(main: Node) -> void:
	_main = main


func reset() -> void:
	taught_perfect = false
	if _main.smoke_mode:
		cine = ""
		cine_t = 0.0
		return
	cine = "intro"
	cine_max = 2.8
	cine_t = 2.8
	_main.ui.say("hatch", "All-range. Don't think. I'll throw you the stick.")


func locked() -> bool:
	return cine != ""


func sim(dt: float) -> void:
	if cine == "":
		return
	if Input.is_action_just_pressed("roll") or Input.is_action_just_pressed("boost") or Input.is_action_just_pressed("pause"):
		cine_t = 0.0
	cine_t -= dt
	if cine == "intro" or cine == "boss":
		_main.i_frames = maxf(_main.i_frames, cine_t + 0.15)
	if cine_t > 0.0:
		return
	var was := cine
	cine = ""
	if was == "intro":
		_main.ui.say("hatch", "A D bank. W juice. Space is the roll. F or flick-down hops — hold it to stay up, you bleed speed.")
		_main.ui.say("pip", "Four Nest buoys on the cardinals. Green hull. Blue motes. Gold flare.")
	elif was == "boss":
		_main.pitch_unlocked = true
		_main.throttle = 0.55
	elif was == "win":
		if _main.running:
			_main.end_run(true)


func begin_boss() -> void:
	if _main.smoke_mode:
		_main.pitch_unlocked = true
		return
	cine = "boss"
	cine_max = 2.3
	cine_t = 2.3


func begin_win() -> void:
	if _main.smoke_mode:
		_main.end_run(true)
		return
	cine = "win"
	cine_max = 2.5
	cine_t = 2.5


func on_roll() -> void:
	if taught_perfect or cine != "" or _main.smoke_mode:
		return
	var px: float = _main.player.position.x
	var pz: float = _main.player.position.z
	var close := false
	for rec in _main.enemies:
		var dx: float = rec.node.position.x - px
		var dz: float = rec.node.position.z - pz
		if dx * dx + dz * dz < 144.0:
			close = true
			break
	if not close:
		for b in _main.boss_bolts:
			var dv: Vector3 = b.mesh.position - _main.player.position
			if dv.length_squared() < 220.0:
				close = true
				break
	if close:
		taught_perfect = true
		_main.ui.say("hatch", "That's a perfect. That's the one you live on. Pocket it.")
		_main.shake_amt = maxf(_main.shake_amt, 0.25)


func apply_cam(dt: float) -> bool:
	if cine == "" or _main.cam == null or _main.player == null:
		return false
	var k := 1.0 - clampf(cine_t / maxf(cine_max, 0.001), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var cam: Camera3D = _main.cam
	var p: Vector3 = _main.player.position
	match cine:
		"intro":
			var from_ship := Vector3(-55.0, 14.0, -62.0)
			var to_ship := Vector3.ZERO
			_main.player.position = from_ship.lerp(to_ship, k)
			_main.player.rotation = Vector3(0.0, lerpf(-1.1, 0.0, k), lerpf(0.45, 0.0, k))
			p = _main.player.position
			var wide := from_ship + Vector3(8.0, 22.0, -28.0)
			var chase := to_ship + Vector3(0.0, 7.8, -4.2)
			cam.position = wide.lerp(chase, k)
			var look := p + Vector3(0.0, 0.5, 0.0)
			if (look - cam.position).length_squared() > 0.05:
				cam.look_at(look)
		"boss":
			if _main.boss == null:
				return false
			var head: Vector3 = _main.boss.head_position()
			var from := head + Vector3(32.0, 16.0, 24.0)
			var to := head + Vector3(18.0, 10.0, 16.0)
			cam.position = from.lerp(to, k)
			if (head - cam.position).length_squared() > 0.01:
				cam.look_at(head)
		"win":
			var a := p + Vector3(-8.0, 6.0, 12.0)
			var b := p + Vector3(0.0, 42.0, 8.0)
			cam.position = a.lerp(b, k)
			if (p - cam.position).length_squared() > 0.01:
				cam.look_at(p)
		_:
			return false
	cam.fov = lerpf(cam.fov, 58.0, 1.0 - exp(-6.0 * dt))
	return true
