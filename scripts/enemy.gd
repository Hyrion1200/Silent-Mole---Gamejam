@tool
extends CharacterBody3D
## @tool so the vision shape shows in the editor and follows the exports as they are tuned.

## Emitted when the enemy starts chasing. Not emitted again when a search turns back into a chase.
signal detected

enum State {
	# Idle
	IDLE,
	# Noticed something --> stands and turns to look
	SUSPICIOUS,
	# Suspicious enough --> walk to what it noticed
	INVESTIGATING,
	# Detected the player --> runs to them, or to the last place it saw or heard them
	CHASING,
	# Lost the player --> looks around the last place it saw or heard them
	SEARCHING,
	# No more stimulus --> walks back to its post
	RETURNING,
}

## We shall probably remove this later in the development or keeping it only for debug purposes
const ICONS: Dictionary[State, String] = {
	State.IDLE: "",
	State.SUSPICIOUS: "?",
	State.INVESTIGATING: "?",
	State.CHASING: "!",
	State.SEARCHING: "!?",
	State.RETURNING: "",
}

## How far the enemy sees straight ahead.
@export var view_range: float = 12.0:
	set(value):
		view_range = value
		_update_view_shape()
## Half-angle of the vision cone, in degrees.
@export_range(1.0, 90.0) var view_half_angle: float = 45.0:
	set(value):
		view_half_angle = value
		_update_view_shape()
## The cone stops widening at this distance from its axis and carries on as a
## straight tube --> so view_range can grow without the vision getting wider.
@export var view_width: float = 4.0:
	set(value):
		view_width = value
		_update_view_shape()
## Eye offset from the body center.
@export var eye_height: float = 0.7:
	set(value):
		eye_height = value
		_update_view_shape()
## Seconds of seeing the player at point-blank to fully detect them
## Takes up to 4x longer at the edge of view_range
@export var detect_time: float = 0.5
## Seconds of seeing the spot lit by the player's lamp to fully detect them
@export var lamp_detect_time: float = 1.5
## Awareness gained from a noise made right next to the enemy
@export var hear_gain: float = 0.4
## Seconds for awareness to decay from 1 to 0 with no stimulus
@export var forget_time: float = 4.0
## How fast the enemy turns toward what caught its attention, in rad/s
@export var turn_speed: float = 3.0
@export var walk_speed: float = 1.5
## Speed once the player is detected
@export var run_speed: float = 3.5
## Awareness above which the enemy walks to what caught its attention
## Below it, it only turns to look
@export var investigate_at: float = 0.3
## How close the enemy gets to where it is going
@export var stop_distance: float = 1.0
## Seconds spent searching around the place where it lost the player
@export var search_time: float = 10.0
## How far from that place it looks
@export var search_radius: float = 6.0
## Seconds given to each search point: the walk there, then standing and looking
@export var search_point_time: float = 3.0
## Cheat range for the searching feature
## 0 searches at random around where it lost the player
## 1 walks straight to where the player really is (as long as that is within search_radius)
@export_range(0.0, 1.0) var search_cheat: float = 0.3

## 0 = unaware, 1 = player detected.
var awareness: float = 0.0
var state: State = State.IDLE
## Where the last stimulus came from.
var _focus: Vector3
## Really getting closer to _focus: awareness does not decay until it gets there.
var _travelling: bool = false
## Where the search started: the last place it saw or heard the player.
var _search_origin: Vector3
## Time left on the current search point.
var _search_timer: float = 0.0

## On start of the scene save "home" position and rotation to comeback in case of chase ending
## We will need to save base animation aswell later on
@onready var _home: Vector3 = global_position
@onready var _home_yaw: float = rotation.y
@onready var _label: Label3D = $Label3D
@onready var _bar: MeshInstance3D = $Debug/Bar


func _ready() -> void:
	# Always shown in the editor, in game only once debug is toggled on
	$Debug.visible = Engine.is_editor_hint()
	_update_view_shape()


