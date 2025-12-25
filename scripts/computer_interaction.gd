extends StaticBody3D

class_name ComputerInteraction

@export var ui_scene: PackedScene
var ui_instance: ComputerUI

func _ready():
	if not ui_scene:
		ui_scene = load("res://scenc/computer_ui.tscn")
		
	if ui_scene:
		ui_instance = ui_scene.instantiate()
		# Add to CanvasLayer so it stays on screen
		var canvas = CanvasLayer.new()
		add_child(canvas)
		canvas.add_child(ui_instance)
		ui_instance.buy_item.connect(_on_buy_item)

func interact(player):
	if ui_instance:
		ui_instance.open()

func _on_buy_item(item_data):
	print("Item bought via computer: ", item_data)
	# Here we would spawn the car or machine
	# For now, let's just log it.
	match item_data["type"]:
		"buy_car":
			spawn_car(item_data["data"])
		"buy_machine":
			spawn_machine(item_data["data"])

func spawn_car(data):
	print("Spawning car: ", data["name"])
	# Load a generic car scene if specialized ones aren't available
	var car_scene = load("res://scenc/car_object.tscn")
	if not car_scene:
		# Fallback to a placeholder
		car_scene = PackedScene.new()
	
	var car = car_scene.instantiate()
	if car.has_method("set_deferred"):
		car.set("car_name", data["name"])
		car.set("base_value", data["price"])
	
	get_parent().add_child(car)
	
	# Find a spawn point or use a relative offset
	var spawn_node = get_tree().get_first_node_in_group("car_spawn_point")
	if spawn_node:
		car.global_position = spawn_node.global_position
	else:
		car.global_position = global_position + global_transform.basis * Vector3(3, 0, 0)

func spawn_machine(data):
	print("Spawning machine: ", data["name"])
	var scene_path = "res://scenc/machine_" + data["id"] + ".tscn"
	var machine_scene = load(scene_path)
	
	if not machine_scene:
		machine_scene = load("res://scenc/machine.tscn")
	
	if machine_scene:
		var machine = machine_scene.instantiate()
		get_parent().add_child(machine)
		
		var spawn_node = get_tree().get_first_node_in_group("machine_spawn_point")
		if spawn_node:
			machine.global_position = spawn_node.global_position
		else:
			machine.global_position = global_position + global_transform.basis * Vector3(-2, 0, 0)
