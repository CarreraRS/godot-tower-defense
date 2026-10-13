extends Node3D
class_name TDLevel
## ฉากด่าน: สร้างแผนที่, จัดการทรัพยากร, Phase, การวางยูนิต และเงื่อนไขชนะ/แพ้

signal gold_changed(value: int)
signal lives_changed(value: int, max_value: int)
signal phase_changed(index: int, total: int, running: bool)
signal selection_changed(defender: TDDefender)
signal announce(title: String, subtitle: String, color: Color)
signal boss_hp_changed(ratio: float, visible: bool)
signal game_finished(victory: bool)
signal placement_changed(data: DefenderData)
signal music_toggled(muted: bool)

const GRID_W := 20
const GRID_H := 12
## จุดเลี้ยวของเส้นทางภาคพื้น (หน่วยเป็นช่อง) — แก้เพื่อเปลี่ยนรูปแผนที่
const WAYPOINTS: Array[Vector2i] = [
	Vector2i(-1, 2), Vector2i(5, 2), Vector2i(5, 8), Vector2i(10, 8),
	Vector2i(10, 3), Vector2i(15, 3), Vector2i(15, 9), Vector2i(20, 9),
]
const GATE_POS := Vector3(-2.2, 0, 2)
const CASTLE_POS := Vector3(21.3, 0, 9)
## ปราสาทยิงพลังใส่ศัตรูที่ยืนตีประตู
const CASTLE_FIRE_POS := CASTLE_POS + Vector3(-0.2, 1.6, 0)
const CASTLE_RELOAD := 1.5         ## วินาทีต่อนัด
const CASTLE_FIRST_DELAY := 1.0    ## เวลาตั้งตัวก่อนยิงนัดแรก (ให้ศัตรูได้ตีก่อนสักที)
const CASTLE_DAMAGE := 60.0        ## ดาเมจต่อนัด (ทหารราบตายนัดเดียวเสมอ)
const CASTLE_BOLT_TIME := 0.35     ## เวลาที่ลูกพลังลอยไปถึงเป้า

@export var defenders: Array[DefenderData] = []
@export var start_gold: int = 300
@export var max_lives: int = 20
@export var map_seed: int = 7

@export_group("Scenes")
@export var gate_scene: PackedScene
@export var castle_scene: PackedScene
@export var tile_ground: PackedScene
@export var tile_straight: PackedScene
@export var tile_corner: PackedScene
@export var tile_blocked: Array[PackedScene] = []
@export var decor_scenes: Array[PackedScene] = []
@export var boom_sound: AudioStream

var gold: int = 0
var lives: int = 0
var phase_index: int = 0          ## Phase ถัดไปที่จะเริ่ม
var phase_running: bool = false
var finished: bool = false
var speed_fast: bool = false

var path_cells: Dictionary = {}   ## Vector2i -> true
var blocked: Dictionary = {}      ## Vector2i -> true (ต้นไม้/หิน)
var occupied: Dictionary = {}     ## Vector2i -> TDDefender
var ground_curve: Curve3D
var air_curve: Curve3D

var _groups_pending: int = 0
var _placing: DefenderData
var _ghost: TDDefender
var _selected: TDDefender
var _hover_cell: Vector2i = Vector2i(-99, -99)
var _hover_mesh: MeshInstance3D
var _boss: TDEnemy
var _enemy_cache: Dictionary = {}
var _castle_cd: float = CASTLE_FIRST_DELAY
var _boom_players: Array[AudioStreamPlayer] = []
var _world: Node3D
var _units: Node3D

@onready var cam: Camera3D = $CameraRig/Camera3D
@onready var rig: Node3D = $CameraRig

func _ready() -> void:
	Engine.time_scale = 1.0
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)
	_units = Node3D.new()
	_units.name = "Units"
	add_child(_units)
	_build_path()
	_build_map()
	_build_hover()
	for i in 4:
		var ap := AudioStreamPlayer.new()
		ap.stream = boom_sound
		add_child(ap)
		_boom_players.append(ap)
	gold = start_gold
	lives = max_lives
	Music.play("battle")
	await get_tree().process_frame
	gold_changed.emit(gold)
	lives_changed.emit(lives, max_lives)
	phase_changed.emit(phase_index, WavesLevel01.PHASES.size(), false)
	announce.emit("ฉากที่ 1 : ด่านหน้าเมืองหลวง", "วางยูนิตป้องกัน แล้วกด \"เริ่ม Phase\" เมื่อพร้อม", Color(1, 0.9, 0.6))

