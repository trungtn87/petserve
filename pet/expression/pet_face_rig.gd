class_name PetFaceRig
extends Node2D


@export var profile: FaceRigProfile

@onready var left_lid: CanvasItem = get_node_or_null("LeftLid") as CanvasItem
@onready var right_lid: CanvasItem = get_node_or_null("RightLid") as CanvasItem
@onready var happy_mouth: CanvasItem = get_node_or_null("HappyMouth") as CanvasItem
@onready var surprise_mouth: CanvasItem = get_node_or_null("SurpriseMouth") as CanvasItem

var _blink_tween: Tween


func _ready() -> void:
	if profile != null:
		position = profile.face_offset
		scale = profile.face_scale
	reset_expression()


func reset_expression() -> void:
	_set_lids(false, 0.05)
	_set_visible(happy_mouth, false)
	_set_visible(surprise_mouth, false)


func present(expression_id: StringName) -> void:
	reset_expression()
	match expression_id:
		PetExpressionController.EXPRESSION_HAPPY:
			_set_visible(happy_mouth, true)
		PetExpressionController.EXPRESSION_SLEEPY:
			_set_lids(true, _sleepy_amount())
		PetExpressionController.EXPRESSION_SURPRISED:
			_set_visible(surprise_mouth, true)


func blink() -> void:
	if left_lid == null or right_lid == null:
		return
	if _blink_tween != null:
		_blink_tween.kill()
	_set_lids(true, 0.05)
	_blink_tween = create_tween()
	_blink_tween.set_parallel(true)
	_blink_tween.tween_property(left_lid, "scale:y", _closed_amount(), 0.065)
	_blink_tween.tween_property(right_lid, "scale:y", _closed_amount(), 0.065)
	_blink_tween.set_parallel(false)
	_blink_tween.tween_interval(0.045)
	_blink_tween.set_parallel(true)
	_blink_tween.tween_property(left_lid, "scale:y", 0.05, 0.075)
	_blink_tween.tween_property(right_lid, "scale:y", 0.05, 0.075)
	_blink_tween.set_parallel(false)
	_blink_tween.tween_callback(_finish_blink)


func _finish_blink() -> void:
	_set_lids(false, 0.05)


func _set_lids(show: bool, amount: float) -> void:
	for lid in [left_lid, right_lid]:
		if lid == null:
			continue
		lid.visible = show
		lid.scale.y = amount


func _set_visible(item: CanvasItem, value: bool) -> void:
	if item != null:
		item.visible = value


func _sleepy_amount() -> float:
	return profile.sleepy_lid_amount if profile != null else 0.72


func _closed_amount() -> float:
	return profile.blink_closed_amount if profile != null else 1.0
