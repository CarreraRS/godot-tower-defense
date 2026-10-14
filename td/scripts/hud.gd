extends CanvasLayer
## HUD ของด่าน: ทรัพยากร, ร้านยูนิต, ข้อมูลยูนิต, ศัตรูเฟสถัดไป, บทพูด, เมนูหยุด, หน้าจบเกม

@export var level_path: NodePath = ^".."
var level: TDLevel

var _gold_label: Label
var _lives_label: Label
var _phase_label: Label
var _score_label: Label
var _start_btn: Button
var _speed_btn: Button
var _auto_btn: Button
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
var _preview_box: HBoxContainer
var _dialog: PanelContainer
var _dialog_name: Label
var _dialog_text: Label
var _dialog_tween: Tween
var _overlay: Control
var _paused: bool = false
var _hero_btn: Button
var _hero_count: Label
var _ab_btn: Button
var _ab_desc: Label
var _gameplay_ui: Array[Control] = []
# --- คัตซีน
var _cs_root: Control
var _cs_bars: Array[ColorRect] = []
var _cs_bubble: PanelContainer
var _cs_tail: Control
var _cs_name: Label
var _cs_text: Label
var _cs_caption: Label
var _cs_hint: Label
var _cs_lines: Array = []
var _cs_i: int = -1
var _cs_done: Callable
var _cs_anchor: Vector3 = Vector3.INF
var _cs_type_tw: Tween
var _cs_active: bool = false

const SPEAKERS := {
	"king": ["พระราชาเอลวาเรนที่ 3", Color(1.0, 0.82, 0.35)],
	"advisor": ["เสนาธิการลีอา", Color(0.6, 0.85, 1.0)],
	"scout": ["หน่วยสอดแนม", Color(0.6, 1.0, 0.6)],
	"hero": ["ผู้กล้าอาเรียน", Color(0.65, 0.92, 1.0)],
	"narrator": ["", Color.WHITE],
}

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
	_build_preview(root)
	_build_banner(root)
	_build_shop(root)
	_build_selection(root)
	_build_dialog(root)
	_build_help(root)
	_build_cutscene(root)
	level.gold_changed.connect(_on_gold)
	level.lives_changed.connect(_on_lives)
	level.phase_changed.connect(_on_phase)
	level.announce.connect(show_banner)
	level.selection_changed.connect(_on_selection)
	level.boss_hp_changed.connect(_on_boss)
	level.game_finished.connect(_on_finished)
	level.placement_changed.connect(_on_placement)
	level.music_toggled.connect(_update_music_btn)
	level.next_wave_preview.connect(_on_preview)
	level.score_changed.connect(_on_score)
	level.story_line.connect(show_dialog)
	level.pause_requested.connect(_toggle_pause)
	level.hero_changed.connect(_on_hero_tokens)
	level.cutscene_requested.connect(play_cutscene)

