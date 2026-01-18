extends Node3D

@export var look_threshold := 0.95
@export var max_distance := 20.0

@onready var camera: Camera3D = get_viewport().get_camera_3d()

var hidden := false

func _process(_delta):
	if hidden or camera == null:
		return

	var to_item = global_position - camera.global_position
	var distance = to_item.length()
	if distance > max_distance:
		return

	var dir = to_item.normalized()
	var camera_forward = -camera.global_transform.basis.z

	if dir.dot(camera_forward) < look_threshold:
		return

	# Raycast for line of sight
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		camera.global_position,
		global_position
	)

	# IMPORTANT: exclude both camera AND this object
	query.exclude = [camera, self]

	var result = space_state.intersect_ray(query)

	# If the ray hits ANYTHING, it's blocked (wall, object, etc.)
	if result:
		return

	# Nothing blocked the view → hide
	visible = false
	hidden = true
	set_process(false)
