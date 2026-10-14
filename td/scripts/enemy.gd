extends Node3D
class_name TDEnemy
## ศัตรูจากประตูมิติ
## - เดินตามเส้นทาง (Curve3D) ระหว่างทางอาจหยุดยิงสกัดยูนิตของเรา (ทำให้หยุดชะงัก)
## - ถึงหน้าเมือง: หน่วยภาคพื้นหยุดตีประตู, หน่วยบินลอยค้างยิงจรวด, เจ็ทพุ่งโจมตีครั้งเดียว
## (ระบบตีประตู/ปราสาทยิงสวน ต่อยอดจากงานของเพื่อนในกลุ่ม: addenemyeffect)

signal died(enemy: TDEnemy)
signal attacked_base(enemy: TDEnemy, damage: int)
signal removed(enemy: TDEnemy)   ## หายไปโดยไม่ได้ถูกฆ่า (เจ็ทพุ่งชน)

enum State { MOVE, SHOOT, SIEGE, DIVE, DEAD }

const GATE_STOP_GROUND := 0.4
const GATE_STOP_AIR := 1.3
const SIEGE_WINDUP := 0.8

var data: EnemyData
var curve: Curve3D
var level_ref: Node
var hp: float
var alive: bool = true
var progress: float = 0.0
var hp_mult: float = 1.0
var state: int = State.MOVE
var attacking: bool = false   ## (ใช้โดยปราสาท) กำลังโจมตีเมือง

var _slow_factor: float = 1.0
var _slow_time: float = 0.0
var _model: Node3D
var _anim: AnimationPlayer
var _bar_root: Node3D
var _bar_fill: MeshInstance3D
var _spawn_t: float = 0.0
var _length: float = 1.0
var _slow_fx: MeshInstance3D
var _shoot_cd: float = 0.0
var _state_t: float = 0.0
var _shot_target: Node3D
var _shot_fired: bool = false
var _face_dir: Vector3 = Vector3.RIGHT
var _lunge_tw: Tween
var _base_scale: float = 1.0

func setup(d: EnemyData, path_curve: Curve3D, hp_multiplier: float = 1.0, lvl: Node = null) -> void:
	data = d
	curve = path_curve
	hp_mult = hp_multiplier
	level_ref = lvl

func _ready() -> void:
	add_to_group("enemies")
	hp = data.max_hp * hp_mult
	_length = curve.get_baked_length()
	_model = data.model.instantiate() as Node3D
	_base_scale = data.model_scale
	_model.scale = Vector3.ONE * _base_scale * 0.01
	add_child(_model)
	var aps := _model.find_children("*", "AnimationPlayer", true, false)
	if aps.size() > 0:
		_anim = aps[0] as AnimationPlayer
		for n in ["Walk", "Idle", "Run"]:
			if _anim.has_animation(n):
				_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		_play(&"Walk")
	_shoot_cd = randf_range(1.0, data.shoot_interval)
	_build_health_bar()
	_update_transform(0.0)

func _play(n: StringName, blend: float = 0.15) -> void:
	if _anim and _anim.has_animation(n):
		if _anim.current_animation == String(n) and _anim.is_playing() and _anim.get_animation(n).loop_mode != Animation.LOOP_NONE:
			return
		_anim.play(n, blend)

func _build_health_bar() -> void:
	_bar_root = Node3D.new()
	add_child(_bar_root)
	_bar_root.position = Vector3(0, 0.8 * data.model_scale + 0.1, 0)
	var w := 0.6 if not data.is_boss else 1.4
	_bar_root.add_child(_make_quad(Vector2(w + 0.04, 0.1), Color(0, 0, 0, 0.6), 0))
	_bar_fill = _make_quad(Vector2(w, 0.06), Color(0.3, 0.95, 0.3), 1)
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

# ---------------------------------------------------------------- main loop
func _physics_process(delta: float) -> void:
	if not alive:
		return
	if _spawn_t < 1.0:
		_spawn_t = min(_spawn_t + delta * 2.0, 1.0)
		_model.scale = Vector3.ONE * _base_scale * max(ease(_spawn_t, 0.4), 0.01)
	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			_slow_factor = 1.0
			if _slow_fx:
				_slow_fx.visible = false
	match state:
		State.MOVE:
			_process_move(delta)
		State.SHOOT:
			_process_shoot(delta)
		State.SIEGE:
			_process_siege(delta)