# ------------------------------------------------------------ helpers
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
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(text: String, cb: Callable, size: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(cb)
	return b

# ------------------------------------------------------------ builders
func _build_top(root: Control) -> void:
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", _panel())
	left.position = Vector2(12, 10)
	root.add_child(left)
	_gameplay_ui.append(left)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	left.add_child(hb)
	_gold_label = _label("ทอง 0", 24, GOLD)
	_lives_label = _label("กำแพงเมือง 20/20", 24, Color(1, 0.55, 0.5))
	_phase_label = _label("Phase 1/6", 24, Color(0.75, 0.85, 1))
	_score_label = _label("", 20, Color(0.85, 0.8, 1))
	hb.add_child(_gold_label)
	hb.add_child(_lives_label)
	hb.add_child(_phase_label)
	hb.add_child(_score_label)
	_score_label.visible = level.mode == "endless"

	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(right)
	_gameplay_ui.append(right)
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	_start_btn = _button("เริ่ม Phase  [Space]", func(): level.start_phase(), 19)
	_start_btn.custom_minimum_size = Vector2(200, 44)
	_speed_btn = _button("ความเร็ว x1", _on_speed, 17)
	_speed_btn.custom_minimum_size = Vector2(118, 44)
	_auto_btn = _button("อัตโนมัติ: ปิด", _on_auto, 17)
	_auto_btn.custom_minimum_size = Vector2(124, 44)
	_auto_btn.visible = level.mode == "endless"
	_music_btn = _button("", _on_music, 17)
	_music_btn.custom_minimum_size = Vector2(100, 44)
	_update_music_btn(Music.muted)
	var menu_btn := _button("เมนู  [Esc]", _toggle_pause, 17)
	menu_btn.custom_minimum_size = Vector2(110, 44)
	right.add_child(_start_btn)
	right.add_child(_speed_btn)
	right.add_child(_auto_btn)
	right.add_child(_music_btn)
	right.add_child(menu_btn)

func _build_preview(root: Control) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _panel(Color(0.08, 0.07, 0.06, 0.7)))
	p.position = Vector2(12, 62)
	root.add_child(p)
	_gameplay_ui.append(p)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	p.add_child(hb)
	hb.add_child(_label("ศัตรูถัดไป:", 16, Color(1, 0.7, 0.6)))
	_preview_box = HBoxContainer.new()
	_preview_box.add_theme_constant_override("separation", 10)
	hb.add_child(_preview_box)

func _build_banner(root: Control) -> void:
	_banner = VBoxContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-450, 110)
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
	_boss_box.position = Vector2(-260, 70)
	_boss_box.size = Vector2(520, 40)
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_boss_box)
	var bl := _label("BOSS — " + (load("res://td/data/enemies/bomber.tres") as EnemyData).thai_name, 18, Color(1, 0.5, 0.45))
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
	root.add_child(panel)
	_gameplay_ui.append(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	panel.add_child(hb)
	for i in level.defenders.size():
		var d: DefenderData = level.defenders[i]
		var b := _make_card(d, str(i + 1), "%d ทอง" % d.cost)
		b.pressed.connect(func(): level.begin_placement(d))
		hb.add_child(b)
		_shop_buttons.append(b)
	if level.hero_data:
		var sep := VSeparator.new()
		hb.add_child(sep)
		var hd := level.hero_data
		_hero_btn = _make_card(hd, "H", "")
		var sb := _panel(Color(0.25, 0.2, 0.08, 0.95), 8)
		sb.border_color = Color(1.0, 0.85, 0.4)
		_hero_btn.add_theme_stylebox_override("normal", sb)
		_hero_btn.pressed.connect(func(): level.begin_placement(hd))
		_hero_count = _hero_btn.get_child(0).get_child(2) as Label
		hb.add_child(_hero_btn)
		_on_hero_tokens(level.hero_tokens)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 8)

func _make_card(d: DefenderData, key_text: String, price: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(104, 112)
	var extra := ""
	if d.splash_radius > 0: extra += "\nดาเมจกระจาย รัศมี %.1f" % d.splash_radius
	if d.armor_pierce: extra += "\nเจาะเกราะ"
	if d.slow_duration > 0: extra += "\nทำให้ช้าลง %d%%" % int((1.0 - d.slow_factor) * 100)
	if d.aura_radius > 0: extra += "\nออร่า +%d%% ดาเมจ รัศมี %.1f" % [int((d.aura_mult - 1.0) * 100), d.aura_radius]
	if d.ability_name != "": extra += "\n\nทักษะ [F] %s: %s (คูลดาวน์ %d วิ)" % [d.ability_name, d.ability_desc, int(d.ability_cd)]
	b.tooltip_text = "%s (%s)\n%s\n\nดาเมจ %d | ระยะ %.1f | โจมตีทุก %.1f วิ\nเป้าหมาย: %s%s" % [
		d.thai_name, d.display_name, d.description, d.damage, d.attack_range, d.fire_interval,
		d.targets_text(), extra]
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 0)
	b.add_child(vb)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(64, 58)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if d.icon:
		icon.texture = d.icon
	vb.add_child(icon)
	var n := _label(d.thai_name, 15)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	n.custom_minimum_size = Vector2(98, 0)
	vb.add_child(n)
	var c := _label(price, 15, GOLD)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(c)
	var key := _label(key_text, 14, Color(1, 1, 1, 0.6))
	key.position = Vector2(6, 2)
	b.add_child(key)
	return b

