extends CharacterBody3D

var game: Node
var speed := 5.2

func _physics_process(delta: float) -> void:
	var input_dir: Vector2 = game.movement_input() if is_instance_valid(game) else Vector2.ZERO
	var direction := Vector3(input_dir.x, 0, input_dir.y)
	if direction.length() > 0.08:
		direction = direction.normalized()
		velocity.x = move_toward(velocity.x, direction.x * speed, 24.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, 24.0 * delta)
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), minf(12.0 * delta, 1.0))
	else:
		velocity.x = move_toward(velocity.x, 0.0, 26.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 26.0 * delta)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	global_position.x = clampf(global_position.x, -15.5, 15.5)
	global_position.z = clampf(global_position.z, -13.5, 13.5)
