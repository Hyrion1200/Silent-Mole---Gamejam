extends RigidBody3D

## Vertical speed above which a released rock counts as falling
## Back under it --> the rock has landed
@export var landed_speed: float = 0.5

## Has been falling since it was released --> a rock let go while resting makes no sound
var _fell: bool = false

@onready var _emitter: FmodEventEmitter3D = $RockEmitter3D


func _ready() -> void:
	# Only watched between a release and the landing
	set_physics_process(false)
	# Replace with good mesh for being dragged
	var mesh: MeshInstance3D = find_children("*", "MeshInstance3D", true, false)[0]
	for body in mesh.find_children("*", "StaticBody3D", true, false):
		body.queue_free()
	var shape := CollisionShape3D.new()
	shape.shape = mesh.mesh.create_convex_shape()
	add_child(shape)
	shape.global_transform = mesh.global_transform
	var player := get_tree().get_first_node_in_group(&"player")
	if player:
		player.dragged.connect(_on_player_dragged)
		player.released.connect(_on_player_released)


func _physics_process(_delta: float) -> void:
	if linear_velocity.y < -landed_speed:
		_fell = true
	elif _fell:
		_emitter.play(false)
		set_physics_process(false)


func _on_player_dragged(body: RigidBody3D) -> void:
	if body == self:
		# Caught again before it landed --> no sound
		set_physics_process(false)


func _on_player_released(body: RigidBody3D) -> void:
	if body == self:
		_fell = false
		set_physics_process(true)
