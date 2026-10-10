extends Node

@onready var _hanged_emiter: FmodEventEmitter3D = $HangedEventEmitter3D

func _play_hanged_mole() -> void:
	_hanged_emiter.play(false)
	return
