extends Control
## เมนูหลักแบบเกมจริง: ฉากหลังเป็นสนามรบ 3D ที่เคลื่อนไหวจริง + โลโก้ + รายการเมนูแบบแถบไฮไลต์
## แผงย่อย (วิธีเล่น / ทำเนียบกองทัพ / ตั้งค่า) เลื่อนเข้ามาจากด้านขวา

const LEVEL := "res://td/scenes/level_01.tscn"
const UNITS := ["knight", "archer", "alchemist", "mage", "golem", "saint", "dragon", "hero"]
const ENEMIES := ["soldier", "humvee", "tank", "helicopter", "jet", "bomber"]
const VERSION := "v1.0"

const C_TEXT := Color(0.86, 0.86, 0.88)
const C_DIM := Color(0.62, 0.62, 0.66)
const C_ACCENT := Color(0.78, 0.55, 1.0)

var _menu_box: VBoxContainer
var _panel: PanelContainer
var _panel_body: VBoxContainer
var _panel_title: Label
var _fade: ColorRect
var _busy: bool = false

func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	var vol: float = float(GameSession.get_value("volume", 0.8))
	AudioServer.set_bus_volume_db(0, linear_to_db(max(vol, 0.001)))
	GameSession.skip_cutscenes = not bool(GameSession.get_value("cutscenes", true))
	Music.play("menu")

	# ---- ฉากหลัง: สนามรบจริงแบบเล่นอัตโนมัติ
	GameSession.mode = "story"
	var lv: Node = load(LEVEL).instantiate()
	lv.set("showcase", true)
	add_child(lv)

	# ---- เงาไล่ระดับให้ตัวหนังสืออ่านง่าย
	add_child(_gradient(Vector2(0, 0), Vector2(1, 0), [Color(0.02, 0.01, 0.04, 0.92), Color(0.02, 0.01, 0.04, 0.55), Color(0, 0, 0, 0)], [0.0, 0.38, 0.72]))
	add_child(_gradient(Vector2(0, 0), Vector2(0, 1), [Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.7)], [0.0, 0.22, 0.75, 1.0]))

	# ---- โลโก้
	var logo := Control.new()
	logo.position = Vector2(92, 64)
	add_child(logo)
	var title := _label("HAUPTTÜR", 92, Color(0.96, 0.95, 0.98), 0)
	title.add_theme_constant_override("outline_size", 0)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	logo.add_child(title)
	var emblem := _Emblem.new()
	emblem.position = Vector2(500, 22)
	logo.add_child(emblem)
	var sub := _label("ป ร ะ ตู มิ ติ แ ห่ ง ก า ร รุ ก ร า น", 18, C_ACCENT, 0)
	sub.position = Vector2(6, 112)
	logo.add_child(sub)

	# ---- รายการเมนู
	_menu_box = VBoxContainer.new()
	_menu_box.position = Vector2(84, 300)
	_menu_box.add_theme_constant_override("separation", 4)
	add_child(_menu_box)
	var cleared := GameSession.story_cleared()
	_item("เล่นโหมดเนื้อเรื่อง" if not cleared else "เล่นเนื้อเรื่องอีกครั้ง", _start_story)
	_item("โหมดไม่สิ้นสุด", _start_endless)
	_item("วิธีเล่น", _show_panel.bind("how"))
	_item("ทำเนียบกองทัพ", _show_panel.bind("roster"))
	_item("ตั้งค่า", _show_panel.bind("settings"))
	if OS.get_name() != "Web":
		_item("ออกจากเกม", func(): get_tree().quit())
	(_menu_box.get_child(0) as Button).grab_focus()

	# ---- มุมล่าง
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = 92
	foot.offset_top = -64
	add_child(foot)
	var dot := _Emblem.new()
	dot.small = true
	dot.custom_minimum_size = Vector2(18, 26)
	foot.add_child(dot)
	var rec := "สถิติโหมดไม่สิ้นสุด: Wave %d • %d คะแนน" % [GameSession.best_wave(), GameSession.best_score()] if GameSession.best_wave() > 0 else "แม่ทัพคนใหม่แห่งเอลวาเรน"
	foot.add_child(_label(rec, 17, C_DIM, 0))
	var ver := _label("%s  •  CP410844 กลุ่ม 14" % VERSION, 14, Color(1, 1, 1, 0.45), 0)
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = -260
	ver.offset_top = -40
	add_child(ver)

	_build_panel()

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 1.4).set_delay(0.2)

