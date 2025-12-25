extends StaticBody3D

class_name BaseMachine

enum MachineType { CRUSHER, RECYCLER, WASHER }

@export var type: MachineType = MachineType.CRUSHER
@export var processing_time: float = 3.0

var is_processing: bool = false
var current_item = null

@onready var label = Label3D.new()

func _ready():
	add_child(label)
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 1.0
	update_ui()

func update_ui():
	var type_name = MachineType.keys()[type]
	if is_processing:
		label.text = "Processing..."
	else:
		label.text = "%s Machine\n[E] Use" % type_name

func interact(player):
	if is_processing:
		player.show_message("Machine is busy...")
		return
	
	if player.grabbed_object and player.grabbed_object is TrashItem:
		process_item(player.grabbed_object)
		player.grabbed_object = null
	else:
		player.show_message("Hold an item to use the machine!")

func process_item(item):
	is_processing = true
	update_ui()
	
	var item_val = item.value
	item.queue_free()
	
	await get_tree().create_timer(processing_time).timeout
	
	finish_processing(item_val)

func finish_processing(original_value):
	is_processing = false
	var bonus = 1.0
	
	match type:
		MachineType.CRUSHER: bonus = 1.5
		MachineType.RECYCLER: bonus = 2.0
		MachineType.WASHER: bonus = 1.2
	
	var final_value = int(original_value * bonus)
	
	# Logic to spawn processed item or just give money
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.has_method("add_money"):
			player.add_money(final_value)
		else:
			player.money += final_value
			player.show_message("Processed item! Gained $%d" % final_value)
	
	update_ui()
