class_name PetExpressionController
extends Node


signal expression_changed(expression_id: StringName)

const EXPRESSION_NEUTRAL: StringName = &"neutral"
const EXPRESSION_HAPPY: StringName = &"happy"
const EXPRESSION_CURIOUS: StringName = &"curious"
const EXPRESSION_SLEEPY: StringName = &"sleepy"
const EXPRESSION_SURPRISED: StringName = &"surprised"

var current_expression: StringName = EXPRESSION_NEUTRAL


func present(expression_id: StringName) -> void:
	if expression_id == StringName():
		expression_id = EXPRESSION_NEUTRAL
	if current_expression == expression_id:
		return
	current_expression = expression_id
	expression_changed.emit(current_expression)


func reset() -> void:
	present(EXPRESSION_NEUTRAL)
