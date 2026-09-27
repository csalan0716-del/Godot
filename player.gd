extends CharacterBody3D

@export var speed := 5.0
@export var mouse_sensitivity := 0.0025
@export var gravity := 15.0
@export var jump_force := 5.0

@export var combo_window := 3.0
@export var max_combo := 5


# ==================================================
# CHAOS HAMMER
# ==================================================

@export var chaos_radius := 2.5
@export var chaos_force := 2.0


# ==================================================
# NODES
# ==================================================

@onready var camera: Camera3D = $Camera3D
@onready var raycast: RayCast3D = $Camera3D/RayCast3D

@onready var hammer: Node3D = $Camera3D/Hammer
@onready var baseball_bat: Node3D = $Camera3D/BaseballBat
@onready var sledgehammer: Node3D = $Camera3D/Sledgehammer
@onready var chaos_hammer: Node3D = $Camera3D/ChaosHammer

@onready var rage_label: Label = $"../HUD/RageLabel"
@onready var level_label: Label = $"../HUD/LevelLabel"
@onready var feedback_label: Label = $"../HUD/FeedbackLabel"
@onready var unlock_label: Label = $"../HUD/UnlockPanel/UnlockLabel"


# ==================================================
# GAME DATA
# ==================================================

var rage_points := 0
var rage_level := 1

var baseball_bat_unlocked := false
var sledgehammer_unlocked := false
var chaos_hammer_unlocked := false

var combo_count := 0
var combo_timer := 0.0

var camera_rotation_x := 0.0
var feedback_message_id := 0


# ==================================================
# WEAPON SWING
# ==================================================

var swing_timer := 0.0
var swing_duration := 0.20
var swing_weapon: Node3D = null

var hammer_base_rotation := Vector3.ZERO
var baseball_bat_base_rotation := Vector3.ZERO
var sledgehammer_base_rotation := Vector3.ZERO
var chaos_hammer_base_rotation := Vector3.ZERO


# ==================================================
# READY
# ==================================================

func _ready():

	add_to_group("player")

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.make_current()

	feedback_label.visible = false

	# Eredeti Inspector forgatások elmentése
	hammer_base_rotation = hammer.rotation
	baseball_bat_base_rotation = baseball_bat.rotation
	sledgehammer_base_rotation = sledgehammer.rotation
	chaos_hammer_base_rotation = chaos_hammer.rotation

	# Kezdő fegyver
	hammer.visible = true
	baseball_bat.visible = false
	sledgehammer.visible = false
	chaos_hammer.visible = false

	update_rage_ui()
	update_level_ui()
	update_unlock_ui()


# ==================================================
# INPUT
# ==================================================

func _input(event):

	if event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:

			hit()


	elif event is InputEventMouseMotion:

		rotate_y(
			-event.relative.x * mouse_sensitivity
		)

		camera_rotation_x -= (
			event.relative.y * mouse_sensitivity
		)

		camera_rotation_x = clamp(
			camera_rotation_x,
			-1.5,
			1.5
		)

		camera.rotation.x = camera_rotation_x


	elif event is InputEventKey:

		if event.pressed and event.keycode == KEY_ESCAPE:

			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


		# DEBUG RAGE
		# R = +500 RAGE

		if event.pressed and event.keycode == KEY_R:

			rage_points += 500

			check_level_up()
			update_rage_ui()

			print(
				"DEBUG RAGE: ",
				rage_points
			)


		# WEAPONS

		if event.pressed and event.keycode == KEY_1:

			switch_to_hammer()


		if event.pressed and event.keycode == KEY_2:

			switch_to_baseball_bat()


		if event.pressed and event.keycode == KEY_3:

			switch_to_sledgehammer()


		if event.pressed and event.keycode == KEY_4:

			switch_to_chaos_hammer()


# ==================================================
# PHYSICS
# ==================================================

func _physics_process(delta):

	if combo_timer > 0.0:

		combo_timer -= delta

		if combo_timer <= 0.0:

			combo_timer = 0.0
			combo_count = 0


	update_weapon_swing(delta)


	if not is_on_floor():

		velocity.y -= gravity * delta

	elif Input.is_key_pressed(KEY_SPACE):

		velocity.y = jump_force


	var direction := Vector3.ZERO


	if Input.is_key_pressed(KEY_W):

		direction -= transform.basis.z


	if Input.is_key_pressed(KEY_S):

		direction += transform.basis.z


	if Input.is_key_pressed(KEY_A):

		direction -= transform.basis.x


	if Input.is_key_pressed(KEY_D):

		direction += transform.basis.x


	direction.y = 0


	if direction.length() > 0:

		direction = direction.normalized()


	velocity.x = direction.x * speed
	velocity.z = direction.z * speed


	move_and_slide()


# ==================================================
# HIT
# ==================================================

