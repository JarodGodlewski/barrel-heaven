extends CanvasLayer
class_name UiLayer
## Barrel Heaven UI — HUD, radar, throttle, level-up draft, comms (blob-cam),
## title/result overlays. Port of js/main.js DOM + js/blobcam.js + js/comms.js.

signal launch_pressed
signal relaunch_pressed
signal card_picked(index: int)
signal pause_pressed
signal quit_pressed

const ACCENT := Color(0.85, 0.55, 0.10)
const WARN := Color(0.82, 0.22, 0.10)
const DIM := Color(0.55, 0.50, 0.36)
const INK := Color(0.93, 0.88, 0.74)
const PANEL_BG := Color(0.06, 0.05, 0.03, 0.86)

var root: Control
var xp_fill: ColorRect
var super_fill: ColorRect
var kit_label: Label
var stats_label: Label
var hp_label: Label
var radar: RadarView
var throttle_view: ThrottleView
var boss_bar: BossBarView
var levelup_root: Control
var cards_box: GridContainer
var overlay_panel: PanelContainer
var overlay_title: Label
var overlay_tag: Label
var overlay_desc: Label
var overlay_btn: Button
var surge_flash: ColorRect
var pause_panel: PanelContainer
var comms_panel: Control
var blob: Control
var name_label: Label
var ch_label: Label
var line_label: Label

var _hud_acc := 0.0
var _radar_acc := 0.0
var _portrait := false
var _last_vp := Vector2.ZERO


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	layer = 10
	_build_hud()
	_build_radar()
	_build_boss_bar()
	_build_comms()
	_build_levelup()
	_build_overlay()
	_build_pause()


# ---------------- build ----------------

func _label(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _build_hud() -> void:
	var brand := _label(root, 13, INK)
	brand.text = "BARREL HEAVEN"
	brand.position = Vector2(12, 10)

	var sub := _label(root, 10, DIM)
	sub.text = "all-range · bullet heaven"
	sub.position = Vector2(12, 28)

	kit_label = _label(root, 11, DIM)
	kit_label.position = Vector2(12, 46)
	kit_label.size = Vector2(900, 16)
	kit_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	stats_label = _label(root, 13, INK)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stats_label.anchor_left = 1.0
	stats_label.offset_left = -420.0
	stats_label.offset_right = -12.0
	stats_label.offset_top = 10.0
	stats_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	hp_label = _label(root, 14, ACCENT)
	hp_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hp_label.anchor_left = 1.0
	hp_label.offset_left = -420.0
	hp_label.offset_right = -12.0
	hp_label.offset_top = 88.0
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var xp_bg := ColorRect.new()
	xp_bg.color = Color(1, 1, 1, 0.08)
	xp_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	xp_bg.anchor_right = 1.0
	xp_bg.offset_top = 0.0
	xp_bg.offset_bottom = 4.0
	xp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(xp_bg)
	xp_fill = ColorRect.new()
	xp_fill.color = ACCENT
	xp_fill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	xp_fill.offset_bottom = 4.0
	xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_bg.add_child(xp_fill)

	var super_bg := ColorRect.new()
	super_bg.color = Color(1, 1, 1, 0.06)
	super_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	super_bg.anchor_right = 1.0
	super_bg.offset_top = 5.0
	super_bg.offset_bottom = 8.0
	super_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(super_bg)
	super_fill = ColorRect.new()
	super_fill.color = Color(1.0, 0.84, 0.42)
	super_fill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	super_fill.offset_top = 5.0
	super_fill.offset_bottom = 8.0
	super_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	super_bg.add_child(super_fill)

	surge_flash = ColorRect.new()
	surge_flash.color = Color(1, 1, 1, 0)
	surge_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	surge_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surge_flash.visible = false
	root.add_child(surge_flash)


func _build_radar() -> void:
	radar = RadarView.new()
	radar.custom_minimum_size = Vector2(112, 112)
	radar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	radar.anchor_left = 1.0
	radar.anchor_top = 1.0
	radar.anchor_right = 1.0
	radar.anchor_bottom = 1.0
	radar.offset_left = -126.0
	radar.offset_top = -164.0
	radar.offset_right = -14.0
	radar.offset_bottom = -52.0
	root.add_child(radar)

	throttle_view = ThrottleView.new()
	throttle_view.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	throttle_view.anchor_left = 1.0
	throttle_view.anchor_top = 1.0
	throttle_view.anchor_right = 1.0
	throttle_view.anchor_bottom = 1.0
	throttle_view.offset_left = -140.0
	throttle_view.offset_top = -164.0
	throttle_view.offset_right = -126.0
	throttle_view.offset_bottom = -52.0
	root.add_child(throttle_view)


func _style_panel(p: PanelContainer, border := ACCENT) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.02, 0.88)
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)


