@tool
class_name ClimbPoint
extends Area3D
## Invisible point the player climbs onto with "interact"
## Placed where the feet should land

## Radius of the sphere the player has to aim at (or stand in) to climb.
@export var radius: float = 0.75:
	set(value):
		radius = value
		_update_range()


func _ready() -> void:
	# Always shown in the editor, in game only once debug is toggled on
	$Debug.visible = Engine.is_editor_hint()
	_update_range()


func _update_range() -> void:
	if not is_node_ready():
		return
	var sphere: SphereShape3D = $CollisionShape3D.shape
	sphere.radius = radius
	$Debug.scale = Vector3.ONE * radius
