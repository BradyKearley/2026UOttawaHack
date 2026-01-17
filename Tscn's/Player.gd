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
@onready var bpm_label = $CanvasLayer/BPMLabel

# Movement smoothing
const ACCELERATION = 8.0
const DECELERATION = 10.0

# Sprint FOV effect
const BASE_FOV = 85.0
const SPRINT_FOV = 95.0
const FOV_LERP_SPEED = 8.0

# Heart rate system
var heart_bpm: float = 60.0  # Resting heart rate
const NORMAL_BPM = 60.0
const SPRINT_BPM = 160.0  # Heart rate while sprinting (increased cap)
const MAX_BPM = 200.0  # Maximum possible BPM
const BPM_INCREASE_SPEED = 15.0  # Slower increase (was 30.0)
const BPM_DECREASE_SPEED = 25.0  # Faster recovery
@onready var heartbeat_sound = $Camera3D/heartBeatSound/AudioStreamPlayer3D
var heartbeat_timer: float = 0.0

# Visual effects for high heart rate
var vignette_intensity: float = 0.0
const MAX_VIGNETTE = 0.3

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
	
	# Update heart rate based on player state
	_update_heart_rate(delta, is_sprinting, horizontal_velocity)
	
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
	
	# Apply visual effects based on heart rate
	_apply_heart_rate_effects(delta)
	
	# Update heartbeat sound
	_update_heartbeat(delta)
	
	move_and_slide()

func _update_heart_rate(delta, is_sprinting: bool, speed: float):
	# Determine target BPM based on player state
	var target_bpm = NORMAL_BPM
	
	if is_sprinting:
		# Sprinting increases heart rate significantly
		target_bpm = SPRINT_BPM
	elif speed > 0.5:
		# Walking increases heart rate moderately
		target_bpm = 80.0
	else:
		# Standing still, return to resting rate
		target_bpm = NORMAL_BPM
	
	# Smoothly transition to target BPM
	if heart_bpm < target_bpm:
		heart_bpm = min(heart_bpm + BPM_INCREASE_SPEED * delta, target_bpm)
	elif heart_bpm > target_bpm:
		heart_bpm = max(heart_bpm - BPM_DECREASE_SPEED * delta, target_bpm)

func _apply_heart_rate_effects(delta):
	# Calculate vignette intensity based on heart rate
	var stress_level = (heart_bpm - NORMAL_BPM) / (MAX_BPM - NORMAL_BPM)
	var target_vignette = clamp(stress_level * MAX_VIGNETTE, 0.0, MAX_VIGNETTE)
	vignette_intensity = lerp(vignette_intensity, target_vignette, delta * 5.0)
	
	# Add subtle camera shake at high heart rates
	if heart_bpm > 100.0:
		var shake_intensity = (heart_bpm - 100.0) / 80.0  # 0 to 1 range
		var shake_amount = shake_intensity * 0.01
		camera.position.x += randf_range(-shake_amount, shake_amount)
		camera.position.y += randf_range(-shake_amount, shake_amount)

func _update_heartbeat(delta):
	# Update BPM display
	if bpm_label:
		bpm_label.text = "BPM: " + str(int(heart_bpm))
	
	# Adjust playback speed based on BPM - moderate scaling
	# pitch_scale also controls playback speed in Godot
	if heartbeat_sound:
		# Less aggressive: 1.0x at 60 BPM to 2.0x at 200 BPM
		var speed_scale = remap(heart_bpm, NORMAL_BPM, MAX_BPM, 1.0, 2.0)
		heartbeat_sound.pitch_scale = clamp(speed_scale, 0.8, 2.2)
		
		# Much louder at high BPM: starts at 0 dB, goes up to +40 dB at max
		var volume_boost = remap(heart_bpm, NORMAL_BPM, MAX_BPM, 0.0, 40.0)
		heartbeat_sound.volume_db = 0.0 + volume_boost
		
		# Start playing if not already
		if not heartbeat_sound.playing:
			heartbeat_sound.play()

# Public method to trigger fear response (call this from other scripts)
func trigger_fear(intensity: float = 1.0):
	# Instantly spike heart rate based on intensity (0.0 to 1.0)
	var bpm_increase = intensity * 60.0  # Up to 60 BPM increase
	heart_bpm = min(heart_bpm + bpm_increase, MAX_BPM)
