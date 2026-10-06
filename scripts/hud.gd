extends CanvasLayer
## HUD ของด่าน: ทรัพยากร, ร้านยูนิต, ข้อมูลยูนิตที่เลือก, ประกาศ Phase, หน้าชนะ/แพ้

@export var level_path: NodePath = ^".."
var level: TDLevel

var _gold_label: Label
var _lives_label: Label
var _phase_label: Label
var _start_btn: Button
var _speed_btn: Button
var _pause_btn: Button
var _music_btn: Button
var _shop_buttons: Array[Button] = []
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _banner_tween: Tween
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _sel_panel: PanelContainer
var _sel_title: Label
var _sel_stats: Label
var _upg_btn: Button
var _sell_btn: Button
var _end_overlay: Control
var _pause_overlay: Control

const GOLD := Color(1.0, 0.84, 0.3)
const PANEL_BG := Color(0.08, 0.07, 0.06, 0.82)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level = get_node(level_path) as TDLevel
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top(root)
	_build_banner(root)
	_build_shop(root)
	_build_selection(root)
	_build_help(root)
	level.gold_changed.connect(_on_gold)
	level.lives_changed.connect(_on_lives)
	level.phase_changed.connect(_on_phase)
	level.announce.connect(show_banner)
	level.selection_changed.connect(_on_selection)
	level.boss_hp_changed.connect(_on_boss)
	level.game_finished.connect(_on_finished)
	level.placement_changed.connect(_on_placement)
	level.music_toggled.connect(_update_music_btn)

# ------------------------------------------------------------ builders
func _panel(color: Color = PANEL_BG, radius: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.border_color = Color(0.75, 0.6, 0.3, 0.8)
	sb.set_border_width_all(2)
	return sb

func _label(text: String, size: int = 20, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	return l

func _button(text: String, cb: Callable, size: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(cb)
	return b

func _build_top(root: Control) -> void:
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", _panel())
	left.position = Vector2(12, 10)
	root.add_child(left)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 28)
	left.add_child(hb)
	_gold_label = _label("ทอง 0", 24, GOLD)
	_lives_label = _label("กำแพงเมือง 20/20", 24, Color(1, 0.55, 0.5))
	_phase_label = _label("Phase 1/6", 24, Color(0.75, 0.85, 1))
	hb.add_child(_gold_label)
	hb.add_child(_lives_label)
	hb.add_child(_phase_label)

	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-590, 12)
	right.size = Vector2(578, 44)
	right.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(right)
	_start_btn = _button("เริ่ม Phase  [Space]", func(): level.start_phase(), 20)
	_start_btn.custom_minimum_size = Vector2(210, 44)
	_speed_btn = _button("ความเร็ว x1", _on_speed, 18)
	_speed_btn.custom_minimum_size = Vector2(120, 44)
	_pause_btn = _button("หยุด", _on_pause, 18)
	_pause_btn.custom_minimum_size = Vector2(90, 44)
	right.add_child(_start_btn)
	right.add_child(_speed_btn)
	right.add_child(_pause_btn)
	_music_btn = _button("", _on_music, 18)
	_music_btn.custom_minimum_size = Vector2(110, 44)
	_update_music_btn(Music.muted)
	right.add_child(_music_btn)

func _build_banner(root: Control) -> void:
	_banner = VBoxContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-450, 90)
	_banner.size = Vector2(900, 120)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_banner)
	_banner_title = _label("", 46, Color(1, 0.9, 0.6))
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.add_theme_constant_override("outline_size", 12)
	_banner_sub = _label("", 22)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	_banner.add_child(_banner_sub)
	_banner.modulate.a = 0.0

	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_box.position = Vector2(-260, 64)
	_boss_box.size = Vector2(520, 40)
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_boss_box)
	var bl := _label("BOSS — Bomber แห่งประตูมิติ", 18, Color(1, 0.5, 0.45))
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(bl)
	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(520, 18)
	_boss_bar.show_percentage = false
	_boss_bar.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.15, 0.12)
	fill.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(4)
	_boss_bar.add_theme_stylebox_override("fill", fill)
	_boss_bar.add_theme_stylebox_override("background", bg)
	_boss_box.add_child(_boss_bar)
	_boss_box.visible = false

