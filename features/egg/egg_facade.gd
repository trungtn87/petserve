class_name EggFacade
extends RefCounted


const EVENT_NONE: String = "none"
const EVENT_NEW_LIFE: String = "new_life"
const EVENT_LOADED: String = "loaded"
const EVENT_PROGRESS: String = "progress"
const EVENT_INTERRUPTED: String = "interrupted"
const EVENT_STAGE_CHANGED: String = "stage_changed"
const EVENT_MUTATION: String = "mutation"
const EVENT_READY_TO_HATCH: String = "ready_to_hatch"


var _random_service: RandomService
var _save_service: SaveService

var _rules: IncubationRules
var _task_engine: TaskEngine
var _mutation_engine: MutationEngine
var _stage_engine: EggStageEngine
var _generator: EggGenerator
var _incubation: IncubationEngine

var _state: EggState = null

var _save_accumulator: float = 0.0


func _init() -> void:
	_build_dependencies()


# =========================================================
# SETUP
# =========================================================

func _build_dependencies() -> void:
	_random_service = RandomService.new()
	_save_service = SaveService.new()

	_rules = IncubationRules.new()
	_task_engine = TaskEngine.new()

	_mutation_engine = MutationEngine.new(
		_random_service
	)

	_stage_engine = EggStageEngine.new(
		_random_service,
		_rules,
		_task_engine,
		_mutation_engine
	)

	_generator = EggGenerator.new(
		_random_service
	)

	_incubation = IncubationEngine.new(
		_task_engine,
		_stage_engine
	)


# =========================================================
# PUBLIC API — LIFE
# =========================================================

func start_new_life() -> String:
	var run_seed: int = (
		_random_service.create_run_seed()
	)

	_state = _generator.create(
		run_seed
	)

	_stage_engine.start(
		_state
	)

	_incubation.attach_state(
		_state
	)

	_save_accumulator = 0.0

	save()

	return EVENT_NEW_LIFE


func load() -> String:
	if not _save_service.has_save():
		return EVENT_NONE

	var data: Dictionary = (
		_save_service.load_game()
	)

	if data.is_empty():
		return EVENT_NONE

	_state = EggState.from_save_dict(
		data
	)

	if not _state.has_active_run():
		_state = null
		return EVENT_NONE

	_incubation.attach_state(
		_state
	)

	_save_accumulator = 0.0

	return EVENT_LOADED


func save() -> bool:
	if _state == null:
		return false

	return _save_service.save_game(
		_state.to_save_dict()
	)


func delete_save() -> bool:
	_incubation.detach_state()

	_state = null

	_save_accumulator = 0.0

	return _save_service.delete_save()


# =========================================================
# PUBLIC API — INPUT
# =========================================================

func tap() -> String:
	if _state == null:
		return EVENT_NONE

	var event: String = (
		_incubation.tap()
	)

	if event != EVENT_NONE:
		save()

	return event


func press() -> void:
	_incubation.press()


func release() -> void:
	_incubation.release()

	# Lưu khi người chơi thả tay.
	save()


func tick(
	delta: float
) -> String:
	if _state == null:
		return EVENT_NONE

	var event: String = (
		_incubation.tick(
			delta
		)
	)

	if event == EVENT_NONE:
		return EVENT_NONE

	_save_accumulator += maxf(
		delta,
		0.0
	)

	# Sự kiện quan trọng phải save ngay.
	if (
		event == EVENT_STAGE_CHANGED
		or event == EVENT_MUTATION
		or event == EVENT_READY_TO_HATCH
		or event == EVENT_INTERRUPTED
	):
		_save_accumulator = 0.0
		save()

		return event

	# WARM / REST có thể update mỗi frame.
	# Không ghi file mỗi frame.
	if _save_accumulator >= 1.0:
		_save_accumulator = 0.0
		save()

	return event


# =========================================================
# PUBLIC API — QUERY
# =========================================================

func has_active_life() -> bool:
	return (
		_state != null
		and _state.has_active_run()
	)


func is_ready_to_hatch() -> bool:
	if _state == null:
		return false

	return _state.is_ready_to_hatch()


func get_snapshot() -> Dictionary:
	if _state == null:
		return {}

	return {
		"game_version": _state.game_version,

		"run_seed": _state.run_seed,
		"egg_seed": _state.egg_seed,

		"egg_type": _state.egg_type,

		"egg_name": EggCatalog.name_for(
			_state.egg_type
		),

		"egg_stage": _state.stage,

		"status": _state.status,

		"mutation_checked": (
			_state.mutation_checked
		),

		"mutation": (
			_state.mutation
		),

		"mutation_roll": (
			_state.mutation_roll
		),

		"current_task": (
			_state.current_task.duplicate(
				true
			)
		),

		"completed_tasks": (
			_state.completed_tasks.duplicate(
				true
			)
		)
	}


func get_display_data() -> Dictionary:
	if _state == null:
		return {}

	return {
		"run_seed": _state.run_seed,

		"egg": {
			"egg_seed": _state.egg_seed,
			"egg_type": _state.egg_type,
			"egg_stage": _state.stage
		},

		"egg_name": EggCatalog.name_for(
			_state.egg_type
		),

		"stage": _state.stage,

		"status": _state.status,

		"task": (
			_state.current_task.duplicate(
				true
			)
		),

		"mutation": _state.mutation
	}
