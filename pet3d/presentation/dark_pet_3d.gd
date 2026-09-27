class_name DarkPet3D
extends PetActor3D

@onready var body_root: Node3D = $BodyRoot
@onready var head: Node3D = $BodyRoot/Head
@onready var left_ear: Node3D = $BodyRoot/Head/LeftEar
@onready var right_ear: Node3D = $BodyRoot/Head/RightEar
@onready var tail_base: Node3D = $BodyRoot/TailBase
@onready var tail_mid: Node3D = $BodyRoot/TailBase/TailMid
@onready var tail_tip: Node3D = $BodyRoot/TailBase/TailMid/TailTip
@onready var face_rig: PetFaceRig3D = $BodyRoot/Head/FaceRig

var _time := 0.0
var _ear_reaction := 0.0

func _process(delta: float) -> void:
	_time += delta
	_ear_reaction = move_toward(_ear_reaction, 0.0, delta * 2.8)
	body_root.position.y = sin(_time * 2.0) * 0.025
	head.rotation.x = sin(_time * 0.75) * 0.025
	left_ear.rotation.z = sin(_time * 1.7) * 0.045 - _ear_reaction
	right_ear.rotation.z = -sin(_time * 1.55) * 0.04 + _ear_reaction
	tail_base.rotation.y = sin(_time * 1.4) * 0.28
	tail_mid.rotation.y = sin(_time * 1.4 - 0.45) * 0.34
	tail_tip.rotation.y = sin(_time * 1.4 - 0.9) * 0.42

func set_look_target(target: Vector3) -> void:
	face_rig.look_at_world(target)

func react_to_touch() -> void:
	_ear_reaction = 0.22
	face_rig.blink()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(body_root, "scale", Vector3(1.04, 0.96, 1.04), 0.09)
	tween.tween_property(body_root, "scale", Vector3.ONE, 0.18)
	notify_tapped()
