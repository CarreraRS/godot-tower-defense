extends Node3D

var enemies_in_range:Array[Node3D]
var current_enemy:Node3D = null
var current_enemy_class:Enemy = null
var current_enemy_targetted:bool = false
var acquire_slerp_progress:float = 0

var last_fire_time:int
@export var fire_rate_ms:int = 1000
@export var projectile_type:PackedScene

# ดึง AnimationPlayer จากโมเดล Wizard
@onready var anim_player: AnimationPlayer = $Wizard/AnimationPlayer

func _on_patrol_zone_area_entered(area):
	if current_enemy == null:
		current_enemy = area
	enemies_in_range.append(area)

func _on_patrol_zone_area_exited(area):
	enemies_in_range.erase(area)

func set_patrolling(patrolling:bool):
	$PatrolZone.monitoring = patrolling
	
func rotate_towards_target(rtarget, delta):
	# กลับทิศทางเวกเตอร์โดยใส่ เครื่องหมายลบ (-) ด้านหน้า target_vector
	var target_vector = -$Wizard.global_position.direction_to(Vector3(rtarget.global_position.x, global_position.y, rtarget.global_position.z))
	var target_basis: Basis = Basis.looking_at(target_vector)
	
	var current_basis_normalized = $Wizard.basis.orthonormalized()
	$Wizard.basis = current_basis_normalized.slerp(target_basis, acquire_slerp_progress)
	
	acquire_slerp_progress += delta
	
	if acquire_slerp_progress > 1:
		$StateChart.send_event("to_attacking_state")

func _find_enemy_parent(n:Node):
	if n is Enemy:
		return n
	elif n.get_parent() != null:
		return _find_enemy_parent(n.get_parent())
	else:
		return null
		
func _on_patrolling_state_state_processing(_delta):
	if enemies_in_range.size() > 0:
		current_enemy = enemies_in_range[0]
		current_enemy_class = _find_enemy_parent(current_enemy)
		$StateChart.send_event("to_acquiring_state")

func _remove_current_enemy():
	print("Enemy finished")
	enemies_in_range.erase(current_enemy)
	
func _on_acquiring_state_state_entered():
	current_enemy_targetted = false
	acquire_slerp_progress = 0

func _on_acquiring_state_state_physics_processing(delta):
	if current_enemy != null and enemies_in_range.has(current_enemy):
		if current_enemy_class.attackable:
			rotate_towards_target(current_enemy, delta)
		else:
			enemies_in_range.erase(current_enemy)
	else:
		$StateChart.send_event("to_patrolling_state")

func _on_attacking_state_state_physics_processing(_delta):
	if current_enemy != null and current_enemy_class.attackable and enemies_in_range.has(current_enemy):
		if current_enemy_class.attackable:
			# หมุนตัวพ่อมดหันหน้าหาศัตรู
			$Wizard.look_at(Vector3(current_enemy.global_position.x, global_position.y, current_enemy.global_position.z))
			# หมุนกลับ 180 องศาเพื่อแก้ปัญหาหันหลัง
			$Wizard.rotate_y(deg_to_rad(180))
			
			_maybe_fire()
		else:
			enemies_in_range.erase(current_enemy)
	else:
		$StateChart.send_event("to_patrolling_state")

func _maybe_fire():
	if Time.get_ticks_msec() > (last_fire_time + fire_rate_ms):
		# เล่นท่าทางร่ายคาถา
		if anim_player and anim_player.has_animation("CharacterArmature|Spell1"):
			anim_player.play("CharacterArmature|Spell1")
			
			# เชื่อมต่อสัญญาณเมื่อเล่นท่าจบ ให้กลับไปเล่นท่า Idle
			if not anim_player.animation_finished.is_connected(_on_animation_finished):
				anim_player.animation_finished.connect(_on_animation_finished)

		# ยิงกระสุนเวทมนตร์ออกไป
		var projectile:Projectile = projectile_type.instantiate()
		projectile.starting_position = $Wizard/projectile_spawn.global_position
		projectile.target = current_enemy
		add_child(projectile)
		
		last_fire_time = Time.get_ticks_msec()

func _on_animation_finished(anim_name: String):
	# เมื่อท่า Spell1 เล่นจบ ให้กลับไปเล่นท่า Idle_Attacking
	if anim_name == "CharacterArmature|Spell1":
		if anim_player and anim_player.has_animation("CharacterArmature|Idle_Attacking"):
			anim_player.play("CharacterArmature|Idle_Attacking")

func _on_attacking_state_state_entered():
	last_fire_time = 0
	# เมื่อเข้าสู่สถานะโจมตี ให้เปลี่ยนเป็นท่าเตรียมพร้อมโจมตีก่อน
	if anim_player and anim_player.has_animation("CharacterArmature|Idle_Attacking"):
		anim_player.play("CharacterArmature|Idle_Attacking")
