extends RigidBody3D


# ==================================================
# OBJECT SETTINGS
# ==================================================

@export var max_health := 3
@export var rage_reward := 100
@export var break_pieces := 8
@export var break_force_min := 3.0
@export var break_force_max := 6.0
@export var break_piece_size := 0.25


# ==================================================
# GAME DATA
# ==================================================

var health := 0


# ==================================================
# READY
# ==================================================

func _ready():

	health = max_health


# ==================================================
# DAMAGE
# ==================================================

func take_damage(damage: int):

	health -= damage

	print(
		name,
		" HP: ",
		health
	)


	if health <= 0:

		destroy()


# ==================================================
# DESTROY
# ==================================================

func destroy():

	print(
		name,
		" DESTROYED"
	)


	# Player megkeresése

	var player = get_tree().get_first_node_in_group("player")


	if player != null:

		player.add_rage(
			rage_reward
		)

	else:

		print(
			"PLAYER NOT FOUND"
		)


	# Eredeti transform mentése

	var break_position := global_position
	var break_rotation := global_rotation

	var parent := get_parent()


	# Törmelék létrehozása

	for i in range(break_pieces):

		var piece := RigidBody3D.new()

		parent.add_child(piece)


		piece.global_position = break_position
		piece.global_rotation = break_rotation


		# Mesh

		var mesh_instance := MeshInstance3D.new()

		var box_mesh := BoxMesh.new()

		box_mesh.size = Vector3(
			break_piece_size,
			break_piece_size,
			break_piece_size
		)

		mesh_instance.mesh = box_mesh

		piece.add_child(
			mesh_instance
		)


		# Collision

		var collision := CollisionShape3D.new()

		var box_shape := BoxShape3D.new()

		box_shape.size = Vector3(
			break_piece_size,
			break_piece_size,
			break_piece_size
		)

		collision.shape = box_shape

		piece.add_child(
			collision
		)


		# Véletlenszerű pozíció

		piece.global_position += Vector3(
			randf_range(
				-0.35,
				0.35
			),

			randf_range(
				-0.35,
				0.35
			),

			randf_range(
				-0.35,
				0.35
			)
		)


		# Véletlenszerű repülési irány

		var explosion_direction := Vector3(
			randf_range(
				-1.0,
				1.0
			),

			randf_range(
				0.3,
				1.2
			),

			randf_range(
				-1.0,
				1.0
			)
		).normalized()


		piece.apply_central_impulse(
			explosion_direction
			* randf_range(
				break_force_min,
				break_force_max
			)
		)


		# 5 másodperc után eltűnik

		get_tree().create_timer(
			5.0
		).timeout.connect(
			piece.queue_free
		)


	# Eredeti tárgy törlése

	queue_free()
