extends Node
## Autoload. Owns the music event --> the only place that changes its parameter.

const PARAMETER := "musParameter"
## Ordered by priority, the index is the threat level the enemies report
const THREAT_LABELS: Array[String] = ["Idle", "Suspicious", "Alerted", "Found"]

var _threats_level: Dictionary[Node, int] = {}
# Same as the value the emitter starts with in music.tscn
var _label := "Menu"
# False while a music set by set_state() plays --> the enemies' reports are only stored
var _threats_enabled := false

@onready var _emitter: FmodEventEmitter3D = $MusicEmitter3D
@onready var _start_emitter: FmodEventEmitter3D = $SilentMoleEmitter3D

func on_start() -> void:
	# Sound
	_start_emitter.play(false)

## For the music that does not depend on the enemies: Menu, Nothing, Death, Ending
## The enemies cannot change the music anymore, until follow_threats()
## Otherwise other enemies can set Found while Death is playing
func set_state(label: String) -> void:
	_threats_enabled = false
	_apply(label)


## Back to the music of the enemies: the highest threat level, Idle without any
func follow_threats() -> void:
	_threats_enabled = true
	_apply(THREAT_LABELS[_threats_level.values().max()] if _threats_level else "Idle")


## Called by each enemy with its own threat level --> the highest one is the one playing
func report(enemy: Node, level: int) -> void:
	if enemy not in _threats_level:
		# Remove this enemy from the array if it exits the scene
		enemy.tree_exiting.connect(func() -> void: _threats_level.erase(enemy))
	_threats_level[enemy] = level
	if _threats_enabled:
		follow_threats()


func _apply(label: String) -> void:
	if label != _label:
		_label = label
		_emitter.set_parameter(PARAMETER, label)
		print("New Music state : " + label)
