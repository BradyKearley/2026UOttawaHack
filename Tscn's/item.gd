extends Node3D

# Item properties
@export var item_name: String = "Item"
@export var can_be_picked_up: bool = true

# Visual feedback when player looks at item
var is_being_looked_at: bool = false
var original_scale: Vector3

func play_sfx():
	$AudioStreamPlayer3D.play()
func _ready():
	original_scale = scale
	# Add to "item" group so player can identify it
	add_to_group("item")

func _process(delta):
	# Slight hover animation when being looked at
	if is_being_looked_at:
		scale = original_scale * (1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.1)
	else:
		scale = lerp(scale, original_scale, delta * 5.0)

func look_at_item():
	is_being_looked_at = true

func look_away():
	is_being_looked_at = false

func pick_up():
	if can_be_picked_up:
		print(item_name + " picked up!")
		queue_free()  # Remove the item from the scene
