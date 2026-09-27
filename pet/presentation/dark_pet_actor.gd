class_name DarkPetActor
extends PetActor


@onready var body: Polygon2D = $Body
@onready var tail: Polygon2D = $Tail
@onready var left_ear: Polygon2D = $LeftEar
@onready var right_ear: Polygon2D = $RightEar
@onready var face: Node2D = $Face
@onready var left_eye: Polygon2D = $Face/LeftEye
@onready var right_eye: Polygon2D = $Face/RightEye
@onready var mark: Polygon2D = $Face/Mark

var _time: float = 0.0
var _reaction_tween: Tween = null


func _ready() -> void:
	$InteractionArea.input_event.connect(_on_interaction_input)


func _process(delta: float) -> void:
	_time += delta
	# Very light living motion. State presentation remains independent.
	body.position.y = sin(_time * 2.0) * 1.5
	tail.rotation = deg_to_rad(sin(_time * 1.7) * 7.0)
	left_ear.rotation = deg_to_rad(sin(_time * 1.3) * 1.5)
	right_ear.rotation = deg_to_rad(-sin(_time * 1.3) * 1.5)


func _on_state_presented(state_id: StringName) -> void:
	_reset_pose()
	match state_id:
		PetState.STATE_HAPPY:
			_play_happy_reaction()
		PetState.STATE_CURIOUS:
			rotation = deg_to_rad(-4.0)
			face.position.x -= 2.0
		PetState.STATE_SURPRISED:
			scale = Vector2(0.96, 1.06)
		PetState.STATE_SLEEPY:
			scale = Vector2(1.02, 0.94)
			left_eye.scale.y = 0.25
			right_eye.scale.y = 0.25


func _play_happy_reaction() -> void:
	if _reaction_tween != null:
		_reaction_tween.kill()
	_reaction_tween = create_tween()
	_reaction_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reaction_tween.tween_property(self, "scale", Vector2(1.08, 0.94), 0.12)
	_reaction_tween.tween_property(self, "scale", Vector2.ONE, 0.22)


func _on_interaction_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		notify_tapped()
	elif event is InputEventScreenTouch and event.pressed:
		notify_tapped()


func _reset_pose() -> void:
	rotation = 0.0
	scale = Vector2.ONE
	face.position = Vector2(0.0, -32.0)
	left_eye.scale = Vector2.ONE
	right_eye.scale = Vector2.ONE
