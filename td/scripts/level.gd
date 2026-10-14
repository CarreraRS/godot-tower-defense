extends Node3D
class_name TDLevel
## ฉากด่าน: สร้างแผนที่, ทรัพยากร, Phase, การวางยูนิต, เงื่อนไขชนะ/แพ้
## รองรับ 2 โหมด (GameSession.mode): "story" = 6 เฟส แมพพังลงเรื่อย ๆ, "endless" = แมพสุ่ม เล่นจนแพ้

signal gold_changed(value: int)
signal lives_changed(value: int, max_value: int)
signal phase_changed(index: int, total: int, running: bool)
signal selection_changed(defender: TDDefender)
signal announce(title: String, subtitle: String, color: Color)
signal boss_hp_changed(ratio: float, visible: bool)
signal game_finished(victory: bool)
signal placement_changed(data: DefenderData)
signal music_toggled(muted: bool)
signal next_wave_preview(entries: Array)   ## [{data: EnemyData, count: int}]
signal score_changed(score: int, kills: int)
signal story_line(speaker: String, text: String)
signal pause_requested
signal hero_changed(tokens: int)
signal cutscene_requested(lines: Array, done: Callable)

const GRID_W := 20
const GRID_H := 12
## เส้นทางของโหมดเนื้อเรื่อง (หน่วยเป็นช่อง)
const STORY_WAYPOINTS: Array[Vector2i] = [
	Vector2i(-1, 2), Vector2i(5, 2), Vector2i(5, 8), Vector2i(10, 8),
	Vector2i(10, 3), Vector2i(15, 3), Vector2i(15, 9), Vector2i(20, 9),
]
const ENEMY_IDS := ["soldier", "humvee", "tank", "helicopter", "jet", "bomber"]

## ปราสาทยิงพลังใส่ศัตรูที่โจมตีเมือง (ต่อยอดจาก addenemyeffect)
const CASTLE_RELOAD := 1.0
const CASTLE_FIRST_DELAY := 1.0
const CASTLE_DAMAGE := 75.0
const CASTLE_BOLT_TIME := 0.35

@export var defenders: Array[DefenderData] = []
@export var hero_data: DefenderData        ## ผู้กล้า: ปลดล็อกด้วยพิธีอัญเชิญ/เหรียญผู้กล้า
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

var mode: String = "story"
var showcase: bool = false        ## ใช้เป็นฉากหลังของเมนูหลัก (ไม่มี HUD, เล่นเองอัตโนมัติ)
var hero_tokens: int = 0          ## จำนวนครั้งที่วางผู้กล้าได้
var hero_summoned: bool = false
var cutscene_active: bool = false
var _showcase_t: float = 0.0
var _showcase_ab_t: float = 4.0
var gold: int = 0
var lives: int = 0
var phase_index: int = 0          ## Phase ถัดไปที่จะเริ่ม (0-based)
var phase_running: bool = false
var finished: bool = false
var speed_level: int = 0          ## 0=x1 1=x2 2=x3
var kills: int = 0
var score: int = 0
var auto_next: bool = false

var waypoints: Array[Vector2i] = []
var path_cells: Dictionary = {}
var blocked: Dictionary = {}
var occupied: Dictionary = {}
var ground_curve: Curve3D
var air_curve: Curve3D
var gate_pos: Vector3
var castle_pos: Vector3
var theme: Dictionary = {}

var _groups_pending: int = 0
var _placing: DefenderData
var _ghost: TDDefender
var _selected: TDDefender
var _hover_mesh: MeshInstance3D
var _boss: TDEnemy
var _enemy_cache: Dictionary = {}
var _boom_players: Array[AudioStreamPlayer] = []
var _world: Node3D
var _units: Node3D
var _wreck: Node3D
var _castle_cd: float = CASTLE_FIRST_DELAY
var _aura_t: float = 0.0
var _auto_t: float = -1.0
var _rng := RandomNumberGenerator.new()
var _pending_bonus: int = 0
var _awaiting_interlude: bool = false
var _castle_node: Node3D
var _defeat_pending: bool = false
var _hero_ab_left: float = 0.0       ## คูลดาวน์ทักษะผู้กล้าที่ค้างไว้ตอนเรียกกลับ
var _hero_redeploy_t: float = 0.0    ## เวลาที่ต้องรอก่อนส่งผู้กล้าลงสนามอีกครั้ง
const HERO_REDEPLOY := 10.0
var _sfx: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_i: int = 0
var _sfx_last: Dictionary = {}
var _env: Environment
var _sun: DirectionalLight3D
var _gate_node: Node3D

@onready var cam: Camera3D = $CameraRig/Camera3D
@onready var rig: Node3D = $CameraRig

func _ready() -> void:
	Engine.time_scale = 1.0
	mode = GameSession.mode
	_rng.seed = map_seed if mode == "story" else GameSession.endless_seed
	_env = ($WorldEnvironment as WorldEnvironment).environment.duplicate()
	($WorldEnvironment as WorldEnvironment).environment = _env
	_sun = $Sun
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)
	_wreck = Node3D.new()
	_wreck.name = "Wreckage"
	add_child(_wreck)
	_units = Node3D.new()
	_units.name = "Units"
	add_child(_units)
	_setup_theme()
	_build_path()
	_build_map()
	_build_hover()
	MapDecor.build(self, _world, _rng)
	for i in 4:
		var ap := AudioStreamPlayer.new()
		ap.stream = boom_sound
		add_child(ap)
		_boom_players.append(ap)
	gold = start_gold
	lives = max_lives
	if showcase:
		_setup_showcase()
		return
	Music.play("battle")
	var intro := mode == "story" and not GameSession.skip_cutscenes
	if intro:
		_gate_node.visible = false
	await get_tree().process_frame
	gold_changed.emit(gold)
	lives_changed.emit(lives, max_lives)
	phase_changed.emit(phase_index, total_phases(), false)
	score_changed.emit(score, kills)
	_emit_preview()
	hero_changed.emit(hero_tokens)
	if mode == "story":
		play_cutscene(WavesLevel01.INTRO, func():
			announce.emit("ฉากที่ 1 : ด่านหน้าเมืองหลวง", "วางยูนิตข้างถนน แล้วกด \"เริ่ม Phase\" เมื่อพร้อม", Color(1, 0.9, 0.6)))
	else:
		announce.emit("โหมดไม่สิ้นสุด : %s" % theme.get("name", ""), "ต้านทานให้นานที่สุด — สถิติสูงสุด Wave %d" % GameSession.best_wave(), Color(0.75, 0.85, 1))

