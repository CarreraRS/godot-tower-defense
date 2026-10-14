class_name MapDecor
## ของตกแต่งแมพที่สร้างจากโค้ด: หมู่บ้านข้างปราสาท, ค่ายศัตรูหน้าประตูมิติ, กำแพงหิน, คบเพลิง, ไร่นา
## และของที่ใช้ตอนแมพพัง (หลุมระเบิด, ไฟ, ควัน, เศษซาก)

static var _mats: Dictionary = {}

static func mat(c: Color, emit: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%s" % [c.to_html(), emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m

static func box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	b.material = mat(c)
	mi.mesh = b
	parent.add_child(mi)
	mi.position = pos
	mi.rotation.y = rot_y
	return mi

static func prism(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var p := PrismMesh.new()
	p.size = size
	p.material = mat(c)
	mi.mesh = p
	parent.add_child(mi)
	mi.position = pos
	mi.rotation.y = rot_y
	return mi

static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, c: Color, emit: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = 8
	cm.rings = 0
	cm.material = mat(c, emit)
	mi.mesh = cm
	parent.add_child(mi)
	mi.position = pos
	return mi

static func _free_spot(level: Node, p: Vector3, avoid: float = 1.1) -> bool:
	## นอกตาราง และไม่ทับถนน/ประตู/ปราสาท
	var inside := p.x > -0.8 and p.x < 19.8 and p.z > -0.8 and p.z < 11.8
	if inside:
		return false
	if p.x < 0 and abs(p.z - level.gate_pos.z) < avoid:
		return false
	if p.x > 19 and abs(p.z - level.castle_pos.z) < avoid + 0.5:
		return false
	if p.distance_to(level.gate_pos) < 2.6 or p.distance_to(level.castle_pos) < 3.2:
		return false
	return true

# ---------------------------------------------------------------- build
static func build(level: Node, world: Node3D, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.name = "Decor"
	world.add_child(root)
	var snow: bool = level.theme.get("id", "") == "snow"
	_border_walls(level, root, rng)
	_village(level, root, rng, snow)
	_enemy_camp(level, root, rng)
	if not snow:
		_fields(level, root, rng)
	_flowers(level, root, rng, snow)

static func _border_walls(level: Node, root: Node3D, rng: RandomNumberGenerator) -> void:
	## กำแพงหินเตี้ยรอบสนาม + คบเพลิง
	var stone := Color(0.55, 0.53, 0.5)
	for z in [-1.05, 12.05]:
		var x := -0.5
		while x < 19.6:
			var seg := rng.randf_range(1.2, 2.4)
			if rng.randf() < 0.8:
				box(root, Vector3(seg, 0.28, 0.22), Vector3(x + seg * 0.5, 0.14, z), stone.darkened(rng.randf_range(0, 0.15)))
			x += seg + rng.randf_range(0.1, 0.6)
		for tx in [2.0, 7.0, 12.0, 17.0]:
			torch(root, Vector3(tx + rng.randf_range(-0.5, 0.5), 0, z))

static func torch(root: Node3D, p: Vector3) -> void:
	cyl(root, 0.03, 0.04, 0.7, p + Vector3(0, 0.35, 0), Color(0.35, 0.22, 0.12))
	cyl(root, 0.07, 0.05, 0.08, p + Vector3(0, 0.72, 0), Color(0.25, 0.2, 0.18))
	var flame := cyl(root, 0.0, 0.06, 0.16, p + Vector3(0, 0.83, 0), Color(1.0, 0.6, 0.15), 4.0)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.65, 0.3)
	l.light_energy = 0.8
	l.omni_range = 1.8
	root.add_child(l)
	l.position = p + Vector3(0, 0.95, 0)

static func house(root: Node3D, p: Vector3, rng: RandomNumberGenerator, snow: bool) -> void:
	var w := rng.randf_range(0.9, 1.4)
	var d := rng.randf_range(0.8, 1.1)
	var h := rng.randf_range(0.6, 0.9)
	var ry := rng.randi_range(0, 3) * PI * 0.5
	var n := Node3D.new()
	root.add_child(n)
	n.position = p
	n.rotation.y = ry
	var wall: Color = [Color(0.93, 0.87, 0.74), Color(0.85, 0.78, 0.66), Color(0.9, 0.9, 0.86)][rng.randi_range(0, 2)]
	var roof: Color = [Color(0.7, 0.25, 0.2), Color(0.3, 0.4, 0.62), Color(0.5, 0.35, 0.22)][rng.randi_range(0, 2)]
	if snow:
		roof = Color(0.95, 0.97, 1.0)
	box(n, Vector3(w, h, d), Vector3(0, h * 0.5, 0), wall)
	box(n, Vector3(0.06, h * 0.9, d + 0.02), Vector3(-w * 0.5 + 0.03, h * 0.45, 0), Color(0.4, 0.27, 0.15))
	box(n, Vector3(0.06, h * 0.9, d + 0.02), Vector3(w * 0.5 - 0.03, h * 0.45, 0), Color(0.4, 0.27, 0.15))
	var r := prism(n, Vector3(w + 0.2, 0.55, d + 0.15), Vector3(0, h + 0.27, 0), roof)
	r.rotation.y = PI * 0.5 if w < d else 0.0
	box(n, Vector3(0.22, 0.36, 0.03), Vector3(0, 0.18, d * 0.5 + 0.01), Color(0.35, 0.22, 0.12))
	box(n, Vector3(0.18, 0.16, 0.03), Vector3(w * 0.28, h * 0.6, d * 0.5 + 0.01), Color(1.0, 0.85, 0.5) if rng.randf() < 0.5 else Color(0.25, 0.3, 0.35))
	cyl(n, 0.08, 0.08, 0.35, Vector3(w * 0.3, h + 0.4, 0), Color(0.45, 0.42, 0.4))

static func _village(level: Node, root: Node3D, rng: RandomNumberGenerator, snow: bool) -> void:
	var cz: float = level.castle_pos.z
	var placed: Array = []
	for i in 40:
		if placed.size() >= 8:
			break
		var p := Vector3(rng.randf_range(20.6, 27.0), 0, cz + rng.randf_range(-7.0, 7.0))
		if not _free_spot(level, p, 1.4):
			continue
		var ok := true
		for q in placed:
			if (q as Vector3).distance_to(p) < 1.7:
				ok = false
		if ok:
			placed.append(p)
			house(root, p, rng, snow)
	# บ่อน้ำ + ลังไม้ในหมู่บ้าน
	for i in 4:
		var p2 := Vector3(rng.randf_range(20.5, 25.0), 0, cz + rng.randf_range(-5.0, 5.0))
		if _free_spot(level, p2, 1.2):
			box(root, Vector3(0.25, 0.25, 0.25), p2 + Vector3(0, 0.125, 0), Color(0.6, 0.42, 0.22), rng.randf() * PI)

static func _enemy_camp(level: Node, root: Node3D, rng: RandomNumberGenerator) -> void:
	## ค่ายทหารข้ามมิติข้างประตู: เต็นท์ ลังเสบียง กระสอบทราย
	var gz: float = level.gate_pos.z
	var olive := Color(0.36, 0.4, 0.26)
	for i in 30:
		var p := Vector3(rng.randf_range(-7.5, -1.2), 0, gz + rng.randf_range(-5.5, 5.5))
		if not _free_spot(level, p, 1.3):
			continue
		var roll := rng.randf()
		if roll < 0.35:
			var t := prism(root, Vector3(0.9, 0.55, 1.1), p + Vector3(0, 0.27, 0), olive.darkened(rng.randf_range(0, 0.2)), rng.randi_range(0, 1) * PI * 0.5)
			t.rotation.y += rng.randf_range(-0.2, 0.2)
		elif roll < 0.7:
			for k in rng.randi_range(1, 3):
				box(root, Vector3(0.28, 0.24, 0.28), p + Vector3(k * 0.3, 0.12 + (0.24 if k == 2 else 0.0), 0), Color(0.35, 0.36, 0.28), rng.randf() * 0.3)
		else:
			for k in 4:
				var a := k * 0.35 - 0.5
				box(root, Vector3(0.3, 0.14, 0.18), p + Vector3(a, 0.07, 0), Color(0.72, 0.65, 0.48), rng.randf_range(-0.2, 0.2))
	# แสงสีม่วงรั่วจากประตูมิติลงพื้น
	var glow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 2.2
	disc.bottom_radius = 2.2
	disc.height = 0.01
	disc.radial_segments = 24
	var gm := FX.emissive_mat(Color(0.6, 0.25, 0.9, 0.25), 1.5, true)
	disc.material = gm
	glow.mesh = disc
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow)
	glow.position = level.gate_pos + Vector3(0.5, 0.02, 0)

static func _fields(level: Node, root: Node3D, rng: RandomNumberGenerator) -> void:
	## ไร่นาด้านนอกสนาม
	for i in 12:
		var p := Vector3(rng.randf_range(0.0, 19.0), 0, [rng.randf_range(-5.5, -2.0), rng.randf_range(13.0, 16.5)][i % 2])
		if not _free_spot(level, p, 1.0):
			continue
		var n := Node3D.new()
		root.add_child(n)
		n.position = p
		n.rotation.y = rng.randi_range(0, 1) * PI * 0.5
		box(n, Vector3(1.8, 0.04, 1.2), Vector3(0, 0.02, 0), Color(0.5, 0.36, 0.22))
		var crop: Color = [Color(0.85, 0.75, 0.3), Color(0.45, 0.7, 0.3)][rng.randi_range(0, 1)]
		for r in 4:
			box(n, Vector3(1.7, 0.1, 0.12), Vector3(0, 0.09, -0.45 + r * 0.3), crop)

static func _flowers(level: Node, root: Node3D, rng: RandomNumberGenerator, snow: bool) -> void:
	var cols := [Color(1, 0.85, 0.3), Color(0.95, 0.45, 0.6), Color(0.6, 0.55, 1.0), Color(1, 1, 1)]
	if snow:
		cols = [Color(0.8, 0.9, 1.0), Color(0.6, 0.75, 1.0)]
	for i in 60:
		var p := Vector3(rng.randf_range(-6, 26), 0, rng.randf_range(-5, 17))
		if not _free_spot(level, p, 1.0):
			continue
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.1
		sm.radial_segments = 6
		sm.rings = 3
		sm.material = mat(cols[rng.randi_range(0, cols.size() - 1)])
		s.mesh = sm
		root.add_child(s)
		s.position = p + Vector3(0, 0.05, 0)

# ---------------------------------------------------------------- devastation pieces
static func crater(parent: Node3D, p: Vector3, r: float) -> void:
	var c := cyl(parent, r, r * 1.1, 0.02, p, Color(0.16, 0.13, 0.11))
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.scale = Vector3(1.0, 1.0, randf_range(0.7, 1.0))
	for i in 5:
		var a := randf() * TAU
		var b := box(parent, Vector3(0.08, 0.06, 0.08), p + Vector3(cos(a) * r, 0.03, sin(a) * r), Color(0.3, 0.27, 0.24), randf() * PI)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func debris(parent: Node3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	for i in rng.randi_range(3, 5):
		var b := box(parent, Vector3(rng.randf_range(0.08, 0.22), rng.randf_range(0.05, 0.12), rng.randf_range(0.08, 0.3)),
			p + Vector3(rng.randf_range(-0.3, 0.3), 0.05, rng.randf_range(-0.3, 0.3)),
			[Color(0.45, 0.43, 0.4), Color(0.4, 0.27, 0.15), Color(0.2, 0.2, 0.2)][rng.randi_range(0, 2)], rng.randf() * PI)
		b.rotation.z = rng.randf_range(-0.4, 0.4)

static func fire(parent: Node3D, p: Vector3, size: float) -> void:
	var f := CPUParticles3D.new()
	var m := SphereMesh.new()
	m.radius = 0.07 * size
	m.height = 0.14 * size
	m.radial_segments = 6
	m.rings = 3
	m.material = FX.emissive_mat(Color(1.0, 0.5, 0.1), 3.5)
	f.mesh = m
	f.amount = 14
	f.lifetime = 0.8
	f.direction = Vector3.UP
	f.spread = 18.0
	f.initial_velocity_min = 0.4 * size
	f.initial_velocity_max = 0.9 * size
	f.gravity = Vector3(0, 0.6, 0)
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	f.emission_sphere_radius = 0.12 * size
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	f.scale_amount_curve = curve
	f.color = Color(1, 1, 1)
	parent.add_child(f)
	f.global_position = p
	# จำกัดจำนวนไฟส่องสว่าง (เว็บ/GL Compatibility รับแสงได้จำกัด)
	if parent.get_tree().get_nodes_in_group("fire_light").size() >= 6:
		return
	var l := OmniLight3D.new()
	l.add_to_group("fire_light")
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 1.2
	l.omni_range = 1.6 * size
	parent.add_child(l)
	l.global_position = p + Vector3.UP * 0.3
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "light_energy", 0.7, randf_range(0.1, 0.2))
	tw.tween_property(l, "light_energy", 1.3, randf_range(0.1, 0.2))

static func smoke_column(parent: Node3D, p: Vector3) -> void:
	var s := CPUParticles3D.new()
	var m := SphereMesh.new()
	m.radius = 0.25
	m.height = 0.5
	m.radial_segments = 6
	m.rings = 3
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.18, 0.17, 0.17, 0.5)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = sm
	s.mesh = m
	s.amount = 16
	s.lifetime = 4.0
	s.direction = Vector3.UP
	s.spread = 10.0
	s.initial_velocity_min = 0.5
	s.initial_velocity_max = 0.8
	s.gravity = Vector3(0.15, 0.1, 0)
	s.scale_amount_min = 0.6
	s.scale_amount_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.6))
	s.scale_amount_curve = curve
	parent.add_child(s)
	s.global_position = p
