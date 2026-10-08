extends RigidBody3D

@export var speed: float = 6.0
## How fast velocity converges to the target, in 1/s.
@export var accel: float = 12.0
@export var mouse_sensitivity: float = 0.002
## Eye offset from the capsule center.
@export var eye_height: float = 0.7

## Max distance to grab or shove an item.
@export var reach: float = 3.0
## Distance in front of the camera where a dragged item is held.
@export var hold_distance: float = 1.5
## Max force pulling a dragged item. Items heavier than about drag_force / gravity
## are too heavy to move.
@export var drag_force: float = 250.0
## Throw impulse. Launch speed is throw_impulse / mass, so heavy items land closer.
@export var throw_impulse: float = 30.0

## How far a footstep is heard by enemies.
@export var step_noise_radius: float = 6.0
## Distance travelled between two footsteps. We can increase it to be more lenient
@export var step_length: float = 0.8

var _held: RigidBody3D
var _yaw: float = 0.0
var _pitch: float = 0.0
var _total_walked: float = 0.0
var _debug: bool = false

@onready var _camera: Camera3D = $Camera3D
@onready var _lamp: SpotLight3D = $Camera3D/Lamp
@onready var _beam: MeshInstance3D = $Camera3D/Lamp/Beam


func _ready() -> void:
	# Capture the mouse to prevent mouse from leaving the window
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# For Debug purposes
	var ring: TorusMesh = $NoiseRing.mesh
	ring.outer_radius = step_noise_radius
	ring.inner_radius = step_noise_radius - 0.06


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -1.55, 1.55)
	elif event.is_action_pressed("ui_cancel"):
		# Check for 'ESC' to free the mouse
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed(&"debug"): # F3
		_debug = not _debug
		get_tree().call_group(&"debug", &"set_visible", _debug)
	elif event.is_action_pressed(&"lamp"): # F
		_lamp.visible = not _lamp.visible
	elif event.is_action_pressed(&"grab"):
		if _held:
			_release()
		else:
			var body := _aimed_body()
			if body and body.is_in_group(&"draggable"): # Left-Click
				_held = body
				# Prevent riding the item we are holding
				add_collision_exception_with(body)
				# Prevent the held item from spinning
				body.lock_rotation = true
	elif event.is_action_pressed(&"throw"):
		# A throwable that is not held (or not draggable) is shoved from where it stands
		var body := _held if _held else _aimed_body()
		if body and body.is_in_group(&"throwable"): # Right-Click
			_release()
			# Same impulse for every item: launch speed is throw_impulse / mass
			body.apply_central_impulse(-_camera.global_basis.z * throw_impulse)


func _release() -> void:
	if _held:
		remove_collision_exception_with(_held)
		_held.lock_rotation = false
		_held = null


func _aimed_body() -> RigidBody3D:
	var from := _camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - _camera.global_basis.z * reach)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).get("collider") as RigidBody3D


func _process(_delta: float) -> void:
	## Prevent stuttering that we would get with get_global_transform()
	_camera.global_position = get_global_transform_interpolated().origin + Vector3.UP * eye_height
	_camera.rotation = Vector3(_pitch, _yaw, 0.0)

	if _beam.is_visible_in_tree():
		# Same ray as the enemies cast to find the spot lit by the lamp
		var from := _lamp.global_position
		var query := PhysicsRayQueryParameters3D.create(from, from - _lamp.global_basis.z * _lamp.spot_range)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var length: float = from.distance_to(hit.position) if hit else _lamp.spot_range
		# Starts below the eye, a line seen exactly end-on would only be a dot
		var start := Vector3(0.0, -0.15, 0.0)
		var end := Vector3(0.0, 0.0, -length)
		_beam.transform = Transform3D(Basis.looking_at(end - start), (start + end) / 2.0) 				.scaled_local(Vector3(1.0, 1.0, start.distance_to(end)))


func _physics_process(delta: float) -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var target := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, _yaw) * speed
	var diff := target - linear_velocity
	diff.y = 0.0
	# We do not want to rotate the player rigidbody
	apply_central_force(diff * accel * mass)

	# Everytime we walk a set distance start the hear function of all ennemies
	_total_walked += Vector2(linear_velocity.x, linear_velocity.z).length() * delta
	if _total_walked > step_length:
		_total_walked = 0.0
		get_tree().call_group(&"enemies", &"hear", global_position, step_noise_radius)

	if _held:
		var hold_point := _camera.global_position - _camera.global_basis.z * hold_distance
		var offset := hold_point - _held.global_position
		if offset.length() > reach:
			# Stuck behind something or left behind: let go
			_release()
		else:
			var pull := (offset * accel - _held.linear_velocity) * accel * _held.mass
			_held.apply_central_force(pull.limit_length(drag_force))