# ---------------------------------------------------------------- map
func _build_path() -> void:
	ground_curve = Curve3D.new()
	ground_curve.add_point(GATE_POS + Vector3(0, 0.2, 0))
	for i in WAYPOINTS.size():
		var w := WAYPOINTS[i]
		ground_curve.add_point(Vector3(w.x, 0.2, w.y))
		if i > 0:
			var a := WAYPOINTS[i - 1]
			var step := (w - a).sign()
			var c := a
			while c != w:
				path_cells[c] = true
				c += step
			path_cells[w] = true
	ground_curve.add_point(CASTLE_POS + Vector3(-0.6, 0.2, 0))
	ground_curve.bake_interval = 0.05

	air_curve = Curve3D.new()
	air_curve.add_point(GATE_POS + Vector3(0, 0.0, 0))
	air_curve.add_point(Vector3(6, 0, 3.5))
	air_curve.add_point(Vector3(13, 0, 6.5))
	air_curve.add_point(CASTLE_POS + Vector3(-0.6, 0, 0))
	air_curve.bake_interval = 0.05

func _cell_score(c: Vector2i) -> int:
	var s := 0
	s += 1 if path_cells.has(c + Vector2i(0, -1)) else 0
	s += 2 if path_cells.has(c + Vector2i(1, 0)) else 0
	s += 4 if path_cells.has(c + Vector2i(0, 1)) else 0
	s += 8 if path_cells.has(c + Vector2i(-1, 0)) else 0
	return s

func _build_map() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	# ช่องเส้นทาง (ใช้การหมุนเดียวกับโปรเจกต์ต้นฉบับ)
	for c in path_cells.keys():
		var score := _cell_score(c)
		var scene := tile_straight
		var rot := 0.0
		match score:
			10, 2, 8: rot = 90.0
			1, 4, 5: rot = 0.0
			6: scene = tile_corner; rot = 180.0
			12: scene = tile_corner; rot = 90.0
			9: scene = tile_corner; rot = 0.0
			3: scene = tile_corner; rot = 270.0
		_spawn_tile(scene, c, rot)
	# ช่องว่าง/สิ่งกีดขวาง
	for x in GRID_W:
		for y in GRID_H:
			var c := Vector2i(x, y)
			if path_cells.has(c):
				continue
			var near_path := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if path_cells.has(c + d):
					near_path = true
			if not near_path and rng.randf() < 0.13 and tile_blocked.size() > 0:
				blocked[c] = true
				_spawn_tile(tile_blocked[rng.randi_range(0, tile_blocked.size() - 1)], c, rng.randi_range(0, 3) * 90.0)
			else:
				_spawn_tile(tile_ground, c, rng.randi_range(0, 3) * 90.0)
	# พื้นรอบนอก + ต้นไม้ตกแต่ง
	for i in 70:
		var p := Vector3(rng.randf_range(-7, 27), 0, rng.randf_range(-6, 18))
		var inside := p.x > -0.8 and p.x < GRID_W - 0.2 and p.z > -0.8 and p.z < GRID_H - 0.2
		if inside or p.distance_to(GATE_POS) < 2.5 or p.distance_to(CASTLE_POS) < 3.0:
			continue
		if abs(p.z - 2) < 0.9 and p.x < 0 or abs(p.z - 9) < 0.9 and p.x > GRID_W - 1:
			continue
		if decor_scenes.is_empty():
			break
		var d: Node3D = decor_scenes[rng.randi_range(0, decor_scenes.size() - 1)].instantiate()
		_world.add_child(d)
		d.position = p
		d.rotation.y = rng.randf() * TAU
		d.scale = Vector3.ONE * rng.randf_range(1.2, 2.2)
	var gate: Node3D = gate_scene.instantiate()
	_world.add_child(gate)
	gate.position = GATE_POS
	gate.rotation.y = deg_to_rad(90)
	var castle: Node3D = castle_scene.instantiate()
	_world.add_child(castle)
	castle.position = CASTLE_POS
	castle.rotation.y = deg_to_rad(90)
	castle.scale = Vector3.ONE * 0.8

