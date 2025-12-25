extends StaticBody3D

class_name RecyclingMachine

@export var input_type: TrashItem.Type = TrashItem.Type.PLASTIC
@export var processing_time: float = 3.0
@export var output_value_multiplier: float = 2.0

@onready var input_area: Area3D = $InputArea
@onready var spawn_point: Marker3D = $SpawnPoint
@onready var timer: Timer = $Timer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_processing: bool = false
var processed_item_data: Dictionary = {}

func _ready():
	input_area.body_entered.connect(_on_body_entered)
	timer.timeout.connect(_on_processing_complete)
	timer.wait_time = processing_time
	timer.one_shot = true

func _on_body_entered(body: Node3D):
	if is_processing: return
	
	if body is TrashItem and body.type == input_type:
		start_processing(body)

func start_processing(item: TrashItem):
	is_processing = true
	processed_item_data = {
		"type": item.type,
		"value": int(item.value * output_value_multiplier)
	}
	
	# If player is holding it, release it
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		if player.grabbed_object == item:
			player.release_object()
			
	item.queue_free()
	
	if animation_player:
		animation_player.play("process")
	
	timer.start()
	print("Machine started processing...")

func _on_processing_complete():
	is_processing = false
	spawn_output()
	print("Processing complete!")

func spawn_output():
	var output_scene = preload("res://scenc/Trash.tscn") # Default processed item
	var output = output_scene.instantiate()
	get_parent().add_child(output)
	output.global_position = spawn_point.global_position
	
	# Update the new item properties
	if output is TrashItem:
		output.type = processed_item_data["type"]
		output.value = processed_item_data["value"]
		# Add a visual indicator that it's processed (e.g. change color)
		var mesh = output.get_node_or_null("MeshInstance3D")
		if mesh:
			var mat = mesh.get_active_material(0).duplicate()
			mat.emission_enabled = true
			mat.emission = Color.GOLD
			mat.emission_energy_multiplier = 0.5
			mesh.set_surface_override_material(0, mat)
