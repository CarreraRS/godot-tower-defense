extends Node
class_name Music
## เครื่องเล่นเพลงประกอบ (BGM) แบบค้างข้ามฉาก พร้อม crossfade
## ใช้: Music.play("battle") / Music.stinger("victory") / Music.toggle_mute()

const TRACKS := {
	"menu": "res://td/audio/bgm_menu.ogg",
	"battle": "res://td/audio/bgm_battle.ogg",
	"boss": "res://td/audio/bgm_boss.ogg",
	"victory": "res://td/audio/stinger_victory.ogg",
	"defeat": "res://td/audio/stinger_defeat.ogg",
}
const VOLUME_DB := -6.0

static var muted: bool = false
static var _node: Music

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _current: String = ""
var _pending: Array = []
var _tween: Tween

static func _instance() -> Music:
	if _node and is_instance_valid(_node):
		return _node
	var tree := Engine.get_main_loop() as SceneTree
	_node = Music.new()
	_node.name = "MusicPlayer"
	tree.root.add_child.call_deferred(_node)
	return _node

## เล่นเพลงวนลูป (ถ้ากำลังเล่นเพลงเดิมอยู่จะไม่เริ่มใหม่)
static func play(track: String, fade: float = 1.2) -> void:
	_instance()._request(track, fade, true)

## เล่นเพลงสั้นครั้งเดียว (ชนะ/แพ้)
static func stinger(track: String, fade: float = 0.6) -> void:
	_instance()._request(track, fade, false)

static func toggle_mute() -> bool:
	muted = not muted
	var n := _instance()
	if n.is_inside_tree():
		n._apply_mute()
	return muted

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	for p in [_a, _b]:
		p.volume_db = -80.0
		add_child(p)
	for r in _pending:
		_switch(r[0], r[1], r[2])
	_pending.clear()

func _request(track: String, fade: float, loop: bool) -> void:
	if not is_inside_tree() or _a == null:
		_pending.append([track, fade, loop])
		return
	_switch(track, fade, loop)

func _switch(track: String, fade: float, loop: bool) -> void:
	if track == _current and loop:
		return
	if not TRACKS.has(track):
		push_warning("Music: ไม่พบเพลง %s" % track)
		return
	var stream := load(TRACKS[track])
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	_current = track
	var old := _a
	_a = _b
	_b = old
	_a.stream = stream
	_a.volume_db = -40.0
	_a.play()
	var target := VOLUME_DB if not muted else -80.0
	if _tween:
		_tween.kill()
	var tw := create_tween().set_parallel(true)
	_tween = tw
	tw.tween_property(_a, "volume_db", target, fade)
	tw.tween_property(_b, "volume_db", -80.0, fade)
	tw.chain().tween_callback(_b.stop)

func _apply_mute() -> void:
	if _tween:
		_tween.kill()
		if _b:
			_b.stop()
	if _a:
		_a.volume_db = -80.0 if muted else VOLUME_DB
