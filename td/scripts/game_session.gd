class_name GameSession
## สถานะที่ใช้ร่วมกันระหว่างฉาก: โหมดเกม, seed แมพ, สถิติ, ระดับเสียง

const SAVE_PATH := "user://haupttuer.cfg"

static var mode: String = "story"      ## "story" | "endless"
static var endless_seed: int = 0
static var skip_cutscenes: bool = false   ## ใช้ตอนทดสอบอัตโนมัติ
static var _cfg: ConfigFile

static func _load() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(SAVE_PATH)
	return _cfg

static func get_value(key: String, default: Variant) -> Variant:
	return _load().get_value("save", key, default)

static func set_value(key: String, v: Variant) -> void:
	_load().set_value("save", key, v)
	_cfg.save(SAVE_PATH)

## ความเร็วกล้อง (WASD/หมุน/ซูม) และความไวเมาส์ (ลากกล้อง) — 0.3 ถึง 2.5 เท่า
static func cam_speed() -> float:
	return float(get_value("cam_speed", 1.0))

static func mouse_sens() -> float:
	return float(get_value("mouse_sens", 1.0))

## บันทึกหน่วยสอดแนม: ศัตรูที่เคยพบแล้ว (ปลดล็อกในทำเนียบกองทัพ)
static func is_seen(id: String) -> bool:
	return (get_value("seen_enemies", []) as Array).has(id)

static func mark_seen(id: String) -> bool:
	var arr: Array = get_value("seen_enemies", [])
	if arr.has(id):
		return false
	arr.append(id)
	set_value("seen_enemies", arr)
	return true

static func best_wave() -> int:
	return int(get_value("endless_best_wave", 0))

static func best_score() -> int:
	return int(get_value("endless_best_score", 0))

## บันทึกสถิติโหมดไม่สิ้นสุด คืนค่า true ถ้าทำลายสถิติ
static func submit_endless(wave: int, score: int) -> bool:
	var record := false
	if wave > best_wave():
		set_value("endless_best_wave", wave)
		record = true
	if score > best_score():
		set_value("endless_best_score", score)
		record = true
	return record

static func story_cleared() -> bool:
	return bool(get_value("story_cleared", false))

static func start_story() -> void:
	mode = "story"

static func start_endless() -> void:
	mode = "endless"
	endless_seed = randi()
