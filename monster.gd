extends Node3D

# Reference to the player node
var player = null

# Movement toward sound source
var target_position: Vector3 = Vector3.ZERO
var is_investigating: bool = false
const MOVE_SPEED = 2.0  # Base movement speed
var move_strength: float = 0.0

func _on_small_area_area_entered(area: Area3D) -> void:
	# Check if the area belongs to the player
	if area.get_parent().is_in_group("player"):
		player = area.get_parent()
		# High sustained BPM increase for small (close) area
		player.set_monster_bpm_modifier(100.0)


func _on_small_area_area_exited(area: Area3D) -> void:
	# Player left the small area - remove BPM modifier
	if area.get_parent().is_in_group("player"):
		var player_ref = area.get_parent()
		if player_ref:
			player_ref.set_monster_bpm_modifier(50.0)
		player = null


func _on_small_area_2_area_entered(area: Area3D) -> void:
	if area.get_parent().is_in_group("player"):
		player = area.get_parent()
		# High sustained BPM increase for small (close) area
		player.set_monster_bpm_modifier(50.0)


func _on_small_area_2_area_exited(area: Area3D) -> void:
	if area.get_parent().is_in_group("player"):
		var player_ref = area.get_parent()
		if player_ref:
			player_ref.set_monster_bpm_modifier(30.0)
		player = null


func _on_big_area_area_entered(area: Area3D) -> void:
	if area.get_parent().is_in_group("player"):
		player = area.get_parent()
		# Moderate sustained BPM increase for big (distant) area
		player.set_monster_bpm_modifier(30.0)


func _on_big_area_area_exited(area: Area3D) -> void:
	if area.get_parent().is_in_group("player"):
		var player_ref = area.get_parent()
		if player_ref:
			player_ref.set_monster_bpm_modifier(10.0)
		player = null


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
	
	# Strength affects how aggressively the monster moves
	# Distance affects the urgency (closer sounds = more urgent)
	var urgency = strength * (1.0 - (distance / 100.0))  # Normalize distance
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
