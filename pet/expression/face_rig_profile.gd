class_name FaceRigProfile
extends Resource


@export var face_offset: Vector2 = Vector2.ZERO
@export var face_scale: Vector2 = Vector2.ONE
@export var left_eye_anchor: Vector2 = Vector2.ZERO
@export var right_eye_anchor: Vector2 = Vector2.ZERO
@export var mouth_anchor: Vector2 = Vector2.ZERO
@export var mark_anchor: Vector2 = Vector2.ZERO

@export_range(0.0, 1.0, 0.01) var sleepy_lid_amount: float = 0.72
@export_range(0.0, 1.0, 0.01) var blink_closed_amount: float = 1.0
@export var blink_min_delay: float = 2.2
@export var blink_max_delay: float = 5.0
