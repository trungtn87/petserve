class_name InfantLifecycle
extends StageLifecycle


# Compatibility constants retained for M7 tests/UI.
const DURATION_SECONDS: int = 2 * 60 * 60
const START_FOOD_SECONDS: int = 15 * 60
const STARVED_GROWTH_MULTIPLIER: float = 0.75


func complete_infant() -> void:
	advance_to_stage(
		2
	)