func hit():

	weapon_swing()


	if not raycast.is_colliding():

		return


	var target = raycast.get_collider()


	# Ütési távolság ellenőrzése

	var hit_distance: float = camera.global_position.distance_to(
		raycast.get_collision_point()
	)


	if hit_distance > 2.2:

		return


	if target is RigidBody3D:

		var direction: Vector3 = -camera.global_transform.basis.z

		var hit_force := 8.0
		var damage := 1


		# HAMMER

		if hammer.visible:

			hit_force = 8.0
			damage = 1


		# BASEBALL BAT

		elif baseball_bat.visible:

			hit_force = 14.0
			damage = 1


		# SLEDGEHAMMER

		elif sledgehammer.visible:

			hit_force = 22.0
			damage = 2


		# CHAOS HAMMER

		elif chaos_hammer.visible:

			hit_force = 32.0
			damage = 3


		# Közvetlen találat

		target.apply_central_impulse(
			direction * hit_force
		)


		if target.has_method("take_damage"):

			target.take_damage(damage)


		# Chaos Hammer lökéshullám

		if chaos_hammer.visible:

			chaos_shockwave(
				target.global_position
			)


# ==================================================
# CHAOS SHOCKWAVE
# ==================================================

func chaos_shockwave(center: Vector3):

	for node in get_tree().current_scene.get_children():

		if node is RigidBody3D:

			var body: RigidBody3D = node


			var distance: float = center.distance_to(
				body.global_position
			)


			if distance <= chaos_radius:

				var direction: Vector3 = (
					body.global_position - center
				)


				if direction.length() < 0.01:

					direction = Vector3.UP


				direction = direction.normalized()


				var strength: float = (
					1.0 - (
						distance / chaos_radius
					)
				)


				strength = clamp(
					strength,
					0.0,
					1.0
				)


				var impulse: Vector3 = (
					direction
					* chaos_force
					* strength
				)


				# Kis extra felfelé lökés

				impulse.y += (
					2.0 * strength
				)


				body.apply_central_impulse(
					impulse
				)


				print(
					"CHAOS SHOCKWAVE -> ",
					body.name,
					" FORCE: ",
					impulse.length()
				)


# ==================================================
# WEAPON SWING
# ==================================================

func weapon_swing():

	if chaos_hammer.visible:

		swing_weapon = chaos_hammer

	elif sledgehammer.visible:

		swing_weapon = sledgehammer

	elif baseball_bat.visible:

		swing_weapon = baseball_bat

	else:

		swing_weapon = hammer


	swing_timer = swing_duration


# ==================================================
# UPDATE WEAPON SWING
# ==================================================

func update_weapon_swing(delta):

	if swing_timer <= 0.0:

		return


	if swing_weapon == null:

		return


	swing_timer -= delta


	var progress := 1.0 - (
		swing_timer / swing_duration
	)


	progress = clamp(
		progress,
		0.0,
		1.0
	)


	var rotation_offset := 0.0


	if progress < 0.5:

		var t := progress / 0.5

		rotation_offset = lerp(
			0.0,
			-1.0,
			t
		)

	else:

		var t := (
			progress - 0.5
		) / 0.5

		rotation_offset = lerp(
			-1.0,
			0.0,
			t
		)


	var base_rotation := Vector3.ZERO


	if swing_weapon == chaos_hammer:

		base_rotation = chaos_hammer_base_rotation

	elif swing_weapon == sledgehammer:

		base_rotation = sledgehammer_base_rotation

	elif swing_weapon == baseball_bat:

		base_rotation = baseball_bat_base_rotation

	else:

		base_rotation = hammer_base_rotation


	swing_weapon.rotation = (
		base_rotation
		+ Vector3(
			rotation_offset,
			0.0,
			0.0
		)
	)


	if swing_timer <= 0.0:

		swing_weapon.rotation = base_rotation
		swing_weapon = null


# ==================================================
# HAMMER
# ==================================================

func switch_to_hammer():

	hammer.visible = true
	baseball_bat.visible = false
	sledgehammer.visible = false
	chaos_hammer.visible = false

	swing_timer = 0.0
	swing_weapon = null

	hammer.rotation = hammer_base_rotation

	print("WEAPON: HAMMER")


# ==================================================
# BASEBALL BAT
# ==================================================

func switch_to_baseball_bat():

	if rage_points < 500:

		print(
			"BASEBALL BAT LOCKED - RAGE: ",
			rage_points
		)

		return


	baseball_bat_unlocked = true

	hammer.visible = false
	baseball_bat.visible = true
	sledgehammer.visible = false
	chaos_hammer.visible = false

	swing_timer = 0.0
	swing_weapon = null

	baseball_bat.rotation = baseball_bat_base_rotation

	print("WEAPON: BASEBALL BAT")


# ==================================================
# SLEDGEHAMMER
# ==================================================

