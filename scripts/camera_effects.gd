extends Camera3D

## Shake played when shake() is called without settings
@export var default_shake: ShakeSettings
## How the view bobs while walking
@export var bob: BobSettings

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

@onready var _shake_emitter: FmodEventEmitter3D = $ShakeEmitter3D
## Set before changing scene so the next camera starts black and fades in
static var fade_in_on_ready: bool = false

## Amplitude of a shake that does not fade on its own
## Driven from outside, by the death of the player
var rumble: float = 0.0

var _shake: float = 0.0
var _shake_settings: ShakeSettings
var _fade_tween: Tween
## Steps walked since the start of the current stride. A stride is a left and a right step
## --> goes from 0 to 2 then starts over
var _bob_steps: float = 0.0
## How much of the bob is applied: 0 --> the view is still, 1 --> the full offsets of the settings
## It follows the speed of the player with a delay (bob.fade_time), or the view would snap
## back to its place when the player stops in the middle of a step
var _bob_amount: float = 0.0

var _playing_shake_sound = false

@onready var _fade: ColorRect = $Fade/Rect


func _ready() -> void:
	if fade_in_on_ready:
		fade_in_on_ready = false
		_fade.color.a = 1.0
		fade_in()


## Reveal the view from black
func fade_in() -> void:
	_fade_to(0.0, fade_in_duration, fade_in_start_ratio)


## Hide the view to black
func fade_out() -> float:
	_fade_to(1.0, fade_out_duration, fade_out_start_ratio)
	return fade_in_duration


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


func shake(settings: ShakeSettings = default_shake) -> void:
	# A weaker shake shall not cut a stronger one short
	if _shake > 0.0 and _shake_settings.amplitude * _shake > settings.amplitude:
		return
	_shake_settings = settings
	_shake = 1.0
	# Start a sound here @Pierre67
	if settings.play_sound:
		_shake_emitter.play(false)
		_shake_emitter.set_parameter("RumbleState", "On")
		_playing_shake_sound = true
		print("Shaking...")


## Advances the bob and returns where it puts the view: x sideways, y up, in meters
## steps is the distance walked this frame in steps
## speed_ratio is the speed of the player over its full speed: 0 standing --> 1 walking
## The player moves the camera with it, so that what hangs under the camera bobs too (lamp)
func walk(steps: float, speed_ratio: float, delta: float) -> Vector2:
	if not bob:
		return Vector2.ZERO
	_bob_steps = fmod(_bob_steps + steps, 2.0)
	# Moves toward the speed ratio, going from 0 to 1 takes fade_time
	_bob_amount = move_toward(_bob_amount, minf(speed_ratio, 1.0), delta / bob.fade_time)
	# Sideways: right on one step and left on the next --> one wave per stride
	var sideway := sin(PI * _bob_steps) * bob.horizontal
	# Vertical: up and down on every step --> two waves per stride
	var vertical := sin(TAU * _bob_steps) * bob.vertical
	return Vector2(sideway, vertical) * _bob_amount


func _process(delta: float) -> void:
	var amplitude := rumble
	if _shake > 0.0:
		_shake = maxf(_shake - delta / _shake_settings.duration, 0.0)
		amplitude += _shake_settings.amplitude * _shake
	elif _playing_shake_sound:
		print("playing rumbe state off")
		_playing_shake_sound = false
		_shake_emitter.set_parameter("RumbleState", "Off")
	# The offsets only move the view --> the player keeps driving position and rotation
	# h_offset and v_offset and Camera3D properties
	h_offset = randf_range(-1.0, 1.0) * amplitude
	v_offset = randf_range(-1.0, 1.0) * amplitude