func _build_boss_bar() -> void:
	boss_bar = BossBarView.new()
	boss_bar.custom_minimum_size = Vector2(420, 30)
	boss_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_bar.anchor_left = 0.5
	boss_bar.anchor_right = 0.5
	boss_bar.offset_left = -210.0
	boss_bar.offset_right = 210.0
	boss_bar.offset_top = 14.0
	boss_bar.offset_bottom = 44.0
	boss_bar.visible = false
	root.add_child(boss_bar)


func _build_comms() -> void:
	comms_panel = PanelContainer.new()
	_style_panel(comms_panel)
	comms_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	comms_panel.anchor_top = 1.0
	comms_panel.anchor_bottom = 1.0
	comms_panel.offset_left = 14.0
	comms_panel.offset_top = -176.0
	comms_panel.offset_bottom = -56.0
	comms_panel.visible = false
	comms_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(comms_panel)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	comms_panel.add_child(h)

	blob = (load("res://src/ui/blob_face.gd") as GDScript).new()
	blob.custom_minimum_size = Vector2(96, 96)
	blob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(blob)

	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(250, 0)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)

	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 8)
	v.add_child(meta)
	name_label = _label(meta, 10, ACCENT)
	ch_label = _label(meta, 10, DIM)
	line_label = _label(v, 13, INK)
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_label.custom_minimum_size = Vector2(250, 40)