func switch_to_sledgehammer():

	if rage_points < 1500:

		print(
			"SLEDGEHAMMER LOCKED - RAGE: ",
			rage_points
		)

		return


	sledgehammer_unlocked = true

	hammer.visible = false
	baseball_bat.visible = false
	sledgehammer.visible = true
	chaos_hammer.visible = false

	swing_timer = 0.0
	swing_weapon = null

	sledgehammer.rotation = sledgehammer_base_rotation

	print("WEAPON: SLEDGEHAMMER")


# ==================================================
# CHAOS HAMMER
# ==================================================

func switch_to_chaos_hammer():

	if rage_points < 3000:

		print(
			"CHAOS HAMMER LOCKED - RAGE: ",
			rage_points
		)

		return


	chaos_hammer_unlocked = true

	hammer.visible = false
	baseball_bat.visible = false
	sledgehammer.visible = false
	chaos_hammer.visible = true

	swing_timer = 0.0
	swing_weapon = null

	chaos_hammer.rotation = chaos_hammer_base_rotation

	print("WEAPON: CHAOS HAMMER")


# ==================================================
# RAGE
# ==================================================

func add_rage(amount: int):

	if combo_timer > 0.0:

		combo_count += 1

	else:

		combo_count = 1


	combo_count = min(
		combo_count,
		max_combo
	)


	combo_timer = combo_window


	var earned_rage := (
		amount * combo_count
	)


	rage_points += earned_rage


	update_rage_ui()
	check_level_up()


	print(
		"RAGE: ",
		rage_points
	)


	print(
		"COMBO: x",
		combo_count
	)


	print(
		"EARNED: ",
		earned_rage
	)


	show_destroy_message(
		earned_rage,
		combo_count
	)


# ==================================================
# LEVEL UP
# ==================================================

func check_level_up():

	var new_level := get_level_from_rage(
		rage_points
	)


	if new_level > rage_level:

		rage_level = new_level

		print(
			"RAGE LEVEL UP! Level ",
			rage_level
		)


	if rage_level >= 2:

		if not baseball_bat_unlocked:

			baseball_bat_unlocked = true

			print(
				"UNLOCKED: BASEBALL BAT"
			)


	if rage_level >= 3:

		if not sledgehammer_unlocked:

			sledgehammer_unlocked = true

			print(
				"UNLOCKED: SLEDGEHAMMER"
			)


	if rage_level >= 4:

		if not chaos_hammer_unlocked:

			chaos_hammer_unlocked = true

			print(
				"UNLOCKED: CHAOS HAMMER"
			)

			switch_to_chaos_hammer()


	update_unlock_ui()
	update_level_ui()


# ==================================================
# LEVEL CALCULATION
# ==================================================

func get_level_from_rage(points: int) -> int:

	if points >= 5000:

		return 5

	elif points >= 3000:

		return 4

	elif points >= 1500:

		return 3

	elif points >= 500:

		return 2

	else:

		return 1


# ==================================================
# RAGE UI
# ==================================================

func update_rage_ui():

	rage_label.text = (
		"RAGE: "
		+ str(rage_points)
	)


# ==================================================
# LEVEL UI
# ==================================================

func update_level_ui():

	level_label.text = (
		"RAGE LEVEL: "
		+ str(rage_level)
	)


# ==================================================
# UNLOCK UI
# ==================================================

func update_unlock_ui():

	var baseball_status := "LOCKED"
	var sledgehammer_status := "LOCKED"
	var chaos_hammer_status := "LOCKED"


	if rage_points >= 500:

		baseball_status = "UNLOCKED"


	if rage_points >= 1500:

		sledgehammer_status = "UNLOCKED"


	if rage_points >= 3000:

		chaos_hammer_status = "UNLOCKED"


	unlock_label.text = """🔓 UNLOCKS

Level 1
🔨 Hammer - UNLOCKED

Level 2
🏏 Baseball Bat - %s

Level 3
🔨 Sledgehammer - %s

Level 4
💥 Chaos Hammer - %s

Level 5
☢️ Chaos Room - LOCKED""" % [
		baseball_status,
		sledgehammer_status,
		chaos_hammer_status
	]


# ==================================================
# DESTROY FEEDBACK
# ==================================================

func show_destroy_message(
	amount: int,
	combo: int
):

	feedback_message_id += 1

	var current_message_id := (
		feedback_message_id
	)


	if combo > 1:

		feedback_label.text = (
			"💥 DESTROYED\n"
			+ "+%d RAGE\n" % amount
			+ "🔥 COMBO x%d" % combo
		)

	else:

		feedback_label.text = (
			"💥 DESTROYED\n"
			+ "+%d RAGE" % amount
		)


	feedback_label.visible = true
	feedback_label.modulate.a = 1.0


	await get_tree().create_timer(
		1.5
	).timeout


	if current_message_id == feedback_message_id:

		feedback_label.visible = false