func total_phases() -> int:
	return WavesLevel01.PHASES.size() if mode == "story" else -1

# ---------------------------------------------------------------- theme / map
func _setup_theme() -> void:
	var t := "grass"
	if mode == "endless":
		t = ["grass", "snow", "dusk"][_rng.randi_range(0, 2)]
	theme = {"id": t, "name": "ทุ่งหญ้า"}
	if t == "snow":
		theme.name = "ดินแดนหิมะ"
		tile_ground = load("res://assets/snow_tile.glb")
		tile_straight = load("res://assets/snow_tile_straight.glb")
		tile_corner = load("res://assets/snow_tile_cornerRound.glb")
		tile_blocked = [load("res://assets/snow_tile_tree.glb"), load("res://assets/snow_tile_treeDouble.glb"),
			load("res://assets/snow_tile_rock.glb"), load("res://assets/snow_tile_crystal.glb"), load("res://assets/snow_tile_hill.glb")]
		decor_scenes = [load("res://assets/snow_detail_tree.glb"), load("res://assets/snow_detail_treeLarge.glb"),
			load("res://assets/snow_detail_treeLarge.glb"), load("res://assets/snow_detail_rocks.glb")]
		($Ground as MeshInstance3D).set_surface_override_material(0, _flat_mat(Color(0.86, 0.9, 0.95)))
		_env.fog_density = 0.006
		_env.fog_light_color = Color(0.85, 0.9, 1.0)
		_sun.light_color = Color(0.9, 0.95, 1.0)
		var sky := (_env.sky.sky_material as ProceduralSkyMaterial).duplicate() as ProceduralSkyMaterial
		sky.sky_top_color = Color(0.45, 0.55, 0.75)
		sky.sky_horizon_color = Color(0.85, 0.88, 0.95)
		_env.sky = _env.sky.duplicate()
		_env.sky.sky_material = sky
	elif t == "dusk":
		theme.name = "ทุ่งสนธยา"
		_sun.light_color = Color(1.0, 0.62, 0.4)
		_sun.light_energy = 0.9
		_env.ambient_light_energy = 0.4
		var sky2 := (_env.sky.sky_material as ProceduralSkyMaterial).duplicate() as ProceduralSkyMaterial
		sky2.sky_top_color = Color(0.25, 0.18, 0.4)
		sky2.sky_horizon_color = Color(0.95, 0.5, 0.35)
		_env.sky = _env.sky.duplicate()
		_env.sky.sky_material = sky2
		($Ground as MeshInstance3D).set_surface_override_material(0, _flat_mat(Color(0.42, 0.58, 0.45)))

func _flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

func _gen_waypoints() -> Array[Vector2i]:
	## สุ่มเส้นทางซิกแซกซ้ายไปขวา (โหมดไม่สิ้นสุด)
	var pts: Array[Vector2i] = []
	var y := _rng.randi_range(2, GRID_H - 3)
	pts.append(Vector2i(-1, y))
	var x := _rng.randi_range(2, 4)
	pts.append(Vector2i(x, y))
	while x < 16:
		var ny := y
		var tries := 0
		while abs(ny - y) < 3 and tries < 20:
			ny = _rng.randi_range(1, GRID_H - 2)
			tries += 1
		pts.append(Vector2i(x, ny))
		y = ny
		x = min(x + _rng.randi_range(3, 5), 18)
		pts.append(Vector2i(x, y))
	pts.append(Vector2i(GRID_W, y))
	return pts

func _build_path() -> void:
	waypoints = STORY_WAYPOINTS.duplicate() if mode == "story" else _gen_waypoints()
	gate_pos = Vector3(-2.2, 0, waypoints[0].y)
	castle_pos = Vector3(21.3, 0, waypoints[waypoints.size() - 1].y)
	ground_curve = Curve3D.new()
	ground_curve.add_point(gate_pos + Vector3(0, 0.2, 0))
	for i in waypoints.size():
		var w := waypoints[i]
		ground_curve.add_point(Vector3(w.x, 0.2, w.y))
		if i > 0:
			var a := waypoints[i - 1]
			var step := (w - a).sign()
			var c := a
			while c != w:
				path_cells[c] = true
				c += step
			path_cells[w] = true
	ground_curve.add_point(castle_pos + Vector3(-0.6, 0.2, 0))
	ground_curve.bake_interval = 0.05
	# หน่วยบินบินตามถนนแต่ตัดโค้งให้นุ่มขึ้น (ยิงถึงได้จากป้อมข้างถนน)
	air_curve = Curve3D.new()
	var n := ground_curve.point_count
	for i in n:
		var p := ground_curve.get_point_position(i)
		p.y = 0.0
		var h_in := Vector3.ZERO
		var h_out := Vector3.ZERO
		if i > 0 and i < n - 1:
			var prev := ground_curve.get_point_position(i - 1)
			var nxt := ground_curve.get_point_position(i + 1)
			var tangent := (nxt - prev)
			tangent.y = 0
			tangent = tangent.normalized() * 0.9
			h_in = -tangent
			h_out = tangent
		air_curve.add_point(p, h_in, h_out)
	air_curve.bake_interval = 0.05

func _cell_score(c: Vector2i) -> int:
	var s := 0
	s += 1 if path_cells.has(c + Vector2i(0, -1)) else 0
	s += 2 if path_cells.has(c + Vector2i(1, 0)) else 0
	s += 4 if path_cells.has(c + Vector2i(0, 1)) else 0
	s += 8 if path_cells.has(c + Vector2i(-1, 0)) else 0
	return s

