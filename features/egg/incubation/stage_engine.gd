class_name EggStageEngine
extends RefCounted


const RESULT_NONE: String = "none"
const RESULT_STAGE_CHANGED: String = "stage_changed"
const RESULT_MUTATION: String = "mutation"
const RESULT_READY_TO_HATCH: String = "ready_to_hatch"


var _random_service: RandomService
var _rules: IncubationRules
var _task_engine: TaskEngine
var _mutation_engine: MutationEngine


func _init(
	random_service: RandomService,
	rules: IncubationRules,
	task_engine: TaskEngine,
	mutation_engine: MutationEngine
) -> void:
	_random_service = random_service
	_rules = rules
	_task_engine = task_engine
	_mutation_engine = mutation_engine


func start(
	state: EggState
) -> void:
	_enter_stage(
		state,
		1
	)


func ensure_ready(
	state: EggState
) -> void:
	if not state.has_active_run():
		return

	if state.status != "incubating":
		return

	if not state.current_task.is_empty():
		state.current_task = (
			_task_engine.normalize_task(
				state.current_task,
				state.stage
			)
		)

		return

	# Nếu stage hiện tại có rule,
	# tự khôi phục task bị thiếu.
	if _rules.has_rules(
		state.stage,
		state.egg_type
	):
		_create_task_for_current_stage(
			state
		)


func complete_current_stage(
	state: EggState
) -> String:
	if state.current_task.is_empty():
		return RESULT_NONE

	_task_engine.mark_complete(
		state.current_task
	)

	state.completed_tasks[
		str(state.stage)
	] = state.current_task.duplicate(
		true
	)

	match state.stage:

		1:
			_enter_stage(
				state,
				2
			)

			return RESULT_STAGE_CHANGED

		2:
			_enter_stage(
				state,
				3
			)

			return RESULT_STAGE_CHANGED

		3:
			var mutated: bool = (
				_mutation_engine.check_once(
					state
				)
			)

			if mutated:
				_enter_stage(
					state,
					4
				)

				return RESULT_MUTATION

			state.current_task = {}
			state.status = "ready_to_hatch"

			return RESULT_READY_TO_HATCH

		4:
			state.current_task = {}
			state.status = "ready_to_hatch"

			return RESULT_READY_TO_HATCH

	return RESULT_NONE


func _enter_stage(
	state: EggState,
	stage: int
) -> void:
	state.stage = clampi(
		stage,
		1,
		4
	)

	state.status = "incubating"

	state.current_task = {}

	_create_task_for_current_stage(
		state
	)


func _create_task_for_current_stage(
	state: EggState
) -> void:
	var options: Array = _rules.get_options(
		state.stage,
		state.egg_type
	)

	if options.is_empty():
		state.current_task = {}
		return

	var scope: String = (
		"egg_stage_%d_task"
		% state.stage
	)

	var rng: RandomNumberGenerator = (
		_random_service.create_stream(
			state.run_seed,
			scope,
			state.egg_seed
		)
	)

	state.current_task = (
		_task_engine.create_task(
			options,
			rng,
			state.stage
		)
	)
