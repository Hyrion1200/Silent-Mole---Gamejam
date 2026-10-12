extends Node

@onready var camera: Camera3D = $"SubViewport/SUB CAMERA/Camera3D"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().create_timer(83).timeout
	camera.fade_out_duration = 10
	camera.fade_out()
	await get_tree().create_timer(10).timeout
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
