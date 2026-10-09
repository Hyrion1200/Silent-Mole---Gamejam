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

## Speed at which a climb point pulls the player up, in m/s.
@export var climb_speed: float = 1.0

## How fast the camera is turned toward the enemy that captured the player, in rad/s.
@export var capture_turn_speed: float = 0.5

## How far a footstep is heard by enemies.
@export var step_noise_radius: float = 6.0
## Distance travelled between two footsteps. We can increase it to be more lenient
@export var step_length: float = 0.8

## Time between the captured signal and the respawn, in seconds
@export var respawn_delay: float = 5.0

## How long the lamp hint stays on screen once the lamp is picked up
@export var lamp_hint_duration: float = 5.0

## Steepest ground the player stands on, in degrees. Steeper --> slides down it
@export_range(0.0, 90.0, 1.0) var max_slope: float = 45.0
## How far under the feet the ground is still followed. Higher --> sticks better over bumps
## Keep it above max_step
@export var ground_snap: float = 0.2
## Highest ledge the player walks over as if it was a slope --> Used for rails
@export var max_step: float = 0.15

## Where to respawn the player, moved by the triggers with spawn_point_set
var spawn_point: Vector3
## Captured, placed and done turning to the captor's head. Read by the captor to send captured
var facing_captor: bool = false

## Picked up from the ground --> F does nothing before that
var _has_lamp: bool = false
var _held: RigidBody3D
var _yaw: float = 0.0
var _pitch: float = 0.0
var _total_walked: float = 0.0
var _debug: bool = false
var _move_tween: Tween
## The enemy that captured the player, and the height of its head above its center
var _captor: Node3D
var _captor_head: float = 0.0

@onready var _camera: Camera3D = $Camera3D
@onready var _lamp: SpotLight3D = $Camera3D/Lamp
@onready var _beam: MeshInstance3D = $Camera3D/Lamp/Beam
@onready var _prompt: Control = $Camera3D/Fade/Prompt
## From the center of the capsule down to the feet
@onready var _half_height: float = $CollisionShape3D.shape.height * $CollisionShape3D.scale.y / 2.0


func _ready() -> void:
	# Capture the mouse to prevent mouse from leaving the window
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spawn_point = global_position
	# The camera does not follow the rotation of the body
	# --> starts the way the player was turned in the editor
	_yaw = global_rotation.y
	# For Debug purposes
	var ring: TorusMesh = $NoiseRing.mesh
	ring.outer_radius = step_noise_radius
	ring.inner_radius = step_noise_radius - 0.06
	# Plane facing the camera at the end of the aim ray
	$Camera3D/Reach.position.z = -reach
	Music.follow_threats()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _captor:
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
	elif _debug and event.is_action_pressed(&"shake"): # C
		_camera.shake()
	elif _debug and event.is_action_pressed(&"fade_in"): # U
		_camera.fade_in()
	elif _debug and event.is_action_pressed(&"fade_out"): # I
		_camera.fade_out()
	elif _debug and event.is_action_pressed(&"cinematic"): # O
		# The cinematics live in the level, not under the player --> reached by group
		get_tree().call_group(&"cinematic", &"play")
	elif _captor:
		# Captured --> We can start something if needed
		pass
	elif event.is_action_pressed(&"lamp"): # F
		if _has_lamp:
			_lamp.visible = not _lamp.visible
	elif event.is_action_pressed(&"interact"): # E
		var target := _aimed(true)
		var point := target as ClimbPoint
		# Prevent retriggering climibing if already climbing or freezed (death animation for ex.)
		if point and not freeze:
			_climb(point)
		elif _is_lamp_pickup(target):
			_pick_lamp(target)
	elif event.is_action_pressed(&"grab"):
		if _held:
			_release()
		else:
			var body := _aimed_body()
			if body and body.is_in_group(&"draggable"): # Left-Click
				_drag(body)
	elif event.is_action_pressed(&"throw"):
		# A throwable that is not held (or not draggable) is shoved from where it stands
		var body := _held if _held else _aimed_body()
		if body and body.is_in_group(&"throwable"): # Right-Click
			_throw(body)


