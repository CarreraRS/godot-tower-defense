extends Node3D
class_name TDDefender
## ยูนิตฝ่ายอาณาจักรที่วางบนช่องว่าง: หาเป้าหมายในระยะ หันหน้า และโจมตี

var data: DefenderData
var level: int = 1
var cell: Vector2i
var total_spent: int = 0
var level_ref: Node        ## อ้างอิงฉาก Level (ใช้เล่นเสียง/เอฟเฟกต์)
var preview: bool = false  ## true = ตัวอย่างตอนลากวาง (ไม่โจมตี)

var _cooldown: float = 0.0
var _target: TDEnemy
var _pivot: Node3D
var _model: Node3D
var _muzzle: Node3D
var _anim: AnimationPlayer
var _range_ring: MeshInstance3D
var _stars: Label3D
var _base: MeshInstance3D

func setup(d: DefenderData) -> void:
	data = d

func _ready() -> void:
	_base = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.36
	cyl.bottom_radius = 0.42
	cyl.height = 0.1
	cyl.radial_segments = 8
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.62, 0.6, 0.56)
	bm.roughness = 0.9
	cyl.material = bm
	_base.mesh = cyl
	_base.position.y = 0.05
	add_child(_base)

	_pivot = Node3D.new()
	_pivot.position.y = 0.1
	add_child(_pivot)
	_model = data.model.instantiate() as Node3D
	_pivot.add_child(_model)
	_muzzle = _model.find_child("Muzzle", true, false) as Node3D
	var aps := _model.find_children("*", "AnimationPlayer", true, false)
	if aps.size() > 0:
		_anim = aps[0] as AnimationPlayer
		_play_idle()

	_range_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.97
	t.outer_radius = 1.0
	t.rings = 48
	t.ring_segments = 3
	t.material = FX.emissive_mat(Color(1, 1, 1, 0.55), 1.0, true)
	_range_ring.mesh = t
	_range_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.01
	cm.radial_segments = 48
	cm.material = FX.emissive_mat(Color(1, 1, 1, 0.08), 0.5, true)
	disc.mesh = cm
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_range_ring.add_child(disc)
	_range_ring.position.y = 0.22
	add_child(_range_ring)
	_range_ring.visible = false

	_stars = Label3D.new()
	_stars.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_stars.font_size = 40
	_stars.outline_size = 8
	_stars.pixel_size = 0.004
	_stars.modulate = Color(1, 0.85, 0.2)
	_stars.position.y = 0.95
	add_child(_stars)
	_refresh()

func _refresh() -> void:
	var r := data.range_at(level)
	_range_ring.scale = Vector3(r, 1, r)
	_stars.text = "★".repeat(level - 1)
	_model.scale = Vector3.ONE * (1.0 + 0.08 * (level - 1))

func show_range(v: bool) -> void:
	if _range_ring:
		_range_ring.visible = v

func set_ring_color(c: Color) -> void:
	(_range_ring.mesh as TorusMesh).material = FX.emissive_mat(Color(c.r, c.g, c.b, 0.7), 1.5, true)

func can_upgrade() -> bool:
	return level < data.max_level

func next_upgrade_cost() -> int:
	return data.upgrade_cost(level)

func upgrade() -> void:
	level += 1
	_refresh()
	FX.ring(get_parent(), global_position, 0.8, Color(1, 0.85, 0.2), 0.5)
	FX.hit_spark(get_parent(), global_position + Vector3.UP * 0.5, Color(1, 0.85, 0.2), 1.5)

func sell_value() -> int:
	return int(total_spent * 0.7)

func _physics_process(delta: float) -> void:
	if preview:
		return
	_cooldown -= delta
	var r := data.range_at(level)
	if not _valid_target(_target, r):
		_target = _find_target(r)
	if _target == null:
		return
	# หันหน้าเข้าหาเป้าหมาย (โมเดลหันไปทาง -Z)
	var to := _target.global_position - global_position
	to.y = 0
	if to.length_squared() > 0.0001:
		var want := atan2(-to.x, -to.z)
		_pivot.rotation.y = lerp_angle(_pivot.rotation.y, want, clamp(delta * 10.0, 0.0, 1.0))
	if _cooldown <= 0.0:
		_cooldown = data.interval_at(level)
		_attack()

func _valid_target(e: TDEnemy, r: float) -> bool:
	if e == null or not is_instance_valid(e) or not e.alive:
		return false
	return _in_range(e, r) and _can_hit(e)

func _can_hit(e: TDEnemy) -> bool:
	return (e.data.is_air and data.hits_air) or (not e.data.is_air and data.hits_ground)

func _in_range(e: TDEnemy, r: float) -> bool:
	var d := Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z)
	return d.length() <= r

func _find_target(r: float) -> TDEnemy:
	var best: TDEnemy = null
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as TDEnemy
		if e == null or not e.alive or not _can_hit(e) or not _in_range(e, r):
			continue
		# เลือกตัวที่เดินไปไกลที่สุด (ใกล้ปราสาทที่สุด)
		if best == null or e.progress > best.progress:
			best = e
	return best

func _attack() -> void:
	_play_attack()
	var dmg := data.damage_at(level)
	if data.attack_type == DefenderData.Attack.MELEE:
		# โจมตีระยะประชิด: ดาเมจทันที + เอฟเฟกต์ฟัน
		if data.splash_radius > 0.0:
			for n in get_tree().get_nodes_in_group("enemies"):
				var e := n as TDEnemy
				if e and e.alive and _can_hit(e) and e.global_position.distance_to(_target.global_position) <= data.splash_radius:
					e.take_damage(dmg, data.armor_pierce)
		else:
			_target.take_damage(dmg, data.armor_pierce)
		if is_instance_valid(_target):
			FX.hit_spark(get_parent(), _target.aim_point(), data.projectile_color, 1.2)
		return
	var p := TDProjectile.new()
	p.start_pos = _muzzle.global_position if _muzzle else global_position + Vector3.UP * 0.5
	p.target = _target
	p.target_pos = _target.aim_point()
	p.damage = dmg
	p.splash = data.splash_radius
	p.pierce = data.armor_pierce
	p.hits_air = data.hits_air
	p.hits_ground = data.hits_ground
	p.slow_factor = data.slow_factor
	p.slow_duration = data.slow_duration
	p.speed = data.projectile_speed
	p.kind = data.attack_type
	p.color = data.projectile_color
	p.level_ref = level_ref
	get_parent().add_child(p)

func _play_idle() -> void:
	if _anim and data.idle_anim != &"" and _anim.has_animation(data.idle_anim):
		_anim.get_animation(data.idle_anim).loop_mode = Animation.LOOP_LINEAR
		_anim.play(data.idle_anim, 0.2)

func _play_attack() -> void:
	if _anim and data.attack_anim != &"" and _anim.has_animation(data.attack_anim):
		_anim.stop()
		_anim.play(data.attack_anim)
		if not _anim.animation_finished.is_connected(_on_anim_done):
			_anim.animation_finished.connect(_on_anim_done)
	else:
		# ไม่มีแอนิเมชัน: ใช้การ "เด้ง" แทน
		var tw := create_tween()
		var s := _model.scale
		tw.tween_property(_model, "scale", s * Vector3(1.12, 0.9, 1.12), 0.06)
		tw.tween_property(_model, "scale", s, 0.12)

func _on_anim_done(_n: StringName) -> void:
	_play_idle()
