extends RigidBody3D

class_name TrashItem

enum Type { BOTTLE, PAPER, PLASTIC }

@export var type: Type = Type.PLASTIC
@export var value: int = 10

func _ready():
	collision_layer = 1
	collision_mask = 1

func get_value() -> int:
	return value

func get_type_name() -> String:
	return Type.keys()[type]
