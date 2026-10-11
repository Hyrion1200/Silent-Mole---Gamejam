extends Node

## Speed of the wagon along its rails above which it is heard rolling
@export var moving_speed: float = 0.5
## Seconds under moving_speed before it counts as stopped
@export var stop_delay: float = 0.3

var _last: Vector3
var _moving: bool = false
## Time spent under moving_speed
var _slow_time: float = 0.0

@onready var _wagon: Node3D = $Enemy3/JAM_Cart2
@onready var _wagon_movement_emitter: FmodEventEmitter3D = $Enemy3/JAM_Cart2/WagonMovementEmitter3D
@onready var _wagon_stop_emitter: FmodEventEmitter3D = $Enemy3/JAM_Cart2/WagonStopEmitter3D


func _ready() -> void:
	_last = _wagon.global_position


func _physics_process(delta: float) -> void:
	# The wagons are frozen and carried by the enemy --> no velocity of their own,
	# so it is worked out from how far the wagon moved along its z axis
	var step := _wagon.global_position - _last
	_last = _wagon.global_position
	if step.length() > 1.0:
		# Teleported back to the start of the round, not a movement
		return
	var moving := absf(step.dot(_wagon.global_basis.z)) / delta > moving_speed
	_slow_time = 0.0 if moving else _slow_time + delta
	if moving == _moving or (not moving and _slow_time < stop_delay):
		return
	_moving = moving
	if moving:
		_wagon_stop_emitter.stop()
		_wagon_movement_emitter.play(false)
	else:
		_wagon_movement_emitter.stop()
		_wagon_stop_emitter.play(false)
