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

static func tracer(parent: Node, from: Vector3, to: Vector3, color: Color, life: float = 0.12) -> void:
	## เส้นกระสุน (เส้นบาง ๆ จางหาย)
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	var d := from.distance_to(to)
	b.size = Vector3(0.025, 0.025, max(d, 0.01))
	b.material = emissive_mat(Color(color.r, color.g, color.b, 0.9), 3.0, true)
	mi.mesh = b
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = (from + to) * 0.5
	if d > 0.01:
		mi.look_at(to, Vector3.UP if abs((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.2, 0.2, 1.0), life)
	tw.tween_callback(mi.queue_free)

static func lob(parent: Node, from: Vector3, to: Vector3, time: float, arc: float, color: Color, on_hit: Callable) -> void:
	## ลูกกระสุน/จรวดที่ลอยไปหาเป้าแล้วเรียก on_hit
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.07
	s.height = 0.14
	s.radial_segments = 6
	s.rings = 3
	s.material = emissive_mat(color, 3.5)
	mi.mesh = s
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = from
	var tw := mi.create_tween()
	tw.tween_method(func(t: float) -> void:
		var p := from.lerp(to, t)
		p.y += sin(t * PI) * arc
		mi.global_position = p
	, 0.0, 1.0, time)
	tw.tween_callback(func() -> void:
		if on_hit.is_valid():
			on_hit.call()
		mi.queue_free())

static func beam(parent: Node, points: PackedVector3Array, color: Color, life: float = 0.25) -> void:
	## สายฟ้าซิกแซกระหว่างจุด
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var segs := 4
		var prev := a
		for k in range(1, segs + 1):
			var t := float(k) / segs
			var p := a.lerp(b, t)
			if k < segs:
				p += Vector3(randf_range(-0.12, 0.12), randf_range(-0.12, 0.12), randf_range(-0.12, 0.12))
			tracer(parent, prev, p, color, life)
			prev = p

## ลำแสงพุ่งขึ้นฟ้า (อัญเชิญ/ทักษะ)
static func pillar(parent: Node, pos: Vector3, color: Color, height: float = 4.0, radius: float = 0.35, life: float = 0.9) -> void:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.6
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 16
	cm.rings = 1
	var mat := emissive_mat(Color(color.r, color.g, color.b, 0.55), 3.0, true)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.material = mat
	m.mesh = cm
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = pos + Vector3.UP * height * 0.5
	m.scale = Vector3(0.2, 1, 0.2)
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3(1, 1, 1), life * 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "scale", Vector3(0.05, 1.2, 0.05), life * 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(m.queue_free)
	_particles(parent, pos + Vector3.UP * 0.2, color, 24, 0.06, 2.5, 0.9, -2.0)

## รอยฟันดาบเป็นเสี้ยววงกลมด้านหน้า (หันตาม yaw)
static func slash(parent: Node, pos: Vector3, yaw: float, radius: float, color: Color, life: float = 0.22) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 14
	var a0 := deg_to_rad(-75.0)
	var a1 := deg_to_rad(75.0)
	for i in seg:
		var t0 := float(i) / seg
		var t1 := float(i + 1) / seg
		var aa := lerpf(a0, a1, t0)
		var ab := lerpf(a0, a1, t1)
		var w0 := sin(t0 * PI)
		var w1 := sin(t1 * PI)
		var o0 := Vector3(sin(aa), 0, -cos(aa)) * radius
		var o1 := Vector3(sin(ab), 0, -cos(ab)) * radius
		var i0 := o0 * (1.0 - 0.35 * w0)
		var i1 := o1 * (1.0 - 0.35 * w1)
		var c0 := Color(color.r, color.g, color.b, 0.9 * w0)
		var c1 := Color(color.r, color.g, color.b, 0.9 * w1)
		st.set_color(Color(c0.r, c0.g, c0.b, 0.0)); st.add_vertex(i0)
		st.set_color(c0); st.add_vertex(o0)
		st.set_color(c1); st.add_vertex(o1)
		st.set_color(Color(c0.r, c0.g, c0.b, 0.0)); st.add_vertex(i0)
		st.set_color(c1); st.add_vertex(o1)
		st.set_color(Color(c1.r, c1.g, c1.b, 0.0)); st.add_vertex(i1)
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.4, 1.4, 1.4, 1.0)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = pos
	m.rotation = Vector3(deg_to_rad(-12.0), yaw, 0)
	m.scale = Vector3(0.7, 1, 0.7)
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3(1.15, 1, 1.15), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "rotation:y", yaw + deg_to_rad(35.0), life)
	tw.tween_property(mat, "albedo_color:a", 0.0, life).set_delay(life * 0.3)
	tw.chain().tween_callback(m.queue_free)