# ------------------------------------------------------------ helpers
func _label(t: String, size: int, c: Color, outline: int = 4) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _gradient(from: Vector2, to: Vector2, cols: Array, offs: Array) -> TextureRect:
	var g := Gradient.new()
	g.colors = PackedColorArray(cols)
	g.offsets = PackedFloat32Array(offs)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = from
	gt.fill_to = to
	gt.width = 256
	gt.height = 256
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

func _item(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(380, 46)
	b.add_theme_font_size_override("font_size", 25)
	var empty := StyleBoxFlat.new()
	empty.bg_color = Color(0, 0, 0, 0)
	empty.content_margin_left = 16
	var hi := StyleBoxFlat.new()
	hi.bg_color = Color(0.92, 0.92, 0.95, 0.88)
	hi.content_margin_left = 16
	var pr := hi.duplicate() as StyleBoxFlat
	pr.bg_color = Color(0.78, 0.55, 1.0, 0.95)
	b.add_theme_stylebox_override("normal", empty)
	b.add_theme_stylebox_override("hover", hi)
	b.add_theme_stylebox_override("focus", hi)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", Color(0.08, 0.07, 0.1))
	b.add_theme_color_override("font_focus_color", Color(0.08, 0.07, 0.1))
	b.add_theme_color_override("font_pressed_color", Color(0.05, 0.03, 0.08))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	b.add_theme_constant_override("outline_size", 0)
	b.mouse_entered.connect(func(): b.grab_focus())
	b.pressed.connect(cb)
	_menu_box.add_child(b)
	return b

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") and _panel.visible:
		_hide_panel()

# ------------------------------------------------------------ start
func _go(mode: String) -> void:
	if _busy:
		return
	_busy = true
	if mode == "endless":
		GameSession.start_endless()
	else:
		GameSession.start_story()
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.6)
	tw.tween_callback(func(): get_tree().change_scene_to_file(LEVEL))

func _start_story() -> void:
	_go("story")

func _start_endless() -> void:
	_go("endless")

# ------------------------------------------------------------ side panel
func _build_panel() -> void:
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.07, 0.86)
	sb.border_color = Color(0.78, 0.55, 1.0, 0.5)
	sb.border_width_left = 2
	sb.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.anchor_left = 0.47
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	_panel.add_child(outer)
	_panel_title = _label("", 34, Color(0.96, 0.95, 0.98), 0)
	outer.add_child(_panel_title)
	var line := ColorRect.new()
	line.color = C_ACCENT
	line.custom_minimum_size = Vector2(80, 3)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	outer.add_child(line)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_panel_body = VBoxContainer.new()
	_panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_panel_body)
	var back := Button.new()
	back.text = "กลับ  [Esc]"
	back.custom_minimum_size = Vector2(160, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_hide_panel)
	outer.add_child(back)
	_panel.visible = false

func _show_panel(id: String) -> void:
	for c in _panel_body.get_children():
		c.queue_free()
	match id:
		"how":
			_panel_title.text = "วิธีเล่น"
			_how()
		"roster":
			_panel_title.text = "ทำเนียบกองทัพ"
			_roster()
		"settings":
			_panel_title.text = "ตั้งค่า"
			_settings()
	_panel.visible = true
	_panel.modulate.a = 0.0
	_panel.position.x += 60
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.25)
	tw.tween_property(_panel, "position:x", _panel.position.x - 60, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _hide_panel() -> void:
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func(): _panel.visible = false)