func _build_levelup() -> void:
	levelup_root = ColorRect.new()
	(levelup_root as ColorRect).color = Color(0.008, 0.024, 0.047, 0.6)
	levelup_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	levelup_root.visible = false
	levelup_root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(levelup_root)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	levelup_root.add_child(center)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)

	var tag := _label(v, 10, DIM)
	tag.text = "ACCESS GRANTED"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var h2 := _label(v, 18, INK)
	h2.text = "Inject a hardpoint"
	h2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	cards_box = GridContainer.new()
	cards_box.columns = 3
	cards_box.add_theme_constant_override("h_separation", 12)
	cards_box.add_theme_constant_override("v_separation", 10)
	cards_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(cards_box)

	var fine := _label(v, 10, DIM)
	fine.text = "1 / 2 / 3 to choose · tap a card"
	fine.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _card_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(250, 130)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_constant_override("line_spacing", 6)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.024, 0.055, 0.078, 0.94)
	sb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.border_color = ACCENT
	sbh.bg_color = Color(0.03, 0.08, 0.11, 0.96)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _build_overlay() -> void:
	overlay_panel = PanelContainer.new()
	overlay_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := Color(0.008, 0.02, 0.04, 0.88)
	var bg := StyleBoxFlat.new()
	bg.bg_color = dim
	bg.set_content_margin_all(28)
	bg.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.3)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(16)
	overlay_panel.add_theme_stylebox_override("panel", bg)
	root.add_child(overlay_panel)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_panel.add_child(center)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)

	overlay_title = _label(v, 24, INK)
	overlay_title.text = "BARREL HEAVEN"
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	overlay_tag = _label(v, 12, DIM)
	overlay_tag.text = "Hold the Well. Ten minutes."
	overlay_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	overlay_desc = _label(v, 14, Color(0.77, 0.85, 0.90))
	overlay_desc.text = "Mercy is spooling. Hatch and Pip on the horn.\nGuns fire themselves — you steer and barrel-roll."
	overlay_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	overlay_btn = Button.new()
	overlay_btn.text = "LAUNCH"
	overlay_btn.custom_minimum_size = Vector2(200, 48)
	overlay_btn.add_theme_font_size_override("font_size", 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ACCENT
	sb.set_corner_radius_all(999)
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	overlay_btn.add_theme_stylebox_override("normal", sb)
	var sbp := sb.duplicate()
	sbp.bg_color = sb.bg_color.darkened(0.15)
	overlay_btn.add_theme_stylebox_override("hover", sb.duplicate())
	overlay_btn.add_theme_stylebox_override("pressed", sbp)
	overlay_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var bc := CenterContainer.new()
	v.add_child(bc)
	bc.add_child(overlay_btn)
	overlay_btn.pressed.connect(func() -> void:
		if overlay_btn.text == "LAUNCH":
			launch_pressed.emit()
		else:
			relaunch_pressed.emit()
	)


func _build_pause() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := Color(0.008, 0.02, 0.04, 0.85)
	var bg := StyleBoxFlat.new()
	bg.bg_color = dim
	bg.set_content_margin_all(28)
	bg.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.3)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(16)
	pause_panel.add_theme_stylebox_override("panel", bg)
	root.add_child(pause_panel)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(center)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)

	var title := _label(v, 24, INK)
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var resume_btn := Button.new()
	resume_btn.text = "RESUME"
	resume_btn.custom_minimum_size = Vector2(200, 48)
	resume_btn.add_theme_font_size_override("font_size", 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ACCENT
	sb.set_corner_radius_all(999)
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	resume_btn.add_theme_stylebox_override("normal", sb)
	var sbp := sb.duplicate()
	sbp.bg_color = sb.bg_color.darkened(0.15)
	resume_btn.add_theme_stylebox_override("hover", sb.duplicate())
	resume_btn.add_theme_stylebox_override("pressed", sbp)
	resume_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var bc := CenterContainer.new()
	v.add_child(bc)
	bc.add_child(resume_btn)
	resume_btn.pressed.connect(func() -> void:
		pause_pressed.emit()
	)

	var quit_btn := Button.new()
	quit_btn.text = "QUIT TO TITLE"
	quit_btn.custom_minimum_size = Vector2(200, 48)
	quit_btn.add_theme_font_size_override("font_size", 16)
	var sb2 := StyleBoxFlat.new()
	sb2.bg_color = Color(0.6, 0.2, 0.2)
	sb2.set_corner_radius_all(999)
	sb2.content_margin_top = 12
	sb2.content_margin_bottom = 12
	quit_btn.add_theme_stylebox_override("normal", sb2)
	var sb2p := sb2.duplicate()
	sb2p.bg_color = sb2.bg_color.darkened(0.15)
	quit_btn.add_theme_stylebox_override("hover", sb2.duplicate())
	quit_btn.add_theme_stylebox_override("pressed", sb2p)
	quit_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var bc2 := CenterContainer.new()
	v.add_child(bc2)
	bc2.add_child(quit_btn)
	quit_btn.pressed.connect(func() -> void:
		quit_pressed.emit()
	)

	pause_panel.visible = false


func show_pause() -> void:
	pause_panel.visible = true

func hide_pause() -> void:
	pause_panel.visible = false


# ---------------- state api ----------------

func show_title() -> void:
	overlay_panel.visible = true
	overlay_title.text = "BARREL HEAVEN"
	overlay_tag.text = "Hold the Well. Ten minutes."
	overlay_desc.text = "Mercy is spooling. Hatch and Pip on the horn.\nGuns fire themselves — you steer and barrel-roll."
	overlay_btn.text = "LAUNCH"


func show_result(won: bool, level: int, kills: int, time_s: int) -> void:
	overlay_panel.visible = true
	overlay_title.text = "MERCY IS AWAY" if won else "HULL LOST"
	overlay_tag.text = "Lv %d · %d kills · %d:%02d" % [level, kills, time_s / 60, time_s % 60]
	overlay_desc.text = "Mercy jumped. Don't ask where." if won else "The curtain doesn't stop. Launch anyway."
	overlay_btn.text = "RELAUNCH"


func hide_overlay() -> void:
	overlay_panel.visible = false


func open_offers(offers: Array) -> void:
	for c in cards_box.get_children():
		c.queue_free()
	for i in offers.size():
		var o: Dictionary = offers[i]
		var btn := _card_button("%d. %s\n\n%s" % [i + 1, o.label, o.detail])
		btn.pressed.connect(card_picked.emit.bind(i))
		cards_box.add_child(btn)
	levelup_root.visible = true
	surge()
	call_deferred("_punch_cards")


func close_offers() -> void:
	levelup_root.visible = false


func surge() -> void:
	if surge_flash == null:
		return
	surge_flash.visible = true
	surge_flash.color = Color(0.55, 0.28, 0.04, 0.32)
	var tw := create_tween()
	tw.tween_property(surge_flash, "color:a", 0.0, 0.22)
	tw.tween_callback(func() -> void:
		surge_flash.visible = false)
	var h := root.size.y
	if h < 8.0:
		h = 720.0
	for i in 5:
		var bar := ColorRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.color = Color(0.92, 0.62, 0.12, 0.9) if i % 2 == 0 else Color(0.55, 0.42, 0.12, 0.75)
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
		var y := randf() * h
		bar.offset_top = y
		bar.offset_bottom = y + (2.0 if i % 2 == 0 else 5.0)
		root.add_child(bar)
		var bt := bar.create_tween()
		bt.tween_property(bar, "offset_top", y + 90.0, 0.16)
		bt.parallel().tween_property(bar, "color:a", 0.0, 0.16)
		bt.tween_callback(bar.queue_free)


func _punch_cards() -> void:
	for c in cards_box.get_children():
		if not (c is Control):
			continue
		var ctrl := c as Control
		ctrl.pivot_offset = ctrl.size * 0.5
		ctrl.scale = Vector2(0.72, 0.72)
		var tw := ctrl.create_tween()
		tw.tween_property(ctrl, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------- per-frame ----------------

static func bars(n: int, mx: int) -> String:
	return "█".repeat(maxi(n, 0)) + "░".repeat(maxi(mx - n, 0))


static func fmt_time(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


# ---------------- responsive layout (portrait-first mobile) ----------------

func _check_layout() -> void:
	var vp := root.size
	if vp == _last_vp or vp == Vector2.ZERO:
		return
	_last_vp = vp
	var portrait := vp.x < vp.y * 1.05 or vp.x < 720.0
	if portrait != _portrait:
		_portrait = portrait
	_apply_layout()
	_apply_safe_area(vp)


func _apply_layout() -> void:
	var p := _portrait
	# stats block: top-right in landscape, under brand in portrait
	if p:
		stats_label.anchor_left = 0.0
		stats_label.offset_left = 14.0
		stats_label.offset_right = 300.0
		stats_label.offset_top = 66.0
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hp_label.anchor_left = 0.0
		hp_label.offset_left = 14.0
		hp_label.offset_right = 300.0
		hp_label.offset_top = 150.0
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		kit_label.size.x = root.size.x - 24.0
	else:
		stats_label.anchor_left = 1.0
		stats_label.offset_left = -420.0
		stats_label.offset_right = -12.0
		stats_label.offset_top = 10.0
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hp_label.anchor_left = 1.0
		hp_label.offset_left = -420.0
		hp_label.offset_right = -12.0
		hp_label.offset_top = 88.0
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		kit_label.size.x = 900.0

	# radar + throttle: smaller, tucked bottom-right in portrait
	if p:
		radar.offset_left = -104.0
		radar.offset_top = -142.0
		radar.offset_right = -16.0
		radar.offset_bottom = -54.0
		throttle_view.offset_left = -116.0
		throttle_view.offset_top = -142.0
		throttle_view.offset_right = -106.0
		throttle_view.offset_bottom = -54.0
	else:
		radar.offset_left = -126.0
		radar.offset_top = -164.0
		radar.offset_right = -14.0
		radar.offset_bottom = -52.0
		throttle_view.offset_left = -140.0
		throttle_view.offset_top = -164.0
		throttle_view.offset_right = -126.0
		throttle_view.offset_bottom = -52.0

	# comms: full-width strip above radar zone in portrait
	if p:
		comms_panel.offset_left = 12.0
		comms_panel.offset_right = -12.0
		comms_panel.offset_top = -206.0
		comms_panel.offset_bottom = -96.0
		blob.custom_minimum_size = Vector2(64, 64)
		line_label.custom_minimum_size = Vector2(0, 40)
	else:
		comms_panel.offset_left = 14.0
		comms_panel.offset_right = 0.0
		comms_panel.offset_top = -176.0
		comms_panel.offset_bottom = -56.0
		blob.custom_minimum_size = Vector2(96, 96)

	# level-up cards stack single-column in portrait
	cards_box.columns = 1 if p else 3

	# boss bar narrows to fit
	boss_bar.offset_left = -160.0 if p else -210.0
	boss_bar.offset_right = 160.0 if p else 210.0


func _apply_safe_area(_vp: Vector2) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	if window == null or window.size.y <= 0:
		return
	var win_rect := Rect2(Vector2(), Vector2(window.size))
	var safe := DisplayServer.get_display_safe_area()
	var inner := safe.intersection(win_rect)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return
	var sx := _vp.x / win_rect.size.x
	var sy := _vp.y / win_rect.size.y
	root.offset_left = inner.position.x * sx
	root.offset_top = inner.position.y * sy
	root.offset_right = -(win_rect.size.x - inner.end.x) * sx
	root.offset_bottom = -(win_rect.size.y - inner.end.y) * sy


func poll(dt: float, main: Node) -> void:
	_check_layout()
	var run: Dictionary = main.GameState_run()
	if not run.is_empty():
		_hud_acc += dt
		if _hud_acc > 0.1:
			_hud_acc = 0.0
			stats_label.text = "KILLS %d\nWAVE %d\nTIME %s\nLV %d" % [
				run.kills, 1 + int(run.elapsed / 18.0), fmt_time(run.elapsed), run.level]
			var hp_col := WARN if run.hp <= 2 else ACCENT
			hp_label.text = "HULL %s" % bars(run.hp, run.max_hp)
			hp_label.add_theme_color_override("font_color", hp_col)
			var frac: float = clampf(float(run.xp) / maxf(run.xp_need, 1.0), 0.0, 1.0)
			xp_fill.size.x = root.size.x * frac
			var s_frac: float = clampf(float(run.get("super_meter", 0.0)) / 100.0, 0.0, 1.0)
			super_fill.size.x = root.size.x * s_frac
			if s_frac >= 1.0:
				var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 90.0)
				super_fill.color.a = pulse
			else:
				super_fill.color.a = 1.0
			var bits: Array = []
			for w in main.loadout.weapons:
				bits.append(main.LoadoutLib.weapon_label(w))
			for p in main.loadout.passives:
				var def: Dictionary = main.LoadoutLib.PASSIVES[p.id]
				if not def.is_empty():
					bits.append("%s %d" % [def.name, p.level])
			kit_label.text = "  ·  ".join(bits)
			throttle_view.set_vals(main.throttle, main.boost_t > 0.0)
		if main.boss != null and not main.boss.dead:
			boss_bar.visible = true
			boss_bar.snapshot(main.boss.bar_data())
			boss_bar.queue_redraw()
		else:
			boss_bar.visible = false
		_radar_acc += dt
		if _radar_acc > 0.05:
			_radar_acc = 0.0
			radar.snapshot(main.player.rotation.y, main.player.position, main.enemies, main.caches)
			radar.queue_redraw()
	comms_tick(dt)


# ---------------- comms ----------------

const CAST := {
	"hatch": {"name": "HATCH", "ch": "WING-2"},
	"pip": {"name": "PIP", "ch": "NEST-1"},
	"kite": {"name": "KITE", "ch": "UNKNOWN"},
}

var _queue: Array = []
var _heard := {}
var _showing := false
var _hide_at := 0.0
var _closing := false


func say(who: String, text: String, hold := 4.1, mood := "") -> void:
	_queue.append({"who": who, "text": text, "hold": hold, "mood": mood})


func say_once(id: String, who: String, text: String, hold := 4.1, mood := "") -> void:
	if _heard.has(id):
		return
	_heard[id] = true
	say(who, text, hold, mood)


func comms_reset() -> void:
	_queue.clear()
	_heard.clear()
	_showing = false
	_closing = false
	comms_panel.visible = false


func start_mission() -> void:
	comms_reset()
	say("hatch", "They'll crawl up your six, kid. Roll when the tracers get close.")
	say("pip", "Four Nest buoys on the cardinals. Green patches hull. Blue scoops motes. Gold is a flare.")


func comms_triggers(ev: Dictionary) -> void:
	var el: float = ev.get("elapsed", 0.0)
	var hp: int = ev.get("hp", 5)
	if el > 22.0 and not ev.get("ever_rolled", false):
		say_once("hatch-nudge", "hatch", "That's a barrel roll. R or Space. Flick the stick. Do it before they stitch you.")
	if ev.get("just_rolled", false):
		say_once("hatch-roll", "hatch", "That's it! Keep that roll in your pocket.")
	if ev.get("just_hit", false):
		say_once("pip-hit", "pip", "Hull ping! I can patch from here — don't make a habit.", 4.1, "worry")
	if el > 38.0:
		say_once("pip-guns", "pip", "G-diffuser's singing. Guns running hot. That's the good kind of hot.")
	if el > 78.0:
		say_once("kite", "kite", "Pretty lights, Rook. The Banner sends its regards.")
	if el > 200.0:
		say_once("pip-spool", "pip", "Spool's halfway. Keep the mouth open.")
	if hp <= 2 and hp > 0:
		say_once("hatch-leak", "hatch", "You're leaking, kid. Fly smart.", 4.1, "worry")
	if ev.get("dead", false):
		_queue.clear()
		say("hatch", "Rook— hey. Hey!", 2.4, "shout")
		say("pip", "Hull's gone. Come home.", 3.2)


func _present(next: Dictionary) -> void:
	var speaker: Dictionary = CAST.get(next.who, CAST.hatch)
	name_label.text = speaker.name
	ch_label.text = speaker.ch
	line_label.text = next.text
	blob.set_speaker(next.who, true, next.mood if next.mood != "" else "talk")
	comms_panel.visible = true
	_showing = true
	_closing = false
	_hide_at = Time.get_ticks_msec() / 1000.0 + next.hold
	AudioManager.speak(next.text)


func comms_tick(dt: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _showing and not _closing and now >= _hide_at:
		blob.sleep()
		_closing = true
		_hide_at = now + 0.3
	elif _showing and _closing and now >= _hide_at:
		_showing = false
		_closing = false
		comms_panel.visible = false
	elif not _showing and _queue.size() > 0:
		_present(_queue.pop_front())
	blob.tick(dt)
	blob.queue_redraw()


# ================= inner views =================

class ThrottleView extends Control:
	var _thr := 0.0
	var _boost := false

	func set_vals(thr: float, boost: bool) -> void:
		_thr = thr
		_boost = boost
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.03, 0.06, 0.09, 0.55))
		draw_rect(Rect2(Vector2(0, 0), Vector2(1, 1)), Color(0.85, 0.55, 0.10, 0.28), false, 1.0)
		var fill_col := Color(1.0, 0.45, 0.08) if _boost else Color(0.85, 0.55, 0.10)
		var h := size.y * (1.0 if _boost else _thr)
		draw_rect(Rect2(Vector2(1, size.y - h), Vector2(size.x - 2.0, h)), fill_col)


class RadarView extends Control:
	const RANGE := 160.0
	var _yaw := 0.0
	var _ppos := Vector3.ZERO
	var _enemies: Array = []
	var _caches: Array = []

	func snapshot(yaw: float, ppos: Vector3, enemies: Array, caches: Array) -> void:
		_yaw = yaw
		_ppos = ppos
		_enemies = enemies
		_caches = caches

	func _to_radar(wx: float, wz: float) -> Vector2:
		var dx := wx - _ppos.x
		var dz := wz - _ppos.z
		var s := sin(_yaw)
		var c := cos(_yaw)
		return Vector2((dx * c - dz * s), -(dx * s + dz * c))

	func _draw() -> void:
		var center := size / 2.0
		draw_circle(center, center.x - 2.0, Color(0.03, 0.07, 0.09, 0.5))
		draw_arc(center, center.x - 2.0, 0, TAU, 32, Color(0.85, 0.55, 0.10, 0.4), 1.0)
		var scale := (center.x - 6.0) / RANGE
		var tri := PackedVector2Array([Vector2(0, -7), Vector2(4.5, 6), Vector2(-4.5, 6)])
		var t2 := PackedVector2Array()
		for v in tri:
			t2.append(center + v)
		draw_colored_polygon(t2, Color(0.85, 0.55, 0.10))
		for rec in _enemies:
			var pos := _to_radar(rec.node.position.x, rec.node.position.z) * scale
			if pos.length_squared() > (center.x - 4.0) * (center.x - 4.0):
				continue
			var elite: bool = rec.get("elite", false)
			draw_rect(Rect2(center + pos - Vector2.ONE * (2.5 if elite else 1.5), Vector2.ONE * (5.0 if elite else 3.0)),
				Color(0.94, 0.76, 0.29) if elite else Color(1.0, 0.42, 0.29))
		var cols := {"patch": Color(0.49, 1.0, 0.69), "vac": Color(0.53, 0.83, 1.0), "flare": Color(1.0, 0.88, 0.54)}
		for c in _caches:
			if c.taken:
				continue
			var cp := _to_radar(c.mesh.position.x, c.mesh.position.z) * scale
			if cp.length_squared() > (center.x - 4.0) * (center.x - 4.0):
				continue
			draw_rect(Rect2(center + cp - Vector2(2, 2), Vector2(4, 4)), cols[c.kind])


class BossBarView extends Control:
	const GOLD := Color(0.94, 0.76, 0.29)
	const RED := Color(1.0, 0.3, 0.2)
	const GREEN := Color(0.3, 1.0, 0.6)
	var _data := {}

	func snapshot(d: Dictionary) -> void:
		_data = d

	func _draw() -> void:
		if _data.is_empty():
			return
		var w := size.x
		var seg := (w - 16.0) / 3.0
		draw_rect(Rect2(0, 14, w, 12), Color(1, 1, 1, 0.08))
		# segments: armL | core | armR
		var core_col := GREEN if bool(_data.get("vulnerable", false)) else Color(0.45, 0.45, 0.5)
		_seg(Rect2(0, 14, seg * float(_data.get("armL", 0.0)), 12), GOLD)
		_seg(Rect2(seg + 8.0, 14, seg * float(_data.get("core", 0.0)), 12), core_col)
		_seg(Rect2((seg + 8.0) * 2.0, 14, seg * float(_data.get("armR", 0.0)), 12), GOLD)
		draw_string(ThemeDB.fallback_font, Vector2(w / 2.0 - 52, 10), "THE GUARDIAN",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.478, 0.627, 0.722))

	func _seg(r: Rect2, col: Color) -> void:
		if r.size.x > 0.5:
			draw_rect(r, col)
