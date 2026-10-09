class_name BobSettings
extends Resource
## How the view bobs while walking

## Max vertical offset of the view, in meters
@export var vertical: float = 0.03
## Max sideways offset of the view, in meters. One sway takes two steps
@export var horizontal: float = 0.015
## Time for the bob to fade in when the player starts walking, and to fade out
## when it stops, in seconds. 0 would snap the view back to its place on a stop
@export var fade_time: float = 0.2
