class_name FX
## เอฟเฟกต์ภาพแบบง่าย (สร้างจากโค้ด ไม่ต้องใช้ไฟล์ภาพ)

static var _mat_cache: Dictionary = {}

static func emissive_mat(c: Color, energy: float = 2.0, transparent: bool = false) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [c.to_html(), energy, transparent]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent or c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = m
	return m

static func _particles(parent: Node, pos: Vector3, color: Color, amount: int, size: float, speed: float, life: float, gravity: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = emissive_mat(color, 3.0)
	p.mesh = mesh
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(life + 0.3, false).timeout.connect(p.queue_free)
	return p

static func explosion(parent: Node, pos: Vector3, scale: float = 1.0) -> void:
	_particles(parent, pos, Color(1.0, 0.55, 0.1), int(18 * scale) + 6, 0.06 * scale, 2.2 * scale, 0.55, -2.0)
	_particles(parent, pos, Color(1.0, 0.9, 0.4), 10, 0.04 * scale, 1.5 * scale, 0.35, 0.0)
	var smoke := _particles(parent, pos, Color(0.25, 0.25, 0.25), 10, 0.09 * scale, 0.7 * scale, 1.0, 0.8)
	(smoke.mesh as SphereMesh).material = _smoke_mat()
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 3.0 * scale
	light.omni_range = 2.5 * scale
	parent.add_child(light)
	light.global_position = pos + Vector3.UP * 0.3
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.35)
	tw.tween_callback(light.queue_free)

static func _smoke_mat() -> StandardMaterial3D:
	if _mat_cache.has("smoke"):
		return _mat_cache["smoke"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.3, 0.3, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_cache["smoke"] = m
	return m

static func hit_spark(parent: Node, pos: Vector3, color: Color, scale: float = 1.0) -> void:
	_particles(parent, pos, color, 8, 0.035 * scale, 1.4 * scale, 0.3, -1.0)

static func float_text(parent: Node, pos: Vector3, text: String, color: Color, size: int = 48) -> void:
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.font_size = size
	l.outline_size = 10
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", pos + Vector3.UP * 0.7, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)

static func ring(parent: Node, pos: Vector3, radius: float, color: Color, life: float = 0.4) -> void:
	## วงคลื่นกระแทก (ใช้กับดาเมจกระจาย)
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.85
	t.outer_radius = 1.0
	t.rings = 24
	t.ring_segments = 4
	t.material = emissive_mat(Color(color.r, color.g, color.b, 0.8), 2.0, true)
	mi.mesh = t
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3.UP * 0.05
	mi.scale = Vector3.ONE * 0.1
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(radius, 1, radius), life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(mi.queue_free)
