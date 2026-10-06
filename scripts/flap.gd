extends Node3D
## กระพือปีก (หมุนรอบแกน Z ไปมา)
@export var amplitude_deg: float = 25.0
@export var speed: float = 6.0
@export var phase: float = 0.0
var _t: float = 0.0
var _base: Vector3

func _ready() -> void:
	_base = rotation

func _process(delta: float) -> void:
	_t += delta * speed
	rotation.z = _base.z + deg_to_rad(sin(_t + phase) * amplitude_deg)
