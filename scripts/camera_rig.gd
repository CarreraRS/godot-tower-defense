extends Node3D
## กล้องมุมสูง: WASD/ลูกศร = เลื่อน, ล้อเมาส์ = ซูม, คลิกกลางค้าง = ลาก, Q/E = หมุน

@export var bounds_min: Vector2 = Vector2(-2, -1)
@export var bounds_max: Vector2 = Vector2(21, 12)
@export var pan_speed: float = 9.0
@export var zoom_min: float = 7.0
@export var zoom_max: float = 22.0
@export var pitch_deg: float = 55.0

var zoom: float = 20.5
var _yaw: float = 0.0
var _shake: float = 0.0
var _dragging: bool = false
@onready var cam: Camera3D = $Camera3D

func _ready() -> void:
	_apply()

func shake(amount: float) -> void:
	_shake = max(_shake, amount)

func _process(delta: float) -> void:
	var real_dt: float = delta / max(Engine.time_scale, 0.001)
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): v.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): v.y += 1
	if Input.is_key_pressed(KEY_Q): _yaw += real_dt * 1.5
	if Input.is_key_pressed(KEY_E): _yaw -= real_dt * 1.5
	if v != Vector2.ZERO:
		var r := v.normalized().rotated(-_yaw) * pan_speed * real_dt * (zoom / 15.0)
		position.x += r.x
		position.z += r.y
	position.x = clamp(position.x, bounds_min.x, bounds_max.x)
	position.z = clamp(position.z, bounds_min.y, bounds_max.y)
	_shake = max(_shake - real_dt, 0.0)
	_apply()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom = clamp(zoom - 1.0, zoom_min, zoom_max)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom = clamp(zoom + 1.0, zoom_min, zoom_max)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var r: Vector2 = (-mm.relative * 0.02 * (zoom / 15.0)).rotated(-_yaw)
		position.x += r.x
		position.z += r.y

func _apply() -> void:
	rotation.y = _yaw
	var p := deg_to_rad(pitch_deg)
	cam.position = Vector3(0, sin(p) * zoom, cos(p) * zoom)
	cam.rotation = Vector3(-p, 0, 0)
	if _shake > 0.0:
		cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.5