func _build_shop(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel())
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	root.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	panel.add_child(hb)
	for i in level.defenders.size():
		var d: DefenderData = level.defenders[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(112, 112)
		b.tooltip_text = "%s (%s)\n%s\n\nดาเมจ %d | ระยะ %.1f | ยิงทุก %.1f วิ\nโจมตี: %s%s%s" % [
			d.thai_name, d.display_name, d.description, d.damage, d.attack_range, d.fire_interval,
			d.targets_text(),
			("\nดาเมจกระจาย รัศมี %.1f" % d.splash_radius) if d.splash_radius > 0 else "",
			"\nเจาะเกราะ" if d.armor_pierce else ""]
		b.pressed.connect(func(): level.begin_placement(d))
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 0)
		b.add_child(vb)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(64, 60)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if d.icon:
			icon.texture = d.icon
		else:
			var g := GradientTexture2D.new()
			g.width = 48
			g.height = 48
			var gr := Gradient.new()
			gr.colors = PackedColorArray([d.color, d.color.darkened(0.5)])
			g.gradient = gr
			icon.texture = g
		vb.add_child(icon)
		var n := _label(d.thai_name, 16)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(n)
		var c := _label("%d ทอง" % d.cost, 15, GOLD)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(c)
		var key := _label(str(i + 1), 14, Color(1, 1, 1, 0.6))
		key.position = Vector2(6, 2)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(key)
		hb.add_child(b)
		_shop_buttons.append(b)
	# จัดให้อยู่กลางล่าง
	await get_tree().process_frame
	panel.position = Vector2((root.size.x - panel.size.x) / 2.0, root.size.y - panel.size.y - 8)

func _build_selection(root: Control) -> void:
	_sel_panel = PanelContainer.new()
	_sel_panel.add_theme_stylebox_override("panel", _panel())
	_sel_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_sel_panel.position = Vector2(-262, -140)
	_sel_panel.custom_minimum_size = Vector2(250, 0)
	root.add_child(_sel_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_sel_panel.add_child(vb)
	_sel_title = _label("", 24, Color(1, 0.9, 0.6))
	_sel_stats = _label("", 16)
	_upg_btn = _button("อัปเกรด", func(): level.upgrade_selected(), 18)
	_sell_btn = _button("ขาย", func(): level.sell_selected(), 18)
	_upg_btn.custom_minimum_size = Vector2(0, 40)
	_sell_btn.custom_minimum_size = Vector2(0, 36)
	vb.add_child(_sel_title)
	vb.add_child(_sel_stats)
	vb.add_child(_upg_btn)
	vb.add_child(_sell_btn)
	_sel_panel.visible = false

func _build_help(root: Control) -> void:
	var l := _label("คลิกซ้าย: วาง/เลือกยูนิต   คลิกขวา/Esc: ยกเลิก   Shift: วางต่อเนื่อง   WASD: เลื่อนกล้อง   ล้อเมาส์: ซูม   Q/E: หมุน   U: อัปเกรด   X: ขาย   M: เปิด/ปิดเพลง", 13, Color(1, 1, 1, 0.75))
	l.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	l.position = Vector2(12, -150)
	l.size = Vector2(300, 140)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)

# ------------------------------------------------------------ handlers
func _on_gold(v: int) -> void:
	_gold_label.text = "ทอง %d" % v
	for i in _shop_buttons.size():
		var b := _shop_buttons[i]
		var afford := v >= level.defenders[i].cost
		b.modulate = Color.WHITE if afford else Color(0.55, 0.5, 0.5)
	if level._selected:
		_on_selection(level._selected)

func _on_lives(v: int, m: int) -> void:
	_lives_label.text = "กำแพงเมือง %d/%d" % [v, m]
	if v < m:
		var tw := create_tween()
		_lives_label.modulate = Color(1, 0.2, 0.2)
		tw.tween_property(_lives_label, "modulate", Color.WHITE, 0.4)

func _on_phase(index: int, total: int, running: bool) -> void:
	var shown: int = min(index + 1, total)
	var boss: bool = index < total and WavesLevel01.PHASES[index].get("boss", false)
	_phase_label.text = ("BOSS PHASE (%d/%d)" if boss else "Phase %d/%d") % [shown, total]
	_start_btn.disabled = running
	if running:
		_start_btn.text = "กำลังรบ..."
	else:
		_start_btn.text = ("เริ่ม BOSS PHASE" if boss else "เริ่ม Phase %d" % shown) + "  [Space]"

func show_banner(title: String, sub: String, color: Color) -> void:
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", color)
	_banner_sub.text = sub
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner.modulate.a = 0.0
	_banner.scale = Vector2.ONE
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(2.6)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)