func _process_move(delta: float) -> void:
	progress += data.speed * _slow_factor * delta
	var stop_at: float = max(_length - (GATE_STOP_AIR if data.is_air else GATE_STOP_GROUND), 0.0)
	if progress >= stop_at:
		progress = stop_at
		_update_transform(delta)
		if data.dive_attack:
			_start_dive()
		else:
			_start_siege()
		return
	_update_transform(delta)
	# ยิงสกัดยูนิตของเรา
	if data.shoot_range > 0.0 and level_ref:
		_shoot_cd -= delta
		if _shoot_cd <= 0.0:
			var t: Node3D = level_ref.find_defender_near(global_position, data.shoot_range)
			if t:
				_begin_shoot(t)
			else:
				_shoot_cd = 0.5

func _update_transform(delta: float) -> void:
	var pos := curve.sample_baked(progress, true)
	pos.y += data.fly_height
	global_position = pos
	var ahead := curve.sample_baked(min(progress + 0.25, _length), true)
	var dir := ahead - curve.sample_baked(progress, true)
	dir.y = 0
	if dir.length_squared() > 0.0001:
		_face_dir = dir.normalized()
		_turn_towards(_face_dir, delta)

func _turn_towards(dir: Vector3, delta: float) -> void:
	var target_basis := Basis.looking_at(dir, Vector3.UP)
	var s := _model.scale
	if delta <= 0.0:
		_model.basis = target_basis.scaled(s)
	else:
		var cur := Quaternion(_model.basis.orthonormalized())
		var q := cur.slerp(Quaternion(target_basis), clamp(delta * 8.0, 0.0, 1.0))
		_model.basis = Basis(q).scaled(s)

# ---------------------------------------------------------------- ยิงสกัดระหว่างทาง
func _begin_shoot(t: Node3D) -> void:
	state = State.SHOOT
	_state_t = data.shoot_pause
	_shot_target = t
	_shot_fired = false
	_play(&"Attack", 0.1)

func _process_shoot(delta: float) -> void:
	_state_t -= delta
	if is_instance_valid(_shot_target):
		var d := _shot_target.global_position - global_position
		d.y = 0
		if d.length_squared() > 0.001:
			_turn_towards(d.normalized(), delta)
	if not _shot_fired and _state_t <= data.shoot_pause * 0.55:
		_shot_fired = true
		if is_instance_valid(_shot_target):
			_fire_at_defender(_shot_target)
	if _state_t <= 0.0:
		state = State.MOVE
		_shoot_cd = data.shoot_interval * randf_range(0.8, 1.25)
		_play(&"Walk")

func _fire_at_defender(t: Node3D) -> void:
	var from := global_position + Vector3.UP * (0.35 * data.model_scale)
	var to := t.global_position + Vector3.UP * 0.4
	var parent := get_parent()
	if data.shoot_splash > 0.0:
		# กระสุนปืนใหญ่/จรวด/ระเบิด: ลอยไปแล้วระเบิด
		var arc := 0.0 if data.is_air else 0.8
		FX.lob(parent, from, to, 0.45, arc, Color(1.0, 0.5, 0.2), func():
			FX.explosion(parent, to, 0.55)
			if level_ref:
				level_ref.stun_defenders(to, data.shoot_splash, data.shoot_stun)
		)
	else:
		FX.tracer(parent, from, to, Color(1.0, 0.85, 0.4))
		FX.hit_spark(parent, to, Color(1.0, 0.8, 0.3), 0.7)
		if t.has_method("stun"):
			t.stun(data.shoot_stun)

