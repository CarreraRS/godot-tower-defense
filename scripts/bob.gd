extends Node3D
## ขยับขึ้นลงเบา ๆ (ลอยตัว/เดิน)
@export var amplitude: float = 0.05
@export var speed: float = 3.0
@export var tilt_deg: float = 0.0
var _t: float = 0.0
var _base_y: float

func _ready() -> void:
	_base_y = position.y
	_t = randf() * TAU

func _process(delta: float) -> void:
	_t += delta * speed
	position.y = _base_y + sin(_t) * amplitude
	if tilt_deg != 0.0:
		rotation.z = deg_to_rad(sin(_t * 0.5) * tilt_deg)
