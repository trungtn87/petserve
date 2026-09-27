extends RefCounted
## Capture rest-space coordinates once: markings follow skinning, never slide.
const Profile = preload("res://pet/appearance/pet_appearance_profile.gd")
const SHADER = preload("res://pet/appearance/moonwhisker.gdshader")
static var _mesh_cache: Dictionary = {}

static func apply(root: Node, profile: Resource) -> void:
	if not profile is Profile:
		return
	var material := ShaderMaterial.new()
	material.shader = SHADER
	for key: String in ["fur_color", "accent_color", "chest_color", "inner_ear_color", "iris_color", "iris_lower_color", "rune_color", "rune_energy"]:
		material.set_shader_parameter(key, profile.get(key))
	_apply_tree(root, material)

static func _apply_tree(node: Node, material: ShaderMaterial) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			instance.mesh = _rest_mesh(instance.mesh)
			instance.material_override = material
	for child: Node in node.get_children():
		_apply_tree(child, material)

static func _rest_mesh(source: Mesh) -> ArrayMesh:
	# Generated meshes are also cached as keys, so repeated palette swaps are cheap.
	if _mesh_cache.has(source):
		return _mesh_cache[source] as ArrayMesh
	var result := ArrayMesh.new()
	for surface: int in range(source.get_surface_count()):
		var arrays := source.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv := PackedVector2Array()
		var depth := PackedVector2Array()
		uv.resize(points.size())
		depth.resize(points.size())
		for i: int in range(points.size()):
			uv[i] = Vector2(points[i].x, points[i].y)
			depth[i] = Vector2(points[i].z, 0.0)
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = depth
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
		result.surface_set_material(surface, source.surface_get_material(surface))
	_mesh_cache[source] = result
	_mesh_cache[result] = result
	return result
