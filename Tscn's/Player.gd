extends CharacterBody3D

# Movement parameters - Horror game pacing
const WALK_SPEED = 2.0
const SPRINT_SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002

# View bobbing parameters
const BOB_FREQ = 2.0 # Footstep frequency
const BOB_AMP = 0.05 # Vertical amplitude (subtle for horror)
const BOB_AMP_SPRINT = 0.08 # More intense during sprint
var bob_time = 0.0

# Camera reference and base position
@onready var camera = $Camera3D
var camera_base_y = 1.6
@onready var bpm_label = $CanvasLayer/BPMLabel
@onready var stamina_label = $CanvasLayer/StaminaLabel
@onready var heart_ui = $CanvasLayer/HeartUI
@onready var red_flash_overlay = $CanvasLayer/RedFlashOverlay

# Item interaction
var raycast: RayCast3D
var current_item: Node3D = null
const INTERACTION_DISTANCE = 3.0

# Movement smoothing
const ACCELERATION = 8.0
const DECELERATION = 10.0

# Sprint FOV effect
const BASE_FOV = 85.0
const SPRINT_FOV = 95.0
const FOV_LERP_SPEED = 8.0

# Heart rate system
var heart_bpm: float = 60.0 # Resting heart rate
const NORMAL_BPM = 60.0
const SPRINT_BPM = 160.0 # Heart rate while sprinting (increased cap)
const MAX_BPM = 200.0 # Maximum possible BPM
const BPM_INCREASE_SPEED = 15.0 # Slower increase (was 30.0)
const BPM_DECREASE_SPEED = 25.0 # Faster recovery
const HIGH_BPM_THRESHOLD = 150.0 # BPM threshold for death timer
const HIGH_BPM_DEATH_TIME = 10.0 # Seconds above threshold before death
var high_bpm_timer: float = 0.0 # Tracks time spent above threshold
@onready var heartbeat_sound = $Camera3D/SFXManager/Heart
@onready var breathing_sound = $Camera3D/SFXManager/Breathing
@onready var footstep_sound = $Camera3D/woodenFloor/AudioStreamPlayer
var heartbeat_timer: float = 0.0

# Footstep sound system
var footstep_timer: float = 0.0
const WALK_FOOTSTEP_INTERVAL = 1  # Time between footsteps when walking
const SPRINT_FOOTSTEP_INTERVAL = 0.5  # Faster footsteps when sprinting

# Heart UI animation
var heart_pulse_time: float = 0.0
const MIN_HEART_SCALE = 0.8
const MAX_HEART_SCALE = 1.2
var red_flash_time: float = 0.0
const RED_FLASH_THRESHOLD = 120.0

# Monster proximity effects
var monster_bpm_modifier: float = 0.0 # Additional BPM from being near monster

# Stamina system
var stamina: float = 100.0 # Current stamina
const MAX_STAMINA = 100.0
const STAMINA_DRAIN_RATE = 20.0 # Stamina per second while sprinting
const STAMINA_RECOVERY_RATE = 15.0 # Stamina per second while not sprinting
const MIN_STAMINA_TO_SPRINT = 0.0 # Minimum stamina needed to start sprinting
var is_winded: bool = false
var winded_sound_played: bool = false

# Visual effects for high heart rate
var vignette_intensity: float = 0.0
const MAX_VIGNETTE = 0.3

# Gravity from project settings
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Sentry tracking
var sentry: Node = null

func _ready():
	# Capture mouse for FPS controls
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_base_y = camera.position.y
	
	# Setup raycast for item interaction
	raycast = RayCast3D.new()
	camera.add_child(raycast)
	raycast.target_position = Vector3(0, 0, -INTERACTION_DISTANCE)
	raycast.enabled = true
	raycast.collide_with_areas = true
	raycast.collide_with_bodies = true
	
	# Get Sentry node for tracking
	sentry = get_tree().get_first_node_in_group("sentry")
	if sentry:
		sentry.track_event("Player initialized")
	else:
		print("Warning: Sentry node not found")

	# Initialize item counter label
	if item_counter_label:
		item_counter_label.text = "Items: 0"


# Item pickup counter
var items_picked_up: int = 0
@onready var item_counter_label = $CanvasLayer/ItemCounterLabel

# Door interaction
var door_in_view: Node3D = null
var inside_door_in_view: Node3D = null