func _build_map() -> void:
	for c in path_cells.keys():
		var sc := _cell_score(c)
		var scene := tile_straight
		var rot := 0.0
		match sc:
			10, 2, 8:
				rot = 90.0
			1, 4, 5:
				rot = 0.0
			6:
				scene = tile_corner
				rot = 180.0
			12:
				scene = tile_corner
				rot = 90.0
			9:
				scene = tile_corner
				rot = 0.0
			3:
				scene = tile_corner
				rot = 270.0
		_spawn_tile(scene, c, rot)
	for x in GRID_W:
		for y in GRID_H:
			var c := Vector2i(x, y)
			if path_cells.has(c):
				continue
			var near_path := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if path_cells.has(c + d):
					near_path = true
			if not near_path and _rng.randf() < 0.13 and tile_blocked.size() > 0:
				blocked[c] = true
				_spawn_tile(tile_blocked[_rng.randi_range(0, tile_blocked.size() - 1)], c, _rng.randi_range(0, 3) * 90.0)
			else:
				_spawn_tile(tile_ground, c, _rng.randi_range(0, 3) * 90.0)
	for i in 70:
		var p := Vector3(_rng.randf_range(-7, 27), 0, _rng.randf_range(-6, 18))
		var inside := p.x > -0.8 and p.x < GRID_W - 0.2 and p.z > -0.8 and p.z < GRID_H - 0.2
		if inside or p.distance_to(gate_pos) < 3.0 or p.distance_to(castle_pos) < 4.5:
			continue
		if abs(p.z - gate_pos.z) < 1.0 and p.x < 0 or abs(p.z - castle_pos.z) < 1.0 and p.x > GRID_W - 1:
			continue
		if decor_scenes.is_empty():
			break
		var d: Node3D = decor_scenes[_rng.randi_range(0, decor_scenes.size() - 1)].instantiate()
		_world.add_child(d)
		d.position = p
		d.rotation.y = _rng.randf() * TAU
		d.scale = Vector3.ONE * _rng.randf_range(1.2, 2.2)
	_gate_node = gate_scene.instantiate()
	_world.add_child(_gate_node)
	_gate_node.position = gate_pos
	_gate_node.rotation.y = deg_to_rad(90)
	var castle: Node3D = castle_scene.instantiate()
	_castle_node = castle
	_world.add_child(castle)
	castle.position = castle_pos
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

func castle_hit_point(from: Vector3) -> Vector3:
	var p := castle_pos + Vector3(-1.0, 0.45, clamp(from.z - castle_pos.z, -0.7, 0.7))
	if from.y > 0.8:
		p = castle_pos + Vector3(-0.4, 1.2, clamp(from.z - castle_pos.z, -0.8, 0.8))
	return p

# ---------------------------------------------------------------- queries used by enemies
func find_defender_near(pos: Vector3, r: float) -> TDDefender:
	var best: TDDefender = null
	var bd := r
	for n in get_tree().get_nodes_in_group("defenders"):
		var d := n as TDDefender
		if d == null or d.preview or d.is_stunned():
			continue
		var dist := Vector2(d.global_position.x - pos.x, d.global_position.z - pos.z).length()
		if dist <= bd:
			bd = dist
			best = d
	return best

func stun_defenders(pos: Vector3, r: float, t: float) -> void:
	for n in get_tree().get_nodes_in_group("defenders"):
		var d := n as TDDefender
		if d and not d.preview and Vector2(d.global_position.x - pos.x, d.global_position.z - pos.z).length() <= r:
			d.stun(t)

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

func _process(delta: float) -> void:
	if showcase:
		_showcase_process(delta)
		return
	_update_hover()
	# เริ่มเฟสถัดไปอัตโนมัติ (โหมดไม่สิ้นสุด)
	if _auto_t > 0.0:
		_auto_t -= delta / max(Engine.time_scale, 0.01)
		if _auto_t <= 0.0:
			_auto_t = -1.0
			if auto_next and not phase_running:
				start_phase()

func _update_hover() -> void:
	var mc: Variant = _mouse_cell()
	if mc == null:
		_hover_mesh.visible = false
		return
	var c: Vector2i = mc
	if _placing:
		var ok := can_place(_placing, c)
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

## เหรียญที่ใช้อัญเชิญผู้กล้า (โหมดไม่สิ้นสุด 15 เหรียญ / เนื้อเรื่องได้จากพิธีอัญเชิญ)
const HERO_COST_ENDLESS := 15

func hero_cost() -> int:
	return HERO_COST_ENDLESS if mode == "endless" else 1

func can_place(d: DefenderData, c: Vector2i) -> bool:
	if d == hero_data:
		return is_buildable(c) and hero_tokens >= hero_cost() and not has_unique(d) and _hero_redeploy_t <= 0.0
	return is_buildable(c) and gold >= d.cost and not (d.unique and has_unique(d))

func can_afford(d: DefenderData) -> bool:
	if d == hero_data:
		return hero_tokens >= hero_cost() and not has_unique(d)
	return gold >= d.cost

func has_unique(d: DefenderData) -> bool:
	for u in occupied.values():
		if (u as TDDefender).data == d:
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if finished or cutscene_active or showcase:
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
			if _placing or _selected:
				cancel_placement()
				select(null)
			else:
				pause_requested.emit()
		elif k == KEY_SPACE:
			start_phase()
		elif k >= KEY_1 and k <= KEY_9:
			var i := k - KEY_1
			if i < defenders.size():
				begin_placement(defenders[i])
		elif k == KEY_F and _selected:
			use_selected_ability()
		elif k == KEY_H and hero_data:
			begin_placement(hero_data)
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
	if d.unique and has_unique(d):
		announce.emit("%s อยู่ในสนามแล้ว" % d.thai_name, "คลิกที่ผู้กล้าแล้วกด F เพื่อใช้ทักษะ", Color(1, 0.6, 0.3))
		return
	if d == hero_data and _hero_redeploy_t > 0.0 and hero_tokens >= hero_cost():
		announce.emit("ผู้กล้ากำลังพักฟื้นที่ปราสาท", "ส่งลงสนามได้อีกครั้งใน %d วินาที" % ceili(_hero_redeploy_t), Color(1, 0.8, 0.4))
		return
	if d == hero_data and hero_tokens < hero_cost():
		if mode == "story":
			announce.emit("ผู้กล้ายังไม่มาถึง", "ผู้กล้าจะถูกอัญเชิญเมื่อบอสปรากฏตัว", Color(1, 0.8, 0.4))
		else:
			announce.emit("เหรียญผู้กล้าไม่พอ (%d/%d)" % [hero_tokens, hero_cost()], "ได้รับ 1 เหรียญทุกครั้งที่ผ่าน Wave", Color(1, 0.8, 0.4))
		return
	if d != hero_data and gold < d.cost:
		announce.emit("ทองไม่พอ", "%s ต้องใช้ %d ทอง" % [d.thai_name, d.cost], Color(1, 0.4, 0.3))
		return
	_placing = d
	_ghost = TDDefender.new()
	_ghost.setup(d)
	_ghost.preview = true
	_units.add_child(_ghost)
	_ghost.remove_from_group("defenders")
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
	if _hover_mesh:
		_hover_mesh.visible = false

