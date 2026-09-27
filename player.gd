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
@onready var rage_label: Label = $"../HUD/RageLabel"
@onready var feedback_label: Label = $"../HUD/FeedbackLabel"

var rage_points := 0
var combo_count := 0
var combo_timer := 0.0
var camera_rotation_x := 0.0
var feedback_message_id := 0


func _ready():
	add_to_group("player")

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.make_current()
	feedback_label.visible = false


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


func _physics_process(delta):
	if combo_timer > 0.0:
		combo_timer -= delta

		if combo_timer <= 0.0:
			combo_timer = 0.0
			combo_count = 0

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


func hit():
	hammer_swing()

	if not raycast.is_colliding():
		return

	var target = raycast.get_collider()

	if target is RigidBody3D:
		var direction = -camera.global_transform.basis.z

		target.apply_central_impulse(direction * 8.0)

		if target.has_method("take_damage"):
			target.take_damage(1)


func hammer_swing():
	var tween = create_tween()

	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		hammer,
		"rotation",
		Vector3(-1.0, 0.0, 0.0),
		0.08
	)

	tween.set_ease(Tween.EASE_IN)

	tween.tween_property(
		hammer,
		"rotation",
		Vector3.ZERO,
		0.12
	)


func add_rage(amount: int):
	if combo_timer > 0.0:
		combo_count += 1
	else:
		combo_count = 1

	combo_count = min(combo_count, max_combo)
	combo_timer = combo_window

	var earned_rage := amount * combo_count

	rage_points += earned_rage
	rage_label.text = "RAGE: " + str(rage_points)

	print("RAGE: ", rage_points)
	print("COMBO: x", combo_count)
	print("EARNED: ", earned_rage)

	show_destroy_message(earned_rage, combo_count)


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
