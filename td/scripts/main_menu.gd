extends Control
## เมนูหลัก: ชื่อเกม เรื่องย่อ รายชื่อยูนิต และปุ่มเริ่มภารกิจ

const LEVEL := "res://td/scenes/level_01.tscn"
const BG := "res://td/icons/menu_bg.png"
const DEFENDERS := ["archer", "knight", "mage", "wizard", "ballista", "catapult", "dragon"]
const ENEMIES := ["soldier", "humvee", "tank", "helicopter", "jet", "bomber"]

func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Music.play("menu")
	var bg_color := ColorRect.new()
	bg_color.color = Color(0.07, 0.05, 0.1)
	bg_color.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_color)
	if ResourceLoader.exists(BG):
		var bg := TextureRect.new()
		bg.texture = load(BG)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(bg)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.02, 0.06, 0.62)
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + s, 70)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	vb.add_child(_label("HAUPTTÜR", 88, Color(0.85, 0.6, 1.0), 16))
	vb.add_child(_label("เฮาพท์-ทือร์ : ประตูมิติแห่งการรุกราน", 28, Color(1, 0.88, 0.6)))
	var story := _label("ณ ใจกลางเมืองแห่งหนึ่งของอาณาจักร ประตูปริศนาได้เปิดขึ้น กองทัพต่างมิติพร้อมอาวุธเหล็กกล้า รถถัง และเครื่องบิน\nได้บุกออกมาหมายยึดครองดินแดน จักรพรรดิจึงแต่งตั้งท่านเป็นแม่ทัพสูงสุด จงจัดกองกำลังปกป้องประชาชนและบ้านเมือง!", 19, Color(0.92, 0.9, 0.95))
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.custom_minimum_size = Vector2(900, 0)
	vb.add_child(story)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vb.add_child(spacer)
	vb.add_child(_label("กองทัพอาณาจักร", 20, Color(0.6, 0.9, 1.0)))
	vb.add_child(_roster(DEFENDERS, "defenders"))
	vb.add_child(_label("กองทัพจากประตูมิติ", 20, Color(1, 0.55, 0.5)))
	vb.add_child(_roster(ENEMIES, "enemies"))

	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(grow)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	vb.add_child(hb)
	var start := Button.new()
	start.text = "เริ่มภารกิจ : ฉากที่ 1 — ด่านหน้าเมืองหลวง"
	start.custom_minimum_size = Vector2(480, 64)
	start.add_theme_font_size_override("font_size", 24)
	start.pressed.connect(func(): get_tree().change_scene_to_file(LEVEL))
	hb.add_child(start)
	var quit := Button.new()
	quit.text = "ออกจากเกม"
	quit.custom_minimum_size = Vector2(200, 64)
	quit.add_theme_font_size_override("font_size", 22)
	quit.pressed.connect(func(): get_tree().quit())
	hb.add_child(quit)
	start.grab_focus()

func _label(t: String, size: int, c: Color, outline: int = 6) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", outline)
	return l

func _roster(ids: Array, folder: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	for id in ids:
		var res: Resource = load("res://td/data/%s/%s.tres" % [folder, id])
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(104, 0)
		var icon_path := "res://td/icons/%s.png" % id
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(80, 80)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(icon_path):
			tr.texture = load(icon_path)
		box.add_child(tr)
		var n := _label(res.thai_name, 15, Color.WHITE, 4)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(n)
		var e := _label(res.display_name, 12, Color(1, 1, 1, 0.6), 3)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(e)
		hb.add_child(box)
	return hb
