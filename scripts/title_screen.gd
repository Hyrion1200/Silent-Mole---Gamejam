extends Node3D

const CameraEffects := preload("res://scripts/camera_effects.gd")
const LEVEL: String = "res://scenes/test_level.tscn"

## Direct children that survive the switch to the level
@export var keep: Array[Node] = []

@onready var _camera: CameraEffects = $Camera3D
@onready var _play: Button = $UI/Play
@onready var _music: FmodEventEmitter3D = $FmodEventEmitter3D


func _ready() -> void:
	# The player captures the mouse --> free it when coming back from a level
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_play.grab_focus()


func _on_play_pressed() -> void:
	_play.disabled = true
	# Switch to Nothing in the event
	_music.set_parameter("musParameter", "Nothing")
	_camera.fade_out()
	await get_tree().create_timer(_camera.fade_out_duration).timeout
	# The level camera takes over the fade from black
	CameraEffects.fade_in_on_ready = true
	_free_title_screen()


func _free_title_screen() -> void:
	for child in get_children():
		if child not in keep:
			child.queue_free()
	add_child(load(LEVEL).instantiate())