func _para(t: String, size: int = 18, c: Color = C_TEXT) -> Label:
	var l := _label(t, size, c, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _how() -> void:
	_panel_body.add_child(_para("ประตูมิติปริศนาเปิดขึ้นหน้าเมืองหลวง กองทัพจากโลกอื่นพร้อมไม้เท้าพ่นไฟ ป้อมเหล็ก และนกเหล็กกำลังบุกเข้ามา ท่านคือแม่ทัพที่ต้องปกป้องอาณาจักรเอลวาเรน", 18, C_DIM))
	var rows := [
		["วางยูนิต", "คลิกการ์ดด้านล่าง (หรือกด 1-7) แล้วคลิกช่องว่างข้างถนน"],
		["ทักษะพิเศษ", "คลิกยูนิตแล้วกด F — เพชรสีทองเหนือหัวแปลว่าทักษะพร้อมใช้"],
		["อัปเกรด / ขาย", "คลิกยูนิตแล้วกด U / X"],
		["เริ่มเฟส", "กด Space เมื่อวางกำลังพร้อม — ดูศัตรูเฟสถัดไปได้มุมซ้ายบน"],
		["ผู้กล้า", "เนื้อเรื่อง: ถูกอัญเชิญเมื่อบอสปรากฏ • ไม่สิ้นสุด: ได้ 1 เหรียญทุก Wave ครบ 15 เหรียญอัญเชิญได้ (กด H)"],
		["ศัตรูล้อมเมือง", "ศัตรูจะหยุดโจมตีประตูเมืองจนกว่าจะถูกกำจัด ปราสาทช่วยยิงสนับสนุน"],
		["กล้อง", "WASD เลื่อน • ล้อเมาส์ซูม • Q/E หมุน • Esc หยุดเกม"],
	]
	for r in rows:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 16)
		var k := _label(r[0], 18, C_ACCENT, 0)
		k.custom_minimum_size = Vector2(150, 0)
		hb.add_child(k)
		hb.add_child(_para(r[1], 18))
		_panel_body.add_child(hb)

func _roster() -> void:
	_panel_body.add_child(_label("กองทัพอาณาจักร (เรียงจากอ่อนไปแข็งแกร่ง)", 20, Color(0.6, 0.9, 1.0), 0))
	for id in UNITS:
		var d: DefenderData = load("res://td/data/defenders/%s.tres" % id)
		var price := "%d ทอง" % d.cost if d.cost > 0 else "อัญเชิญ"
		_panel_body.add_child(_unit_row(d.icon, "%s  •  %s" % [d.thai_name, price], d.description.replace("\n", " ") + "\nทักษะ [F] %s — %s" % [d.ability_name, d.ability_desc]))
	_panel_body.add_child(_label("บันทึกหน่วยสอดแนม — ศัตรูจากประตูมิติ", 20, Color(1, 0.55, 0.5), 0))
	_panel_body.add_child(_para("ไม่มีใครในอาณาจักรรู้จักสิ่งเหล่านี้มาก่อน ทุกอย่างคือสิ่งที่หน่วยสอดแนมเห็นด้วยตาตัวเอง", 15, C_DIM))
	var found := 0
	for id in ENEMIES:
		var e: EnemyData = load("res://td/data/enemies/%s.tres" % id)
		if GameSession.is_seen(id):
			found += 1
			var row := _unit_row(e.icon, e.thai_name + ("  •  บอส" if e.is_boss else ""), e.lore + "\nคำแนะนำเสนาธิการ: " + e.counter)
			_panel_body.add_child(row)
		else:
			var row2 := _unit_row(e.icon, "???", "ยังไม่เคยพบ... หน่วยสอดแนมจะบันทึกเมื่อเจอศัตรูชนิดนี้ครั้งแรก")
			(row2.get_child(0) as TextureRect).modulate = Color(0, 0, 0, 0.85)
			_panel_body.add_child(row2)
	_panel_body.add_child(_label("บันทึกแล้ว %d/%d" % [found, ENEMIES.size()], 15, C_DIM, 0))

