@tool
class_name PatrolPoint
extends Marker3D
## A stop on the round of an enemy, see Enemy.patrol
## Its rotation is the way the enemy faces while it stands there.
## @tool so the arrow showing that way is drawn in the editor.

## Seconds the enemy stands here before walking to the next stop
@export_range(0.0, 10.0, 0.1, "or_greater") var wait: float = 1.0


func _ready() -> void:
	# Arrow pointing the way the enemy faces, built here so a bare PatrolPoint node is enough
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.15
	cone.height = 0.6
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 0.6, 1.0)
	cone.material = material
	var arrow := MeshInstance3D.new()
	arrow.mesh = cone
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The tip of the cone is on +Y: laid down to point forward (-Z), its base on the point
	arrow.rotation.x = -PI / 2.0
	arrow.position.z = -cone.height / 2.0
	# Always shown in the editor, in game only once debug is toggled on
	arrow.visible = Engine.is_editor_hint()
	arrow.add_to_group(&"debug")
	add_child(arrow)
	if not Engine.is_editor_hint():
		# Stays where it was placed, even as a child of the enemy walking the round
		top_level = true
