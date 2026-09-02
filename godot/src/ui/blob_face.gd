extends Control

const SAMPLES := 56
const EYE_TILT := 0.46
const LIGHT := Vector3(-0.42, -0.72, 0.55)
const PILOTS := {
	"hatch": {
		"fill": Color(0.42, 0.32, 0.18),
		"mid": Color(0.28, 0.20, 0.11),
		"shade": Color(0.12, 0.09, 0.06),
		"eye": 0.78,
	},
	"pip": {
		"fill": Color(0.28, 0.42, 0.18),
		"mid": Color(0.16, 0.26, 0.10),
		"shade": Color(0.07, 0.12, 0.05),
		"eye": 1.15,
	},
	"kite": {
		"fill": Color(0.62, 0.22, 0.14),
		"mid": Color(0.38, 0.10, 0.08),
		"shade": Color(0.16, 0.04, 0.04),
		"eye": 0.92,
	},
}

var who := "hatch"
var mood := "idle"
var talking := false
var clock := 0.0
var blink := 2.1
var morph := 1.0
var r_from: PackedFloat32Array
var r_to: PackedFloat32Array
var gaze := Vector2.ZERO


func _ready() -> void:
	r_from = _profile("hatch", "idle")
	r_to = r_from
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_speaker(id: String, is_talking: bool, mood_name := "talk") -> void:
	if not PILOTS.has(id):
		id = "hatch"
	who = id
	talking = is_talking
	mood = mood_name if mood_name != "" else ("talk" if is_talking else "idle")
	r_from = _radii_now()
	r_to = _profile(who, mood)
	morph = 0.0


func sleep() -> void:
	set_speaker(who, false, "rest")
	talking = false


func tick(dt: float) -> void:
	clock += dt
	morph = minf(1.0, morph + dt * 3.4)
	gaze.x = 0.55 * sin(clock * 0.65) + 0.28 * sin(clock * 1.35 + 1.1)
	gaze.y = 0.32 * sin(clock * 0.5 + 0.7)
	blink -= dt
	if blink < 0.0:
		blink = 1.8 + randf() * 2.5


func _radii_now() -> PackedFloat32Array:
	var e := 1.0 - pow(1.0 - morph, 5.0)
	var out := PackedFloat32Array()
	out.resize(SAMPLES)
	if r_from.is_empty() or r_to.is_empty():
		return _profile(who, mood)
	for i in SAMPLES:
		out[i] = lerpf(r_from[i], r_to[i], e)
	return out


func _shape(id: String, a: float) -> float:
	var r := 1.0
	match id:
		"hatch":
			r = 1.0 + 0.24 * absf(sin(a))
			r += 0.11 * exp(-pow((a - 0.62) / 0.22, 2.0))
			r += 0.11 * exp(-pow((a + 0.62) / 0.22, 2.0))
		"pip":
			r = 1.08 + 0.32 * (0.5 - 0.5 * cos(a))
			r += 0.10 * exp(-pow((a - 2.35) / 0.40, 2.0))
			r += 0.10 * exp(-pow((a + 2.35) / 0.40, 2.0))
			r *= 0.92 + 0.08 * absf(sin(a))
		"kite":
			r = 1.0 - 0.20 * maxf(0.0, cos(a))
			r *= 1.0 + 0.10 * absf(sin(a))
			r += 0.06 * maxf(0.0, -cos(a))
		_:
			r = 1.0
	return r


func _profile(id: String, mood_name: String) -> PackedFloat32Array:
	var squash := 1.0
	var stretch := 1.0
	var amp := 0.0
	match mood_name:
		"talk":
			stretch = 1.04
			squash = 0.97
			amp = 0.03
		"shout":
			stretch = 1.10
			squash = 0.90
			amp = 0.06
		"worry":
			stretch = 1.08
			squash = 0.90
		"rest":
			squash = 0.86
			stretch = 1.04
		"smug", "glare":
			amp = 0.025
	var out := PackedFloat32Array()
	out.resize(SAMPLES)
	for i in SAMPLES:
		var a := float(i) / SAMPLES * TAU
		var r := _shape(id, a) * (1.0 + amp * cos(3.0 * a))
		r *= lerpf(squash, stretch, 0.5 + 0.5 * sin(a))
		out[i] = r
	return out


