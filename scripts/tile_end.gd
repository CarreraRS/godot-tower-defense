extends Node3D

func _on_area_3d_area_entered(area: Area3D):
	# 1. เช็กว่าเป็น Area3D ของศัตรูหรือไม่
	if not area.is_in_group("enemies"):
		return

	# 2. ค้นหา PathFollow3D ของศัตรู
	# จากโครงสร้าง: Enemy01 -> Path3D -> PathFollow3D -> Enemy -> Area3D
	var path_follow: PathFollow3D = null
	
	# ลองหา PathFollow3D จาก Node แม่ไล่ขึ้นไป
	var parent = area.get_parent()
	while parent != null:
		if parent is PathFollow3D:
			path_follow = parent
			break
		parent = parent.get_parent()

	# 3. ถ้าเจอ PathFollow3D แต่เพิ่งเดินไปได้ไม่ถึง 80% (เพิ่งเกิด) ให้ข้ามไป ไม่นับเป็นจุดจบ
	if path_follow and path_follow.progress_ratio < 0.8:
		return

	print("ศัตรูเดินครบลูปมาถึงจุดสิ้นสุดแล้ว!")

	# 4. เรียกสั่งลดชีวิตใน Main Scene
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("enemy_reached_end"):
		main_scene.enemy_reached_end()

	# 5. สั่งเปลี่ยน State ของศัตรูไปที่ ToDamagingState เพื่อทำลายตัวละคร
	var enemy_root = area.owner
	if enemy_root == null:
		enemy_root = area.get_node_or_null("../../../..")

	if enemy_root and enemy_root.has_node("EnemyStateChart"):
		enemy_root.get_node("EnemyStateChart").send_event("ToDamagingState")
	elif enemy_root:
		enemy_root.queue_free()
	else:
		area.queue_free()