# ---------------------------------------------------------------- โจมตีเมือง
func _start_siege() -> void:
	state = State.SIEGE
	attacking = true
	_state_t = SIEGE_WINDUP
	var d := curve.sample_baked(_length, true) - curve.sample_baked(max(_length - 1.0, 0.0), true)
	d.y = 0
	_face_dir = d.normalized() if d.length_squared() > 0.0001 else Vector3.RIGHT
	var side := _face_dir.cross(Vector3.UP).normalized()
	var spread := 0.45 if not data.is_boss else 0.0
	var tw := create_tween()
	tw.tween_property(self, "global_position", global_position + side * randf_range(-spread, spread), 0.35)
	FX.float_text(get_parent(), global_position + Vector3.UP * (0.9 * data.model_scale + 0.2), "!", Color(1.0, 0.35, 0.3), 64)
	_play(&"Idle")

func _process_siege(delta: float) -> void:
	_state_t -= delta * _slow_factor   # โดนสโลว์ = ตีช้าลง
	if _state_t <= 0.0:
		_state_t += data.attack_interval * randf_range(0.9, 1.1)
		if data.is_air:
			_air_strike()
		else:
			_ground_strike()

func _ground_strike() -> void:
	if _lunge_tw and _lunge_tw.is_valid():
		_lunge_tw.kill()
	_play(&"Attack", 0.05)
	var base_pos := position
	var reach := _face_dir * (0.25 * data.model_scale)
	_lunge_tw = create_tween()
	_lunge_tw.tween_property(self, "position", base_pos - reach * 0.4, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_lunge_tw.tween_property(self, "position", base_pos + reach, 0.08).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_lunge_tw.tween_callback(_on_impact)
	_lunge_tw.tween_property(self, "position", base_pos, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _on_impact() -> void:
	if alive:
		attacked_base.emit(self, data.strike_damage)

func _air_strike() -> void:
	# ยิงจรวด/ทิ้งระเบิดใส่เมือง
	var parent := get_parent()
	var from := global_position + Vector3.DOWN * 0.1
	var to := strike_point()
	FX.lob(parent, from, to, 0.5, 0.0, Color(1.0, 0.45, 0.15), _on_impact)

## จุดที่โดนตี (ใช้วางเอฟเฟกต์)
func strike_point() -> Vector3:
	if level_ref and level_ref.has_method("castle_hit_point"):
		return level_ref.castle_hit_point(global_position)
	return global_position + _face_dir * 0.5

func _start_dive() -> void:
	state = State.DIVE
	attacking = false
	var target := strike_point()
	FX.float_text(get_parent(), global_position + Vector3.UP * 0.6, "!!", Color(1.0, 0.35, 0.3), 64)
	var tw := create_tween()
	tw.tween_property(self, "global_position", target, 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		if not alive:
			return
		alive = false
		remove_from_group("enemies")
		attacked_base.emit(self, data.base_damage)
		FX.explosion(get_parent(), global_position, 1.0)
		removed.emit(self)
		queue_free())

# ---------------------------------------------------------------- damage
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
		factor = lerp(factor, 1.0, 0.5)
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
	state = State.DEAD
	remove_from_group("enemies")
	if _lunge_tw and _lunge_tw.is_valid():
		_lunge_tw.kill()
	var parent := get_parent()
	if data.explodes:
		FX.explosion(parent, global_position + Vector3.UP * 0.2, 1.0 if not data.is_boss else 2.5)
	else:
		FX.hit_spark(parent, global_position + Vector3.UP * 0.25, Color(0.9, 0.9, 0.8), 1.2)
	FX.float_text(parent, global_position + Vector3.UP * 0.8, "+%d" % data.reward, Color(1.0, 0.85, 0.2))
	died.emit(self)
	_bar_root.visible = false
	if data.is_air:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "global_position:y", 0.05, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(_model, "rotation:z", 1.2, 0.6)
		tw.chain().tween_callback(_crash)
	elif _anim and _anim.has_animation(&"Death"):
		_anim.play(&"Death", 0.1)
		var tw2 := create_tween()
		tw2.tween_interval(1.1)
		tw2.tween_property(self, "position:y", position.y - 0.4, 0.6)
		tw2.tween_callback(queue_free)
	else:
		var tw3 := create_tween()
		tw3.tween_property(_model, "scale", Vector3.ONE * 0.01, 0.25)
		tw3.tween_callback(queue_free)

func _crash() -> void:
	FX.explosion(get_parent(), global_position, 0.8)
	queue_free()
