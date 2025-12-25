extends Control

class_name ComputerUI

signal buy_item(item_data)
signal sell_car(car_id)

@onready var tabs = $Panel/TabContainer
@onready var car_list = $Panel/TabContainer/Cars/ScrollContainer/VBoxContainer
@onready var machine_list = $Panel/TabContainer/Machines/ScrollContainer/VBoxContainer
@onready var sell_list = $Panel/TabContainer/Sell/ScrollContainer/VBoxContainer
@onready var player = get_tree().get_first_node_in_group("player")

var cars_for_sale = [
	{"id": "old_sedan", "name": "Old Sedan", "price": 500, "condition": "Rusty", "description": "A beat up sedan. Needs a lot of work."},
	{"id": "rusty_truck", "name": "Rusty Truck", "price": 1200, "condition": "Non-functional", "description": "Good for parts or a full restore."},
	{"id": "vintage_coupe", "name": "Vintage Coupe", "price": 2500, "condition": "Damaged", "description": "Classic car with potential high resale value."}
]

var machines_for_sale = [
	{"id": "crusher", "name": "Bottle Crusher", "price": 800, "description": "Reduces bottle volume for easier recycling."},
	{"id": "recycler", "name": "Recycling Machine", "price": 2000, "description": "Processes trash into raw materials."},
	{"id": "washer", "name": "Industrial Washer", "price": 1500, "description": "Cleans dirty items to increase their value."}
]

func _ready():
	hide()
	populate_cars()
	populate_machines()

func open():
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	populate_sell_list()

func close():
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func populate_cars():
	for car in cars_for_sale:
		var item = create_item_row(car, "buy_car")
		car_list.add_child(item)

func populate_machines():
	for machine in machines_for_sale:
		var item = create_item_row(machine, "buy_machine")
		machine_list.add_child(item)

func populate_sell_list():
	# Clear previous items
	for child in sell_list.get_children():
		child.queue_free()
	
	# Find all cars in the scene
	var cars = get_tree().get_nodes_in_group("sellable_cars")
	for car in cars:
		if car is CarObject:
			var data = {
				"name": car.car_name,
				"price": car.get_sell_value(),
				"condition": "Fixed" if car.is_fixed else "Damaged",
				"node": car
			}
			var item = create_sell_row(data)
			sell_list.add_child(item)

func create_item_row(data, type):
	var panel = PanelContainer.new()
	var hbox = HBoxContainer.new()
	panel.add_child(hbox)
	
	var label = Label.new()
	label.text = "%s - $%d\n%s" % [data["name"], data["price"], data.get("condition", "")]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	
	var btn = Button.new()
	btn.text = "Buy"
	btn.pressed.connect(Callable(self, "_on_buy_pressed").bind(data, type))
	hbox.add_child(btn)
	
	return panel

func create_sell_row(data):
	var panel = PanelContainer.new()
	var hbox = HBoxContainer.new()
	panel.add_child(hbox)
	
	var label = Label.new()
	label.text = "%s (%s)\nValue: $%d" % [data["name"], data["condition"], data["price"]]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	
	var btn = Button.new()
	btn.text = "Sell"
	btn.pressed.connect(Callable(self, "_on_sell_pressed").bind(data))
	hbox.add_child(btn)
	
	return panel

func _on_buy_pressed(data, type):
	if player and player.money >= data["price"]:
		player.money -= data["price"]
		if player.has_method("show_message"):
			player.show_message("Bought %s for $%d" % [data["name"], data["price"]])
		emit_signal("buy_item", {"type": type, "data": data})
	else:
		if player.has_method("show_message"):
			player.show_message("Not enough money!")

func _on_sell_pressed(data):
	if player:
		if player.has_method("add_money"):
			player.add_money(data["price"])
		else:
			player.money += data["price"]
			player.show_message("Sold %s for $%d" % [data["name"], data["price"]])
			
		data["node"].queue_free()
		populate_sell_list()

func _input(event):
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		close()
