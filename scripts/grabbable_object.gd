extends RigidBody3D

class_name GrabbableObject

# إعدادات الكائن القابل للإمساك
@export var is_grabbable: bool = true
@export var highlight_color: Color = Color.YELLOW
@export var original_color: Color = Color.WHITE
@export var mass_when_grabbed: float = 0.5

# المتغيرات الداخلية
var is_highlighted: bool = false
var original_mass: float
var mesh_instance: MeshInstance3D

func _ready():
	# حفظ الكتلة الأصلية
	original_mass = mass
	
	# البحث عن MeshInstance3D
	mesh_instance = find_mesh_instance()
	
	# تعيين طبقة التصادم
	collision_layer = 1  # Layer 1 for grabbable objects
	collision_mask = 1

func find_mesh_instance() -> MeshInstance3D:
	# البحث عن MeshInstance3D في العقد الفرعية
	for child in get_children():
		if child is MeshInstance3D:
			return child
		# البحث بشكل متكرر في العقد الفرعية
		var found = recursive_find_mesh(child)
		if found:
			return found
	return null

func recursive_find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = recursive_find_mesh(child)
		if found:
			return found
	return null

func highlight():
	if not is_grabbable or is_highlighted:
		return
	
	is_highlighted = true
	if mesh_instance:
		var material = mesh_instance.get_active_material(0)
		if material:
			# إنشاء مادة جديدة لتجنب التعديل على الأصلية
			var new_material = material.duplicate()
			new_material.albedo_color = highlight_color
			mesh_instance.set_surface_override_material(0, new_material)

func unhighlight():
	if not is_highlighted:
		return
	
	is_highlighted = false
	if mesh_instance:
		# استعادة المادة الأصلية
		mesh_instance.set_surface_override_material(0, null)

func on_grabbed():
	if not is_grabbable:
		return
	
	# تقليل الكتلة عند الإمساك
	mass = mass_when_grabbed
	
	# إضافة تأثير بصري إذا لزم الأمر
	print("تم الإمساك بالكائن: ", name)

func on_released():
	# استعادة الكتلة الأصلية
	mass = original_mass
	
	# إضافة تأثير بصري إذا لزم الأمر
	print("تم إفلات الكائن: ", name)

func on_thrown(force: Vector3):
	# يمكن إضافة تأثيرات خاصة عند الرمي
	print("تم رمي الكائن: ", name, " بقوة: ", force.length())
