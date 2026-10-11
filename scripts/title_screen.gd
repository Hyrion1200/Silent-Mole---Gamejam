extends Node3D

const CameraEffects := preload("res://scripts/camera_effects.gd")
const LEVEL: String = "res://scenes/level_1.tscn"

@onready var _camera: CameraEffects = $"SubViewportContainer (dithered)/SubViewport/Camera3D"
@onready var _fade: ColorRect = $"SubViewportContainer (dithered)/SubViewport/Camera3D/Fade/Rect"
@onready var _ui: Control = $"SubViewportConterner text HD/SubViewport/UI"
@onready var _play: Button = $"SubViewportConterner text HD/SubViewport/UI/Play"


func _ready() -> void:
	# The player captures the mouse --> free it when coming back from a level
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_play.grab_focus()
	Music.set_state("Menu")


func _process(_delta: float) -> void:
	# Keep the same alpha
	_ui.modulate.a = 1.0 - _fade.color.a


func _on_play_pressed() -> void:
	_play.disabled = true
	# Silence while the listener goes from the title camera to the player
	Music.set_state("Nothing")
	Music.on_start()
	_camera.fade_out()
	await get_tree().create_timer(_camera.fade_out_duration).timeout
	# The level camera takes over the fade from black
	CameraEffects.fade_in_on_ready = true
	Music.start_rumble()
	get_tree().change_scene_to_file(LEVEL)
