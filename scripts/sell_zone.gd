extends Area3D

@export var sell_multiplier: float = 1.0

func _ready():
	# الربط مع حدث دخول الأجسام
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D):
	if body is TrashItem:
		sell_item(body)

func sell_item(item: TrashItem):
	var value = int(item.get_value() * sell_multiplier)
	
	# البحث عن اللاعب وإعطاؤه المال
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		player.add_money(value)
		
		# إذا كان اللاعب يمسك بهذا الكائن، يجب عليه إفلاته قبل حذفه
		if player.grabbed_object == item:
			player.release_object()
			
		# حذف الكائن من العالم
		item.queue_free()
		print("Item sold for: ", value)
