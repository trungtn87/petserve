extends SceneTree
## Run after --editor --import --quit. Verify appearance does not alter rig data.
const Actor = preload("res://pet/presentation/pet_3d_test_actor.gd")
const Shadow = preload("res://data/pet/appearance/moon_shadow.tres")
const Frost = preload("res://data/pet/appearance/moon_frost.tres")
func _initialize() -> void:
	create_timer(20.0).timeout.connect(func() -> void: quit(1))
	call_deferred("run")
func find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var found := find_mesh(child)
		if found != null:
			return found
	return null
func run() -> void:
	var original := Actor.MODEL.instantiate()
	var original_mesh := find_mesh(original)
	var first := Actor.new()
	var second := Actor.new()
	root.add_child(first)
	root.add_child(second)
	var mesh := find_mesh(first.model)
	var other := find_mesh(second.model)
	assert(mesh.skin != null)
	var before := original_mesh.mesh.surface_get_arrays(0)
	var after := mesh.mesh.surface_get_arrays(0)
	for slot: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_INDEX]:
		if slot == Mesh.ARRAY_NORMAL:
			for i: int in range(before[slot].size()):
				assert(before[slot][i].distance_to(after[slot][i]) < 0.0002)
		else:
			assert(before[slot] == after[slot], "Appearance changed geometry or skin")
	for i: int in range(after[Mesh.ARRAY_VERTEX].size()):
		var p: Vector3 = after[Mesh.ARRAY_VERTEX][i]
		assert(after[Mesh.ARRAY_TEX_UV][i].is_equal_approx(Vector2(p.x,p.y)))
		assert(is_equal_approx(after[Mesh.ARRAY_TEX_UV2][i].x,p.z))
	var shared_mesh := mesh.mesh
	first.play_clip("happy")
	first.player.advance(0.4)
	var head := first.skeleton.find_bone("Head")
	var pose := first.skeleton.get_bone_pose_rotation(head)
	first.set_appearance(Frost)
	assert(mesh.mesh == shared_mesh, "Palette swap rebuilt mesh")
	assert(first.player.current_animation == "happy")
	assert(first.skeleton.get_bone_pose_rotation(head).is_equal_approx(pose))
	assert(mesh.material_override != other.material_override)
	assert(mesh.material_override.get_shader_parameter("fur_color") == Frost.fur_color)
	assert(other.material_override.get_shader_parameter("fur_color") == Shadow.fur_color)
	first.set_appearance(null)
	assert(first.appearance_profile == Frost)
	var definition := load("res://data/pet/dark_pet_3d.tres") as PetDefinition
	first.setup(definition)
	assert(first.appearance_profile == Shadow)
	assert(original_mesh.material_override == null)
	original.free()
	first.queue_free()
	second.queue_free()
	await process_frame
	print("PASS: rest coordinates, unchanged mesh/skin, isolated palettes, cached swaps, animation continuity, PetDefinition integration")
	quit()
