extends Node3D
## หมุนโหนดต่อเนื่อง (ใบพัดเฮลิคอปเตอร์ ฯลฯ)
@export var axis: Vector3 = Vector3.UP
@export var speed_deg: float = 900.0

func _process(delta: float) -> void:
	rotate_object_local(axis.normalized(), deg_to_rad(speed_deg) * delta)