func _on_hero_tokens(t: int) -> void:
	if _hero_btn == null:
		return
	var placed := level.has_unique(level.hero_data)
	if placed:
		_hero_count.text = "อยู่ในสนาม"
	elif level._hero_redeploy_t > 0.0:
		_hero_count.text = "พักฟื้น..."
	elif level.mode == "story":
		_hero_count.text = "พร้อมอัญเชิญ!" if t > 0 else "ล็อก"
	else:
		_hero_count.text = "เหรียญ %d/%d" % [min(t, level.hero_cost()), level.hero_cost()]
	var ok := t >= level.hero_cost() and not placed and level._hero_redeploy_t <= 0.0
	_hero_btn.modulate = Color.WHITE if ok else Color(0.55, 0.5, 0.5)
	if ok:
		var tw := create_tween().set_loops(4)
		tw.tween_property(_hero_btn, "self_modulate", Color(1.6, 1.4, 0.9), 0.35)
		tw.tween_property(_hero_btn, "self_modulate", Color.WHITE, 0.35)

func _build_selection(root: Control) -> void:
	_sel_panel = PanelContainer.new()
	_sel_panel.add_theme_stylebox_override("panel", _panel())
	_sel_panel.custom_minimum_size = Vector2(260, 0)
	root.add_child(_sel_panel)
	_sel_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_sel_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	_sel_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_sel_panel.offset_top -= 70
	_sel_panel.offset_bottom -= 70
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_sel_panel.add_child(vb)
	_sel_title = _label("", 23, Color(1, 0.9, 0.6))
	_sel_stats = _label("", 16)
	_ab_btn = _button("ทักษะ", func(): level.use_selected_ability(), 18)
	_ab_btn.custom_minimum_size = Vector2(0, 44)
	var ab_sb := _panel(Color(0.3, 0.22, 0.06, 0.95), 8)
	ab_sb.border_color = Color(1.0, 0.85, 0.4)
	_ab_btn.add_theme_stylebox_override("normal", ab_sb)
	_ab_desc = _label("", 14, Color(1, 0.9, 0.7))
	_ab_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ab_desc.custom_minimum_size = Vector2(250, 0)
	_upg_btn = _button("อัปเกรด", func(): level.upgrade_selected(), 18)
	_sell_btn = _button("ขาย", func(): level.sell_selected(), 18)
	_upg_btn.custom_minimum_size = Vector2(0, 40)
	_sell_btn.custom_minimum_size = Vector2(0, 36)
	vb.add_child(_sel_title)
	vb.add_child(_sel_stats)
	vb.add_child(_ab_desc)
	vb.add_child(_ab_btn)
	vb.add_child(_upg_btn)
	vb.add_child(_sell_btn)
	_sel_panel.visible = false

func _build_dialog(root: Control) -> void:
	_dialog = PanelContainer.new()
	_dialog.add_theme_stylebox_override("panel", _panel(Color(0.1, 0.07, 0.12, 0.88)))
	_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_dialog)
	_dialog.custom_minimum_size = Vector2(430, 0)
	_dialog.position = Vector2(12, 300)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog.add_child(vb)
	_dialog_name = _label("", 18, Color(1, 0.8, 0.35))
	_dialog_text = _label("", 17)
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_text.custom_minimum_size = Vector2(400, 0)
	vb.add_child(_dialog_name)
	vb.add_child(_dialog_text)
	_dialog.modulate.a = 0.0

