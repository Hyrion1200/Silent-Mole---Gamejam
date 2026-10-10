extends RigidBody3D

## A cart with this script can be shoved by the player. Without it, the cart stays frozen in place


func _ready() -> void:
	add_to_group(&"throwable")
	# The trimesh collider from the import only works on a static body --> convex one, as for the rocks
	var mesh: MeshInstance3D = find_children("*", "MeshInstance3D", true, false)[0]
	for body in mesh.find_children("*", "StaticBody3D", true, false):
		body.queue_free()
	var shape := CollisionShape3D.new()
	shape.shape = mesh.mesh.create_convex_shape()
	add_child(shape)
	shape.global_transform = mesh.global_transform
	freeze = false
