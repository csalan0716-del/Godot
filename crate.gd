extends RigidBody3D

@export var max_health := 3
@export var rage_reward := 100

var health := max_health


func take_damage(damage: int):
	health -= damage

	print(name, " HP: ", health)

	if health <= 0:
		destroy()


func destroy():
	print(name, " DESTROYED")

	var player = get_tree().get_first_node_in_group("player")

	if player != null:
		player.add_rage(rage_reward)
	else:
		print("PLAYER NOT FOUND")

	var break_position = global_position
	var break_rotation = global_rotation
	var parent = get_parent()

	for i in range(8):
		var piece := RigidBody3D.new()

		parent.add_child(piece)

		piece.global_position = break_position
		piece.global_rotation = break_rotation

		var mesh_instance := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()

		box_mesh.size = Vector3(0.25, 0.25, 0.25)
		mesh_instance.mesh = box_mesh

		piece.add_child(mesh_instance)

		var collision := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()

		box_shape.size = Vector3(0.25, 0.25, 0.25)
		collision.shape = box_shape

		piece.add_child(collision)

		piece.global_position += Vector3(
			randf_range(-0.35, 0.35),
			randf_range(-0.35, 0.35),
			randf_range(-0.35, 0.35)
		)

		var explosion_direction := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(0.3, 1.2),
			randf_range(-1.0, 1.0)
		).normalized()

		piece.apply_central_impulse(
			explosion_direction * randf_range(3.0, 6.0)
		)

		get_tree().create_timer(5.0).timeout.connect(piece.queue_free)

	queue_free()
