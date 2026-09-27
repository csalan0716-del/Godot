extends CharacterBody3D

@export var speed := 5.0
@export var mouse_sensitivity := 0.0025
@export var gravity := 15.0
@export var jump_force := 5.0

@export var combo_window := 3.0
@export var max_combo := 5

@onready var camera: Camera3D = $Camera3D
@onready var raycast: RayCast3D = $Camera3D/RayCast3D
@onready var hammer: Node3D = $Camera3D/Hammer
@onready var baseball_bat: Node3D = $Camera3D/BaseballBat

@onready var rage_label: Label = $"../HUD/RageLabel"
@onready var level_label: Label = $"../HUD/LevelLabel"
@onready var feedback_label: Label = $"../HUD/FeedbackLabel"
@onready var unlock_label: Label = $"../HUD/UnlockPanel/UnlockLabel"

var rage_points := 0
var rage_level := 1
var baseball_bat_unlocked := false

var combo_count := 0
var combo_timer := 0.0

var camera_rotation_x := 0.0
var feedback_message_id := 0

# Weapon swing
var swing_timer := 0.0
var swing_duration := 0.20
var swing_weapon: Node3D = null

# FIX:
# Az Inspectorban beállított eredeti forgatásokat itt tároljuk.
var hammer_base_rotation := Vector3.ZERO
var baseball_bat_base_rotation := Vector3.ZERO


func _ready():
	add_to_group("player")

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.make_current()

	feedback_label.visible = false

	# Elmentjük az Inspectorban beállított alapforgatásokat.
	hammer_base_rotation = hammer.rotation
	baseball_bat_base_rotation = baseball_bat.rotation

	# Alapból a Hammer van elővéve.
	hammer.visible = true
	baseball_bat.visible = false

	update_rage_ui()
	update_level_ui()


func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			hit()

	elif event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)

		camera_rotation_x -= event.relative.y * mouse_sensitivity
		camera_rotation_x = clamp(camera_rotation_x, -1.5, 1.5)

		camera.rotation.x = camera_rotation_x

	elif event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		if event.pressed and event.keycode == KEY_1:
			switch_to_hammer()

		if event.pressed and event.keycode == KEY_2:
			switch_to_baseball_bat()


func _physics_process(delta):
	# Combo timer
	if combo_timer > 0.0:
		combo_timer -= delta

		if combo_timer <= 0.0:
			combo_timer = 0.0
			combo_count = 0

	# Weapon animation
	update_weapon_swing(delta)

	# Gravity / jump
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_key_pressed(KEY_SPACE):
		velocity.y = jump_force

	# Movement
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


func hit():
	weapon_swing()

	if not raycast.is_colliding():
		return

	var target = raycast.get_collider()

	if target is RigidBody3D:
		var direction = -camera.global_transform.basis.z

		var hit_force := 8.0

		# Baseball ütő erősebb.
		if baseball_bat.visible:
			hit_force = 14.0

		target.apply_central_impulse(direction * hit_force)

		if target.has_method("take_damage"):
			target.take_damage(1)


func weapon_swing():
	# Meghatározzuk az aktív fegyvert.
	if baseball_bat.visible:
		swing_weapon = baseball_bat
	else:
		swing_weapon = hammer

	# FONTOS:
	# Nem az aktuális rotationt mentjük el!
	# Mindig az eredeti Inspector-értéket használjuk.
	swing_timer = swing_duration


func update_weapon_swing(delta):
	if swing_timer <= 0.0:
		return

	if swing_weapon == null:
		return

	swing_timer -= delta

	var progress := 1.0 - (swing_timer / swing_duration)
	progress = clamp(progress, 0.0, 1.0)

	var rotation_offset := 0.0

	if progress < 0.5:
		# Előre lendítés
		var t := progress / 0.5
		rotation_offset = lerp(0.0, -1.0, t)
	else:
		# Visszatérés
		var t := (progress - 0.5) / 0.5
		rotation_offset = lerp(-1.0, 0.0, t)

	var base_rotation := Vector3.ZERO

	if swing_weapon == baseball_bat:
		base_rotation = baseball_bat_base_rotation
	else:
		base_rotation = hammer_base_rotation

	swing_weapon.rotation = base_rotation + Vector3(
		rotation_offset,
		0.0,
		0.0
	)

	# Animáció vége.
	if swing_timer <= 0.0:
		swing_weapon.rotation = base_rotation
		swing_weapon = null


func switch_to_hammer():
	hammer.visible = true
	baseball_bat.visible = false

	# Animáció megszakítása.
	swing_timer = 0.0
	swing_weapon = null

	# Vissza az eredeti Inspector pozícióba.
	hammer.rotation = hammer_base_rotation

	print("WEAPON: HAMMER")


func switch_to_baseball_bat():
	if not baseball_bat_unlocked:
		print("BASEBALL BAT LOCKED")
		return

	hammer.visible = false
	baseball_bat.visible = true

	# Animáció megszakítása.
	swing_timer = 0.0
	swing_weapon = null

	# Vissza az eredeti Inspector pozícióba.
	baseball_bat.rotation = baseball_bat_base_rotation

	print("WEAPON: BASEBALL BAT")


func add_rage(amount: int):
	if combo_timer > 0.0:
		combo_count += 1
	else:
		combo_count = 1

	combo_count = min(combo_count, max_combo)
	combo_timer = combo_window

	var earned_rage := amount * combo_count

	rage_points += earned_rage

	update_rage_ui()
	check_level_up()

	print("RAGE: ", rage_points)
	print("COMBO: x", combo_count)
	print("EARNED: ", earned_rage)

	show_destroy_message(earned_rage, combo_count)


func check_level_up():
	var new_level := get_level_from_rage(rage_points)

	if new_level > rage_level:
		rage_level = new_level

		print("RAGE LEVEL UP! Level ", rage_level)

		if rage_level >= 2 and not baseball_bat_unlocked:
			baseball_bat_unlocked = true

			unlock_label.text = """🔓 UNLOCKS

Level 1
🔨 Hammer - UNLOCKED

Level 2
🏏 Baseball Bat - UNLOCKED

Level 3
🔨 Sledgehammer - LOCKED

Level 4
💥 Chaos Hammer - LOCKED

Level 5
☢️ Chaos Room - LOCKED"""

	update_level_ui()


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


func update_rage_ui():
	rage_label.text = "RAGE: " + str(rage_points)


func update_level_ui():
	level_label.text = "RAGE LEVEL: " + str(rage_level)


func show_destroy_message(amount: int, combo: int):
	feedback_message_id += 1
	var current_message_id := feedback_message_id

	if combo > 1:
		feedback_label.text = "💥 DESTROYED\n+%d RAGE\n🔥 COMBO x%d" % [amount, combo]
	else:
		feedback_label.text = "💥 DESTROYED\n+%d RAGE" % amount

	feedback_label.visible = true
	feedback_label.modulate.a = 1.0

	await get_tree().create_timer(1.5).timeout

	if current_message_id == feedback_message_id:
		feedback_label.visible = false
