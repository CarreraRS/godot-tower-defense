extends Resource
class_name EnemyData
## ข้อมูลของศัตรูจากประตูมิติ

@export var id: StringName = &"soldier"
@export var display_name: String = "Soldier"
@export var thai_name: String = "ทหารราบ"
@export var model: PackedScene
@export var icon: Texture2D
@export var max_hp: float = 60.0
@export var speed: float = 1.0          ## ช่องต่อวินาที
@export var armor: float = 0.0          ## ลดดาเมจต่อการโจมตีหนึ่งครั้ง
@export var reward: int = 8
@export var base_damage: int = 1        ## (เจ็ท) ดาเมจตอนพุ่งชนเมือง
@export var is_air: bool = false
@export var fly_height: float = 0.0
@export var is_boss: bool = false
@export var explodes: bool = false      ## ยานพาหนะ = ระเบิดเมื่อถูกทำลาย
@export var model_scale: float = 1.0
@export_multiline var lore: String = ""      ## บันทึกหน่วยสอดแนม (มุมมองอาณาจักร)
@export var counter: String = ""             ## คำแนะนำของเสนาธิการ

@export_group("Siege (ถึงหน้าเมือง)")
@export var attack_interval: float = 1.5   ## วินาทีต่อการโจมตีเมืองหนึ่งครั้ง
@export var strike_damage: int = 1          ## ลดกำแพงเมืองต่อครั้ง
@export var dive_attack: bool = false       ## พุ่งโจมตีครั้งเดียวแล้วหายไป (เจ็ท)

@export_group("Suppress (ยิงสกัดระหว่างทาง)")
@export var shoot_range: float = 0.0        ## 0 = ไม่ยิงยูนิตเรา
@export var shoot_interval: float = 4.0
@export var shoot_pause: float = 0.6        ## หยุดเดินขณะยิง
@export var shoot_stun: float = 1.0         ## ยูนิตเราหยุดทำงานกี่วินาที
@export var shoot_splash: float = 0.0