func _build_help(root: Control) -> void:
	var l := _label("คลิกซ้าย: วาง/เลือก   คลิกขวา: ยกเลิก   F: ใช้ทักษะ   H: ผู้กล้า   U: อัปเกรด   X: ขาย   WASD/ล้อเมาส์/Q,E: กล้อง   Esc: เมนู", 13, Color(1, 1, 1, 0.75))
	root.add_child(l)
	_gameplay_ui.append(l)
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 0)
	l.position.y -= 138
	l.position.x = 12

# ------------------------------------------------------------ handlers
func _on_gold(v: int) -> void:
	_gold_label.text = "ทอง %d" % v
	_refresh_shop()
	if level._selected:
		_on_selection(level._selected)

func _refresh_shop() -> void:
	for i in _shop_buttons.size():
		var d: DefenderData = level.defenders[i]
		var ok := level.gold >= d.cost and not (d.unique and level.has_unique(d))
		_shop_buttons[i].modulate = Color.WHITE if ok else Color(0.55, 0.5, 0.5)
	if _hero_btn:
		_on_hero_tokens(level.hero_tokens)

func _on_lives(v: int, m: int) -> void:
	_lives_label.text = "กำแพงเมือง %d/%d" % [v, m]
	if v < m:
		var tw := create_tween()
		_lives_label.modulate = Color(1, 0.2, 0.2)
		tw.tween_property(_lives_label, "modulate", Color.WHITE, 0.4)

func _on_phase(index: int, total: int, running: bool) -> void:
	if total < 0:
		_phase_label.text = "Wave %d" % (index + (1 if running else 0)) if (running or index > 0) else "Wave 0"
		_start_btn.text = "กำลังรบ..." if running else "เริ่ม Wave %d  [Space]" % (index + 1)
	else:
		var shown: int = min(index + 1, total)
		var boss: bool = index < total and WavesLevel01.PHASES[index].get("boss", false)
		_phase_label.text = ("BOSS PHASE (%d/%d)" if boss else "Phase %d/%d") % [shown, total]
		_start_btn.text = "กำลังรบ..." if running else (("เริ่ม BOSS PHASE" if boss else "เริ่ม Phase %d" % shown) + "  [Space]")
	_start_btn.disabled = running
	_refresh_shop()

func _on_score(s: int, k: int) -> void:
	_score_label.text = "คะแนน %d" % s

func _on_preview(entries: Array) -> void:
	for c in _preview_box.get_children():
		c.queue_free()
	for e in entries:
		var d: EnemyData = e.data
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 2)
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(34, 34)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = d.icon
		tr.tooltip_text = "%s%s — เลือด %d เกราะ %d" % [d.thai_name, " (บิน)" if d.is_air else "", d.max_hp, d.armor]
		hb.add_child(tr)
		hb.add_child(_label("x%d" % e.count, 16, Color(1, 0.6, 0.55) if d.is_air or d.is_boss else Color.WHITE))
		_preview_box.add_child(hb)

func show_banner(title: String, sub: String, color: Color) -> void:
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", color)
	_banner_sub.text = sub
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner.modulate.a = 0.0
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(2.6)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)

func show_dialog(speaker: String, text: String) -> void:
	if SPEAKERS.has(speaker):
		_dialog_name.add_theme_color_override("font_color", SPEAKERS[speaker][1])
		speaker = SPEAKERS[speaker][0]
	_dialog_name.text = speaker
	_dialog_text.text = text
	if _dialog_tween:
		_dialog_tween.kill()
	_dialog_tween = create_tween()
	_dialog_tween.tween_property(_dialog, "modulate:a", 1.0, 0.3)
	_dialog_tween.tween_interval(6.5)
	_dialog_tween.tween_property(_dialog, "modulate:a", 0.0, 0.8)

