@tool
class_name CinematicCamera
extends Path3D
## Camera riding the path, animate PathFollow3D:progress_ratio in the AnimationPlayer to move it

# Is it useful ? For now no but it MAY BE USEFUL LATER so i add it for now and we will see. It is GOOD PRACTICE :)
signal finished

## The camera keeps aiming at this node, empty to look along the path
@export var look_at_target: Node3D

@onready var _camera: Camera3D = $PathFollow3D/Camera3D
@onready var _animation: AnimationPlayer = $AnimationPlayer


## Take over the view, play the animation 'Main', then give the view back
func play(animation: StringName = &"Main") -> void:
	var previous: Camera3D = get_viewport().get_camera_3d()
	_camera.make_current()
	_animation.play(animation)
	await _animation.animation_finished
	if previous:
		# Return back to the original camera
		previous.make_current()
	finished.emit()


func _process(_delta: float) -> void:
	# Runs in the editor too --> the camera preview shows the real framing
	if look_at_target and not _camera.global_position.is_equal_approx(look_at_target.global_position):
		_camera.look_at(look_at_target.global_position)