## Debug shape: a cone tip that widens up to view_width, then a tube up to view_range.
func _update_view_shape() -> void:
	if not is_node_ready():
		return
	var slope := tan(deg_to_rad(view_half_angle))
	var tip := minf(view_range, view_width / slope)
	var cone: CylinderMesh = $Debug/Cone.mesh
	cone.height = tip
	cone.bottom_radius = tip * slope
	$Debug/Cone.position = Vector3(0.0, eye_height, -tip / 2.0)
	$Debug/Tube.visible = view_range > tip
	if view_range > tip:
		var tube: CylinderMesh = $Debug/Tube.mesh
		tube.height = view_range - tip
		tube.top_radius = cone.bottom_radius
		tube.bottom_radius = cone.bottom_radius
		$Debug/Tube.position = Vector3(0.0, eye_height, -(tip + view_range) / 2.0)


## Called through the "enemies" group by anything that makes noise.
## radius is how far the noise carries.
func hear(at: Vector3, radius: float) -> void:
	# Sound travels along the walkable path, so walls muffles it.
	# Falls back to the straight line where there is no navmesh.
	var path := NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, at, true)
	var walked := 0.0
	for i in range(1, path.size()):
		walked += path[i - 1].distance_to(path[i])
	var loudness := 1.0 - maxf(walked, global_position.distance_to(at)) / radius
	if loudness > 0.0:
		awareness = minf(awareness + hear_gain * loudness, 1.0)
		_focus = at
		if state == State.SEARCHING:
			# Runs to the new noise, then searches around that one
			_set_state(State.CHASING)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# We only have one player so its fine doing it like this
	var player := get_tree().get_first_node_in_group(&"player") as CollisionObject3D
	# If we end up with multiple lamp i'll change this
	var lamp := get_tree().get_first_node_in_group(&"lamp") as SpotLight3D
	var gain := 0.0
	if player and _sees_body(player):
		_focus = player.global_position
		var closeness := 1.0 - global_position.distance_to(_focus) / view_range
		gain = lerpf(0.25, 1.0, closeness) / detect_time
	elif lamp and lamp.is_visible_in_tree() and _sees_lamp(lamp, player):
		gain = 1.0 / lamp_detect_time

	if gain > 0.0:
		awareness = minf(awareness + gain * delta, 1.0)
	_set_state(_next_state(gain))

	# Horizontal velocity wanted this tick
	var move := Vector3.ZERO
	match state:
		State.IDLE:
			pass
		State.SUSPICIOUS:
			_forget(gain, delta)
		State.INVESTIGATING:
			move = _step_toward(_focus) * walk_speed
			_forget(gain, delta)
		State.CHASING:
			move = _step_toward(_focus) * run_speed
			if gain <= 0.0 and move == Vector3.ZERO:
				# Got to the last place it saw or heard the player: search around it
				_set_state(State.SEARCHING)
				_search_origin = _focus
				_pick_search_point(player)
			else:
				_forget(gain, delta)
		State.SEARCHING:
			_search_timer -= delta
			if _search_timer <= 0.0:
				_pick_search_point(player)
			move = _step_toward(_focus) * walk_speed
			# The bar empties over the search, then the enemy gives up
			awareness = maxf(awareness - delta / search_time, 0.0)
		State.RETURNING:
			move = _step_toward(_home) * walk_speed
			if move == Vector3.ZERO:
				_set_state(State.IDLE)

	velocity = Vector3(move.x, velocity.y, move.z)
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	# Only counts while it really gets closer: blocked by something the navmesh does
	# not know about (a crate), awareness decays and the enemy ends up giving up
	_travelling = state in [State.INVESTIGATING, State.CHASING] and get_real_velocity().dot(move) > 0.5 * move.length_squared()

	# Look where it walks, else at the stimulus, else the way it faced at its post
	var yaw := _home_yaw
	if move != Vector3.ZERO:
		yaw = atan2(-move.x, -move.z)
	elif awareness > 0.0:
		var dir := _focus - global_position
		yaw = atan2(-dir.x, -dir.z)
	rotation.y = rotate_toward(rotation.y, yaw, turn_speed * delta)
	_bar.scale.x = maxf(awareness, 0.001)
	_label.text = ICONS[state]


