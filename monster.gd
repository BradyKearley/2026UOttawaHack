extends Node3D

# Reference to the player node
var player = null

# Movement toward sound source
var target_position: Vector3 = Vector3.ZERO
var is_investigating: bool = false
const MOVE_SPEED = 2.0 # Base movement speed
var move_strength: float = 0.0

func fade_out_sound(audio: AudioStreamPlayer3D, time: float = 1.0) -> void:
	if not audio or not audio.playing:
		return

	var tween = get_tree().create_tween()
	tween.tween_property(audio, "volume_db", -80.0, time)
	tween.finished.connect(func():
		audio.stop()
		# reset so next play isn't silent
	)

@onready var near_sound=$near
@onready var closest_sound=$closest
@onready var middle_near_sound=$middle_near

# Sentry tracking
var sentry: Node = null

func _ready():
	# Get Sentry node for error tracking
	sentry = get_tree().get_first_node_in_group("sentry")
	if sentry:
		sentry.track_event("Monster initialized")

func _on_small_area_area_entered(area: Area3D) -> void:
	# Check if the area belongs to the player
	if area.get_parent().is_in_group("player"):
		player = area.get_parent()
		# High sustained BPM increase for small (close) area
		player.set_monster_bpm_modifier(100.0)
		closest_sound.volume_db = -10
		closest_sound.play()


func _on_small_area_area_exited(area: Area3D) -> void:
	# Player left the small area - remove BPM modifier
	if area.get_parent().is_in_group("player"):
		var player_ref = area.get_parent()
		if player_ref:
			player_ref.set_monster_bpm_modifier(50.0)
		player = null
		fade_out_sound(closest_sound, 1.0)


func _on_small_area_2_area_entered(area: Area3D) -> void:
	if area.get_parent().is_in_group("player"):
		player = area.get_parent()
		# High sustained BPM increase for small (close) area
		player.set_monster_bpm_modifier(50.0)
		middle_near_sound.volume_db = 8.0
		middle_near_sound.play()

func _on_small_area_2_area_exited(area: Area3D) -> void:
	if area.get_parent().is_in_group("player"):
		var player_ref = area.get_parent()
		if player_ref:
			player_ref.set_monster_bpm_modifier(30.0)
		player = null
		fade_out_sound(middle_near_sound, 1.5)

func _on_big_area_area_entered(area: Area3D) -> void:
	if area.get_parent().is_in_group("player"):
		player = area.get_parent()
		# Moderate sustained BPM increase for big (distant) area
		player.set_monster_bpm_modifier(30.0)
		near_sound.volume_db = 60
		near_sound.play()

func _on_big_area_area_exited(area: Area3D) -> void:
	if area.get_parent().is_in_group("player"):
		var player_ref = area.get_parent()
		if player_ref:
			player_ref.set_monster_bpm_modifier(10.0)
		player = null
		fade_out_sound(near_sound, 1.5)

func _on_big_area_2_area_entered(area: Area3D) -> void:
	if area.get_parent().is_in_group("player"):
		player = area.get_parent()
		# Moderate sustained BPM increase for big (distant) area
		player.set_monster_bpm_modifier(10.0)


func _on_big_area_2_area_exited(area: Area3D) -> void:
	if area.get_parent().is_in_group("player"):
		var player_ref = area.get_parent()
		if player_ref:
			player_ref.set_monster_bpm_modifier(0.0)
		player = null

# Called by player when a sound is made
func hear_sound(sound_position: Vector3, strength: float, distance: float):
	# Set target position to move toward
	target_position = sound_position
	is_investigating = true
	move_strength = strength
	
	# Track when monster hears sound
	if sentry:
		sentry.track_event("Monster heard sound", "strength: %.2f, distance: %.1f" % [strength, distance])
	
	# Strength affects how aggressively the monster moves
	# Distance affects the urgency (closer sounds = more urgent)
	var urgency = strength * (1.0 - (distance / 100.0)) # Normalize distance
	move_strength = clamp(urgency, 0.1, 1.0)

func _process(delta):
	if is_investigating:
		# Move toward the target position
		var direction = (target_position - global_position).normalized()
		
		# Move speed is affected by sound strength
		var effective_speed = MOVE_SPEED * move_strength
		global_position += direction * effective_speed * delta
		
		# Stop investigating when close enough to the target
		if global_position.distance_to(target_position) < 1.0:
			is_investigating = false
			move_strength = 0.0
