extends Node3D

const CameraEffects := preload("res://scripts/camera_effects.gd")
const LEVEL: String = "res://scenes/test_level.tscn"

@onready var _camera: CameraEffects = $Camera3D
@onready var _play: Button = $UI/Play


func _ready() -> void:
	# The player captures the mouse --> free it when coming back from a level
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_play.grab_focus()
	Music.set_state("Menu")


func _on_play_pressed() -> void:
	_play.disabled = true
	# Silence while the listener goes from the title camera to the player
	Music.set_state("Nothing")
	_camera.fade_out()
	await get_tree().create_timer(_camera.fade_out_duration).timeout
	# The level camera takes over the fade from black
	CameraEffects.fade_in_on_ready = true
	get_tree().change_scene_to_file(LEVEL)
