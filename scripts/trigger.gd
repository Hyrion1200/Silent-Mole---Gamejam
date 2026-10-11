@tool
class_name Trigger
extends Area3D
## Invisible box that starts the ticked events when the player walks in
signal trigger_on_entered(ambient_level)
signal stinger_on_entered(which_stinger)

## Size of the box the player has to walk in.
@export var size: Vector3 = Vector3.ONE * 2.0:
	set(value):
		size = value
		_update_size()

## Only the first time the player walks in
@export var fire_once: bool = false

## Shake the camera with these settings
@export var camera_shake: ShakeSettings
## Respawn the player here from now on
@export var spawn_point_set: bool = false
## Game ending
@export var game_end: bool = false
## Play this cinematic
@export var cinematic: CinematicCamera

enum Ambient {
	START = 0,
	CORRIDOR,
	LARGE,
	TUNNEL,
	NOTHING,
	NONE
}
## Which ambient parameter should be playing from AmbientEmitter3D
@export var ambient_level: Ambient = Ambient.NONE

enum Stinger {
	Nothing = 0,
	Stinger1,
	Stinger2,
	Stinger3
}
@export var stinger: Stinger = Stinger.Nothing


func _ready() -> void:
	# Always shown in the editor, in game only once debug is toggled on
	$Debug.visible = Engine.is_editor_hint()
	_update_size()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _update_size() -> void:
	if not is_node_ready():
		return
	var box: BoxShape3D = $CollisionShape3D.shape
	box.size = size
	$Debug.scale = size

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if not body.is_in_group(&"player"):
		return
	if ambient_level != Ambient.NONE:
		trigger_on_entered.emit(ambient_level)
	if stinger != Stinger.Nothing:
		stinger_on_entered.emit(stinger)
	if camera_shake:
		# The player's viewport, not ours: in the composited level the player and its camera
		# are in a SubViewport while the triggers are in the root one, which has no camera
		body.get_viewport().get_camera_3d().shake(camera_shake)
	if spawn_point_set:
		body.spawn_point = global_position
	if cinematic:
		cinematic.play()
	if game_end:
		body.get_viewport().get_camera_3d().fade_out_duration = 5
		body.get_viewport().get_camera_3d().fade_out_start_ratio = 0.2
		body.get_viewport().get_camera_3d().fade_out()
		await get_tree().create_timer(5).timeout
		Music.set_state("Ending")
		get_tree().change_scene_to_file("res://scenes/Epilogue.tscn")
	if fire_once:
		# Delete the object we do not need it anymore
		queue_free()