func _try_place(mp: Vector2) -> void:
	var mc: Variant = _mouse_cell(mp)
	if mc == null:
		return
	var c: Vector2i = mc
	if not can_place(_placing, c):
		return
	var d := _placing
	place_defender(d, c)
	if not Input.is_key_pressed(KEY_SHIFT) or gold < d.cost or d.unique:
		cancel_placement()

func place_defender(d: DefenderData, c: Vector2i) -> TDDefender:
	var u := TDDefender.new()
	u.setup(d)
	u.cell = c
	u.level_ref = self
	u.total_spent = d.cost
	_units.add_child(u)
	u.position = Vector3(c.x, 0.2, c.y)
	occupied[c] = u
	if d == hero_data:
		u.total_spent = 0
		u.ability_left = max(_hero_ab_left, 0.0)
		hero_tokens -= hero_cost()
		hero_changed.emit(hero_tokens)
		FX.pillar(_units, u.global_position, Color(1.0, 0.95, 0.7), 7.0, 0.6, 1.2)
		FX.ring(_units, u.global_position, 2.0, Color(0.7, 0.9, 1.0), 0.8)
		play_boom(-6.0)
		if rig.has_method("shake"):
			rig.shake(0.3)
		announce.emit("ผู้กล้าอาเรียนลงสนาม!", "คลิกผู้กล้าแล้วกด F เพื่อใช้ \"%s\"" % d.ability_name, Color(0.7, 0.9, 1.0))
	else:
		add_gold(-d.cost)
	FX.ring(_units, u.global_position, 0.7, Color(0.9, 0.9, 1.0), 0.35)
	_update_auras()
	return u

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
	_update_auras()
	selection_changed.emit(_selected)

func sell_selected() -> void:
	if not _selected:
		return
	var u := _selected
	select(null)
	if u.data == hero_data:
		hero_tokens += hero_cost()
		_hero_ab_left = u.ability_left
		_hero_redeploy_t = HERO_REDEPLOY
		announce.emit("ผู้กล้ากลับไปพักที่ปราสาท", "ส่งลงสนามใหม่ได้ใน %d วินาที (คูลดาวน์ทักษะนับต่อ)" % int(HERO_REDEPLOY), Color(0.8, 0.9, 1.0))
		hero_changed.emit(hero_tokens)
		FX.pillar(_units, u.global_position, Color(1.0, 0.95, 0.7), 5.0, 0.4, 0.8)
	else:
		add_gold(u.sell_value())
		FX.float_text(_units, u.global_position + Vector3.UP * 0.6, "+%d" % u.sell_value(), Color(1, 0.85, 0.2))
	occupied.erase(u.cell)
	u.remove_from_group("defenders")
	u.queue_free()
	_update_auras.call_deferred()

func use_selected_ability() -> void:
	if _selected and is_instance_valid(_selected):
		if not _selected.use_ability():
			if _selected.data.ability != DefenderData.Ability.NONE:
				announce.emit("ทักษะยังไม่พร้อม", "อีก %d วินาที" % ceili(_selected.ability_left), Color(1, 0.7, 0.4))
		selection_changed.emit(_selected)

func add_gold(v: int) -> void:
	gold += v
	gold_changed.emit(gold)

func _update_auras() -> void:
	## ออร่าผู้กล้า: เพิ่มดาเมจให้ยูนิตรอบตัว
	var heroes: Array = []
	for u in occupied.values():
		var d := u as TDDefender
		if is_instance_valid(d) and d.data.aura_radius > 0.0:
			heroes.append(d)
	for u in occupied.values():
		var d2 := u as TDDefender
		if not is_instance_valid(d2):
			continue
		var m := 1.0
		for h in heroes:
			if h != d2 and h.global_position.distance_to(d2.global_position) <= h.aura_radius() + 0.05:
				m = max(m, h.aura_mult())
		d2.buff_mult = m

# ---------------------------------------------------------------- phases
func current_phase_data(i: int) -> Dictionary:
	if mode == "story":
		return WavesLevel01.PHASES[i] if i < WavesLevel01.PHASES.size() else {}
	return _endless_phase(i + 1)

func _endless_phase(n: int) -> Dictionary:
	## สร้างเวฟอัตโนมัติ: ยิ่งไกลยิ่งยากและมีศัตรูชนิดใหม่
	var r := RandomNumberGenerator.new()
	r.seed = GameSession.endless_seed + n * 7919
	var groups: Array = []
	var budget := 8.0 + n * 4.0 + pow(n, 1.35)
	var pool := [["soldier", 1.0]]
	if n >= 3: pool.append(["humvee", 3.0])
	if n >= 5: pool.append(["helicopter", 5.0])
	if n >= 6: pool.append(["tank", 8.0])
	if n >= 8: pool.append(["jet", 4.0])
	var boss := n % 10 == 0
	if boss:
		groups.append({"enemy": "bomber", "count": int(n / 10), "interval": 6.0, "delay": 12.0})
		budget *= 0.6
	var kinds: int = min(pool.size(), 1 + r.randi_range(0, 2))
	pool.shuffle()
	var delay := 0.0
	for k in kinds:
		var e: Array = pool[k]
		var share := budget / kinds
		var count: int = max(2, int(share / float(e[1])))
		count = min(count, 30)
		groups.append({"enemy": e[0], "count": count, "interval": clamp(14.0 / count, 0.5, 3.0), "delay": delay})
		delay += r.randf_range(3.0, 7.0)
	return {"title": ("BOSS WAVE %d" if boss else "WAVE %d") % n,
		"subtitle": "ระลอกที่ %d จากประตูมิติ" % n, "groups": groups, "boss": boss}

