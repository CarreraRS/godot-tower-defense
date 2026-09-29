extends Button

@export var activity_button_icon: Texture2D
@export var activity_draggable: PackedScene
@export var cost: int = 100

@onready var main = $"../.." # ปรับ NodePath ให้ตรงกับตำแหน่งของ Main Scene

var _is_dragging: bool = false
var _draggable: Node
var _is_valid_location: bool = false
var _last_valid_location: Vector3
var _cam: Camera3D
var RAYCAST_LENGTH: float = 100
@onready var _error_mat: BaseMaterial3D = preload("res://materials/red_transparent.material")

func _ready():
	if activity_button_icon:
		icon = activity_button_icon
	
	if activity_draggable:
		_draggable = activity_draggable.instantiate()
		if _draggable.has_method("set_patrolling"):
			_draggable.set_patrolling(false)
		add_child(_draggable)
		_draggable.visible = false
	
	_cam = get_viewport().get_camera_3d()

func _process(_delta):
	# ปิดใช้งานปุ่มถ้าเงินไม่พอ
	disabled = main.cash < cost

func _physics_process(_delta):
	if _is_dragging and _draggable:
		var space_state = _draggable.get_world_3d().direct_space_state
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var origin: Vector3 = _cam.project_ray_origin(mouse_pos)
		var end: Vector3 = origin + _cam.project_ray_normal(mouse_pos) * RAYCAST_LENGTH
		
		var query = PhysicsRayQueryParameters3D.create(origin, end, "100111".reverse().bin_to_int())
		query.collide_with_areas = true
		
		# --- เพิ่มส่วนนี้: ยกเว้น Collision ของตัวลากและยูนิตย่อยข้างใน ---
		var exceptions: Array[RID] = []
		_get_all_collision_rids(_draggable, exceptions)
		query.exclude = exceptions
		# --------------------------------------------------------
		
		var rayResult: Dictionary = space_state.intersect_ray(query)
		
		if rayResult.size() > 0:
			var co: CollisionObject3D = rayResult.get("collider")
			if co.get_groups().size() > 0 and co.get_groups()[0] == "grid_empty":
				_draggable.visible = true
				_is_valid_location = true
				_last_valid_location = Vector3(co.global_position.x, 0.2, co.global_position.z)
				_draggable.global_position = _last_valid_location
				clear_child_mesh_error(_draggable)
			else:
				_draggable.visible = true
				_draggable.global_position = Vector3(co.global_position.x, 0.2, co.global_position.z)
				_is_valid_location = false
				set_child_mesh_error(_draggable)
		else:
			_draggable.visible = false

# ฟังก์ชันช่วยดึง RID ของ Collision ทั้งหมดในยูนิต
func _get_all_collision_rids(n: Node, rids: Array[RID]):
	if n is CollisionObject3D:
		rids.append(n.get_rid())
	for c in n.get_children():
		_get_all_collision_rids(c, rids)

func set_child_mesh_error(n: Node):
	for c in n.get_children():
		if c is MeshInstance3D:
			set_mesh_error(c)
		
		# วนลูปค้นหาต่อแม้จะเป็น Node ทั่วไปหรือ Sub-Scene
		if c.get_child_count() > 0:
			set_child_mesh_error(c)

func set_mesh_error(mesh_3d: MeshInstance3D):
	# ป้องกัน Error หาก Node ไม่มีทรัพยากร Mesh
	if mesh_3d.mesh == null:
		return
		
	for si in mesh_3d.mesh.get_surface_count():
		mesh_3d.set_surface_override_material(si, _error_mat)

func clear_child_mesh_error(n: Node):
	for c in n.get_children():
		if c is MeshInstance3D:
			clear_mesh_error(c)
		
		# วนลูปค้นหาต่อแม้จะเป็น Node ทั่วไปหรือ Sub-Scene
		if c.get_child_count() > 0:
			clear_child_mesh_error(c)

func clear_mesh_error(mesh_3d: MeshInstance3D):
	# ป้องกัน Error หาก Node ไม่มีทรัพยากร Mesh
	if mesh_3d.mesh == null:
		return
		
	for si in mesh_3d.mesh.get_surface_count():
		mesh_3d.set_surface_override_material(si, null)

func _on_button_down():
	if main.cash >= cost:
		_is_dragging = true

func _on_button_up():
	_is_dragging = false
	if _draggable:
		_draggable.visible = false
	
	if _is_valid_location and main.cash >= cost:
		var activity = activity_draggable.instantiate()
		# เพิ่มไอเทมเข้าไปใน Main Scene โดยตรงเพื่อให้จัดการง่าย
		main.add_child(activity)
		activity.global_position = _last_valid_location
		main.cash -= cost
		_is_valid_location = false