func _drag(body: RigidBody3D) -> void:
	_held = body
	# Prevent riding the item we are holding
	add_collision_exception_with(body)
	# Prevent the held item from spinning
	body.lock_rotation = true
	# Start the dragged SFX @Pierre67


func _throw(body: RigidBody3D) -> void:
	_let_go()
	# Same impulse for every item: launch speed is throw_impulse / mass
	body.apply_central_impulse(-_camera.global_basis.z * throw_impulse)
	# Start the throw SFX @Pierre67


func _release() -> void:
	if _held:
		_let_go()
		# Start the SFX release @Pierre67


## Stops holding the item without any SFX, shared by _release and _throw
func _let_go() -> void:
	if _held:
		remove_collision_exception_with(_held)
		_held.lock_rotation = false
		_held = null


func _is_lamp_pickup(target: Object) -> bool:
	return target is Node and target.is_in_group(&"lamp_pickup")


## The lamp on the ground is gone
## F now works and the hint is shown for a while
func _pick_lamp(item: Node) -> void:
	item.queue_free()
	_has_lamp = true
	# Start the pickup SFX @Pierre67

	# Create the UI hint for lamp_hint_duration and then hide it
	get_tree().call_group(&"lamp_hint", &"show")
	await get_tree().create_timer(lamp_hint_duration).timeout
	get_tree().call_group(&"lamp_hint", &"hide")


## Frozen and moved by physical forces --> straight up to the point's height, then over onto it
## May have to be changed later but will do the job for now
func _climb(point: ClimbPoint) -> void:
	_release()
	freeze = true
	# Otherwise the speed from before the climb keeps counting footsteps and comes back after
	linear_velocity = Vector3.ZERO
	var collision: CollisionShape3D = $CollisionShape3D
	var capsule: CapsuleShape3D = collision.shape
	# The point marks where the feet land
	var top := point.global_position + Vector3.UP * capsule.height * collision.scale.y / 2.0
	var above := Vector3(global_position.x, top.y, global_position.z)
	_move_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_move_tween.tween_property(self, ^"global_position", above, global_position.distance_to(above) / climb_speed)
	_move_tween.tween_property(self, ^"global_position", top, above.distance_to(top) / climb_speed)
	_move_tween.tween_callback(set_freeze_enabled.bind(false))
	# Start the climb SFX @Pierre67


## Caught by an enemy: frozen for good, the camera turns to the enemy's head and the view fades out.
## head_height is the head above the captor's center. Called every tick the player is in a death range.
## The player is slid to distance from the captor, on the side they were caught on.
func capture(captor: Node3D, head_height: float, distance: float) -> void:
	if _captor:
		return
	_captor = captor
	_captor_head = head_height
	# Start the captured SFX @Pierre67
	Music.set_state("Death")
	# Connect to the captured signal
	captor.captured.connect(_on_captured, CONNECT_ONE_SHOT)
	_release()
	# A climb in progress would carry on and unfreeze the player at its end
	if _move_tween:
		_move_tween.kill()
	freeze = true
	linear_velocity = Vector3.ZERO
	var away := global_position - captor.global_position
	away.y = 0.0
	# ponytail: straight slide with no collision, can end in a wall. Add a ray if it happens
	var place := global_position - away + away.normalized() * distance
	_move_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_move_tween.tween_property(self, ^"global_position", place, global_position.distance_to(place) / speed)



## The captor saw the player face it --> the view fades out, then the player respawns
func _on_captured() -> void:
	_camera.fade_out()
	await get_tree().create_timer(respawn_delay).timeout
	respawn()