func _hp_mult(i: int) -> float:
	if mode == "story":
		return 1.0 + 0.18 * i
	var n := i
	return 1.0 + 0.12 * n + 0.009 * n * n

func _emit_preview() -> void:
	var ph := current_phase_data(phase_index)
	var counts := {}
	var order: Array = []
	for g in ph.get("groups", []):
		if not counts.has(g.enemy):
			counts[g.enemy] = 0
			order.append(g.enemy)
		counts[g.enemy] += int(g.count)
	var entries: Array = []
	for id in order:
		entries.append({"data": _enemy_data(id), "count": counts[id]})
	next_wave_preview.emit(entries)

func start_phase() -> void:
	if phase_running or finished or cutscene_active or _awaiting_interlude or showcase:
		return
	var ph := current_phase_data(phase_index)
	if ph.is_empty():
		return
	_auto_t = -1.0
	phase_running = true
	phase_changed.emit(phase_index, total_phases(), true)
	var col := Color(1, 0.3, 0.25) if ph.get("boss", false) else Color(1, 0.9, 0.6)
	if ph.get("boss", false):
		Music.play("boss")
	announce.emit(ph["title"], ph["subtitle"], col)
	if mode == "story" and ph.has("line"):
		story_line.emit("advisor", ph["line"])
	_groups_pending = 0
	for g in ph["groups"]:
		_groups_pending += 1
		_run_group(g, phase_index)

func _run_group(g: Dictionary, pidx: int) -> void:
	var d := _enemy_data(g["enemy"])
	var siren_lead := 4.5 if d.is_boss else 0.0
	await get_tree().create_timer(max(g.get("delay", 0.0) - siren_lead, 0.0), false).timeout
	if d.is_boss and not finished:
		# เสียงไซเรนดังมาจากอีกฝากของประตูมิติ ก่อนบอสโผล่
		play_sfx("siren", 0.0, 0.0)
		announce.emit("เสียงไซเรนประหลาดดังมาจากประตูมิติ!", "มีบางอย่างขนาดมหึมากำลังจะออกมา...", Color(1, 0.4, 0.35))
		if _gate_node:
			var tw := _gate_node.create_tween().set_loops(4)
			tw.tween_property(_gate_node, "scale", Vector3.ONE * (_gate_node.scale.x * 1.06), 0.5)
			tw.tween_property(_gate_node, "scale", Vector3.ONE * _gate_node.scale.x, 0.5)
		rig.shake(0.15)
		await get_tree().create_timer(siren_lead, false).timeout
	for i in int(g["count"]):
		if finished:
			return
		spawn_enemy(d, pidx)
		await get_tree().create_timer(g.get("interval", 1.0), false).timeout
	_groups_pending -= 1
	_check_phase_end()

func _enemy_data(id: String) -> EnemyData:
	if not _enemy_cache.has(id):
		_enemy_cache[id] = load("res://td/data/enemies/%s.tres" % id)
	return _enemy_cache[id]

func spawn_enemy(d: EnemyData, pidx: int = -1) -> TDEnemy:
	if pidx < 0:
		pidx = phase_index
	var e := TDEnemy.new()
	e.setup(d, air_curve if d.is_air else ground_curve, _hp_mult(pidx), self)
	e.died.connect(_on_enemy_died)
	e.attacked_base.connect(_on_enemy_attack)
	e.removed.connect(func(_x): _check_phase_end.call_deferred())
	_units.add_child(e)
	if not showcase and GameSession.mark_seen(String(d.id)) and not d.is_boss:
		show_story_line("scout", "พบศัตรูชนิดใหม่: %s! บันทึกลงสมุดหน่วยสอดแนมแล้ว (ดูได้ในทำเนียบกองทัพ)" % d.thai_name)
	if d.is_boss:
		_boss = e
		boss_hp_changed.emit(1.0, true)
		if showcase:
			return e
		if mode == "story" and not hero_summoned:
			hero_summoned = true
			Engine.time_scale = 0.08
			play_cutscene(WavesLevel01.HERO_SUMMON, _summon_hero)
		else:
			announce.emit("BOSS: %s" % d.thai_name, "หยุดมันก่อนถึงเมือง!", Color(1, 0.3, 0.25))
			if hero_tokens >= hero_cost() and not has_unique(hero_data):
				show_story_line("advisor", "บอสปรากฏตัวแล้ว! ท่านมีเหรียญผู้กล้า กด H เพื่ออัญเชิญผู้กล้าได้เลย")
	return e

func _on_enemy_died(e: TDEnemy) -> void:
	add_gold(e.data.reward)
	kills += 1
	score += e.data.reward
	score_changed.emit(score, kills)
	if e == _boss:
		boss_hp_changed.emit(0.0, false)
		_boss = null
	_check_phase_end.call_deferred()

func _on_enemy_attack(e: TDEnemy, dmg: int) -> void:
	if finished or _defeat_pending:
		return
	if showcase:
		FX.explosion(_units, e.strike_point(), 0.4)
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
		_begin_defeat()

func _physics_process(delta: float) -> void:
	_castle_process(delta)
	if _hero_redeploy_t > 0.0:
		_hero_redeploy_t -= delta
		if _hero_redeploy_t <= 0.0:
			hero_changed.emit(hero_tokens)
	if _hero_ab_left > 0.0:
		_hero_ab_left -= delta
	_aura_t -= delta
	if _aura_t <= 0.0:
		_aura_t = 0.5
		_update_auras()
	if _boss and is_instance_valid(_boss) and _boss.alive:
		boss_hp_changed.emit(_boss.hp / (_boss.data.max_hp * _boss.hp_mult), true)

