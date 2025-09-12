extends CharacterBody3D

const SPEED: float = 0.5            # wandering speed
const CHANGE_INTERVAL: float = 2.0  # seconds before picking new direction

var wander_dir: Vector3 = Vector3.ZERO
var wander_time: float = 0.0

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0

	# Countdown to next direction change
	wander_time -= delta
	if wander_time <= 0.0:
		_pick_new_direction()

	# Apply wandering movement on the XZ plane
	velocity.x = wander_dir.x * SPEED
	velocity.z = wander_dir.z * SPEED

	move_and_slide()

	# Optional: face the direction of travel
	if wander_dir.length_squared() > 0.0:
		#look_at(global_position + Vector3(wander_dir.x, 0, wander_dir.z), Vector3.UP)
		var face_dir := -wander_dir
		look_at(global_position + Vector3(face_dir.x, 0.0, face_dir.z), Vector3.UP)

func _pick_new_direction() -> void:
	# Random flat direction
	var dir := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD
	wander_dir = dir.normalized()

	# Pick new wander duration between 1–3 seconds
	wander_time = randf_range(1.0, 3.0)