## Back to the last spawn point, free to move, with every enemy back at its post
func respawn() -> void:
	_release()
	if _move_tween:
		_move_tween.kill()
	_captor = null
	facing_captor = false
	linear_velocity = Vector3.ZERO
	global_position = spawn_point
	freeze = false
	get_tree().call_group(&"enemies", &"reset")
	Music.follow_threats()
	_camera.fade_in()


## Keeps the player on bumpy ground: no sliding down a slope, no take off over a bump.
## One ray is enough --> the normal of what it hits is the slope
## target is the horizontal velocity the player needs
func _follow_ground(target: Vector3) -> void:
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * (_half_height + ground_snap))
	query.exclude = [get_rid()]
	# Launch a raycast to check for ground
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < cos(deg_to_rad(max_slope)):
		# In the air or on a wall --> the physics alone
		return

	var normal: Vector3 = hit.normal
	# Because there is no friction --> gravity would drag it down the slope
	apply_central_force(-get_gravity().slide(normal) * mass * gravity_scale)

	# Vertical speed of someone walking on that slope: going up faster than this is will send the player upward
	# at the end of the slope
	var along := -(normal.x * linear_velocity.x + normal.z * linear_velocity.z) / normal.y
	linear_velocity.y = minf(linear_velocity.y, along)

	# A low ledge is a wall for the capsule. Blocked at the feet but free max_step higher
	# --> lifted over it, as fast as it walks

	# Check 5cm ahead with a new collision
	var ahead := target.normalized() * 0.05
	var block := KinematicCollision3D.new()
	# Free for further than it is high, or a slope too steep to walk on would be climbed too
	if test_move(global_transform, ahead, block) and block.get_normal().y < cos(deg_to_rad(max_slope)) \
			and not test_move(global_transform.translated(Vector3.UP * max_step), ahead + target.normalized() * max_step):
		linear_velocity.y = maxf(linear_velocity.y, target.length())


func _aimed_body() -> RigidBody3D:
	return _aimed() as RigidBody3D


## What the camera looks at within reach. Climb points are areas, bodies still block the ray.
func _aimed(areas: bool = false) -> Object:
	var from := _camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - _camera.global_basis.z * reach)
	query.exclude = [get_rid()]
	query.collide_with_areas = areas
	# Standing inside a climb point counts as aiming at it
	query.hit_from_inside = areas
	return get_world_3d().direct_space_state.intersect_ray(query).get("collider")


func _process(delta: float) -> void:
	## Prevent stuttering that we would get with get_global_transform()
	_camera.global_position = get_global_transform_interpolated().origin + Vector3.UP * eye_height
	if is_instance_valid(_captor):
		# The mouse no longer drives the view, it turns to the head of the captor
		var to := _captor.global_position + Vector3.UP * _captor_head - _camera.global_position
		var yaw := atan2(-to.x, -to.z)
		var pitch := atan2(to.y, Vector2(to.x, to.z).length())
		_yaw = rotate_toward(_yaw, yaw, capture_turn_speed * delta)
		_pitch = rotate_toward(_pitch, pitch, capture_turn_speed * delta)
		# Only once the player is placed and the camera faces the head
		facing_captor = not _move_tween.is_running() and is_zero_approx(angle_difference(_yaw, yaw)) and is_equal_approx(_pitch, pitch)
	_camera.rotation = Vector3(_pitch, _yaw, 0.0)
	# Same rays as the keys, so the prompt shows exactly when E, grab or throw would work
	var body := _aimed_body()
	var target := _aimed(true)
	# This line is starting to become horrible.
	_prompt.visible = _captor == null and (_held != null \
			or (body != null and (body.is_in_group(&"draggable") or body.is_in_group(&"throwable"))) \
			or (not freeze and target is ClimbPoint) or _is_lamp_pickup(target))

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
	# Frozen --> moved by a tween (climb, capture), not by the physics
	if not freeze:
		_follow_ground(target)

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