func _check_phase_end() -> void:
	if not phase_running or finished or _groups_pending > 0:
		return
	if get_tree().get_nodes_in_group("enemies").size() > 0:
		return
	phase_running = false
	var bonus := 40 + 15 * phase_index
	phase_index += 1
	score += 100 * phase_index
	score_changed.emit(score, kills)
	if mode == "story" and phase_index >= WavesLevel01.PHASES.size():
		boss_hp_changed.emit(0.0, false)
		play_cutscene(WavesLevel01.ENDING, func(): _finish(true))
		return
	phase_changed.emit(phase_index, total_phases(), false)
	_emit_preview()
	Music.play("battle")
	if mode == "story":
		_apply_devastation(phase_index)
		var ph := current_phase_data(phase_index)
		_pending_bonus = bonus
		announce.emit("ผ่าน Phase %d แล้ว!" % phase_index, "", Color(0.5, 1, 0.5))
		var lines: Array = ph.get("interlude", [])
		_awaiting_interlude = true
		await get_tree().create_timer(1.6, false).timeout
		_awaiting_interlude = false
		if finished:
			return
		play_cutscene(lines, func():
			if _pending_bonus > 0:
				_give_bonus())
	else:
		add_gold(bonus)
		hero_tokens += 1
		hero_changed.emit(hero_tokens)
		var sub := "ทองสนับสนุน +%d  •  เหรียญผู้กล้า +1 (%d/%d)" % [bonus, hero_tokens, hero_cost()]
		if hero_tokens == hero_cost() and not has_unique(hero_data):
			show_story_line("advisor", "เหรียญผู้กล้าครบแล้ว! กด H เพื่ออัญเชิญผู้กล้าลงสนาม")
		announce.emit("ต้านไว้ได้! Wave %d" % phase_index, sub, Color(0.5, 1, 0.5))
		if auto_next:
			_auto_t = 5.0

func _finish(victory: bool) -> void:
	if finished:
		return
	finished = true
	cancel_placement()
	select(null)
	Engine.time_scale = 1.0
	if mode == "story" and victory:
		GameSession.set_value("story_cleared", true)
	Music.stinger("victory" if victory else "defeat")
	game_finished.emit(victory)

func endless_record() -> bool:
	return GameSession.submit_endless(phase_index, score)

# ---------------------------------------------------------------- castle defense
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
	var best: TDEnemy = null
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as TDEnemy
		if e and e.alive and e.attacking:
			if best == null or e.hp < best.hp:
				best = e
	return best

func _castle_fire(target: TDEnemy) -> void:
	var fire_pos := castle_pos + Vector3(-0.2, 1.6, 0)
	var dmg := CASTLE_DAMAGE * (1.0 + 0.15 * phase_index)
	FX.ring(_units, castle_pos, 1.2, Color(0.55, 0.85, 1.0), 0.3)
	FX.hit_spark(_units, fire_pos, Color(0.6, 0.9, 1.0), 1.5)
	play_sfx("castle", -10.0)
	var to := target.aim_point()
	FX.lob(_units, fire_pos, to, CASTLE_BOLT_TIME, 0.8, Color(0.55, 0.85, 1.0), func():
		FX.explosion(_units, to, 0.6)
		if is_instance_valid(target) and target.alive:
			if target.data.id == &"soldier":
				target.take_damage(target.hp + 1.0, true)
			else:
				target.take_damage(dmg, true))

# ---------------------------------------------------------------- story: แมพพังลงทุกเฟส
func _apply_devastation(stage: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 1000 + stage
	var k := clampf(stage / 5.0, 0.0, 1.0)
	# ท้องฟ้ามืดลง ไฟและควันมากขึ้น
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_sun, "light_color", Color(1, 0.88, 0.72).lerp(Color(1.0, 0.68, 0.52), k), 2.0)
	tw.tween_property(_sun, "light_energy", lerp(1.1, 0.85, k), 2.0)
	tw.tween_property(_env, "fog_density", lerp(0.002, 0.006, k), 2.0)
	tw.tween_property(_env, "fog_light_color", Color(0.75, 0.75, 0.8).lerp(Color(0.55, 0.45, 0.45), k), 2.0)
	tw.tween_property(_env, "ambient_light_energy", lerp(0.55, 0.35, k), 2.0)
	var sky := _env.sky.sky_material as ProceduralSkyMaterial
	if sky:
		tw.tween_property(sky, "sky_top_color", Color(0.22, 0.32, 0.58).lerp(Color(0.25, 0.15, 0.25), k), 2.0)
		tw.tween_property(sky, "sky_horizon_color", Color(0.85, 0.66, 0.52).lerp(Color(0.75, 0.42, 0.3), k), 2.0)
	if _gate_node:
		tw.tween_property(_gate_node, "scale", Vector3.ONE * (1.0 + 0.08 * stage), 2.0)
	# หลุมระเบิด เศษซาก และไฟ
	for i in 3 + stage:
		var p := Vector3(r.randf_range(-1.5, GRID_W + 0.5), 0.0, r.randf_range(-1.0, GRID_H))
		var c := Vector2i(roundi(p.x), roundi(p.z))
		if occupied.has(c):
			continue
		var on_path := path_cells.has(c)
		MapDecor.crater(_wreck, Vector3(p.x, 0.205 if (on_path or (c.x >= 0 and c.x < GRID_W and c.y >= 0 and c.y < GRID_H)) else 0.0, p.z), r.randf_range(0.25, 0.5))
		if r.randf() < 0.2 + 0.06 * stage:
			MapDecor.fire(_wreck, Vector3(p.x, 0.22, p.z), r.randf_range(0.6, 1.2))
		elif r.randf() < 0.5:
			MapDecor.debris(_wreck, Vector3(p.x, 0.2, p.z), r)
	for i in stage:
		MapDecor.smoke_column(_wreck, Vector3(r.randf_range(0, GRID_W), 0.2, r.randf_range(-3, GRID_H + 2)))

# ---------------------------------------------------------------- misc
func cycle_speed() -> int:
	speed_level = (speed_level + 1) % 3
	Engine.time_scale = [1.0, 2.0, 3.0][speed_level]
	return speed_level + 1

