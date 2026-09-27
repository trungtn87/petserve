class_name ExpressionProfile
extends Resource


@export var expressions: Array[ExpressionDefinition] = []


func find_by_state(state_id: StringName) -> ExpressionDefinition:
	for expression: ExpressionDefinition in expressions:
		if expression != null and expression.state_id == state_id:
			return expression
	return null


func has_state(state_id: StringName) -> bool:
	return find_by_state(state_id) != null
