class_name PetFaceRig3D
extends Node3D

@export var look_limit_degrees: float = 13.0
@export var look_smoothing: float = 7.0
@export var blink_min_delay: float = 2.2
@export var blink_max_delay: float = 5.0

@onready var left_eye: Node3D = $LeftEye
@onready var right_eye: Node3D = $RightEye
@onready var left_lid: Node3D = $LeftLid
@onready var right_lid: Node3D = $RightLid

var _target: Vector3 = Vector3(0, 0, 3)
var _blink_elapsed := 0.0
var _next_blink := 3.0
var _rng := RandomNumberGenerator.new()
var _blink_tween: Tween

func _ready() -> void:
	_rng.randomize()
	_schedule_blink()

func _process(delta: float) -> void:
	_blink_elapsed += delta
	_update_eye(left_eye, delta)
	_update_eye(right_eye, delta)
	if _blink_elapsed >= _next_blink:
		_blink_elapsed = 0.0
		_schedule_blink()
		blink()

func look_at_world(target: Vector3) -> void:
	_target = target

func _update_eye(eye: Node3D, delta: float) -> void:
	var local_target := eye.to_local(_target)
	var yaw := clampf(atan2(local_target.x, local_target.z), deg_to_rad(-look_limit_degrees), deg_to_rad(look_limit_degrees))
	var pitch := clampf(-atan2(local_target.y, absf(local_target.z)), deg_to_rad(-look_limit_degrees), deg_to_rad(look_limit_degrees))
	var desired := Vector3(pitch, yaw, 0.0)
	eye.rotation = eye.rotation.lerp(desired, clampf(delta * look_smoothing, 0.0, 1.0))

func blink() -> void:
	if _blink_tween != null:
		_blink_tween.kill()
	_blink_tween = create_tween()
	_blink_tween.set_parallel(true)
	_blink_tween.tween_property(left_lid, "scale:y", 0.08, 0.07)
	_blink_tween.tween_property(right_lid, "scale:y", 0.08, 0.07)
	_blink_tween.set_parallel(false)
	_blink_tween.tween_interval(0.05)
	_blink_tween.set_parallel(true)
	_blink_tween.tween_property(left_lid, "scale:y", 1.0, 0.09)
	_blink_tween.tween_property(right_lid, "scale:y", 1.0, 0.09)

func _schedule_blink() -> void:
	_next_blink = _rng.randf_range(blink_min_delay, blink_max_delay)
