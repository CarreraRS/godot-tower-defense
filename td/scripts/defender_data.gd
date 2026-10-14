extends Resource
class_name DefenderData
## ข้อมูลของยูนิตฝ่ายอาณาจักร (ป้อมป้องกัน) — แก้ค่าได้จาก Inspector

enum Ability { NONE, POWER, RAPID, POTION, EMPOWER, QUAKE, BLESS, INFERNO, HEROIC }
enum Attack { ARROW, BOLT, FIREBALL, ROCK, SPEAR, MELEE, CHAIN, PULSE }

@export var id: StringName = &"archer"
@export var display_name: String = "Archer"
@export var thai_name: String = "นักธนู"
@export_multiline var description: String = ""
@export var model: PackedScene
@export var icon: Texture2D
@export var color: Color = Color.WHITE

@export_group("Stats")
@export var cost: int = 60
@export var attack_range: float = 2.5
@export var damage: float = 10.0
@export var fire_interval: float = 1.0
@export var hits_ground: bool = true
@export var hits_air: bool = true
@export var splash_radius: float = 0.0
@export var armor_pierce: bool = false
@export var slow_factor: float = 1.0   ## 1 = ไม่ทำให้ช้า, 0.5 = ช้าลงครึ่งหนึ่ง
@export var slow_duration: float = 0.0
@export var chain_count: int = 0       ## CHAIN: จำนวนเป้าที่สายฟ้ากระโดดไปเพิ่ม
@export var unique: bool = false       ## วางได้ตัวเดียวต่อด่าน (ผู้กล้า)
@export var aura_radius: float = 0.0   ## เพิ่มดาเมจให้ยูนิตรอบตัว
@export var aura_mult: float = 1.0

@export_group("Attack Visual")
@export var attack_type: Attack = Attack.ARROW
@export var projectile_speed: float = 8.0
@export var projectile_color: Color = Color(1, 0.9, 0.6)
@export var attack_anim: StringName = &""   ## ชื่อแอนิเมชันโจมตีในโมเดล (ถ้ามี)
@export var idle_anim: StringName = &""
@export var attack_delay: float = 0.0       ## หน่วงเวลาให้ตรงจังหวะท่าโจมตี

@export_group("Ability")
## ทักษะกดใช้: 0=ไม่มี 1=POWER 2=RAPID 3=POTION 4=EMPOWER 5=QUAKE 6=BLESS 7=INFERNO 8=HEROIC
@export var ability: Ability = Ability.NONE
@export var ability_name: String = ""
@export_multiline var ability_desc: String = ""
@export var ability_cd: float = 25.0       ## คูลดาวน์ (วินาที)
@export var ability_dur: float = 6.0       ## ระยะเวลาที่ได้ผล
@export var ability_power: float = 2.0     ## ตัวคูณหลัก
@export var ability_radius: float = 2.5    ## รัศมี (สำหรับทักษะวงกว้าง)

@export_group("Upgrade")
@export var max_level: int = 3
@export var upgrade_cost_mult: float = 0.8

func upgrade_cost(level: int) -> int:
	return int(round(cost * upgrade_cost_mult * level / 5.0)) * 5

func damage_at(level: int) -> float:
	return damage * pow(1.5, level - 1)

func range_at(level: int) -> float:
	return attack_range + 0.3 * (level - 1)

func interval_at(level: int) -> float:
	return fire_interval * pow(0.9, level - 1)

func targets_text() -> String:
	if hits_ground and hits_air:
		return "ภาคพื้น + อากาศ"
	elif hits_air:
		return "อากาศเท่านั้น"
	return "ภาคพื้นเท่านั้น"