func _on_selection(u: TDDefender) -> void:
	_sel_panel.visible = u != null
	if u == null:
		return
	var d := u.data
	_sel_title.text = "%s  Lv.%d" % [d.thai_name, u.level]
	_sel_stats.text = "%s\nดาเมจ: %d\nระยะ: %.1f ช่อง\nยิงทุก: %.2f วินาที\nเป้าหมาย: %s%s%s" % [
		d.display_name, d.damage_at(u.level), d.range_at(u.level), d.interval_at(u.level), d.targets_text(),
		("\nกระจาย: %.1f" % d.splash_radius) if d.splash_radius > 0 else "",
		"\nทำให้ช้าลง %d%%" % int((1.0 - d.slow_factor) * 100) if d.slow_duration > 0 else ""]
	if u.can_upgrade():
		var c := u.next_upgrade_cost()
		_upg_btn.text = "อัปเกรด Lv.%d  (%d ทอง)" % [u.level + 1, c]
		_upg_btn.disabled = level.gold < c
	else:
		_upg_btn.text = "เลเวลสูงสุดแล้ว"
		_upg_btn.disabled = true
	_sell_btn.text = "ขาย  (+%d ทอง)" % u.sell_value()

func _on_placement(d: DefenderData) -> void:
	for i in _shop_buttons.size():
		var sel := d != null and level.defenders[i] == d
		_shop_buttons[i].add_theme_color_override("font_color", Color.YELLOW if sel else Color.WHITE)
		_shop_buttons[i].button_pressed = false
		_shop_buttons[i].self_modulate = Color(1.4, 1.3, 0.8) if sel else Color.WHITE

func _on_boss(ratio: float, vis: bool) -> void:
	_boss_box.visible = vis
	_boss_bar.value = ratio

func _on_speed() -> void:
	var fast := level.toggle_speed()
	_speed_btn.text = "ความเร็ว x2" if fast else "ความเร็ว x1"

func _on_pause() -> void:
	if level.finished:
		return
	get_tree().paused = not get_tree().paused
	_pause_btn.text = "เล่นต่อ" if get_tree().paused else "หยุด"
	if get_tree().paused:
		_pause_overlay = _make_overlay("หยุดชั่วคราว", "กด \"เล่นต่อ\" เพื่อกลับสู่สนามรบ", Color(0.8, 0.9, 1), false)
	elif _pause_overlay:
		_pause_overlay.queue_free()
		_pause_overlay = null

func _on_finished(victory: bool) -> void:
	_sel_panel.visible = false
	_boss_box.visible = false
	if victory:
		_end_overlay = _make_overlay("ภารกิจสำเร็จ!", "ท่านแม่ทัพหยุดยั้งกองทัพจากประตู Haupttür ได้สำเร็จ\nอาณาจักรปลอดภัย — ปลดล็อกภารกิจป้องกันถัดไป", Color(1, 0.85, 0.3), true)
	else:
		_end_overlay = _make_overlay("ภารกิจล้มเหลว", "กองทัพต่างมิติทำลายกำแพงเมืองได้\nท่านไม่สามารถปกป้องประชาชนและบ้านเมืองได้...", Color(1, 0.35, 0.3), true)

func _make_overlay(title: String, sub: String, color: Color, with_buttons: bool) -> Control:
	var ov := ColorRect.new()
	ov.color = Color(0, 0, 0, 0.6)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ov)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	ov.add_child(vb)
	var t := _label(title, 72, color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 14)
	vb.add_child(t)
	var s := _label(sub, 24)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(s)
	if with_buttons:
		var hb := HBoxContainer.new()
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_theme_constant_override("separation", 20)
		vb.add_child(hb)
		var r := _button("เล่นอีกครั้ง", _on_retry, 24)
		r.custom_minimum_size = Vector2(220, 56)
		var m := _button("กลับเมนูหลัก", _on_menu, 24)
		m.custom_minimum_size = Vector2(220, 56)
		hb.add_child(r)
		hb.add_child(m)
	if not with_buttons:
		ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.modulate.a = 0.0
	create_tween().tween_property(ov, "modulate:a", 1.0, 0.5)
	return ov

func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://td/scenes/main_menu.tscn")

func _on_music() -> void:
	_update_music_btn(Music.toggle_mute())

func _update_music_btn(m: bool) -> void:
	_music_btn.text = "เพลง: ปิด" if m else "เพลง: เปิด"
