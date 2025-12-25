extends RigidBody3D

class_name CarObject

@export var car_name: String = "Old Sedan"
@export var base_value: int = 500
@export var fix_cost: int = 300
@export var is_fixed: bool = false

@onready var interaction_label = Label3D.new()

func _ready():
	add_to_group("sellable_cars")
	add_child(interaction_label)
	interaction_label.pixel_size = 0.005
	interaction_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interaction_label.position.y = 1.5
	update_ui()

func update_ui():
	if is_fixed:
		interaction_label.text = "%s (Fixed)\nWorth: $%d" % [car_name, int(base_value * 2.5)]
	else:
		interaction_label.text = "%s (Damaged)\nFix Cost: $%d\n[E] Fix" % [car_name, fix_cost]

func interact(player):
	if not is_fixed:
		if player.money >= fix_cost:
			player.money -= fix_cost
			fix_car()
			if player.has_method("show_message"):
				player.show_message("Fixed %s! Ready to sell." % car_name)
		else:
			if player.has_method("show_message"):
				player.show_message("Not enough money to fix!")
	else:
		if player.has_method("show_message"):
			player.show_message("This car is already fixed. Sell it via computer.")

func fix_car():
	is_fixed = true
	# Change visual appearance if possible
	# mesh.material_override = fixed_material
	update_ui()

func get_sell_value():
	return int(base_value * 2.5) if is_fixed else base_value
