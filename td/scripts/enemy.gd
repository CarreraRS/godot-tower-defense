extends Node3D
class_name TDEnemy
## ศัตรูจากประตูมิติ: เคลื่อนที่ตามเส้นทาง (Curve3D) จนถึงปราสาท

signal died(enemy: TDEnemy)
signal attacked_base(enemy: TDEnemy, damage: int)  ## ตีประตูหนึ่งครั้ง

const GATE_STOP := 0.35        ## หยุดก่อนถึงปลายเส้นทางเท่านี้ (ยืนหน้าประตู)
const ATTACK_WINDUP := 0.8     ## เวลาตั้งท่าก่อนตีครั้งแรก

var data: EnemyData
var curve: Curve3D
var hp: float
var alive: bool = true
var progress: float = 0.0       ## ระยะที่เดินไปแล้วบนเส้นทาง (ใช้เลือกเป้าหมาย)
var hp_mult: float = 1.0

var _slow_factor: float = 1.0
var _slow_time: float = 0.0
var _model: Node3D
var _bar_root: Node3D
var _bar_fill: MeshInstance3D
var _bar_bg: MeshInstance3D
var _spawn_t: float = 0.0
var _length: float = 1.0
var _slow_fx: MeshInstance3D

var attacking: bool = false     ## กำลังยืนตีประตูเมือง
var _attack_t: float = 0.0
var _face_dir: Vector3 = Vector3.RIGHT
var _lunge_tw: Tween

func setup(d: EnemyData, path_curve: Curve3D, hp_multiplier: float = 1.0) -> void:
	data = d
	curve = path_curve
	hp_mult = hp_multiplier

func _ready() -> void:
	add_to_group("enemies")
	hp = data.max_hp * hp_mult
	_length = curve.get_baked_length()
	_model = data.model.instantiate() as Node3D
	_model.scale = Vector3.ONE * data.model_scale * 0.01
	add_child(_model)
	_build_health_bar()
	_update_transform(0.0)

func _build_health_bar() -> void:
	_bar_root = Node3D.new()
	add_child(_bar_root)
	var h := 0.8 * data.model_scale + 0.1
	_bar_root.position = Vector3(0, h, 0)
	var w := 0.6 if not data.is_boss else 1.4
	_bar_bg = _make_quad(Vector2(w + 0.04, 0.1), Color(0, 0, 0, 0.6), 0)
	_bar_fill = _make_quad(Vector2(w, 0.06), Color(0.3, 0.95, 0.3), 1)
	_bar_root.add_child(_bar_bg)
	_bar_root.add_child(_bar_fill)
	_bar_root.visible = false

