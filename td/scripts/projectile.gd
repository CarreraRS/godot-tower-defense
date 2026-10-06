extends Node3D
class_name TDProjectile
## กระสุน/ลูกธนู/ลูกไฟ ที่พุ่งเข้าหาเป้าหมาย

var target: TDEnemy
var target_pos: Vector3
var start_pos: Vector3
var damage: float = 10.0
var splash: float = 0.0
var pierce: bool = false
var hits_air: bool = true
var hits_ground: bool = true
var slow_factor: float = 1.0
var slow_duration: float = 0.0
var speed: float = 8.0
var kind: int = DefenderData.Attack.ARROW
var color: Color = Color.WHITE
var level_ref: Node

var _t: float = 0.0
var _dist: float = 1.0
var _arc: float = 0.0

func setup_visual() -> void:
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match kind:
		DefenderData.Attack.ARROW:
			var b := BoxMesh.new()
			b.size = Vector3(0.02, 0.02, 0.28)
			b.material = FX.emissive_mat(color, 1.0)
			mi.mesh = b
		DefenderData.Attack.SPEAR:
			var b2 := BoxMesh.new()
			b2.size = Vector3(0.04, 0.04, 0.55)
			b2.material = FX.emissive_mat(color, 1.0)
			mi.mesh = b2
		DefenderData.Attack.ROCK:
			var s := SphereMesh.new()
			s.radius = 0.11
			s.height = 0.22
			s.radial_segments = 6
			s.rings = 4
			var m := StandardMaterial3D.new()
			m.albedo_color = color
			s.material = m
			mi.mesh = s
			_arc = 1.6
		DefenderData.Attack.FIREBALL:
			var s2 := SphereMesh.new()
			s2.radius = 0.12
			s2.height = 0.24
			s2.material = FX.emissive_mat(color, 4.0)
			mi.mesh = s2
			_arc = 0.3
		_:
			var s3 := SphereMesh.new()
			s3.radius = 0.07
			s3.height = 0.14
			s3.material = FX.emissive_mat(color, 4.0)
			mi.mesh = s3
	add_child(mi)

func _ready() -> void:
	global_position = start_pos
	if is_instance_valid(target):
		target_pos = target.aim_point()
	_dist = max(start_pos.distance_to(target_pos), 0.1)
	setup_visual()

func _physics_process(delta: float) -> void:
	if is_instance_valid(target) and target.alive:
		target_pos = target.aim_point()
	_dist = max(start_pos.distance_to(target_pos), 0.1)
	_t += delta * speed / _dist
	var p := start_pos.lerp(target_pos, min(_t, 1.0))
	p.y += sin(min(_t, 1.0) * PI) * _arc * _dist * 0.3
	var prev := global_position
	global_position = p
	if (p - prev).length_squared() > 0.000001:
		look_at(p + (p - prev), Vector3.UP)
	if _t >= 1.0:
		_impact()

func _impact() -> void:
	set_physics_process(false)
	if splash > 0.0:
		for e in get_tree().get_nodes_in_group("enemies"):
			var en := e as TDEnemy
			if en == null or not en.alive:
				continue
			if en.data.is_air and not hits_air:
				continue
			if not en.data.is_air and not hits_ground:
				continue
			var d := Vector2(en.global_position.x - target_pos.x, en.global_position.z - target_pos.z).length()
			if d <= splash or en == target:
				en.take_damage(damage if en == target else damage * 0.7, pierce)
				if slow_duration > 0.0:
					en.apply_slow(slow_factor, slow_duration)
		var parent := get_parent()
		if kind == DefenderData.Attack.ROCK or kind == DefenderData.Attack.FIREBALL:
			FX.explosion(parent, target_pos, 0.8 if kind == DefenderData.Attack.FIREBALL else 0.6)
			FX.ring(parent, Vector3(target_pos.x, 0.25, target_pos.z), splash, color)
			if level_ref and level_ref.has_method("play_boom"):
				level_ref.play_boom(-10.0)
	else:
		if is_instance_valid(target) and target.alive:
			target.take_damage(damage, pierce)
			if slow_duration > 0.0:
				target.apply_slow(slow_factor, slow_duration)
		FX.hit_spark(get_parent(), target_pos, color, 0.8)
	queue_free()