func _on_selection(u: TDDefender) -> void:
	_sel_panel.visible = u != null
	if u == null:
		return
	var d := u.data
	_sel_title.text = "%s  Lv.%d" % [d.thai_name, u.level]
	var dm := u.dmg_mult()
	var lines := "%s\nดาเมจ: %d%s\nระยะ: %.1f ช่อง\nโจมตีทุก: %.2f วินาที\nเป้าหมาย: %s" % [
		d.display_name, d.damage_at(u.level) * dm,
		("  (บัฟ x%.2f)" % dm) if dm > 1.01 else "",
		u.current_range(), d.interval_at(u.level) / u.rate_mult(), d.targets_text()]
	if d.splash_radius > 0: lines += "\nกระจาย: %.1f" % d.splash_radius
	if d.slow_duration > 0: lines += "\nทำให้ช้าลง %d%%" % int((1.0 - d.slow_factor) * 100)
	if d.aura_radius > 0: lines += "\nออร่า: +%d%% ดาเมจ รัศมี %.1f" % [int((u.aura_mult() - 1.0) * 100), u.aura_radius()]
	_sel_stats.text = lines
	if u.can_upgrade():
		var c := u.next_upgrade_cost()
		_upg_btn.text = "อัปเกรด Lv.%d  (%d ทอง)" % [u.level + 1, c]
		_upg_btn.disabled = level.gold < c
	else:
		_upg_btn.text = "เลเวลสูงสุดแล้ว"
		_upg_btn.disabled = true
	if d == level.hero_data:
		_sell_btn.text = "ส่งกลับ (คืน %d เหรียญ)" % level.hero_cost() if level.mode == "endless" else "ส่งกลับปราสาท"
	else:
		_sell_btn.text = "ขาย  (+%d ทอง)" % u.sell_value()
	_ab_desc.visible = d.ability != DefenderData.Ability.NONE
	_ab_btn.visible = _ab_desc.visible
	_ab_desc.text = "ทักษะ: %s\n%s" % [d.ability_name, d.ability_desc]
	_update_ability_btn(u)

func _update_ability_btn(u: TDDefender) -> void:
	if u.ability_ready():
		_ab_btn.text = "ใช้ทักษะ: %s  [F]" % u.data.ability_name
		_ab_btn.disabled = false
	else:
		_ab_btn.text = "คูลดาวน์ %d วิ" % ceili(u.ability_left)
		_ab_btn.disabled = true

func _process(_delta: float) -> void:
	if _sel_panel.visible and level._selected and is_instance_valid(level._selected):
		_update_ability_btn(level._selected)
	if _cs_active and _cs_anchor != Vector3.INF:
		_place_bubble()

func _on_placement(d: DefenderData) -> void:
	for i in _shop_buttons.size():
		var sel := d != null and level.defenders[i] == d
		_shop_buttons[i].self_modulate = Color(1.4, 1.3, 0.8) if sel else Color.WHITE

func _on_boss(ratio: float, vis: bool) -> void:
	_boss_box.visible = vis
	_boss_bar.value = ratio

func _on_speed() -> void:
	_speed_btn.text = "ความเร็ว x%d" % level.cycle_speed()

func _on_auto() -> void:
	level.auto_next = not level.auto_next
	_auto_btn.text = "อัตโนมัติ: เปิด" if level.auto_next else "อัตโนมัติ: ปิด"
	if level.auto_next and not level.phase_running and level.phase_index > 0:
		level._auto_t = 3.0

func _on_music() -> void:
	_update_music_btn(Music.toggle_mute())

func _update_music_btn(m: bool) -> void:
	_music_btn.text = "เพลง: ปิด" if m else "เพลง: เปิด"