func _input(event):
	# Mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Rotate player body horizontally
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		# Rotate camera vertically
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		# Clamp vertical rotation to prevent over-rotation
		camera.rotation.x = clamp(camera.rotation.x, -PI / 2, PI / 2)

	# Door interaction with E key
	if (event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E)):
		if door_in_view:
			get_tree().change_scene_to_file("res://IsaacRm.tscn")
			return
		if inside_door_in_view:
			if items_picked_up >= 5:
				get_tree().change_scene_to_file("res://jacob_porch_win.tscn")
			else:
				inside_door_in_view.play_no_sound()
		# Item interaction
		if current_item and current_item.has_method("pick_up"):
			print("Picking up item: ", current_item)
			current_item.pick_up()
			items_picked_up += 1
			if item_counter_label:
				item_counter_label.text = "Items: " + str(items_picked_up)
			current_item = null

	# Release mouse with ESC (for testing)
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(delta: float) -> void:
	if stamina < 70:
		if breathing_sound: # Check if node exists
			if not breathing_sound.is_playing():
				breathing_sound.play()
			# Make louder as stamina gets lower - using very quiet volumes
			# Loudest at stamina 0 (-20 dB), quietest at stamina 50 (-40 dB)
			var new_volume = remap(stamina, 0.0, 50.0, -0.0, -20.0)
			breathing_sound.volume_db = new_volume
			# Make breathing faster as stamina decreases
			var breathing_speed = remap(stamina, 0.0, 70.0, 1.4, 1.0)
			breathing_sound.pitch_scale = breathing_speed
	else:
		if breathing_sound:
			breathing_sound.stop()
	
	# Check for items in front of the player
	_check_for_items()

func _check_for_items():
	door_in_view = null
	inside_door_in_view = null
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		# Door detection
		if collider and collider.is_in_group("door"):
			door_in_view = collider
			return
		if collider and collider.is_in_group("insideDoor"):
			inside_door_in_view = collider
			return
		# Check if we're looking at a shadowy entity
		if collider and collider.is_in_group("shadowy_entity"):
			if current_item != collider:
				if current_item and current_item.has_method("look_away"):
					current_item.look_away()
				current_item = collider
				if current_item.has_method("look_at_item"):
					current_item.look_at_item()
			return
		# Check if we're looking at an item
		if collider and collider.is_in_group("item"):
			# New item detected
			if current_item != collider:
				print("Looking at item: ", collider)
				# Clear previous item
				if current_item and current_item.has_method("look_away"):
					current_item.look_away()
				current_item = collider
				if current_item.has_method("look_at_item"):
					current_item.look_at_item()
		else:
			# Not looking at an item
			if current_item and current_item.has_method("look_away"):
				current_item.look_away()
			current_item = null
	else:
		# Not looking at anything
		if current_item and current_item.has_method("look_away"):
			current_item.look_away()
		current_item = null

