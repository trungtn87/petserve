class_name DarkPetActor
extends PetActor


@onready var body: Polygon2D = $Body
@onready var left_eye: Polygon2D = $Face/LeftEye
@onready var right_eye: Polygon2D = $Face/RightEye
@onready var mark: Polygon2D = $Face/Mark


func present_state(state: PetState) -> void:
	if state == null:
		return

	# Reference presentation only. Real expression composition is added later.
	match state.primary:
		PetState.STATE_SLEEPY:
			scale.y = 0.96
		_:
			scale = Vector2.ONE