## The state the enemy should be in this tick, from its awareness and what it perceives.
## gain is how fast sight is filling awareness, 0 when it sees nothing
func _next_state(gain: float) -> State:
	if awareness <= 0.0:
		return State.IDLE if state == State.IDLE else State.RETURNING
	match state:
		State.CHASING:
			# Only leaves by starting a search, or by awareness running out
			return State.CHASING
		State.SEARCHING:
			return State.CHASING if gain > 0.0 else State.SEARCHING
	if awareness >= 1.0:
		return State.CHASING
	return State.INVESTIGATING if awareness >= investigate_at else State.SUSPICIOUS


func _set_state(new_state: State) -> void:
	if new_state == State.CHASING and state not in [State.CHASING, State.SEARCHING]:
		detected.emit()
	state = new_state


## Awareness decays when nothing feeds it, except while the enemy is still on its
## way to check what it noticed.
func _forget(gain: float, delta: float) -> void:
	if gain <= 0.0 and not _travelling:
		awareness = maxf(awareness - delta / forget_time, 0.0)


## Next place to look at during a search, a random walkable point around where the
## player was lost, pulled toward where they really are by search_cheat.
func _pick_search_point(player: Node3D) -> void:
	_search_timer = search_point_time
	var centre := _search_origin
	if player:
		centre += (player.global_position - _search_origin).limit_length(search_radius) * search_cheat
	# The more it cheats, the less it strays from that centre
	var spread := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * search_radius * (1.0 - search_cheat)
	_focus = NavigationServer3D.map_get_closest_point(
			get_world_3d().navigation_map, centre + Vector3(spread.x, 0.0, spread.y))


## Horizontal direction to walk in to reach target along the navmesh,
## or zero once there or when there is no way to get closer.
func _step_toward(target: Vector3) -> Vector3:
	var to := target - global_position
	to.y = 0.0
	if to.length() <= stop_distance:
		return Vector3.ZERO
	# With lots of ennemy it might lags but we will probably get nowhere this problem so fck it
	for point in NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, target, true):
		to = point - global_position
		to.y = 0.0
		if to.length() > 0.1:
			return to.normalized()
	return Vector3.ZERO


func _sees_body(body: CollisionObject3D) -> bool:
	# Center, head and feet, so a body half behind cover is still seen.
	# It amps the difficulty so it may not be a bad idea
	for h: float in [0.0, 0.3, -0.3]:
		if _sees(body.global_position + Vector3.UP * h, body):
			return true
	return false


func _sees_lamp(lamp: SpotLight3D, holder: CollisionObject3D) -> bool:
	# one ray along the beam axis, the edges of the light cone are ignored
	# otherwise it is way too hard for the player
	var from := lamp.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - lamp.global_basis.z * lamp.spot_range)
	if holder:
		query.exclude = [holder.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	# Pull the spot off the surface so the sight ray does not hit the lit wall itself
	var spot: Vector3 = hit.position + hit.normal * 0.05
	# A beam landing on the enemy is noticed even from behind
	if hit.collider == self or _sees(spot):
		if awareness < investigate_at:
			# Not suspicious enough yet --> only looks at the light
			_focus = spot
		elif not _travelling:
			# Cheat: works out where the light comes from, even with no line of sight
			# to the lamp. Not refreshed on the way there, so the player can move off.
			_focus = lamp.global_position
		return true
	return false


## True if point is inside the vision cone with nothing but target in the way.
func _sees(point: Vector3, target: CollisionObject3D = null) -> bool:
	var eye := global_position + Vector3.UP * eye_height
	var to := point - eye
	# Distance along the view axis, and away from it
	var ahead := to.dot(-global_basis.z)
	var aside := sqrt(maxf(to.length_squared() - ahead * ahead, 0.0))
	if ahead <= 0.0 or ahead > view_range or aside > minf(ahead * tan(deg_to_rad(view_half_angle)), view_width):
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, point)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == target