func _spawn_tile(scene: PackedScene, c: Vector2i, rot_deg: float) -> void:
	var t: Node3D = scene.instantiate()
	_world.add_child(t)
	t.position = Vector3(c.x, 0, c.y)
	t.rotation_degrees.y = rot_deg

func _build_hover() -> void:
	_hover_mesh = MeshInstance3D.new()
	var q := BoxMesh.new()
	q.size = Vector3(0.96, 0.02, 0.96)
	q.material = FX.emissive_mat(Color(0.3, 1, 0.4, 0.45), 1.0, true)
	_hover_mesh.mesh = q
	_hover_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hover_mesh.visible = false
	add_child(_hover_mesh)

func is_buildable(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GRID_W and c.y < GRID_H \
		and not path_cells.has(c) and not blocked.has(c) and not occupied.has(c)

# ---------------------------------------------------------------- input
func _mouse_cell(mp: Vector2 = Vector2(-1, -1)) -> Variant:
	if mp == Vector2(-1, -1):
		mp = get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	var hit: Variant = Plane(Vector3.UP, 0.2).intersects_ray(from, dir)
	if hit == null:
		return null
	var h: Vector3 = hit
	return Vector2i(roundi(h.x), roundi(h.z))

func _process(_delta: float) -> void:
	var mc: Variant = _mouse_cell()
	if mc == null:
		_hover_mesh.visible = false
		return
	var c: Vector2i = mc
	_hover_cell = c
	if _placing:
		var ok := is_buildable(c) and gold >= _placing.cost
		_hover_mesh.visible = true
		_hover_mesh.position = Vector3(c.x, 0.21, c.y)
		var col := Color(0.3, 1, 0.4, 0.45) if ok else Color(1, 0.25, 0.2, 0.45)
		(_hover_mesh.mesh as BoxMesh).material = FX.emissive_mat(col, 1.0, true)
		_ghost.visible = true
		_ghost.position = Vector3(c.x, 0.2, c.y)
		_ghost.set_ring_color(Color(0.4, 1, 0.5) if ok else Color(1, 0.3, 0.3))
	else:
		_hover_mesh.visible = occupied.has(c)
		if occupied.has(c):
			_hover_mesh.position = Vector3(c.x, 0.21, c.y)
			(_hover_mesh.mesh as BoxMesh).material = FX.emissive_mat(Color(1, 1, 1, 0.25), 1.0, true)

func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if _placing:
				_try_place(mb.position)
			else:
				var mc: Variant = _mouse_cell(mb.position)
				if mc != null and occupied.has(mc):
					select(occupied[mc])
				else:
					select(null)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement()
			select(null)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_ESCAPE:
			cancel_placement()
			select(null)
		elif k == KEY_SPACE:
			start_phase()
		elif k >= KEY_1 and k <= KEY_9:
			var i := k - KEY_1
			if i < defenders.size():
				begin_placement(defenders[i])
		elif k == KEY_U and _selected:
			upgrade_selected()
		elif k == KEY_X and _selected:
			sell_selected()
		elif k == KEY_M:
			Music.toggle_mute()
			music_toggled.emit(Music.muted)

# ---------------------------------------------------------------- placement / selection
func begin_placement(d: DefenderData) -> void:
	if finished:
		return
	cancel_placement()
	select(null)
	if gold < d.cost:
		announce.emit("ทองไม่พอ", "%s ต้องใช้ %d ทอง" % [d.thai_name, d.cost], Color(1, 0.4, 0.3))
		return
	_placing = d
	_ghost = TDDefender.new()
	_ghost.setup(d)
	_ghost.preview = true
	_units.add_child(_ghost)
	_ghost.show_range(true)
	_ghost.visible = false
	for gi in _ghost.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).transparency = 0.35
	placement_changed.emit(d)

func cancel_placement() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	if _placing:
		_placing = null
		placement_changed.emit(null)
	_hover_mesh.visible = false

func _try_place(mp: Vector2) -> void:
	var mc: Variant = _mouse_cell(mp)
	if mc == null:
		return
	var c: Vector2i = mc
	if not is_buildable(c):
		return
	if gold < _placing.cost:
		announce.emit("ทองไม่พอ", "", Color(1, 0.4, 0.3))
		cancel_placement()
		return
	var d := _placing
	var u := TDDefender.new()
	u.setup(d)
	u.cell = c
	u.level_ref = self
	u.total_spent = d.cost
	_units.add_child(u)
	u.position = Vector3(c.x, 0.2, c.y)
	occupied[c] = u
	add_gold(-d.cost)
	FX.ring(_units, u.global_position, 0.7, Color(0.9, 0.9, 1.0), 0.35)
	# กด Shift ค้างไว้เพื่อวางต่อเนื่อง
	if not Input.is_key_pressed(KEY_SHIFT) or gold < d.cost:
		cancel_placement()

