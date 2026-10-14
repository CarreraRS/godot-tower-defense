extends Node3D
class_name TDDefender
## ยูนิตฝ่ายอาณาจักรที่วางบนช่องว่าง: หาเป้าหมายในระยะ หันหน้า โจมตี
## และมีทักษะพิเศษกดใช้ (ปุ่ม F หรือปุ่มในแผงยูนิต) พร้อมคูลดาวน์

signal ability_used(unit: TDDefender)

var data: DefenderData
var level: int = 1
var cell: Vector2i
var total_spent: int = 0
var level_ref: Node
var preview: bool = false
var buff_mult: float = 1.0      ## จากออร่า (นักบุญ / ผู้กล้า)
var ability_left: float = 0.0   ## เวลาคูลดาวน์ที่เหลือ (0 = พร้อมใช้)

var _cooldown: float = 0.0
var _target: TDEnemy
var _pivot: Node3D
var _model: Node3D
var _muzzle: Node3D
var _range_ring: MeshInstance3D
var _stars: Label3D
var _base: MeshInstance3D
var _aura_fx: MeshInstance3D
var _buff_fx: MeshInstance3D
var _ready_fx: Node3D
var _model_base_scale: Vector3 = Vector3.ONE
var _sword: Node3D          ## ดาบ (อัศวิน/ผู้กล้า) — เหวี่ยงตอนโจมตี
var _sword_rest: Vector3
var _throw_arm: Node3D      ## แขนขว้าง (นักปรุงยา)
var _arm_rest: Vector3
var _anim_tw: Tween

const SFX := {"knight": ["slash", -10.0], "archer": ["bow", -15.0], "alchemist": ["throw", -13.0],
	"mage": ["zap", -13.0], "golem": ["thud", -7.0], "saint": ["chime", -15.0], "dragon": ["fire", -11.0],
	"hero": ["hero", -6.0]}
## บัฟชั่วคราว: {key: {t, dmg, rate, range, color}}
var _buffs: Dictionary = {}

func setup(d: DefenderData) -> void:
	data = d

func _ready() -> void:
	add_to_group("defenders")
	_base = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.36
	cyl.bottom_radius = 0.42
	cyl.height = 0.1
	cyl.radial_segments = 8
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.62, 0.6, 0.56) if not data.unique else Color(0.85, 0.7, 0.35)
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
	_model_base_scale = _model.scale
	_muzzle = _model.find_child("Muzzle", true, false) as Node3D
	_sword = _model.find_child("Sword", true, false) as Node3D
	if _sword:
		_sword_rest = _sword.rotation
	_throw_arm = _model.find_child("ThrowArm", true, false) as Node3D
	if _throw_arm:
		_arm_rest = _throw_arm.rotation

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

	if data.aura_radius > 0.0 and not preview:
		_aura_fx = _make_ring(Color(1.0, 0.8, 0.3, 0.35), 0.21)
		add_child(_aura_fx)

	if not preview:
		_buff_fx = _make_ring(Color(1, 1, 1, 0.8), 0.12)
		_buff_fx.scale = Vector3(0.45, 1, 0.45)
		_buff_fx.visible = false
		add_child(_buff_fx)
		if data.ability != DefenderData.Ability.NONE:
			_ready_fx = Node3D.new()
			var gem := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.09, 0.1, 0.09)
			pm.material = FX.emissive_mat(Color(1.0, 0.85, 0.3), 3.0)
			gem.mesh = pm
			gem.rotation_degrees.z = 180
			gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_ready_fx.add_child(gem)
			_ready_fx.position.y = 1.05 if not data.unique else 1.15
			add_child(_ready_fx)

	_stars = Label3D.new()
	_stars.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_stars.font_size = 40
	_stars.outline_size = 8
	_stars.pixel_size = 0.004
	_stars.modulate = Color(1, 0.85, 0.2)
	_stars.position.y = 0.9
	add_child(_stars)
	_refresh()

