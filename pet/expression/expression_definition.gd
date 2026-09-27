class_name ExpressionDefinition
extends Resource


@export var id: StringName = &""
@export var state_id: StringName = &""
@export_range(0.05, 30.0, 0.05) var duration: float = 0.8
@export var priority: int = 0
@export var interruptible: bool = true


func is_valid() -> bool:
	return not id.is_empty() and not state_id.is_empty() and duration > 0.0
