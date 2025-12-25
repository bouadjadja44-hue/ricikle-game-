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
@export var grab_distance: float = 2.5
@export var grab_force: float = 15.0
@export var throw_force: float = 10.0

# Nodes
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

# المتغيرات الأساسية
var gravity: float = 9.8
var is_running: bool = false

# متغيرات الحركة المتقدمة
var time_since_ground: float = 0.0
var time_since_jump_request: float = 0.0
var head_bob_time: float = 0.0
var original_head_position: Vector3

# متغيرات الكاميرا
var camera_pitch: float = 0.0

# متغيرات الإمساك
var grabbed_object: RigidBody3D = null
var original_grabbed_properties: Dictionary = {}

# Inventory System
var inventory: Dictionary = {}
var money: int = 0

@onready var interaction_label: Label = null
@onready var hold_position: Marker3D = null

func _ready():
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	original_head_position = head.position
	setup_ui()
	
	# نقطة الإمساك
	hold_position = Marker3D.new()
	camera.add_child(hold_position)
	hold_position.position = Vector3(0.3, -0.3, -0.8) # وضعية "اليد"

func setup_ui():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	interaction_label = Label.new()
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_KEEP_WIDTH, 100)
	canvas.add_child(interaction_label)
	
	var crosshair = ColorRect.new()
	crosshair.custom_minimum_size = Vector2(4, 4)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	canvas.add_child(crosshair)

func _physics_process(delta):
	update_timers(delta)
	handle_movement(delta)
	handle_grabbing(delta)
	handle_head_bob(delta)
	move_and_slide()

func update_timers(delta):
	if not is_on_floor():
		time_since_ground += delta
	else:
		time_since_ground = 0.0
	
	if Input.is_action_pressed("jump"):
		time_since_jump_request = 0.0
	else:
		time_since_jump_request += delta

func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		handle_mouse_look(event)
	
	if Input.is_action_just_pressed("ui_cancel"):
		toggle_mouse_mode()

func handle_movement(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	var can_jump = is_on_floor() or time_since_ground < coyote_time
	var jump_requested = time_since_jump_request < jump_buffer_time
	
	if can_jump and jump_requested:
		velocity.y = jump_velocity
		time_since_jump_request = jump_buffer_time
		time_since_ground = coyote_time
	
	is_running = Input.is_action_pressed("run")
	var current_speed = run_speed if is_running else walk_speed
	
	var input_dir = Input.get_vector("left", "right", "forward", "back")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if is_on_floor():
		if direction:
			velocity.x = move_toward(velocity.x, direction.x * current_speed, acceleration * delta)
			velocity.z = move_toward(velocity.z, direction.z * current_speed, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, friction * delta)
			velocity.z = move_toward(velocity.z, 0, friction * delta)
	else:
		if direction:
			velocity.x = move_toward(velocity.x, direction.x * current_speed * air_control, acceleration * delta * 0.5)
			velocity.z = move_toward(velocity.z, direction.z * current_speed * air_control, acceleration * delta * 0.5)

func handle_head_bob(delta):
	if is_on_floor() and velocity.length() > 0.1:
		head_bob_time += delta * head_bob_frequency * (run_speed if is_running else walk_speed)
		var bob_offset = Vector3(0, sin(head_bob_time * 2.0) * head_bob_amount, sin(head_bob_time) * head_bob_amount * 0.3)
		head.position = original_head_position + bob_offset
	else:
		head_bob_time = 0.0
		head.position = head.position.lerp(original_head_position, delta * 5.0)

func handle_mouse_look(event: InputEventMouseMotion):
	rotate_y(-event.relative.x * mouse_sensitivity)
	head.rotate_x(-event.relative.y * mouse_sensitivity)
	head.rotation.x = clamp(head.rotation.x, deg_to_rad(look_down_limit), deg_to_rad(look_up_limit))

func handle_grabbing(delta):
	if Input.is_action_just_pressed("grab"):
		if grabbed_object:
			release_object()
		else:
			process_interaction()
	
	if Input.is_action_just_pressed("throw") and grabbed_object:
		throw_object()
	
	if grabbed_object and is_instance_valid(grabbed_object):
		var target_pos = hold_position.global_position
		var current_pos = grabbed_object.global_position
		var direction = target_pos - current_pos
		
		# سحب الكائن نحو نقطة الإمساك
		grabbed_object.linear_velocity = direction * grab_force
		grabbed_object.angular_velocity = grabbed_object.angular_velocity.lerp(Vector3.ZERO, delta * 10.0)
		
		# إذا ابتعد كثيراً افلته
		if direction.length() > 2.0:
			release_object()

func process_interaction():
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		camera.global_position,
		camera.global_position + camera.global_transform.basis * Vector3.FORWARD * grab_distance
	)
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		
		# التحقق من وجود نظام تفاعل مخصص
		if collider.has_method("interact"):
			collider.interact(self)
			return

		if collider is RigidBody3D:
			grabbed_object = collider
			original_grabbed_properties = {
				"gravity_scale": grabbed_object.gravity_scale,
				"linear_damp": grabbed_object.linear_damp,
				"angular_damp": grabbed_object.angular_damp,
				"collision_layer": grabbed_object.collision_layer
			}
			
			grabbed_object.gravity_scale = 0.0
			grabbed_object.linear_damp = 10.0
			grabbed_object.angular_damp = 10.0
			grabbed_object.collision_layer = 0 # منع التصادم مع اللاعب أثناء الحمل

func release_object():
	if not grabbed_object: return
	grabbed_object.gravity_scale = original_grabbed_properties["gravity_scale"]
	grabbed_object.linear_damp = original_grabbed_properties["linear_damp"]
	grabbed_object.angular_damp = original_grabbed_properties["angular_damp"]
	grabbed_object.collision_layer = original_grabbed_properties["collision_layer"]
	grabbed_object = null

func add_money(amount: int):
	money += amount
	show_message("Sold Item: +$%d (Total: $%d)" % [amount, money])

func throw_object():
	if not grabbed_object: return
	var dir = camera.global_transform.basis * Vector3.FORWARD
	var obj = grabbed_object
	release_object()
	obj.apply_central_impulse(dir * throw_force)

func show_message(text: String):
	interaction_label.text = text
	interaction_label.modulate.a = 1.0
	var tween = get_tree().create_tween()
	tween.tween_property(interaction_label, "modulate:a", 0.0, 2.0).set_delay(1.5)

func toggle_mouse_mode():
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