func _unit_row(icon: Texture2D, head: String, body: String) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(64, 64)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture = icon
	hb.add_child(tr)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 0)
	vb.add_child(_label(head, 19, Color(1, 0.88, 0.6), 0))
	vb.add_child(_para(body, 15, C_DIM))
	hb.add_child(vb)
	return hb

func _settings() -> void:
	var vrow := HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 16)
	var k := _label("ระดับเสียง", 19, C_TEXT, 0)
	k.custom_minimum_size = Vector2(200, 0)
	vrow.add_child(k)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = float(GameSession.get_value("volume", 0.8))
	sl.custom_minimum_size = Vector2(280, 28)
	sl.value_changed.connect(func(v: float):
		AudioServer.set_bus_volume_db(0, linear_to_db(max(v, 0.001)))
		GameSession.set_value("volume", v))
	vrow.add_child(sl)
	_panel_body.add_child(vrow)
	_panel_body.add_child(_speed_slider("ความเร็วกล้อง", "cam_speed"))
	_panel_body.add_child(_speed_slider("ความไวเมาส์ (ลากกล้อง)", "mouse_sens"))
	_panel_body.add_child(_toggle("เพลงประกอบ", not Music.muted, func(on: bool):
		if on == Music.muted:
			Music.toggle_mute()))
	_panel_body.add_child(_toggle("แสดงคัตซีนเนื้อเรื่อง", bool(GameSession.get_value("cutscenes", true)), func(on: bool):
		GameSession.set_value("cutscenes", on)
		GameSession.skip_cutscenes = not on))
	if OS.get_name() != "Web":
		_panel_body.add_child(_toggle("เต็มจอ", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, func(on: bool):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)))

func _speed_slider(text: String, key: String) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	var k := _label(text, 19, C_TEXT, 0)
	k.custom_minimum_size = Vector2(200, 0)
	hb.add_child(k)
	var sl := HSlider.new()
	sl.min_value = 0.3
	sl.max_value = 2.5
	sl.step = 0.1
	sl.value = float(GameSession.get_value(key, 1.0))
	sl.custom_minimum_size = Vector2(280, 28)
	var val := _label("x%.1f" % sl.value, 18, C_DIM, 0)
	sl.value_changed.connect(func(v: float):
		GameSession.set_value(key, v)
		val.text = "x%.1f" % v)
	hb.add_child(sl)
	hb.add_child(val)
	return hb

func _toggle(text: String, on: bool, cb: Callable) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	var k := _label(text, 19, C_TEXT, 0)
	k.custom_minimum_size = Vector2(200, 0)
	hb.add_child(k)
	var c := CheckButton.new()
	c.button_pressed = on
	c.toggled.connect(cb)
	hb.add_child(c)
	return hb

## สัญลักษณ์ประตูมิติ (กรอบประตูเรืองแสงสีม่วง)
class _Emblem extends Control:
	var small: bool = false
	var _t: float = 0.0
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var w := 14.0 if small else 34.0
		var h := 22.0 if small else 62.0
		var glow := 0.55 + 0.25 * sin(_t * 2.0)
		var r := Rect2(Vector2(0, 0), Vector2(w, h))
		draw_rect(r.grow(4.0 if not small else 2.0), Color(0.6, 0.3, 1.0, 0.18 * glow))
		draw_rect(r, Color(0.45, 0.2, 0.85, 0.55 + 0.3 * glow))
		draw_rect(r, Color(0.92, 0.8, 1.0), false, 3.0 if not small else 2.0)
		draw_rect(Rect2(Vector2(w * 0.3, h * 0.15), Vector2(w * 0.4, h * 0.7)), Color(1, 0.9, 1, 0.35 * glow))