## เสียงประกอบการโจมตี/ทักษะ (ไฟล์ res://td/audio/sfx_<name>.wav)
func play_sfx(sfx_name: String, vol_db: float = -8.0, pitch_var: float = 0.08) -> void:
	if not _sfx.has(sfx_name):
		var path := "res://td/audio/sfx_%s.wav" % sfx_name
		if not ResourceLoader.exists(path):
			return
		_sfx[sfx_name] = load(path)
	var now := Time.get_ticks_msec()
	if now - int(_sfx_last.get(sfx_name, -1000)) < 70:
		return
	_sfx_last[sfx_name] = now
	if _sfx_players.is_empty():
		for i in 10:
			var p := AudioStreamPlayer.new()
			add_child(p)
			_sfx_players.append(p)
	var ap := _sfx_players[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx_players.size()
	ap.stream = _sfx[sfx_name]
	ap.volume_db = vol_db - (12.0 if showcase else 0.0)
	ap.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	ap.play()

func play_boom(volume_db: float = 0.0) -> void:
	for p in _boom_players:
		if not p.playing:
			p.volume_db = volume_db
			p.pitch_scale = randf_range(0.85, 1.15)
			p.play()
			return

func _exit_tree() -> void:
	Engine.time_scale = 1.0

# ---------------------------------------------------------------- story / cutscenes
func show_story_line(who: String, text: String) -> void:
	story_line.emit(who, text)

func play_cutscene(lines: Array, done: Callable = Callable()) -> void:
	if lines.is_empty() or GameSession.skip_cutscenes or showcase:
		for l in lines:
			if l.has("action"):
				cutscene_action(l["action"])
		_restore_speed()
		if done.is_valid():
			done.call()
		return
	cutscene_active = true
	cancel_placement()
	select(null)
	rig.save_view()
	rig.locked = true
	cutscene_requested.emit(lines, func():
		rig.restore_view()
		rig.locked = false
		cutscene_active = false
		_restore_speed()
		if done.is_valid():
			done.call())

func _restore_speed() -> void:
	Engine.time_scale = [1.0, 2.0, 3.0][speed_level]

## เลื่อนกล้องไปยังจุดที่บทพูดอ้างถึง
func cutscene_focus(target: String) -> void:
	match target:
		"gate":
			rig.focus(gate_pos + Vector3(2.0, 0, 0), 10.0)
		"castle":
			rig.focus(castle_pos + Vector3(-2.0, 0, 0), 10.0)
		"field":
			rig.focus(Vector3(10, 0, 6.5), 19.0)
		"boss":
			if _boss and is_instance_valid(_boss):
				rig.focus(_boss.global_position + Vector3(1.5, 0, 0), 11.0)
			else:
				rig.focus(gate_pos + Vector3(2.0, 0, 0), 11.0)

func cutscene_anchor(who: String) -> Vector3:
	## จุดในโลกที่กล่องข้อความของผู้พูดชี้ไป
	match who:
		"king":
			return castle_pos + Vector3(0, 3.4, 1.0)
		"hero":
			for u in occupied.values():
				if (u as TDDefender).data == hero_data:
					return (u as Node3D).global_position + Vector3.UP * 1.3
			return castle_pos + Vector3(-0.5, 3.0, 0)
		"scout":
			return gate_pos + Vector3(2.0, 1.2, 1.0)
	return Vector3.INF

func cutscene_action(action: String) -> void:
	match action:
		"gate_open":
			_gate_node.visible = true
			_gate_node.scale = Vector3(0.05, 0.05, 0.05)
			var tw := _gate_node.create_tween().set_ignore_time_scale(true)
			tw.tween_property(_gate_node, "scale", Vector3.ONE, 1.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			FX.pillar(_units, gate_pos, Color(0.75, 0.4, 1.0), 8.0, 1.0, 1.6)
			FX.explosion(_units, gate_pos + Vector3.UP * 0.5, 1.4)
			play_boom(-2.0)
			play_sfx("rumble", -2.0, 0.0)
			rig.shake(0.5)
		"gate_close":
			_explode_gate()
		"castle_fall":
			_destroy_castle()
		"ritual":
			FX.pillar(_units, castle_pos, Color(1.0, 0.95, 0.6), 12.0, 1.2, 2.0)
			FX.ring(_units, castle_pos + Vector3.UP * 0.2, 3.0, Color(1.0, 0.9, 0.5), 1.0)
			rig.shake(0.3)
			play_sfx("chime", -2.0, 0.0)
			play_sfx("rumble", -4.0, 0.0)
		"gold":
			if _pending_bonus > 0:
				_give_bonus()

func _give_bonus() -> void:
	var b := _pending_bonus
	_pending_bonus = 0
	add_gold(b)
	FX.float_text(_units, castle_pos + Vector3.UP * 2.5, "+%d ทอง" % b, Color(1, 0.85, 0.2), 64)
	announce.emit("ทองสนับสนุนจากพระราชา +%d" % b, "เตรียมกำลังให้พร้อม แล้วกด \"เริ่ม Phase\"", Color(1, 0.85, 0.3))

func _summon_hero() -> void:
	hero_tokens += 1
	hero_changed.emit(hero_tokens)
	FX.pillar(_units, castle_pos, Color(1.0, 0.95, 0.7), 10.0, 0.8, 1.4)
	play_boom(-4.0)
	announce.emit("ผู้กล้าอาเรียนถูกอัญเชิญแล้ว!", "คลิกช่องว่างเพื่อส่งผู้กล้าลงสนาม (ปุ่ม H)", Color(0.7, 0.9, 1.0))
	begin_placement(hero_data)

# ---------------------------------------------------------------- showcase (ฉากหลังเมนู)
const SHOWCASE_UNITS := [["knight", Vector2i(4, 3)], ["archer", Vector2i(6, 4)], ["mage", Vector2i(6, 7)],
	["golem", Vector2i(9, 7)], ["alchemist", Vector2i(9, 4)], ["saint", Vector2i(11, 5)], ["dragon", Vector2i(14, 5)],
	["archer", Vector2i(11, 2)], ["knight", Vector2i(16, 8)], ["mage", Vector2i(14, 2)]]

func _setup_showcase() -> void:
	if has_node("HUD"):
		$HUD.queue_free()
	for p in SHOWCASE_UNITS:
		for d in defenders:
			if d.id == StringName(p[0]) and is_buildable(p[1]):
				gold = 99999
				place_defender(d, p[1])
	if hero_data and is_buildable(Vector2i(16, 4)):
		var h := TDDefender.new()
		h.setup(hero_data)
		h.cell = Vector2i(16, 4)
		h.level_ref = self
		_units.add_child(h)
		h.position = Vector3(16, 0.2, 4)
		occupied[h.cell] = h
	_apply_devastation(2)
	rig.locked = true
	rig.orbit_speed = 0.035
	rig.position = Vector3(9.5, 0, 5.5)
	rig.zoom = 13.0
	rig.pitch_deg = 30.0

func _showcase_process(delta: float) -> void:
	_showcase_t -= delta
	if _showcase_t <= 0.0:
		_showcase_t = randf_range(1.2, 2.6)
		var pool := ["soldier", "soldier", "soldier", "humvee", "tank", "helicopter", "jet"]
		spawn_enemy(_enemy_data(pool[randi() % pool.size()]), 2)
	_showcase_ab_t -= delta
	if _showcase_ab_t <= 0.0:
		_showcase_ab_t = randf_range(3.0, 6.0)
		var us := occupied.values()
		us.shuffle()
		for u in us:
			if (u as TDDefender).use_ability():
				break

## ตอนจบ: ประตูมิติระเบิดเป็นชุดแล้วสลายหายไป
func _explode_gate() -> void:
	if _gate_node == null or not _gate_node.visible:
		return
	_env.fog_density = 0.002
	var tw := _gate_node.create_tween().set_ignore_time_scale(true)
	for i in 6:
		tw.tween_callback(func():
			var off := Vector3(randf_range(-0.6, 0.6), randf_range(0.3, 2.6), randf_range(-0.8, 0.8))
			FX.explosion(_units, gate_pos + off, randf_range(0.8, 1.3))
			play_boom(-4.0)
			rig.shake(0.25))
		tw.tween_property(_gate_node, "rotation:z", deg_to_rad(randf_range(-6.0, 6.0)), 0.2)
	tw.tween_callback(func():
		FX.pillar(_units, gate_pos, Color(0.8, 0.45, 1.0), 10.0, 1.4, 1.4)
		FX.explosion(_units, gate_pos + Vector3.UP * 1.2, 2.2)
		FX.ring(_units, gate_pos + Vector3.UP * 0.2, 4.0, Color(0.85, 0.55, 1.0), 0.9)
		play_boom(0.0)
		play_sfx("rumble", 0.0, 0.0)
		rig.shake(0.6))
	tw.tween_property(_gate_node, "scale", Vector3(1.3, 1.3, 1.3), 0.12)
	tw.tween_property(_gate_node, "scale", Vector3(0.01, 0.01, 0.01), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _gate_node.visible = false)

# ---------------------------------------------------------------- defeat cutscene
func _begin_defeat() -> void:
	if _defeat_pending or finished:
		return
	_defeat_pending = true
	cancel_placement()
	select(null)
	boss_hp_changed.emit(0.0, false)
	Engine.time_scale = 0.35
	var lines: Array = WavesLevel01.DEFEAT if mode == "story" else WavesLevel01.DEFEAT_ENDLESS
	if GameSession.skip_cutscenes:
		_destroy_castle()
		_restore_speed()
		_finish(false)
		return
	play_cutscene(lines, func(): _finish(false))

## ปราสาทระเบิดเป็นชุด ทรุดตัวลง ไฟลุกและควันพวยพุ่ง
func _destroy_castle() -> void:
	if _castle_node == null or _castle_node.get_meta("destroyed", false):
		return
	_castle_node.set_meta("destroyed", true)
	var base := _castle_node.scale
	var tw := _castle_node.create_tween().set_ignore_time_scale(true)
	for i in 7:
		tw.tween_callback(func():
			var off := Vector3(randf_range(-1.6, 1.6), randf_range(0.4, 2.8), randf_range(-0.4, 2.0))
			FX.explosion(_units, castle_pos + off, randf_range(0.9, 1.5))
			play_boom(-3.0)
			rig.shake(0.3))
		tw.tween_interval(0.22)
	tw.tween_callback(func():
		FX.explosion(_units, castle_pos + Vector3(0, 1.5, 0.8), 2.4)
		FX.ring(_units, castle_pos + Vector3.UP * 0.2, 4.5, Color(1.0, 0.5, 0.2), 1.0)
		play_boom(0.0)
		play_sfx("rumble", 0.0, 0.0)
		rig.shake(0.7))
	tw.set_parallel(true)
	tw.tween_property(_castle_node, "scale", Vector3(base.x * 1.05, base.y * 0.35, base.z * 1.05), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_castle_node, "rotation:z", deg_to_rad(8.0), 1.4)
	tw.tween_property(_castle_node, "position:y", -0.3, 1.4)
	tw.set_parallel(false)
	tw.tween_callback(func():
		var r := RandomNumberGenerator.new()
		for i in 6:
			var p := castle_pos + Vector3(r.randf_range(-1.8, 1.8), 0.2, r.randf_range(-0.6, 2.2))
			MapDecor.fire(_wreck, p, r.randf_range(1.0, 1.6))
			MapDecor.debris(_wreck, p, r)
		for i in 3:
			MapDecor.smoke_column(_wreck, castle_pos + Vector3(r.randf_range(-1.2, 1.2), 0.3, r.randf_range(0, 1.8))))
	var tw2 := create_tween().set_parallel(true).set_ignore_time_scale(true)
	tw2.tween_property(_sun, "light_color", Color(1.0, 0.45, 0.3), 2.5)
	tw2.tween_property(_env, "fog_density", 0.01, 2.5)
	tw2.tween_property(_env, "fog_light_color", Color(0.45, 0.25, 0.22), 2.5)