func _make_ring(c: Color, y: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var at := TorusMesh.new()
	at.inner_radius = 0.96
	at.outer_radius = 1.0
	at.rings = 48
	at.ring_segments = 3
	at.material = FX.emissive_mat(c, 1.5, true)
	m.mesh = at
	m.position.y = y
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

func _refresh() -> void:
	var r := current_range()
	_range_ring.scale = Vector3(r, 1, r)
	_stars.text = ("Lv%d" % level) if level > 1 else ""
	_model.scale = _model_base_scale * (1.0 + 0.08 * (level - 1))
	if _aura_fx:
		var ar := aura_radius()
		_aura_fx.scale = Vector3(ar, 1, ar)

func aura_radius() -> float:
	return data.aura_radius + 0.25 * (level - 1)

func aura_mult() -> float:
	return data.aura_mult + 0.05 * (level - 1)

func show_range(v: bool) -> void:
	if _range_ring:
		_refresh()
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

# ---------------------------------------------------------------- buffs
func add_buff(key: String, dmg: float, rate: float, rng: float, dur: float, color: Color) -> void:
	_buffs[key] = {"t": dur, "dmg": dmg, "rate": rate, "range": rng, "color": color}
	if _buff_fx:
		(_buff_fx.mesh as TorusMesh).material = FX.emissive_mat(Color(color.r, color.g, color.b, 0.85), 2.5, true)
		_buff_fx.visible = true
	_refresh()

func has_buffs() -> bool:
	return not _buffs.is_empty()

func dmg_mult() -> float:
	var m := buff_mult
	for b in _buffs.values():
		m *= b.dmg
	return m

func rate_mult() -> float:
	var m := 1.0
	for b in _buffs.values():
		m *= b.rate
	return m

func range_mult() -> float:
	var m := 1.0
	for b in _buffs.values():
		m *= b.range
	return m

func current_range() -> float:
	return data.range_at(level) * range_mult()

func _tick_buffs(delta: float) -> void:
	if _buffs.is_empty():
		return
	var changed := false
	for k in _buffs.keys():
		_buffs[k].t -= delta
		if _buffs[k].t <= 0.0:
			_buffs.erase(k)
			changed = true
	if changed:
		if _buff_fx:
			_buff_fx.visible = not _buffs.is_empty()
		_refresh()

# ---------------------------------------------------------------- ability
func ability_ready() -> bool:
	return data.ability != DefenderData.Ability.NONE and ability_left <= 0.0

func use_ability() -> bool:
	if preview or not ability_ready():
		return false
	ability_left = data.ability_cd
	var p := data.ability_power
	var dur := data.ability_dur
	var fxp := get_parent()
	var me := global_position
	match data.ability:
		DefenderData.Ability.POWER:
			add_buff("power", p, 1.0, 1.0, dur, Color(1.0, 0.35, 0.25))
			FX.ring(fxp, me + Vector3.UP * 0.1, 1.0, Color(1.0, 0.4, 0.3), 0.5)
			FX.hit_spark(fxp, me + Vector3.UP * 0.6, Color(1.0, 0.5, 0.3), 2.0)
		DefenderData.Ability.RAPID:
			add_buff("rapid", 1.0, p, 1.0, dur, Color(0.5, 1.0, 0.4))
			FX.ring(fxp, me + Vector3.UP * 0.1, 1.0, Color(0.5, 1.0, 0.4), 0.5)
		DefenderData.Ability.EMPOWER:
			add_buff("empower", p, 1.0, 1.5, dur, Color(0.55, 0.75, 1.0))
			FX.pillar(fxp, me, Color(0.55, 0.75, 1.0), 2.0, 0.3, 0.7)
		DefenderData.Ability.POTION:
			var from := _muzzle.global_position if _muzzle else me + Vector3.UP * 0.6
			for u in _allies_in(data.ability_radius):
				var ally := u as TDDefender
				FX.lob(fxp, from, ally.global_position + Vector3.UP * 0.5, 0.5, 0.8, Color(0.45, 1.0, 0.35), func():
					if is_instance_valid(ally):
						ally.add_buff("potion", p, 1.0, 1.0, dur, Color(0.45, 1.0, 0.35))
						FX.hit_spark(ally.get_parent(), ally.global_position + Vector3.UP * 0.5, Color(0.45, 1.0, 0.35), 1.2)
				)
		DefenderData.Ability.BLESS:
			for u in _allies_in(data.ability_radius):
				(u as TDDefender).add_buff("bless", p, 1.5, 1.0, dur, Color(1.0, 0.88, 0.45))
				FX.pillar(fxp, (u as Node3D).global_position, Color(1.0, 0.9, 0.55), 1.8, 0.25, 0.8)
			FX.ring(fxp, me + Vector3.UP * 0.1, data.ability_radius, Color(1.0, 0.9, 0.5), 0.8)
		DefenderData.Ability.QUAKE:
			var dmg := data.damage_at(level) * dmg_mult() * p
			for e in _enemies_in(data.ability_radius, false):
				e.take_damage(dmg, true)
				if e.alive:
					e.apply_slow(0.3, dur)
				FX.hit_spark(fxp, e.global_position + Vector3.UP * 0.1, Color(0.6, 0.5, 0.35), 1.2)
			FX.ring(fxp, me + Vector3.UP * 0.05, data.ability_radius, Color(0.7, 0.6, 0.4), 0.6)
			FX.ring(fxp, me + Vector3.UP * 0.05, data.ability_radius * 0.6, Color(0.45, 0.85, 1.0), 0.45)
			_shake(0.25)
		DefenderData.Ability.INFERNO:
			var dmg2 := data.damage_at(level) * dmg_mult() * p
			var mz := _muzzle.global_position if _muzzle else me + Vector3.UP * 0.8
			for e in _enemies_in(current_range() + 0.5, true):
				var pts := PackedVector3Array([mz, e.aim_point()])
				FX.beam(fxp, pts, Color(1.0, 0.5, 0.1), 0.35)
				FX.explosion(fxp, e.aim_point(), 0.6)
				e.take_damage(dmg2, true)
			FX.ring(fxp, me + Vector3.UP * 0.1, current_range(), Color(1.0, 0.45, 0.1), 0.6)
			_shake(0.2)
		DefenderData.Ability.HEROIC:
			var dmg3 := data.damage_at(level) * dmg_mult() * p
			for e in _enemies_in(data.ability_radius, true):
				FX.pillar(fxp, Vector3(e.global_position.x, 0.2, e.global_position.z), Color(0.65, 0.9, 1.0), 5.0, 0.3, 0.8)
				e.take_damage(dmg3, true)
			FX.pillar(fxp, me, Color(1.0, 0.95, 0.7), 6.0, 0.5, 1.0)
			FX.ring(fxp, me + Vector3.UP * 0.1, data.ability_radius, Color(0.7, 0.9, 1.0), 0.8)
			_shake(0.35)
	_play_attack()
	_sfx("ability", -6.0)
	match data.ability:
		DefenderData.Ability.QUAKE:
			_sfx("thud", 0.0)
		DefenderData.Ability.INFERNO:
			_sfx("fire", -2.0)
		DefenderData.Ability.HEROIC:
			_sfx("hero", 0.0)
			_sfx("rumble", -4.0)
		DefenderData.Ability.POTION:
			_sfx("throw", -6.0)
		DefenderData.Ability.BLESS:
			_sfx("chime", -4.0)
	FX.float_text(fxp, me + Vector3.UP * 1.1, data.ability_name, Color(1.0, 0.9, 0.4), 40)
	ability_used.emit(self)
	return true

func _shake(a: float) -> void:
	if level_ref and level_ref.get("rig") and level_ref.rig.has_method("shake"):
		level_ref.rig.shake(a)

func _allies_in(r: float) -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("defenders"):
		var d := n as TDDefender
		if d and not d.preview and d.global_position.distance_to(global_position) <= r + 0.05:
			out.append(d)
	return out

func _enemies_in(r: float, include_air: bool) -> Array[TDEnemy]:
	var out: Array[TDEnemy] = []
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as TDEnemy
		if e == null or not e.alive:
			continue
		if e.data.is_air and not include_air:
			continue
		if _in_range(e, r):
			out.append(e)
	return out

# ---------------------------------------------------------------- loop
func _process(delta: float) -> void:
	if _ready_fx:
		var rdy := ability_ready()
		_ready_fx.visible = rdy
		if rdy:
			_ready_fx.rotate_y(delta * 3.0)
			_ready_fx.position.y = (1.05 if not data.unique else 1.15) + sin(Time.get_ticks_msec() * 0.005) * 0.04

func _physics_process(delta: float) -> void:
	if preview:
		return
	if ability_left > 0.0:
		ability_left -= delta
	_tick_buffs(delta)
	_cooldown -= delta
	var r := current_range()
	if not _valid_target(_target, r):
		_target = null
		_target = _find_target(r)
	if _target == null:
		return
	var to := _target.global_position - global_position
	to.y = 0
	if to.length_squared() > 0.0001:
		var want := atan2(-to.x, -to.z)
		_pivot.rotation.y = lerp_angle(_pivot.rotation.y, want, clamp(delta * 10.0, 0.0, 1.0))
	if _cooldown <= 0.0:
		_cooldown = data.interval_at(level) / rate_mult()
		_play_attack()
		if _throw_arm:
			# รอให้แขนเหวี่ยงขึ้นก่อนค่อยปล่อยขวด
			get_tree().create_timer(0.13, false).timeout.connect(_delayed_attack.bind(_target))
		else:
			_attack(_target)

func _delayed_attack(tgt: Variant) -> void:
	if is_instance_valid(tgt) and (tgt as TDEnemy).alive:
		_attack(tgt)

func _valid_target(o: Variant, r: float) -> bool:
	if o == null or not is_instance_valid(o):
		return false
	var e := o as TDEnemy
	if e == null or not e.alive:
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
		if best == null or e.progress > best.progress:
			best = e
	return best

func _damage() -> float:
	return data.damage_at(level) * dmg_mult()

func _sfx(n: String, vol: float) -> void:
	if level_ref and level_ref.has_method("play_sfx"):
		level_ref.play_sfx(n, vol)

func _attack(target: TDEnemy) -> void:
	var dmg := _damage()
	if SFX.has(String(data.id)):
		var sx: Array = SFX[String(data.id)]
		_sfx(sx[0], sx[1])
	match data.attack_type:
		DefenderData.Attack.MELEE:
			if not is_instance_valid(target) or not target.alive:
				return
			var splash := data.splash_radius
			if _buffs.has("power"):
				splash = max(splash, data.ability_radius)
			if splash > 0.0:
				var c := target.global_position
				for n in get_tree().get_nodes_in_group("enemies"):
					var e := n as TDEnemy
					if e and e.alive and _can_hit(e) and e.global_position.distance_to(c) <= splash:
						e.take_damage(dmg, data.armor_pierce)
				if not data.unique:
					FX.ring(get_parent(), Vector3(c.x, 0.25, c.z), splash, data.projectile_color, 0.3)
				if data.unique:
					FX.beam(get_parent(), PackedVector3Array([global_position + Vector3.UP * 0.6, target.aim_point()]), data.projectile_color, 0.15)
			else:
				target.take_damage(dmg, data.armor_pierce)
			FX.hit_spark(get_parent(), target.aim_point(), data.projectile_color, 1.2)
			# รอยฟันดาบหันไปทางเป้าหมาย
			var big := data.unique or _buffs.has("power")
			var sc := Color(0.75, 0.92, 1.0) if data.unique else (Color(1.0, 0.55, 0.4) if _buffs.has("power") else Color(0.95, 0.97, 1.0))
			FX.slash(get_parent(), global_position + Vector3.UP * 0.42, _pivot.rotation.y, (1.6 if data.unique else (1.0 if big else 0.75)), sc)
		DefenderData.Attack.CHAIN:
			_chain(target, dmg)
		DefenderData.Attack.PULSE:
			_pulse(dmg)
		_:
			if not is_instance_valid(target) or not target.alive:
				return
			var p := TDProjectile.new()
			p.start_pos = _muzzle.global_position if _muzzle else global_position + Vector3.UP * 0.5
			p.target = target
			p.target_pos = target.aim_point()
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

func _chain(first: TDEnemy, dmg: float) -> void:
	## สายฟ้ากระโดดหลายเป้า (ดาเมจลดลงทีละ 25%)
	if not is_instance_valid(first) or not first.alive:
		return
	var pts := PackedVector3Array()
	pts.append(_muzzle.global_position if _muzzle else global_position + Vector3.UP * 0.8)
	var hit: Array = []
	var cur: TDEnemy = first
	var d := dmg
	for i in data.chain_count + 1:
		if cur == null:
			break
		pts.append(cur.aim_point())
		hit.append(cur)
		cur.take_damage(d, data.armor_pierce)
		d *= 0.75
		var nxt: TDEnemy = null
		var best := 1.8
		for n in get_tree().get_nodes_in_group("enemies"):
			var e := n as TDEnemy
			if e == null or not e.alive or hit.has(e) or not _can_hit(e):
				continue
			var dist := e.global_position.distance_to(pts[pts.size() - 1])
			if dist < best:
				best = dist
				nxt = e
		cur = nxt
	FX.beam(get_parent(), pts, data.projectile_color, 0.22)

func _pulse(dmg: float) -> void:
	## ทุบพื้นโจมตีรอบตัว + ทำให้ช้า
	var r := current_range()
	FX.ring(get_parent(), global_position + Vector3.UP * 0.05, r, data.projectile_color, 0.45)
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as TDEnemy
		if e == null or not e.alive or not _can_hit(e) or not _in_range(e, r):
			continue
		e.take_damage(dmg, data.armor_pierce)
		if e.alive and data.slow_duration > 0.0:
			e.apply_slow(data.slow_factor, data.slow_duration)
		FX.hit_spark(get_parent(), e.global_position + Vector3.UP * 0.1, data.projectile_color, 0.9)

func _play_attack() -> void:
	if _anim_tw and _anim_tw.is_valid():
		_anim_tw.kill()
		if _sword:
			_sword.rotation = _sword_rest
		if _throw_arm:
			_throw_arm.rotation = _arm_rest
	_anim_tw = create_tween()
	if _sword:
		# ง้างดาบขึ้น แล้วฟันลงด้านหน้า
		_anim_tw.tween_property(_sword, "rotation:x", _sword_rest.x + deg_to_rad(70.0), 0.07).set_ease(Tween.EASE_OUT)
		_anim_tw.tween_property(_sword, "rotation:x", _sword_rest.x - deg_to_rad(85.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_anim_tw.tween_property(_sword, "rotation:x", _sword_rest.x, 0.22).set_trans(Tween.TRANS_SINE)
	elif _throw_arm:
		# ยกแขนเหวี่ยงขวดขึ้นเหนือไหล่ แล้วลดแขนลง
		_anim_tw.tween_property(_throw_arm, "rotation:z", deg_to_rad(150.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_anim_tw.tween_property(_throw_arm, "rotation:z", _arm_rest.z, 0.3).set_trans(Tween.TRANS_SINE)
	else:
		var s := _model_base_scale * (1.0 + 0.08 * (level - 1))
		_anim_tw.tween_property(_model, "scale", s * Vector3(1.12, 0.9, 1.12), 0.06)
		_anim_tw.tween_property(_model, "scale", s, 0.12)
