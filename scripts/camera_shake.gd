extends Camera3D

## Max offset of the view at full strength, in meters
@export var shake_amplitude: float = 0.5
## Time for a full strength shake to fade out, in seconds
@export var shake_duration: float = 0.4

var _shake: float = 0.0

func shake(strength: float = 1.0) -> void:
	_shake = maxf(_shake, strength)
	# Start a sound here @Pierre67


func _process(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(_shake - delta / shake_duration, 0.0)
	# The offsets only move the view --> the player keeps driving position and rotation
	# h_offset and v_offset and Camera3D properties
	h_offset = randf_range(-1.0, 1.0) * shake_amplitude * _shake
	v_offset = randf_range(-1.0, 1.0) * shake_amplitude * _shake