func _band(ndot: float, p: Dictionary) -> Color:
	var fill: Color = p.fill
	var mid: Color = p.mid
	var shade: Color = p.shade
	if ndot > 0.58:
		return fill
	if ndot > 0.28:
		return mid
	return shade


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var rad := s * 0.46
	var rr := _radii_now()
	var p: Dictionary = PILOTS.get(who, PILOTS["hatch"])
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.resize(SAMPLES)
	cols.resize(SAMPLES)
	var L := LIGHT.normalized()
	for i in SAMPLES:
		var a := float(i) / SAMPLES * TAU
		var th := a - PI * 0.5
		var n := Vector3(cos(th), sin(th), 0.42).normalized()
		var nd := clampf(n.dot(L), 0.0, 1.0)
		var col := _band(nd, p)
		var rim := pow(1.0 - clampf(n.z, 0.0, 1.0), 2.4)
		col = col.lerp(Color(1.0, 0.72, 0.28), rim * 0.22)
		pts[i] = c + Vector2(cos(th), sin(th)) * (rr[i] * rad)
		cols[i] = col
	draw_polygon(pts, cols)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, Color(0.08, 0.05, 0.02, 0.85), 2.2, true)
	var spec := c + Vector2(-rad * 0.22, -rad * 0.28)
	draw_circle(spec, rad * 0.13, Color(1.0, 0.92, 0.70, 0.22))
	draw_circle(spec + Vector2(-rad * 0.04, -rad * 0.03), rad * 0.05, Color(1.0, 0.95, 0.82, 0.35))
	var lid := 1.0 if blink >= 0.09 else 0.13
	var es: float = 0.10 * s * float(p.eye)
	if who == "pip":
		es *= 1.08
	var gx := gaze.x * s * 0.045
	var gy := gaze.y * s * 0.035
	var eye_y := -es * (0.18 if who == "pip" else 0.38)
	if who == "hatch":
		eye_y = -es * 0.22
	_eye(c + Vector2(-es * 1.22 + gx, eye_y + gy), es * 0.62, es * 1.22 * lid, EYE_TILT, p)
	_eye(c + Vector2(es * 1.22 + gx, eye_y + gy), es * 0.62, es * 1.22 * lid, EYE_TILT, p)
	var talk_w := 0.0
	if talking or mood == "talk" or mood == "shout":
		talk_w = 0.5 + 0.5 * maxf(0.0, sin(clock * 13.0))
		if mood == "shout":
			talk_w = 0.82 + 0.18 * talk_w
	if talk_w > 0.08:
		var mw := es * (1.05 + talk_w)
		var mh := es * (0.22 + 0.5 * talk_w)
		var mp := c + Vector2(gx * 0.25, es * (1.15 if who != "pip" else 1.35) + gy * 0.15)
		draw_set_transform(mp, 0.0, Vector2(mw * 0.5, mh * 0.5))
		draw_circle(Vector2.ZERO, 1.0, Color(0.96, 0.93, 0.84))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _eye(pos: Vector2, w: float, h: float, tilt: float, p: Dictionary) -> void:
	var shade: Color = p.shade
	draw_set_transform(pos, tilt, Vector2(maxf(w, 0.5) * 0.58, maxf(h, 0.5) * 0.58))
	draw_circle(Vector2.ZERO, 1.0, shade.darkened(0.15))
	draw_set_transform(pos, tilt, Vector2(maxf(w, 0.4) * 0.5, maxf(h, 0.4) * 0.5))
	draw_circle(Vector2.ZERO, 1.0, Color(0.97, 0.94, 0.86))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