func select(u: TDDefender) -> void:
	if _selected and is_instance_valid(_selected):
		_selected.show_range(false)
	_selected = u
	if u:
		u.show_range(true)
		u.set_ring_color(Color(1, 1, 1))
	selection_changed.emit(u)

func upgrade_selected() -> void:
	if not _selected or not _selected.can_upgrade():
		return
	var cost := _selected.next_upgrade_cost()
	if gold < cost:
		announce.emit("ทองไม่พอสำหรับอัปเกรด", "", Color(1, 0.4, 0.3))
		return
	add_gold(-cost)
	_selected.total_spent += cost
	_selected.upgrade()
	selection_changed.emit(_selected)

func sell_selected() -> void:
	if not _selected:
		return
	var u := _selected
	select(null)
	add_gold(u.sell_value())
	FX.float_text(_units, u.global_position + Vector3.UP * 0.6, "+%d" % u.sell_value(), Color(1, 0.85, 0.2))
	occupied.erase(u.cell)
	u.queue_free()

func add_gold(v: int) -> void:
	gold += v
	gold_changed.emit(gold)

# ---------------------------------------------------------------- phases
func start_phase() -> void:
	if phase_running or finished or phase_index >= WavesLevel01.PHASES.size():
		return
	var ph: Dictionary = WavesLevel01.PHASES[phase_index]
	phase_running = true
	phase_changed.emit(phase_index, WavesLevel01.PHASES.size(), true)
	var col := Color(1, 0.3, 0.25) if ph.get("boss", false) else Color(1, 0.9, 0.6)
	if ph.get("boss", false):
		Music.play("boss")
	announce.emit(ph["title"], ph["subtitle"], col)
	_groups_pending = 0
	for g in ph["groups"]:
		_groups_pending += 1
		_run_group(g)

func _run_group(g: Dictionary) -> void:
	var d := _enemy_data(g["enemy"])
	await get_tree().create_timer(g.get("delay", 0.0), false).timeout
	for i in int(g["count"]):
		if finished:
			return
		spawn_enemy(d)
		await get_tree().create_timer(g.get("interval", 1.0), false).timeout
	_groups_pending -= 1
	_check_phase_end()

func _enemy_data(id: String) -> EnemyData:
	if not _enemy_cache.has(id):
		_enemy_cache[id] = load("res://td/data/enemies/%s.tres" % id)
	return _enemy_cache[id]

func spawn_enemy(d: EnemyData) -> TDEnemy:
	var e := TDEnemy.new()
	e.setup(d, air_curve if d.is_air else ground_curve, 1.0 + 0.04 * phase_index)
	e.died.connect(_on_enemy_died)
	e.attacked_base.connect(_on_enemy_attack)
	_units.add_child(e)
	if d.is_boss:
		_boss = e
		boss_hp_changed.emit(1.0, true)
		announce.emit("⚠ BOSS: %s" % d.thai_name, "หยุดมันก่อนถึงเมือง!", Color(1, 0.3, 0.25))
	return e

func _on_enemy_died(e: TDEnemy) -> void:
	add_gold(e.data.reward)
	if e == _boss:
		boss_hp_changed.emit(0.0, false)
		_boss = null
	_check_phase_end.call_deferred()

## ศัตรูตีประตูเมืองหนึ่งครั้ง
func _on_enemy_attack(e: TDEnemy, dmg: int) -> void:
	if finished:
		return
	lives = max(lives - dmg, 0)
	lives_changed.emit(lives, max_lives)
	var hit := e.strike_point()
	FX.explosion(_units, hit, 0.45 if not e.data.is_boss else 1.0)
	FX.float_text(_units, hit + Vector3.UP * 0.3, "-%d" % dmg, Color(1.0, 0.3, 0.25), 44)
	play_boom(-10.0)
	if rig.has_method("shake"):
		rig.shake(0.08 if not e.data.is_boss else 0.3)
	if lives <= 0:
		_finish(false)

