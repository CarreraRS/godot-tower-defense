extends Resource
class_name EnemyData
## ข้อมูลของศัตรูจากประตูมิติ

@export var id: StringName = &"soldier"
@export var display_name: String = "Soldier"
@export var thai_name: String = "ทหารราบ"
@export var model: PackedScene
@export var max_hp: float = 60.0
@export var speed: float = 1.0          ## ช่องต่อวินาที
@export var armor: float = 0.0          ## ลดดาเมจต่อการโจมตีหนึ่งครั้ง
@export var reward: int = 8
@export var base_damage: int = 1        ## ดาเมจรวมต่อกำแพงเมือง (= จำนวนครั้งที่ตีประตู ครั้งละ 1)
@export var attack_interval: float = 1.2 ## วินาทีระหว่างการตีประตูแต่ละครั้ง
@export var is_air: bool = false
@export var fly_height: float = 0.0
@export var is_boss: bool = false
@export var explodes: bool = false      ## ยานพาหนะ = ระเบิดเมื่อถูกทำลาย
@export var model_scale: float = 1.0