# ------------------------------------------------------------ pause menu / end screens
func _toggle_pause() -> void:
	if level.finished:
		return
	_paused = not _paused
	get_tree().paused = _paused
	if _paused:
		_overlay = _make_overlay("หยุดชั่วคราว", "", Color(0.8, 0.9, 1))
		var vb: VBoxContainer = _overlay.get_child(0)
		var vol := HBoxContainer.new()
		vol.alignment = BoxContainer.ALIGNMENT_CENTER
		vol.add_child(_label("ระดับเสียง", 20))
		var sl := HSlider.new()
		sl.custom_minimum_size = Vector2(260, 24)
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = db_to_linear(AudioServer.get_bus_volume_db(0))
		sl.value_changed.connect(func(v): AudioServer.set_bus_volume_db(0, linear_to_db(max(v, 0.001))); GameSession.set_value("volume", v))
		vol.add_child(sl)
		vb.add_child(vol)
		vb.add_child(_speed_row("ความเร็วกล้อง", "cam_speed"))
		vb.add_child(_speed_row("ความไวเมาส์", "mouse_sens"))
		_add_buttons(vb, [["เล่นต่อ", _toggle_pause], ["เริ่มใหม่", _on_retry], ["กลับเมนูหลัก", _on_menu]])
	elif _overlay:
		_overlay.queue_free()
		_overlay = null

func _speed_row(text: String, key: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var l := _label(text, 20)
	l.custom_minimum_size = Vector2(160, 0)
	hb.add_child(l)
	var sl := HSlider.new()
	sl.custom_minimum_size = Vector2(260, 24)
	sl.min_value = 0.3
	sl.max_value = 2.5
	sl.step = 0.1
	sl.value = float(GameSession.get_value(key, 1.0))
	var val := _label("x%.1f" % sl.value, 18, Color(1, 1, 1, 0.75))
	sl.value_changed.connect(func(v: float):
		GameSession.set_value(key, v)
		val.text = "x%.1f" % v)
	hb.add_child(sl)
	hb.add_child(val)
	return hb

func _on_finished(victory: bool) -> void:
	_sel_panel.visible = false
	_dialog.visible = false
	_boss_box.visible = false
	if level.mode == "endless":
		var rec := level.endless_record()
		var sub := "ต้านทานได้ %d Wave • กำจัดศัตรู %d • คะแนน %d" % [level.phase_index, level.kills, level.score]
		sub += "\n" + ("— สถิติใหม่! —" if rec else "สถิติสูงสุด: Wave %d • คะแนน %d" % [GameSession.best_wave(), GameSession.best_score()])
		_overlay = _make_overlay("กำแพงเมืองแตกแล้ว", sub, Color(1, 0.7, 0.35))
		_add_buttons(_overlay.get_child(0), [["เล่นใหม่ (แมพใหม่)", _on_retry_endless], ["กลับเมนูหลัก", _on_menu]])
	elif victory:
		_overlay = _make_overlay("ภารกิจสำเร็จ!", "ท่านแม่ทัพหยุดยั้งกองทัพจากประตู Haupttür ได้สำเร็จ\nอาณาจักรปลอดภัย — ลองท้าทายโหมดไม่สิ้นสุดเพื่อทำสถิติ!", Color(1, 0.85, 0.3))
		_add_buttons(_overlay.get_child(0), [["เล่นอีกครั้ง", _on_retry], ["กลับเมนูหลัก", _on_menu]])
	else:
		_overlay = _make_overlay("ภารกิจล้มเหลว", "กองทัพต่างมิติทำลายกำแพงเมืองได้\nท่านไม่สามารถปกป้องประชาชนและบ้านเมืองได้...", Color(1, 0.35, 0.3))
		_add_buttons(_overlay.get_child(0), [["เล่นอีกครั้ง", _on_retry], ["กลับเมนูหลัก", _on_menu]])

func _make_overlay(title: String, sub: String, color: Color) -> Control:
	var ov := ColorRect.new()
	ov.color = Color(0, 0, 0, 0.6)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ov)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	ov.add_child(vb)
	var t := _label(title, 66, color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 14)
	vb.add_child(t)
	if sub != "":
		var s := _label(sub, 23)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(s)
	ov.modulate.a = 0.0
	create_tween().tween_property(ov, "modulate:a", 1.0, 0.4)
	return ov

func _add_buttons(vb: VBoxContainer, items: Array) -> void:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 20)
	vb.add_child(hb)
	for it in items:
		var b := _button(it[0], it[1], 24)
		b.custom_minimum_size = Vector2(230, 56)
		hb.add_child(b)

