extends RigidBody3D

class_name TrashItem

@export var trash_type: String = "Plastic"
@export var trash_value: int = 1
@export var interact_text: String = "Pick up Trash"

func _ready():
	# Use layer 2 for trash objects to differentiate from other grabbable objects if needed
	# or just use layer 1 but identify by class
	collision_layer = 1
	collision_mask = 1

func collect():
	# This function will be called by the player
	queue_free()
	return {"type": trash_type, "value": trash_value}
