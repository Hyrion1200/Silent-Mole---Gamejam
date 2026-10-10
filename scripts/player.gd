extends RigidBody3D

## An item starts being dragged / stops being held (released or thrown)
signal dragged(body: RigidBody3D)
signal released(body: RigidBody3D)

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
## Mass of a dragged item that halves the walk speed and the camera turn speed
## Lower --> items weigh more on the player
@export var drag_half_mass: float = 10.0
## Throw impulse. Launch speed is throw_impulse / mass, so heavy items land closer.
@export var throw_impulse: float = 30.0

## Speed at which a climb point pulls the player up, in m/s.
@export var climb_speed: float = 1.0

## Time for the camera to snap to the enemy that captured the player, in seconds.
## It goes about 10% past the enemy's head, then settles back on it
@export var capture_turn_time: float = 0.45
## Shake played when the player is caught
@export var capture_shake: ShakeSettings

## How far a footstep is heard by enemies.
@export var step_noise_radius: float = 6.0
## Distance travelled between two footsteps. We can increase it to be more lenient
@export var step_length: float = 0.8

## Speed while the sneak key (Ctrl) is held
@export var slow_speed: float = 1.2
## How far a footstep is heard by enemies while sneaking
@export var slow_step_noise_radius: float = 2.5
## Distance travelled between two footsteps while sneaking
@export var slow_step_length: float = 1.5

## Time spent staring at the captor before the fade out and the growing shake start, in seconds
@export var death_hold: float = 1.0
## Time spent in the dark between the end of the fade out and the respawn, in seconds
@export var respawn_delay: float = 5.0
## Amplitude of the camera shake that grows from the start of the fade out to the respawn, in meters
@export var death_shake_start: float = 0.05
@export var death_shake_end: float = 0.8

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

## Picked up from the ground --> F does nothing before that
var _has_lamp: bool = false
var _held: RigidBody3D
var _yaw: float = 0.0
var _pitch: float = 0.0
var _total_walked: float = 0.0
var _debug: bool = true
var _move_tween: Tween
## The enemy that captured the player, and the height of its head above its center
var _captor: Node3D
var _captor_head: float = 0.0
## Where the camera looked when the player was caught (pitch, yaw), and how far it has
## turned from there to the captor's head: 0 --> 1, above 1 while it overshoots
var _look_from: Vector2
var _look_weight: float = 0.0
var _look_tween: Tween
## Captured, placed and done turning to the captor's head --> the death ending has started
var _facing_captor: bool = false

@onready var _camera: Camera3D = $Camera3D
@onready var _lamp: SpotLight3D = $Camera3D/Lamp
@onready var _beam: MeshInstance3D = $Camera3D/Lamp/Beam
@onready var _prompt: Control = $Camera3D/Fade/Prompt
## From the center of the capsule down to the feet
@onready var _half_height: float = $CollisionShape3D.shape.height * $CollisionShape3D.scale.y / 2.0
@onready var _footsteps_emitter: FmodEventEmitter3D = $FootstepsEmitter3D
@onready var _slow_footsteps_emitter: FmodEventEmitter3D = $SlowFootstepsEmitter3D
@onready var _light_on_emitter: FmodEventEmitter3D = $LightOnEmitter3D
@onready var _light_off_emitter: FmodEventEmitter3D = $LightOffEmitter3D
@onready var _interact_emitter: FmodEventEmitter3D = $InteractEmitter3D
@onready var _throw_emitter: FmodEventEmitter3D = $ThrowEmitter3D
@onready var _ambient_emitter: FmodEventEmitter3D = $AmbientEmitter3D
@onready var _climb_emitter: FmodEventEmitter3D = $ClimbEmitter3D
@onready var _stinger1_emitter: FmodEventEmitter3D = $Stinger1Emitter3D
@onready var _stinger2_emitter: FmodEventEmitter3D = $Stinger2Emitter3D
@onready var _stinger3_emitter: FmodEventEmitter3D = $Stinger3Emitter3D
@onready var particle_falling: GPUParticles3D = $"Particles Follow/falling debris/Particle rock"


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
	Music.follow_threats()
	# Get every triggers in the scene and connect to their signal
	var trigger_array = get_tree().get_nodes_in_group("trigger")
	for trigger in trigger_array:
		trigger.connect("trigger_on_entered", _on_trigger_signal)
		trigger.connect("stinger_on_entered", _on_stinger_signal)
	
	