func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_retry_endless() -> void:
	get_tree().paused = false
	GameSession.start_endless()
	get_tree().reload_current_scene()

func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://td/scenes/main_menu.tscn")

# ------------------------------------------------------------ cutscene
func _build_cutscene(root: Control) -> void:
	_cs_root = Control.new()
	_cs_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cs_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_cs_root.visible = false
	_cs_root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_cs_advance())
	root.add_child(_cs_root)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 0.92)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		if top:
			bar.anchor_bottom = 0.0
			bar.offset_bottom = 0
		else:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
			bar.offset_top = 0
		_cs_root.add_child(bar)
		_cs_bars.append(bar)
	_cs_bubble = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.93, 0.84, 0.97)
	sb.border_color = Color(0.55, 0.4, 0.2)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	_cs_bubble.add_theme_stylebox_override("panel", sb)
	_cs_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cs_root.add_child(_cs_bubble)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cs_bubble.add_child(vb)
	_cs_name = Label.new()
	_cs_name.add_theme_font_size_override("font_size", 20)
	_cs_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_cs_name)
	_cs_text = Label.new()
	_cs_text.add_theme_font_size_override("font_size", 21)
	_cs_text.add_theme_color_override("font_color", Color(0.15, 0.1, 0.06))
	_cs_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cs_text.custom_minimum_size = Vector2(520, 0)
	_cs_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_cs_text)
	_cs_tail = Control.new()
	_cs_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tri := Polygon2D.new()
	tri.polygon = PackedVector2Array([Vector2(-16, -3), Vector2(16, -3), Vector2(0, 22)])
	tri.color = Color(0.97, 0.93, 0.84)
	_cs_tail.add_child(tri)
	_cs_root.add_child(_cs_tail)
	_cs_caption = _label("", 30, Color(1, 0.95, 0.85))
	_cs_caption.add_theme_constant_override("outline_size", 10)
	_cs_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cs_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cs_caption.anchor_left = 0.1
	_cs_caption.anchor_right = 0.9
	_cs_caption.anchor_top = 1.0
	_cs_caption.anchor_bottom = 1.0
	_cs_caption.offset_top = -190
	_cs_caption.offset_bottom = -110
	_cs_root.add_child(_cs_caption)
	_cs_hint = _label("คลิก / Space เพื่อไปต่อ", 15, Color(1, 1, 1, 0.7))
	_cs_hint.anchor_left = 1.0
	_cs_hint.anchor_right = 1.0
	_cs_hint.anchor_top = 1.0
	_cs_hint.anchor_bottom = 1.0
	_cs_hint.offset_left = -260
	_cs_hint.offset_top = -48
	_cs_root.add_child(_cs_hint)
	var skip := _button("ข้ามคัตซีน  [Esc]", _cs_finish, 16)
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -190
	skip.offset_top = 14
	skip.offset_right = -14
	skip.offset_bottom = 52
	_cs_root.add_child(skip)

func play_cutscene(lines: Array, done: Callable) -> void:
	_cs_lines = lines
	_cs_done = done
	_cs_i = -1
	_cs_active = true
	_cs_root.visible = true
	_dialog.modulate.a = 0.0
	_sel_panel.visible = false
	if _banner_tween:
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_ignore_time_scale(true)
	for c in _gameplay_ui:
		tw.tween_property(c, "modulate:a", 0.0, 0.35)
	tw.tween_property(_cs_bars[0], "offset_bottom", 72.0, 0.45)
	tw.tween_property(_cs_bars[1], "offset_top", -72.0, 0.45)
	_cs_advance()

func _input(event: InputEvent) -> void:
	if not _cs_active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER:
			_cs_advance()
			get_viewport().set_input_as_handled()
		elif k == KEY_ESCAPE:
			_cs_finish()
			get_viewport().set_input_as_handled()

