extends CharacterBody3D

class_name PlayerController

# إعدادات الحركة الأساسية
@export_group("Movement Settings")
@export var walk_speed: float = 3.5
@export var run_speed: float = 6.0
@export var jump_velocity: float = 3.5
@export var acceleration: float = 5.0
@export var friction: float = 8.0
@export var air_control: float = 0.2
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.15

@export_group("Camera Settings")
@export var mouse_sensitivity: float = 0.0015
@export var controller_sensitivity: float = 1.5
@export var look_up_limit: float = 85.0
@export var look_down_limit: float = -85.0
@export var head_bob_amount: float = 0.03
@export var head_bob_frequency: float = 1.5

@export_group("Grab System")
@export var grab_distance: float = 3.0
@export var grab_force: float = 12.0
@export var throw_force: float = 15.0
@export var grab_smoothness: float = 8.0

# Nodes
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var foot_area: Area3D = $FootArea

# المتغيرات الأساسية
var gravity: float = 9.8
var is_running: bool = false
var is_on_ground: bool = false

# متغيرات الحركة المتقدمة
var time_since_ground: float = 0.0
var time_since_jump_request: float = 0.0
var head_bob_time: float = 0.0
var original_head_position: Vector3

# متغيرات الكاميرا
var camera_pitch: float = 0.0
var camera_yaw: float = 0.0

# متغيرات الإمساك
var grabbed_object: RigidBody3D = null
var grab_joint: PinJoint3D = null
var original_grabbed_properties: Dictionary = {}

func _ready():
	# إعداد وضع الماوس
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# ربط أحداث القدم
	foot_area.body_entered.connect(_on_foot_entered)
	foot_area.body_exited.connect(_on_foot_exited)
	
	# حفظ الموضع الأصلي للرأس
	original_head_position = head.position

func _physics_process(delta):
	# تحديث المؤقتات
	update_timers(delta)
	
	# معالجة الإدخال والحركة
	handle_movement(delta)
	handle_grabbing(delta)
	handle_head_bob(delta)
	
	# تطبيق الحركة
	move_and_slide()

func update_timers(delta):
	# تحديث مؤقت Coyote Time
	if not is_on_ground:
		time_since_ground += delta
	else:
		time_since_ground = 0.0
	
	# تحديث مؤقت Jump Buffer
	if Input.is_action_pressed("jump"):
		time_since_jump_request = 0.0
	else:
		time_since_jump_request += delta

func _input(event):
	# معالجة مدخلات الماوس والكونترولر
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		handle_mouse_look(event)
	elif event is InputEventJoypadMotion:
		handle_controller_look(event)
	
	# تبديل وضع الماوس
	if Input.is_action_just_pressed("ui_cancel"):
		toggle_mouse_mode()

func handle_movement(delta):
	# الجاذبية
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# القفز مع Coyote Time و Jump Buffer
	var can_jump = is_on_ground or time_since_ground < coyote_time
	var jump_requested = time_since_jump_request < jump_buffer_time
	
	if can_jump and jump_requested:
		velocity.y = jump_velocity
		time_since_jump_request = jump_buffer_time  # منع القفز المزدوج
	
	# الجري
	is_running = Input.is_action_pressed("run")
	
	# تحديد السرعة
	var current_speed = run_speed if is_running else walk_speed
	
	# حساب اتجاه الحركة
	var input_dir = Input.get_vector("left", "right", "forward", "back")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# تطبيق التسارع والاحتكاك بشكل واقعي
	if is_on_floor():
		# حركة على الأرض - أكثر تحكماً
		if direction:
			velocity.x = move_toward(velocity.x, direction.x * current_speed, acceleration * delta)
			velocity.z = move_toward(velocity.z, direction.z * current_speed, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, friction * delta)
			velocity.z = move_toward(velocity.z, 0, friction * delta)
	else:
		# حركة في الهواء - تحكم محدود
		if direction:
			velocity.x = move_toward(velocity.x, direction.x * current_speed * air_control, acceleration * delta * 0.5)
			velocity.z = move_toward(velocity.z, direction.z * current_speed * air_control, acceleration * delta * 0.5)

func handle_head_bob(delta):
	# Head Bob - حركة رأس خفيفة وطبيعية جداً
	if is_on_floor() and get_current_speed() > 0.1:
		head_bob_time += delta * head_bob_frequency * (run_speed if is_running else walk_speed)
		var bob_offset = Vector3(0, sin(head_bob_time * 2.0) * head_bob_amount, sin(head_bob_time) * head_bob_amount * 0.3)
		head.position = original_head_position + bob_offset
	else:
		head_bob_time = 0.0
		head.position = head.position.lerp(original_head_position, delta * 5.0)

