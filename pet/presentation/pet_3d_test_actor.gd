extends Node3D
## Presentation only: no pet simulation, egg state, RNG or save writes.

const MODEL: PackedScene = preload("res://assets/pets/dark_pet/dark_pet_rigged_v3.glb")
const Clips = preload("res://pet/presentation/dark_pet_test_clips.gd")

var skeleton: Skeleton3D
var player: AnimationPlayer
var current_clip: String = "idle"

func _ready() -> void:
	var model := MODEL.instantiate()
	add_child(model)
	skeleton = _find_skeleton(model)
	if skeleton == null:
		push_error("Pet 3D test: model has no Skeleton3D.")
		return
	player = AnimationPlayer.new()
	player.name = "TestAnimationPlayer"
	add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library("", Clips.build(skeleton, self))
	play_clip("idle")

func play_clip(clip_name: String) -> void:
	if player == null or not player.has_animation(clip_name):
		return
	current_clip = clip_name
	player.play(clip_name, 0.2)

func reset_pose() -> void:
	if player == null:
		return
	player.stop()
	skeleton.reset_bone_poses()
	current_clip = "RESET"

func set_paused(paused: bool) -> void:
	if player == null:
		return
	if paused:
		player.pause()
	elif current_clip != "RESET":
		player.play()

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
