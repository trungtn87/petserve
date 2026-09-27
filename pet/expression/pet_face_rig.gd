class_name PetFaceRig
extends Node2D

@export var sleepy_lid_amount: float = 0.72
@export var blink_closed_amount: float = 1.0
@export var blink_min_delay: float = 2.2
@export var blink_max_delay: float = 5.0
@export var look_radius: float = 7.0
@export var look_smoothing: float = 8.0

@onready var left_lid: CanvasItem = get_node_or_null("LeftLid") as CanvasItem
@onready var right_lid: CanvasItem = get_node_or_null("RightLid") as CanvasItem
@onready var happy_mouth: CanvasItem = get_node_or_null("HappyMouth") as CanvasItem
@onready var surprise_mouth: CanvasItem = get_node_or_null("SurpriseMouth") as CanvasItem
@onready var left_glint: Node2D = get_node_or_null("LeftGlint") as Node2D
@onready var right_glint: Node2D = get_node_or_null("RightGlint") as Node2D

var _blink_tween: Tween
var _look_target: Vector2 = Vector2.ZERO
var _look_offset: Vector2 = Vector2.ZERO
var _left_glint_origin: Vector2 = Vector2.ZERO
var _right_glint_origin: Vector2 = Vector2.ZERO

func _ready() -> void:
	if left_glint != null:
		_left_glint_origin = left_glint.position
	if right_glint != null:
		_right_glint_origin = right_glint.position
	reset_expression()

func _process(delta: float) -> void:
	_look_offset = _look_offset.lerp(_look_target, clampf(delta * look_smoothing, 0.0, 1.0))
	if left_glint != null:
		left_glint.position = _left_glint_origin + _look_offset
	if right_glint != null:
		right_glint.position = _right_glint_origin + _look_offset

func look_at_local(local_target: Vector2) -> void:
	if local_target.length_squared() < 0.001:
		_look_target = Vector2.ZERO
		return
	_look_target = local_target.normalized() * minf(look_radius, local_target.length() * 0.025)

func look_neutral() -> void:
	_look_target = Vector2.ZERO

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
			_set_lids(true, sleepy_lid_amount)
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
	_blink_tween.tween_property(left_lid, "scale:y", blink_closed_amount, 0.065)
	_blink_tween.tween_property(right_lid, "scale:y", blink_closed_amount, 0.065)
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
