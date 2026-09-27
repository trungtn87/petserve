class_name MutationEngine
extends RefCounted


const MUTATION_BASE: int = 10000
const MUTATION_SUCCESS: int = 100


var _random_service: RandomService


func _init(
	random_service: RandomService
) -> void:
	_random_service = random_service


func check_once(
	state: EggState
) -> bool:
	if state.mutation_checked:
		return state.mutation

	var rng: RandomNumberGenerator = (
		_random_service.create_stream(
			state.run_seed,
			"egg_mutation",
			state.egg_seed
		)
	)

	var roll: int = rng.randi_range(
		1,
		MUTATION_BASE
	)

	state.mutation_checked = true
	state.mutation_roll = roll

	state.mutation = (
		roll <= MUTATION_SUCCESS
	)

	return state.mutation
