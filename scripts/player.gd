extends RigidBody3D

@export var speed: float = 6.0
## How fast velocity converges to the target, in 1/s.
@export var accel: float = 12.0
@export var mouse_sensitivity: float = 0.002
## Eye offset from the capsule center.
@export var eye_height: float = 0.7

var _yaw: float = 0.0
var _pitch: float = 0.0

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	# Capture the mouse to prevent mouse from leaving the window
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -1.55, 1.55)
	elif event.is_action_pressed("ui_cancel"):
		# Check for 'ESC' to free the mouse
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	## Prevent stuttering that we would get with get_global_transform()
	_camera.global_position = get_global_transform_interpolated().origin + Vector3.UP * eye_height
	_camera.rotation = Vector3(_pitch, _yaw, 0.0)


func _physics_process(_delta: float) -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var target := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, _yaw) * speed
	var diff := target - linear_velocity
	diff.y = 0.0
	# We do not want to rotate the player rigidbody
	apply_central_force(diff * accel * mass)