enum Stinger {
	Nothing = 0,
	Stinger1,
	Stinger2,
	Stinger3
}
func _on_stinger_signal(stinger) -> void:
	if stinger == Stinger.Stinger1:
		_stinger1_emitter.play(false)
	elif stinger == Stinger.Stinger2:
		_stinger2_emitter.play(false)
	elif stinger == Stinger.Stinger3:
		_stinger3_emitter.play(false)
		
	return


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _captor:
		var sensitivity := mouse_sensitivity * _burden()
		_yaw -= event.relative.x * sensitivity
		_pitch = clampf(_pitch - event.relative.y * sensitivity, -1.55, 1.55)
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
		# Debug --> works without having picked the lamp up
		if _has_lamp or _debug:
			_lamp.visible = not _lamp.visible
			# Play light event
			if (_lamp.visible):
				_light_on_emitter.play(false)
				_light_off_emitter.stop()
			else:
				_light_off_emitter.play(false)
				_light_on_emitter.stop()
	elif event.is_action_pressed(&"interact"): # E
		var target := _aimed(true)
		var point := target as ClimbPoint
		var body := _aimed_body()
		if _held:
			_release()
		# Prevent retriggering climibing if already climbing or freezed (death animation for ex.)
		elif point and not freeze:
			_climb(point)
		elif _is_lamp_pickup(target):
			_pick_lamp(target.owner)
		elif body and body.is_in_group(&"draggable"):
			_drag(body)
		# Only what cannot be dragged is thrown: shoved from where it stands
		elif body and body.is_in_group(&"throwable"):
			_throw(body)


func _drag(body: RigidBody3D) -> void:
	_held = body
	dragged.emit(body)
	# Prevent riding the item we are holding
	add_collision_exception_with(body)
	# Prevent the held item from spinning
	body.lock_rotation = true
	# Start the dragged SFX @Pierre67
	_interact_emitter.play(false)

func _throw(body: RigidBody3D) -> void:
	_let_go()
	# Same impulse for every item: launch speed is throw_impulse / mass
	body.apply_central_impulse(-_camera.global_basis.z * throw_impulse)
	# Start the throw SFX @Pierre67
	_throw_emitter.play(false)


func _release() -> void:
	if _held:
		_let_go()
		# Start the SFX release @Pierre67
		_throw_emitter.play(false)


## How much the dragged item slows the player: 1 with free hands, 0.5 at drag_half_mass
func _burden() -> float:
	return drag_half_mass / (drag_half_mass + _held.mass) if _held else 1.0


## Stops holding the item without any SFX, shared by _release and _throw
func _let_go() -> void:
	if _held:
		remove_collision_exception_with(_held)
		_held.lock_rotation = false
		released.emit(_held)
		_held = null


## The ray hits the collision body inside the pickup, the group is on the root of its scene
func _is_lamp_pickup(target: Object) -> bool:
	return target is Node and target.owner != null and target.owner.is_in_group(&"lamp_pickup")


## The lamp on the ground is gone
## F now works and the hint is shown for a while
func _pick_lamp(item: Node) -> void:
	item.queue_free()
	_has_lamp = true
	# Start the pickup SFX @Pierre67
	_interact_emitter.play(false)
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
	_climb_emitter.play(false)
	

