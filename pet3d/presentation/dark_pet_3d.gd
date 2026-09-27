class_name DarkPet3D
extends PetActor3D

@onready var body_root: Node3D = $BodyRoot
@onready var head: Node3D = $BodyRoot/Head
@onready var left_ear: Node3D = $BodyRoot/Head/LeftEar
@onready var right_ear: Node3D = $BodyRoot/Head/RightEar
@onready var front_left_leg: Node3D = $BodyRoot/FrontLeftLeg
@onready var front_right_leg: Node3D = $BodyRoot/FrontRightLeg
@onready var back_left_leg: Node3D = $BodyRoot/BackLeftLeg
@onready var back_right_leg: Node3D = $BodyRoot/BackRightLeg
@onready var tail_base: Node3D = $BodyRoot/TailBase
@onready var tail_mid: Node3D = $BodyRoot/TailBase/TailMid
@onready var tail_tip: Node3D = $BodyRoot/TailBase/TailMid/TailTip
@onready var face_rig: PetFaceRig3D = $BodyRoot/Head/FaceRig

var _time := 0.0
var _ear_reaction := 0.0
var _look_target := Vector3(0, 1.5, 3)
var _tail_velocity := Vector3.ZERO
var _tail_mid_velocity := Vector3.ZERO
var _tail_tip_velocity := Vector3.ZERO

func _process(delta: float) -> void:
	_time += delta
	_ear_reaction = move_toward(_ear_reaction, 0.0, delta * 2.8)
	_update_idle()
	_update_head(delta)
	_update_ears()
	_update_tail(delta)
	_update_legs()

func _update_idle() -> void:
	body_root.position.y = sin(_time * 2.0) * 0.025
	body_root.scale.y = 1.0 + sin(_time * 2.0) * 0.012

func _update_head(delta: float) -> void:
	var local_target := head.to_local(_look_target)
	var desired_yaw := clampf(atan2(local_target.x, local_target.z) * 0.28, -0.18, 0.18)
	var desired_pitch := clampf(-atan2(local_target.y, absf(local_target.z)) * 0.18, -0.08, 0.08)
	head.rotation.y = lerp_angle(head.rotation.y, desired_yaw, clampf(delta * 3.2, 0.0, 1.0))
	head.rotation.x = lerp_angle(head.rotation.x, desired_pitch + sin(_time * 0.75) * 0.018, clampf(delta * 3.2, 0.0, 1.0))

func _update_ears() -> void:
	left_ear.rotation.z = -0.12 + sin(_time * 1.7) * 0.045 - _ear_reaction
	right_ear.rotation.z = 0.12 - sin(_time * 1.55) * 0.04 + _ear_reaction

func _update_tail(delta: float) -> void:
	var base_target := Vector3(1.5708, sin(_time * 1.15) * 0.12, 1.05 + sin(_time * 1.15) * 0.18)
	var mid_target := Vector3(0, sin(_time * 1.15 - 0.45) * 0.10, -0.28 + sin(_time * 1.15 - 0.45) * 0.24)
	var tip_target := Vector3(0, sin(_time * 1.15 - 0.9) * 0.12, -0.28 + sin(_time * 1.15 - 0.9) * 0.32)
	_tail_velocity += (base_target - tail_base.rotation) * 12.0 * delta
	_tail_mid_velocity += (mid_target - tail_mid.rotation) * 10.0 * delta
	_tail_tip_velocity += (tip_target - tail_tip.rotation) * 8.0 * delta
	_tail_velocity *= pow(0.06, delta)
	_tail_mid_velocity *= pow(0.08, delta)
	_tail_tip_velocity *= pow(0.10, delta)
	tail_base.rotation += _tail_velocity * delta
	tail_mid.rotation += _tail_mid_velocity * delta
	tail_tip.rotation += _tail_tip_velocity * delta

func _update_legs() -> void:
	var settle := sin(_time * 2.0) * 0.012
	front_left_leg.position.y = 0.27 + settle
	front_right_leg.position.y = 0.27 - settle * 0.5
	back_left_leg.position.y = 0.25 - settle * 0.35
	back_right_leg.position.y = 0.25 + settle * 0.35

func set_look_target(target: Vector3) -> void:
	_look_target = target
	face_rig.look_at_world(target)

func react_to_touch() -> void:
	_ear_reaction = 0.22
	face_rig.blink()
	_tail_velocity.z += 1.6
	_tail_mid_velocity.z += 2.0
	_tail_tip_velocity.z += 2.6
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(body_root, "scale", Vector3(1.04, 0.94, 1.04), 0.09)
	tween.tween_property(body_root, "scale", Vector3.ONE, 0.18)
	notify_tapped()
