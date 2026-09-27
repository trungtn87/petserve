class_name DarkPetActor
extends PetActor


@onready var body: Polygon2D = $Body
@onready var face: Node2D = $Face
@onready var left_eye: Polygon2D = $Face/LeftEye
@onready var right_eye: Polygon2D = $Face/RightEye
@onready var mark: Polygon2D = $Face/Mark


func _on_state_presented(state_id: StringName) -> void:
	_reset_pose()

	match state_id:
		PetState.STATE_HAPPY:
			scale = Vector2(1.04, 0.96)
			face.position.y += 2.0
		PetState.STATE_CURIOUS:
			rotation = deg_to_rad(-4.0)
			face.position.x -= 2.0
		PetState.STATE_SURPRISED:
			scale = Vector2(0.96, 1.06)
		PetState.STATE_SLEEPY:
			scale = Vector2(1.02, 0.92)
			left_eye.scale.y = 0.35
			right_eye.scale.y = 0.35


func _reset_pose() -> void:
	position = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE
	face.position = Vector2(0.0, -32.0)
	left_eye.scale = Vector2.ONE
	right_eye.scale = Vector2.ONE
