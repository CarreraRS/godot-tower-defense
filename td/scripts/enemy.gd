extends Node3D
class_name TDEnemy
## ศัตรูจากประตูมิติ: เคลื่อนที่ตามเส้นทาง (Curve3D) จนถึงปราสาท

signal died(enemy: TDEnemy)
signal reached_base(enemy: TDEnemy)

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
	progress += data.speed * _slow_factor * delta
	if progress >= _length:
		alive = false
		remove_from_group("enemies")
		reached_base.emit(self)
		queue_free()
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
