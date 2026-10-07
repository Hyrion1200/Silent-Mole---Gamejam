@tool
extends EditorScenePostImport


## Gives every mesh of a blockout a static trimesh collider so it can be walked on.
func _post_import(scene: Node) -> Object:
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		# Prevent light from crossing through walls
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		mesh.create_trimesh_collision()
		for body in mesh.find_children("*", "", true, false):
			body.owner = scene
	return scene
