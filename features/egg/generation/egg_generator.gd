class_name EggGenerator
extends RefCounted


var _random_service: RandomService


func _init(
	random_service: RandomService
) -> void:
	_random_service = random_service


func create(
	run_seed: int
) -> EggState:
	var state: EggState = EggState.new()

	var rng: RandomNumberGenerator = (
		_random_service.create_stream(
			run_seed,
			"egg_identity"
		)
	)

	var type_index: int = rng.randi_range(
		0,
		EggCatalog.TYPES.size() - 1
	)

	state.run_seed = run_seed

	state.egg_seed = rng.randi_range(
		1,
		2147483646
	)

	state.egg_type = (
		EggCatalog.TYPES[type_index]
	)

	state.stage = 1
	state.status = "incubating"

	state.mutation_checked = false
	state.mutation = false
	state.mutation_roll = -1

	state.current_task = {}
	state.completed_tasks = {}

	return state
