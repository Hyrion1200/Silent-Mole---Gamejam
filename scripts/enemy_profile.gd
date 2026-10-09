@tool
class_name EnemyProfile
extends Resource
## Tuning of an enemy, shared by every enemy using the same .tres
## @tool so the enemies using it update their vision shape in the editor as it is tuned.

## How far the enemy sees straight ahead.
@export var view_range: float = 12.0:
	set(value):
		view_range = value
		emit_changed()
## Half-angle of the vision cone, in degrees.
@export_range(1.0, 90.0) var view_half_angle: float = 45.0:
	set(value):
		view_half_angle = value
		emit_changed()
## The cone stops widening at this distance from its axis and carries on as a
## straight tube --> so view_range can grow without the vision getting wider.
@export var view_width: float = 4.0:
	set(value):
		view_width = value
		emit_changed()
## How far above and below eye level the enemy sees at most. The vision is view_width
## squashed down to this height, so it is an ellipse seen from the front.
@export_range(0.1, 20.0, 0.1, "or_greater") var view_height: float = 2.0:
	set(value):
		view_height = value
		emit_changed()
## Eye level for the animated enemy
@export var animation_eye_height: float = 1.5:
	set(value):
		animation_eye_height = value
		emit_changed()
## Eye offset from the body center.
@export var eye_height: float = 0.7:
	set(value):
		eye_height = value
		emit_changed()
## Radius of the death range, a sphere right in front of the enemy
## A player touching it is captured
@export var death_range: float = 0.6:
	set(value):
		death_range = value
		emit_changed()
## Distance from the enemy where a captured player is placed, so the enemy is not seen from too close
@export var death_placement_distance: float = 1.5
## How far the enemy bends over the captured player once they face it, in degrees.
## It is way taller than the player, this brings its face down toward them
@export_range(0.0, 60.0, 1.0) var death_lean: float = 8.0
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
