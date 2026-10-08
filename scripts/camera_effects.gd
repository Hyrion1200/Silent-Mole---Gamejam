extends Camera3D

## Max offset of the view at full strength, in meters
@export var shake_amplitude: float = 0.5
## Time for a full strength shake to fade out, in seconds
@export var shake_duration: float = 0.4

## Time for a full fade out, in seconds
@export var fade_out_duration: float = 1.0
## Share of fade_out_duration spent on the first 10% of the fade out
## 0.1 is linear, higher makes the fade out start slow then rush to black
@export_range(0.0, 1.0) var fade_out_start_ratio: float = 0.5
## Time for a full fade in, in seconds
@export var fade_in_duration: float = 1.0
## Share of fade_in_duration spent on the first 10% of the fade in
## 0.1 is linear, higher makes the fade in start slow then rush to the view
@export_range(0.0, 1.0) var fade_in_start_ratio: float = 0.5

var _shake: float = 0.0
var _fade_tween: Tween

@onready var _fade: ColorRect = $Fade/Rect


## Reveal the view from black
func fade_in() -> void:
	_fade_to(0.0, fade_in_duration, fade_in_start_ratio)


## Hide the view to black
func fade_out() -> void:
	_fade_to(1.0, fade_out_duration, fade_out_start_ratio)


func _fade_to(alpha: float, fade_duration: float, start_ratio: float) -> void:
	# Only one tween shall drive the alpha at a time
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	# Skip the slow start when the opposite fade is interrupted past the first 10%
	if absf(_fade.color.a - alpha) <= 0.9:
		_fade_tween.tween_property(_fade, ^"color:a", alpha, fade_duration)
		return
	_fade_tween.tween_property(_fade, ^"color:a", lerpf(1.0 - alpha, alpha, 0.1), fade_duration * start_ratio)
	_fade_tween.tween_property(_fade, ^"color:a", alpha, fade_duration * (1.0 - start_ratio))


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