func _cs_advance() -> void:
	if not _cs_active:
		return
	if _cs_type_tw and _cs_type_tw.is_running():
		_cs_type_tw.kill()
		_cs_text.visible_ratio = 1.0
		_cs_caption.visible_ratio = 1.0
		return
	_cs_i += 1
	if _cs_i >= _cs_lines.size():
		_cs_finish()
		return
	var line: Dictionary = _cs_lines[_cs_i]
	var who: String = line.get("who", "narrator")
	if line.has("focus"):
		level.cutscene_focus(line["focus"])
	if line.has("action"):
		level.cutscene_action(line["action"])
	var text: String = line.get("text", "")
	var dur: float = clamp(text.length() * 0.022, 0.4, 2.2)
	_cs_type_tw = create_tween().set_ignore_time_scale(true)
	if who == "narrator":
		_cs_bubble.visible = false
		_cs_tail.visible = false
		_cs_caption.visible = true
		_cs_caption.text = text
		_cs_caption.visible_ratio = 0.0
		_cs_type_tw.tween_property(_cs_caption, "visible_ratio", 1.0, dur)
		_cs_anchor = Vector3.INF
	else:
		_cs_caption.visible = false
		_cs_bubble.visible = true
		var sp: Array = SPEAKERS.get(who, [who, Color.WHITE])
		_cs_name.text = sp[0]
		_cs_name.add_theme_color_override("font_color", (sp[1] as Color).darkened(0.45))
		_cs_text.text = text
		_cs_text.visible_ratio = 0.0
		_cs_type_tw.tween_property(_cs_text, "visible_ratio", 1.0, dur)
		_cs_anchor = level.cutscene_anchor(who)
		_cs_bubble.reset_size()
		if _cs_anchor == Vector3.INF:
			_cs_tail.visible = false
			var vs := get_viewport().get_visible_rect().size
			_cs_bubble.position = Vector2((vs.x - _cs_bubble.size.x) * 0.5, vs.y - 92 - _cs_bubble.size.y)
		else:
			_cs_tail.visible = true
			_place_bubble()
		_cs_bubble.scale = Vector2(0.9, 0.9)
		_cs_bubble.pivot_offset = _cs_bubble.size * Vector2(0.5, 1.0)
		create_tween().set_ignore_time_scale(true).tween_property(_cs_bubble, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _place_bubble() -> void:
	var cam := level.cam
	if cam.is_position_behind(_cs_anchor):
		return
	var vs := get_viewport().get_visible_rect().size
	var p := cam.unproject_position(_cs_anchor)
	var sz := _cs_bubble.size
	var bp := Vector2(p.x - sz.x * 0.5, p.y - sz.y - 26)
	bp.x = clamp(bp.x, 16, vs.x - sz.x - 16)
	bp.y = clamp(bp.y, 84, vs.y - sz.y - 96)
	_cs_bubble.position = bp
	_cs_tail.position = Vector2(clamp(p.x, bp.x + 30, bp.x + sz.x - 30), bp.y + sz.y)

func _cs_finish() -> void:
	if not _cs_active:
		return
	_cs_active = false
	if _cs_type_tw:
		_cs_type_tw.kill()
	# ทำ action ที่ถูกข้ามไปด้วย (เช่น เปิดประตู)
	for j in range(max(_cs_i + 1, 0), _cs_lines.size()):
		if _cs_lines[j].has("action"):
			level.cutscene_action(_cs_lines[j]["action"])
	var tw := create_tween().set_parallel(true).set_ignore_time_scale(true)
	for c in _gameplay_ui:
		tw.tween_property(c, "modulate:a", 1.0, 0.35)
	tw.tween_property(_cs_bars[0], "offset_bottom", 0.0, 0.35)
	tw.tween_property(_cs_bars[1], "offset_top", 0.0, 0.35)
	tw.chain().tween_callback(func(): _cs_root.visible = false)
	_cs_bubble.visible = false
	_cs_tail.visible = false
	_cs_caption.visible = false
	if _cs_done.is_valid():
		_cs_done.call()
