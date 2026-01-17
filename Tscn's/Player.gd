extends CharacterBody3D

# Movement parameters - Horror game pacing
const WALK_SPEED = 2.0
const SPRINT_SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002

# View bobbing parameters
const BOB_FREQ = 2.0  # Footstep frequency
const BOB_AMP = 0.05  # Vertical amplitude (subtle for horror)
const BOB_AMP_SPRINT = 0.08  # More intense during sprint
var bob_time = 0.0

# Camera reference and base position
@onready var camera = $Camera3D
var camera_base_y = 1.6

# Movement smoothing
const ACCELERATION = 8.0
const DECELERATION = 10.0

# Sprint FOV effect
const BASE_FOV = 85.0
const SPRINT_FOV = 95.0
const FOV_LERP_SPEED = 8.0

# Gravity from project settings
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	# Capture mouse for FPS controls
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_base_y = camera.position.y

func _input(event):
	# Mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Rotate player body horizontally
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		# Rotate camera vertically
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		# Clamp vertical rotation to prevent over-rotation
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	# Release mouse with ESC (for testing)
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Check if sprinting
	var is_sprinting = Input.is_action_pressed("sprint") and is_on_floor()
	var current_speed = SPRINT_SPEED if is_sprinting else WALK_SPEED
	
	# Get input direction
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Apply movement with smooth acceleration/deceleration
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, DECELERATION * delta)
		velocity.z = move_toward(velocity.z, 0, DECELERATION * delta)
	
	# Calculate horizontal speed for view effects
	var horizontal_velocity = Vector2(velocity.x, velocity.z).length()
	
	# View bobbing effect
	if is_on_floor() and horizontal_velocity > 0.1:
		bob_time += delta * horizontal_velocity * BOB_FREQ
		var bob_amount = BOB_AMP_SPRINT if is_sprinting else BOB_AMP
		
		# Vertical bob (up and down)
		var bob_offset_y = sin(bob_time * 2.0) * bob_amount
		# Horizontal bob (side to side, subtle)
		var bob_offset_x = cos(bob_time) * bob_amount * 0.3
		
		camera.position.y = camera_base_y + bob_offset_y
		camera.position.x = bob_offset_x
		
		# Slight tilt for immersion
		camera.rotation.z = lerp(camera.rotation.z, -input_dir.x * 0.02, delta * 5.0)
	else:
		# Return to base position when not moving
		bob_time = 0.0
		camera.position.y = lerp(camera.position.y, camera_base_y, delta * 10.0)
		camera.position.x = lerp(camera.position.x, 0.0, delta * 10.0)
		camera.rotation.z = lerp(camera.rotation.z, 0.0, delta * 5.0)
	
	# Sprint FOV effect
	var target_fov = SPRINT_FOV if is_sprinting else BASE_FOV
	camera.fov = lerp(camera.fov, target_fov, delta * FOV_LERP_SPEED)
	
	move_and_slide()