func _physics_process(delta: float) -> void:
	_castle_process(delta)
	if _boss and is_instance_valid(_boss) and _boss.alive:
		boss_hp_changed.emit(_boss.hp / (_boss.data.max_hp * _boss.hp_mult), true)

# ---------------------------------------------------------------- ปราสาทยิงสวน
func _castle_process(delta: float) -> void:
	if finished:
		return
	var target := _castle_pick_target()
	if target == null:
		_castle_cd = CASTLE_FIRST_DELAY
		return
	_castle_cd -= delta
	if _castle_cd <= 0.0:
		_castle_cd = CASTLE_RELOAD
		_castle_fire(target)

func _castle_pick_target() -> TDEnemy:
	## เลือกศัตรูที่ยืนตีประตูอยู่ ตัวที่เลือดเหลือน้อยสุดก่อน
	var best: TDEnemy = null
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as TDEnemy
		if e and e.alive and e.attacking:
			if best == null or e.hp < best.hp:
				best = e
	return best

func _castle_fire(target: TDEnemy) -> void:
	var bolt := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.14
	sm.height = 0.28
	sm.material = FX.emissive_mat(Color(0.55, 0.85, 1.0), 4.0)
	bolt.mesh = sm
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.5, 0.8, 1.0)
	glow.light_energy = 2.5
	glow.omni_range = 1.5
	bolt.add_child(glow)
	_units.add_child(bolt)
	bolt.global_position = CASTLE_FIRE_POS
	FX.ring(_units, CASTLE_POS, 1.2, Color(0.55, 0.85, 1.0), 0.3)
	FX.hit_spark(_units, CASTLE_FIRE_POS, Color(0.6, 0.9, 1.0), 1.5)
	# ลอยโค้งขึ้นแล้วพุ่งลงหาเป้า
	var start := CASTLE_FIRE_POS
	var target_obj: Object = target
	var tw := bolt.create_tween()
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(bolt):
			return
		var end: Vector3 = (target_obj as TDEnemy).aim_point() if is_instance_valid(target_obj) else bolt.global_position
		var p := start.lerp(end, t)
		p.y += sin(t * PI) * 0.8
		bolt.global_position = p
	, 0.0, 1.0, CASTLE_BOLT_TIME)
	tw.tween_callback(func() -> void:
		_castle_bolt_hit(target_obj, bolt.global_position)
		bolt.queue_free()
	)

func _castle_bolt_hit(target_obj: Object, pos: Vector3) -> void:
	FX.explosion(_units, pos, 0.6)
	FX.ring(_units, Vector3(pos.x, 0.0, pos.z), 0.6, Color(0.55, 0.85, 1.0), 0.3)
	if not is_instance_valid(target_obj):
		return
	var target := target_obj as TDEnemy
	if target == null or not target.alive:
		return
	if target.data.id == &"soldier":
		target.take_damage(target.hp + 1.0, true)   # ทหารราบตายนัดเดียว
	else:
		target.take_damage(CASTLE_DAMAGE, true)

func _check_phase_end() -> void:
	if not phase_running or finished or _groups_pending > 0:
		return
	if get_tree().get_nodes_in_group("enemies").size() > 0:
		return
	phase_running = false
	var bonus := 40 + 15 * phase_index
	phase_index += 1
	if phase_index >= WavesLevel01.PHASES.size():
		_finish(true)
		return
	add_gold(bonus)
	phase_changed.emit(phase_index, WavesLevel01.PHASES.size(), false)
	announce.emit("ผ่าน Phase แล้ว!", "ได้รับทองสนับสนุนจากจักรพรรดิ +%d" % bonus, Color(0.5, 1, 0.5))

func _finish(victory: bool) -> void:
	if finished:
		return
	finished = true
	cancel_placement()
	select(null)
	Engine.time_scale = 1.0
	Music.stinger("victory" if victory else "defeat")
	game_finished.emit(victory)

# ---------------------------------------------------------------- misc
func toggle_speed() -> bool:
	speed_fast = not speed_fast
	Engine.time_scale = 2.0 if speed_fast else 1.0
	return speed_fast

func play_boom(volume_db: float = 0.0) -> void:
	for p in _boom_players:
		if not p.playing:
			p.volume_db = volume_db
			p.pitch_scale = randf_range(0.85, 1.15)
			p.play()
			return

func _exit_tree() -> void:
	Engine.time_scale = 1.0