## Caught by an enemy: frozen for good, the camera turns to the enemy's head and the view fades out.
## head_height is the head above the captor's center. Called once by the enemy whose death range is entered.
## The player is slid to distance from the captor, on the side they were caught on.
func capture(captor: Node3D, head_height: float, distance: float) -> void:
	if _captor:
		# Already caught by another enemy
		return
	_captor = captor
	_captor_head = head_height
	# Start the captured SFX @Pierre67
	Music.set_state("Death")
	_release()
	# A climb in progress would carry on and unfreeze the player at its end
	if _move_tween:
		_move_tween.kill()
	freeze = true
	linear_velocity = Vector3.ZERO
	var away := global_position - captor.global_position
	away.y = 0.0
	# Straight slide with no collision, can end in a wall
	var place := global_position - away + away.normalized() * distance
	_move_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_move_tween.tween_property(self, ^"global_position", place, global_position.distance_to(place) / speed)
	if capture_shake:
		_camera.shake(capture_shake)
	_look_from = Vector2(_pitch, _yaw)
	# Tween.TRANS_BACK allow the overshooting
	_look_weight = 0.0
	_look_tween = create_tween()
	_look_tween.tween_property(self, ^"_look_weight", 1.0, capture_turn_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Placed and facing the captor --> stares at it for a while, then the view fades out
## as the shake grows, then the player respawns
func _die() -> void:
	# The captor drops its chase animation for the one where it sees the player
	_captor.faced()
	var tween := create_tween()
	tween.tween_interval(death_hold)
	tween.tween_callback(_camera.fade_out)
	# The shake grows all the way to the respawn
	tween.tween_property(_camera, ^"rumble", death_shake_end, _camera.fade_out_duration + respawn_delay).from(death_shake_start)
	tween.tween_callback(respawn)


## Back to the last spawn point, free to move, with every enemy back at its post
func respawn() -> void:
	_release()
	if _move_tween:
		_move_tween.kill()
	_captor = null
	_facing_captor = false
	_camera.rumble = 0.0
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

enum Ambient {
	START = 0,
	CORRIDOR,
	LARGE,
	TUNNEL,
	NOTHING
}
func _on_trigger_signal(ambient_level) -> void:
	print("Ambient level received : " + str(ambient_level))
	var ambient_name = "Start"
	if ambient_level == Ambient.CORRIDOR:
		ambient_name = "Corridor"
	elif ambient_level == Ambient.LARGE:
		ambient_name = "Large"
	elif ambient_level == Ambient.TUNNEL:
		ambient_name = "Tunnel"
	elif ambient_level == Ambient.NOTHING:
		ambient_name = "Nothing"
	_ambient_emitter.set_parameter("ambParameter", ambient_name)


func _process(delta: float) -> void:
	# Same distance as the footsteps, counted per frame --> a bob counted per physics tick would judder
	var walked := Vector2(linear_velocity.x, linear_velocity.z).length()
	var sneaking := Input.is_action_pressed(&"sneak")
	# Over the full speed even while sneaking --> the slow walk bobs less
	var bob: Vector2 = _camera.walk(walked * delta / (slow_step_length if sneaking else step_length), walked / speed, delta)
	# The debug ring shows how far the next footstep carries
	var carry := (slow_step_noise_radius if sneaking else step_noise_radius) / step_noise_radius
	$NoiseRing.scale = Vector3(carry, 1.0, carry)
	# Prevent stuttering that we would get with get_global_transform()
	_camera.global_position = get_global_transform_interpolated().origin + Vector3.UP * (eye_height + bob.y) \
			+ Vector3.RIGHT.rotated(Vector3.UP, _yaw) * bob.x
	if is_instance_valid(_captor):
		# The mouse no longer drives the view, it turns to the head of the captor
		var to := _captor.global_position + Vector3.UP * _captor_head - _camera.global_position
		var yaw := atan2(-to.x, -to.z)
		var pitch := atan2(to.y, Vector2(to.x, to.z).length())
		# The head moves in the view while the player is slid into place --> aimed at every frame
		_yaw = lerp_angle(_look_from.y, yaw, _look_weight)
		_pitch = clampf(lerpf(_look_from.x, pitch, _look_weight), -1.55, 1.55)
		# Only once the player is placed and the camera faces the head
		if not _facing_captor and not _move_tween.is_running() and not _look_tween.is_running():
			_facing_captor = true
			_die()
	_camera.global_rotation = Vector3(_pitch, _yaw, 0.0)
	# Same rays as the keys, so the prompt shows exactly when E would work
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
		_beam.transform = Transform3D(Basis.looking_at(end - start), (start + end) / 2.0).scaled_local(Vector3(1.0, 1.0, start.distance_to(end)))


func _physics_process(delta: float) -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var sneaking := Input.is_action_pressed(&"sneak")
	var target := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, _yaw) * (slow_speed if sneaking else speed) * _burden()
	var diff := target - linear_velocity
	diff.y = 0.0
	# We do not want to rotate the player rigidbody
	apply_central_force(diff * accel * mass)
	# Frozen --> moved by a tween (climb, capture), not by the physics
	if not freeze:
		_follow_ground(target)

	# Everytime we walk a set distance start the hear function of all ennemies
	_total_walked += Vector2(linear_velocity.x, linear_velocity.z).length() * delta
	if _total_walked > (slow_step_length if sneaking else step_length):
		_total_walked = 0.0
		get_tree().call_group(&"enemies", &"hear", global_position, slow_step_noise_radius if sneaking else step_noise_radius)
		# Play footstep @Pierre67
		var footsteps := _slow_footsteps_emitter if sneaking else _footsteps_emitter
		var ground_raycast: RayCast3D = $GroundCheck
		if ground_raycast.is_colliding():
			var collider = ground_raycast.get_collider()
			if collider and collider.is_in_group("wood_ground"):
				footsteps.set_parameter("footstepParameter", "Wood")
			elif collider and collider.is_in_group("metal_ground"):
				footsteps.set_parameter("footstepParameter", "Metal")
			else:
				footsteps.set_parameter("footstepParameter", "Dirt")

		footsteps.play(false)

	if _held:
		var hold_point := _camera.global_position - _camera.global_basis.z * hold_distance
		var offset := hold_point - _held.global_position
		if offset.length() > reach:
			# Stuck behind something or left behind: let go
			_release()
		else:
			var pull := (offset * accel - _held.linear_velocity) * accel * _held.mass
			_held.apply_central_force(pull.limit_length(drag_force))