func handle_mouse_look(event: InputEventMouseMotion):
	# دوران أفقي (الجسم كامل)
	var yaw_rotation = -event.relative.x * mouse_sensitivity
	rotate_y(yaw_rotation)
	
	# دوران عمودي (الرأس فقط)
	var pitch_rotation = -event.relative.y * mouse_sensitivity
	head.rotate_x(pitch_rotation)
	
	# تحديد حدود الدوران العمودي
	var clamped_pitch = clamp(head.rotation.x, deg_to_rad(look_down_limit), deg_to_rad(look_up_limit))
	head.rotation.x = clamped_pitch

func handle_controller_look(event: InputEventJoypadMotion):
	# التحكم بالكونترولر
	if event.axis == JOY_AXIS_RIGHT_X:
		rotate_y(-event.axis_value * controller_sensitivity * get_process_delta_time())
	elif event.axis == JOY_AXIS_RIGHT_Y:
		var pitch = -event.axis_value * controller_sensitivity * get_process_delta_time()
		camera_pitch += pitch
		camera_pitch = clamp(camera_pitch, deg_to_rad(look_down_limit), deg_to_rad(look_up_limit))
		head.rotation.x = camera_pitch

func handle_grabbing(_delta):
	# الإمساك بالكائن
	if Input.is_action_just_pressed("grab"):
		if grabbed_object:
			release_object()
		else:
			try_grab_object()
	
	# رمي الكائن
	if Input.is_action_just_pressed("throw") and grabbed_object:
		throw_object()
	
	# تحريك الكائن الممسوك
	if grabbed_object and grab_joint and is_instance_valid(grab_joint):
		var target_pos = camera.global_position + camera.global_transform.basis * Vector3.FORWARD * grab_distance
		grab_joint.global_position = target_pos

func try_grab_object():
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		camera.global_position,
		camera.global_position + camera.global_transform.basis * Vector3.FORWARD * grab_distance
	)
	query.collision_mask = 1  # Layer 1 for grabbable objects
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider is RigidBody3D:
		grabbed_object = result.collider
		
		# حفظ الخصائص الأصلية
		original_grabbed_properties = {
			"gravity_scale": grabbed_object.gravity_scale,
			"linear_damp": grabbed_object.linear_damp,
			"angular_damp": grabbed_object.angular_damp,
			"mass": grabbed_object.mass
		}
		
		# إنشاء وصلة تثبيت مع تحقق أفضل
		grab_joint = PinJoint3D.new()
		grab_joint.node_a = self.get_path()
		grab_joint.node_b = grabbed_object.get_path()
		grab_joint.global_position = result.position
		
		# إعدادات الوصلة الأكثر استقراراً
		grab_joint.params.spring_length = 0.0
		grab_joint.params.spring_stiffness = grab_force
		grab_joint.params.damping = 15.0
		grab_joint.params.max_force = 500.0
		
		# إضافة الوصلة بشكل آمن
		call_deferred("add_child_deferred", grab_joint)
		
		# تعديل خصائص الكائن الممسوك
		grabbed_object.gravity_scale = 0.05
		grabbed_object.linear_damp = 10.0
		grabbed_object.angular_damp = 10.0
		grabbed_object.mass = min(grabbed_object.mass, 3.0)  # تحديد أقصى كتلة
		
		print("✅ تم الإمساك بالكائن: ", grabbed_object.name)

func add_child_deferred(joint: PinJoint3D):
	add_child(joint)

func release_object():
	if not grabbed_object:
		return
	
	# إزالة الوصلة
	if grab_joint:
		grab_joint.queue_free()
		grab_joint = null
	
	# استعادة الخصائص الأصلية
	if not original_grabbed_properties.is_empty():
		grabbed_object.gravity_scale = original_grabbed_properties["gravity_scale"]
		grabbed_object.linear_damp = original_grabbed_properties["linear_damp"]
		grabbed_object.angular_damp = original_grabbed_properties["angular_damp"]
		grabbed_object.mass = original_grabbed_properties["mass"]
	
	print("🔄 تم إفلات الكائن: ", grabbed_object.name)
	grabbed_object = null
	original_grabbed_properties.clear()

func throw_object():
	if not grabbed_object:
		return
	
	# حساب اتجاه الرمي
	var throw_direction = camera.global_transform.basis * Vector3.FORWARD
	
	# تطبيق قوة الرمي
	grabbed_object.apply_central_impulse(throw_direction * throw_force)
	
	# إفلات الكائن
	release_object()
	
	print("🚀 تم رمي الكائن")

func toggle_mouse_mode():
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# أحداث القدم للكشف عن الأرض
func _on_foot_entered(body):
	is_on_ground = true

func _on_foot_exited(body):
	is_on_ground = false

# دالة للحصول على سرعة اللاعب الحالية
func get_current_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()

# دالة للتحقق مما إذا كان اللاعب يتحرك
func is_moving() -> bool:
	return get_current_speed() > 0.1