func _physics_process(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Update stamina
	var wants_to_sprint = Input.is_action_pressed("sprint") and is_on_floor()
	var can_sprint = stamina >= MIN_STAMINA_TO_SPRINT and not is_winded
	
	# Check if sprinting (requires stamina)
	var is_sprinting = wants_to_sprint and can_sprint
	
	# Get input direction to check if moving
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var is_moving = input_dir.length() > 0.1
	
	# Drain stamina while sprinting and moving
	if is_sprinting and is_moving:
		stamina = max(0.0, stamina - STAMINA_DRAIN_RATE * delta)
		if stamina <= 0.0:
			is_winded = true
			if not winded_sound_played:
				# TODO: Play winded audio sound here
				# winded_sound.play()
				winded_sound_played = true
				print("Player is winded!")
				if sentry:
					sentry.track_event("Player winded", "stamina depleted")
	elif not wants_to_sprint:
		# Only recover stamina when not trying to sprint
		stamina = min(MAX_STAMINA, stamina + STAMINA_RECOVERY_RATE * delta)
		if stamina >= MAX_STAMINA * 0.3: # Reset winded state at 30% stamina
			is_winded = false
			winded_sound_played = false
	
	var current_speed = SPRINT_SPEED if is_sprinting else WALK_SPEED
	
	# Get direction for movement
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
	
	# Sprinting attracts the monster with sound
	if is_sprinting and horizontal_velocity > 0.5:
		# Call soundMade every frame while sprinting (distance and strength can be adjusted)
		soundMade(40.0, 0.6) # Moderate hear distance and strength for sprinting
	
	# Update heart rate based on player state
	_update_heart_rate(delta, is_sprinting, horizontal_velocity)
	
	# View bobbing effect
	if is_on_floor() and horizontal_velocity > 0.1:
		bob_time += delta * horizontal_velocity * BOB_FREQ
		
		# Footstep sound system
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			if footstep_sound:
				if is_sprinting:
					footstep_sound.volume_db = -5.0
					footstep_timer = SPRINT_FOOTSTEP_INTERVAL
				else:
					footstep_sound.volume_db = -10.0
					footstep_timer = WALK_FOOTSTEP_INTERVAL
				footstep_sound.pitch_scale = randf_range(0.8,1.2)
				footstep_sound.play()
				print("Playing footstep - Sprint: ", is_sprinting, " Volume: ", footstep_sound.volume_db)
		
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
		
		# Stop footstep sound when not moving
		if footstep_sound and footstep_sound.playing:
			footstep_sound.stop()
		footstep_timer = 0.0
	
	# Apply visual effects based on heart rate
	_apply_heart_rate_effects(delta)
	
	# Update heartbeat sound
	_update_heartbeat(delta)
	
	# Update heart UI animation
	_update_heart_ui(delta)
	
	move_and_slide()

func _update_heart_rate(delta, is_sprinting: bool, speed: float):
	# Determine target BPM based on player state
	var target_bpm = NORMAL_BPM
	var previous_bpm = heart_bpm
	
	if is_sprinting:
		# Sprinting increases heart rate significantly
		target_bpm = SPRINT_BPM
	elif speed > 0.5:
		# Walking increases heart rate moderately
		target_bpm = 70
	else:
		# Standing still, return to resting rate
		target_bpm = NORMAL_BPM
	
	# Add monster proximity modifier to target BPM
	target_bpm += monster_bpm_modifier
	target_bpm = clamp(target_bpm, NORMAL_BPM, MAX_BPM)
	
	# Smoothly transition to target BPM
	if heart_bpm < target_bpm:
		heart_bpm = min(heart_bpm + BPM_INCREASE_SPEED * delta, target_bpm)
	elif heart_bpm > target_bpm:
		heart_bpm = max(heart_bpm - BPM_DECREASE_SPEED * delta, target_bpm)
	
	# Track when BPM reaches critical levels
	if sentry and previous_bpm < 180 and heart_bpm >= 180:
		sentry.track_event("Critical BPM reached", "BPM: %.0f, Monster modifier: %.0f" % [heart_bpm, monster_bpm_modifier])
	
	# Death timer: track time spent above HIGH_BPM_THRESHOLD
	if heart_bpm >= HIGH_BPM_THRESHOLD:
		high_bpm_timer += delta
		if high_bpm_timer >= HIGH_BPM_DEATH_TIME:
			_trigger_death()
	else:
		high_bpm_timer = 0.0 # Reset timer when BPM drops below threshold

func _trigger_death():
	# Load and display death screen
	if sentry:
		sentry.track_event("Player died", "cause: heart rate above %.0f BPM for %.0f seconds" % [HIGH_BPM_THRESHOLD, HIGH_BPM_DEATH_TIME])
	
	var death_screen = load("res://Tscn's/DeathScreen.tscn").instantiate()
	get_tree().root.add_child(death_screen)


func _apply_heart_rate_effects(delta):
	# Calculate vignette intensity based on heart rate
	var stress_level = (heart_bpm - NORMAL_BPM) / (MAX_BPM - NORMAL_BPM)
	var target_vignette = clamp(stress_level * MAX_VIGNETTE, 0.0, MAX_VIGNETTE)
	vignette_intensity = lerp(vignette_intensity, target_vignette, delta * 5.0)
	
	# Add subtle camera shake at high heart rates
	if heart_bpm > 100.0:
		var shake_intensity = (heart_bpm - 100.0) / 80.0 # 0 to 1 range
		var shake_amount = shake_intensity * 0.01
		camera.position.x += randf_range(-shake_amount, shake_amount)
		camera.position.y += randf_range(-shake_amount, shake_amount)

func _update_heartbeat(delta):
	# Update BPM display
	if bpm_label:
		bpm_label.text = "BPM: " + str(int(heart_bpm))
	
	# Update stamina display
	if stamina_label:
		stamina_label.text = "Stamina: " + str(int(stamina))
		# Change color based on stamina level
		if stamina < 30.0:
			stamina_label.label_settings.font_color = Color(1, 0.2, 0.2, 1) # Red when low
		elif stamina < 60.0:
			stamina_label.label_settings.font_color = Color(1, 1, 0.2, 1) # Yellow when medium
		else:
			stamina_label.label_settings.font_color = Color(0.2, 1, 0.2, 1) # Green when high
	
	# Adjust playback speed based on BPM - moderate scaling
	# pitch_scale also controls playback speed in Godot
	if heartbeat_sound:
		# Less aggressive: 1.0x at 60 BPM to 2.0x at 200 BPM
		var speed_scale = remap(heart_bpm, NORMAL_BPM, MAX_BPM, 1.0, 3.0)
		heartbeat_sound.pitch_scale = clamp(speed_scale, 0.8, 2.2)
		
		# Much louder at high BPM: starts at 0 dB, goes up to +40 dB at max
		var volume_boost = remap(heart_bpm, NORMAL_BPM, MAX_BPM, 80, 90.0)
		heartbeat_sound.volume_db = -135 + volume_boost
		
		# Start playing if not already
		if not heartbeat_sound.playing:
			heartbeat_sound.play()
func _update_heart_ui(delta):
	if not heart_ui:
		return
	
	# Calculate pulse speed based on BPM (beats per minute to beats per second)
	var beats_per_second = heart_bpm / 60.0
	var pulse_speed = beats_per_second * TAU  # Convert to radians per second for sine wave
	heart_pulse_time += delta * pulse_speed
	
	# Create pulsing effect with sine wave (sharper pulse for more dramatic effect)
	var pulse = sin(heart_pulse_time)
	# Use power function to make the pulse more pronounced (sharper beat)
	var pulse_normalized = pulse * 0.5 + 0.5  # Convert from -1..1 to 0..1
	pulse_normalized = pow(pulse_normalized, 2.0)  # Square it for sharper pulse
	
	var scale_range = MAX_HEART_SCALE - MIN_HEART_SCALE
	var heart_scale = MIN_HEART_SCALE + pulse_normalized * scale_range
	
	# Apply scale
	heart_ui.scale = Vector2(heart_scale, heart_scale)
	
	# Change color intensity based on BPM (redder at higher BPM)
	var stress_level = clamp((heart_bpm - NORMAL_BPM) / (MAX_BPM - NORMAL_BPM), 0.0, 1.0)
	heart_ui.modulate = Color(1.0, 1.0 - stress_level * 0.5, 1.0 - stress_level * 0.5, 1.0)
	
	# Red vignette effect when BPM exceeds threshold
	if red_flash_overlay and heart_bpm > RED_FLASH_THRESHOLD:
		# Calculate flash speed and intensity based on how far above threshold
		var excess_bpm = heart_bpm - RED_FLASH_THRESHOLD
		var flash_intensity = clamp(excess_bpm / (MAX_BPM - RED_FLASH_THRESHOLD), 0.0, 1.0)
		
		# Flash synced with heartbeat
		var flash_pulse = sin(heart_pulse_time)
		var flash_normalized = flash_pulse * 0.5 + 0.5  # 0 to 1
		flash_normalized = pow(flash_normalized, 3.0)  # Sharp flash
		
		# Apply vignette with increasing maximum intensity
		var max_vignette_intensity = 0.3 + (flash_intensity * 0.7)  # 0.3 to 1.0 max intensity
		var vignette_intensity = flash_normalized * max_vignette_intensity
		
		# Update shader parameter
		if red_flash_overlay.material:
			red_flash_overlay.material.set_shader_parameter("intensity", vignette_intensity)
	else:
		# Fade out vignette when below threshold
		if red_flash_overlay and red_flash_overlay.material:
			var current_intensity = red_flash_overlay.material.get_shader_parameter("intensity")
			red_flash_overlay.material.set_shader_parameter("intensity", lerp(current_intensity, 0.0, delta * 5.0))
# Public method to trigger fear response (call this from other scripts)
func trigger_fear(intensity: float = 1.0):
	# Instantly spike heart rate based on intensity (0.0 to 1.0)
	var bpm_increase = intensity * 60.0 # Up to 60 BPM increase
	heart_bpm = min(heart_bpm + bpm_increase, MAX_BPM)
	
	# Track fear events in Sentry
	if sentry and intensity > 0.5:
		sentry.track_event("Player fear triggered", "intensity: %.2f, BPM: %.0f" % [intensity, heart_bpm])

# Public method to set sustained BPM increase from monster proximity
func set_monster_bpm_modifier(bpm_increase: float):
	monster_bpm_modifier = bpm_increase

# Public method to emit sounds that the monster can hear
func soundMade(HearDistance: float, Strength: float):
	# Find all monsters in the scene and notify them of the sound
	var monsters = get_tree().get_nodes_in_group("monster")
	for monster in monsters:
		var distance = global_position.distance_to(monster.global_position)
		if distance <= HearDistance:
			# Call the monster's hear_sound function with player position and strength
			monster.hear_sound(global_position, Strength, distance)