func _make_quad(size: Vector2, c: Color, prio: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = true
	m.render_priority = prio
	q.material = m
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _physics_process(delta: float) -> void:
	if not alive:
		return
	# ขยายตัวตอนเกิดจากประตู
	if _spawn_t < 1.0:
		_spawn_t = min(_spawn_t + delta * 2.0, 1.0)
		_model.scale = Vector3.ONE * data.model_scale * ease(_spawn_t, 0.4)
	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			_slow_factor = 1.0
			if _slow_fx:
				_slow_fx.visible = false
	if attacking:
		_process_attack(delta)
		return
	progress += data.speed * _slow_factor * delta
	var stop_at: float = max(_length - GATE_STOP, 0.0)
	if progress >= stop_at:
		progress = stop_at
		_update_transform(delta)
		_start_attack()
		return
	_update_transform(delta)

func _update_transform(delta: float) -> void:
	var pos := curve.sample_baked(progress, true)
	pos.y += data.fly_height
	global_position = pos
	var ahead := curve.sample_baked(min(progress + 0.25, _length), true)
	ahead.y += data.fly_height
	var dir := ahead - pos
	dir.y = 0
	if dir.length_squared() > 0.0001:
		var target_basis := Basis.looking_at(dir.normalized(), Vector3.UP)
		if delta <= 0.0:
			_model.basis = target_basis.scaled(_model.scale)
		else:
			var cur := Quaternion(_model.basis.orthonormalized())
			var q := cur.slerp(Quaternion(target_basis), clamp(delta * 8.0, 0.0, 1.0))
			_model.basis = Basis(q).scaled(_model.scale)

# ---------------------------------------------------------------- โจมตีประตูเมือง
func _start_attack() -> void:
	attacking = true
	_attack_t = ATTACK_WINDUP
	var d := curve.sample_baked(_length, true) - curve.sample_baked(max(_length - 1.0, 0.0), true)
	d.y = 0
	_face_dir = d.normalized() if d.length_squared() > 0.0001 else Vector3.RIGHT
	# ขยับไปยืนเรียงข้างกันหน้าประตู จะได้ไม่ซ้อนเป็นก้อนเดียว
	var side := _face_dir.cross(Vector3.UP).normalized()
	var spread := 0.45 if not data.is_boss else 0.0
	var tw := create_tween()
	tw.tween_property(self, "global_position", global_position + side * randf_range(-spread, spread), 0.3)
	FX.float_text(get_parent(), global_position + Vector3.UP * (0.9 * data.model_scale + 0.2), "!", Color(1.0, 0.35, 0.3), 64)

func _process_attack(delta: float) -> void:
	_attack_t -= delta * _slow_factor   # โดนสโลว์ = ตีช้าลงด้วย
	if _attack_t <= 0.0:
		_attack_t += data.attack_interval
		_strike()

func _strike() -> void:
	if _lunge_tw and _lunge_tw.is_valid():
		_lunge_tw.kill()
	_model.position = Vector3.ZERO
	var reach := _face_dir * (0.25 * data.model_scale)
	_lunge_tw = create_tween()
	# ถอยง้าง -> พุ่งใส่ประตู -> กลับที่
	_lunge_tw.tween_property(_model, "position", -reach * 0.4, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_lunge_tw.tween_property(_model, "position", reach, 0.08).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_lunge_tw.tween_callback(_on_impact)
	_lunge_tw.tween_property(_model, "position", Vector3.ZERO, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _on_impact() -> void:
	if not alive:
		return
	attacked_base.emit(self, 1)

## จุดที่โดนตี (ใช้วางเอฟเฟกต์)
func strike_point() -> Vector3:
	return global_position + _face_dir * (0.35 * data.model_scale) + Vector3.UP * (0.3 * data.model_scale + 0.15)

func aim_point() -> Vector3:
	return global_position + Vector3.UP * (0.25 * data.model_scale)

func take_damage(amount: float, pierce: bool = false) -> void:
	if not alive:
		return
	var dmg := amount
	if not pierce:
		dmg = max(amount - data.armor, amount * 0.25)
	hp -= dmg
	_bar_root.visible = true
	var ratio: float = clamp(hp / (data.max_hp * hp_mult), 0.0, 1.0)
	_bar_fill.scale.x = max(ratio, 0.001)
	var m := (_bar_fill.mesh as QuadMesh).material as StandardMaterial3D
	m.albedo_color = Color(1.0, 0.25, 0.2).lerp(Color(0.3, 0.95, 0.3), ratio)
	if hp <= 0.0:
		_die()

func apply_slow(factor: float, duration: float) -> void:
	if data.is_boss:
		factor = lerp(factor, 1.0, 0.5)   # บอสโดนสโลว์น้อยกว่า
	_slow_factor = min(_slow_factor, factor)
	_slow_time = max(_slow_time, duration)
	if _slow_fx == null:
		_slow_fx = MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.22 * data.model_scale
		t.outer_radius = 0.3 * data.model_scale
		t.material = FX.emissive_mat(Color(0.4, 0.8, 1.0, 0.7), 2.0, true)
		_slow_fx.mesh = t
		_slow_fx.position.y = 0.05
		add_child(_slow_fx)
	_slow_fx.visible = true

func _die() -> void:
	alive = false
	attacking = false
	if _lunge_tw and _lunge_tw.is_valid():
		_lunge_tw.kill()
	remove_from_group("enemies")
	var parent := get_parent()
	if data.explodes:
		FX.explosion(parent, global_position + Vector3.UP * 0.2, 1.0 if not data.is_boss else 2.5)
	else:
		FX.hit_spark(parent, global_position + Vector3.UP * 0.25, Color(0.9, 0.9, 0.8), 1.2)
	FX.float_text(parent, global_position + Vector3.UP * 0.8, "+%d" % data.reward, Color(1.0, 0.85, 0.2))
	died.emit(self)
	if data.is_air:
		# เครื่องบินตกลงพื้น
		_bar_root.visible = false
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "global_position:y", 0.05, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(_model, "rotation:z", 1.2, 0.6)
		tw.chain().tween_callback(_crash)
	else:
		var tw2 := create_tween()
		tw2.tween_property(_model, "scale", Vector3.ONE * 0.01, 0.25)
		tw2.tween_callback(queue_free)

func _crash() -> void:
	FX.explosion(get_parent(), global_position, 0.8)
	queue_free()
