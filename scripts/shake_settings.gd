class_name ShakeSettings
extends Resource
## How a camera shake looks, shared by the camera and the triggers

## Max offset of the view at the start of the shake, in meters
@export var amplitude: float = 0.5
## Time for the shake to fade out, in seconds
@export_range(0.0, 7.0) var duration: float = 0.4
## Should it play sound
@export var play_sound: bool = false
