class_name IncubationEngine
extends RefCounted


const EVENT_NONE: String = "none"
const EVENT_PROGRESS: String = "progress"
const EVENT_INTERRUPTED: String = "interrupted"
const EVENT_STAGE_CHANGED: String = "stage_changed"
const EVENT_MUTATION: String = "mutation"
const EVENT_READY_TO_HATCH: String = "ready_to_hatch"


var _task_engine: TaskEngine
var _stage_engine: EggStageEngine

var _state: EggState = null

var _is_pressed: bool = false


func _init(
	task_engine: TaskEngine,
	stage_engine: EggStageEngine
) -> void:
	_task_engine = task_engine
	_stage_engine = stage_engine


# =========================================================
# STATE
# =========================================================

func attach_state(
	state: EggState
) -> void:
	_state = state

	_is_pressed = false

	if _state == null:
		return

	_stage_engine.ensure_ready(
		_state
	)


func detach_state() -> void:
	_state = null
	_is_pressed = false


func get_state() -> EggState:
	return _state


func has_state() -> bool:
	return (
		_state != null
		and _state.has_active_run()
	)


# =========================================================
# INPUT
# =========================================================

func tap() -> String:
	if not _can_process_task():
		return EVENT_NONE

	var event: String = (
		_task_engine.tap(
			_state.current_task
		)
	)

	if event == TaskEngine.EVENT_NONE:
		return EVENT_NONE

	if _task_engine.is_complete(
		_state.current_task
	):
		return _complete_task()

	return event


func press() -> void:
	if not has_state():
		return

	_is_pressed = true


func release() -> void:
	_is_pressed = false


func tick(
	delta: float
) -> String:
	if not _can_process_task():
		return EVENT_NONE

	var event: String = (
		_task_engine.advance_time(
			_state.current_task,
			delta,
			_is_pressed
		)
	)

	if event == TaskEngine.EVENT_NONE:
		return EVENT_NONE

	if _task_engine.is_complete(
		_state.current_task
	):
		return _complete_task()

	return event


# =========================================================
# TASK
# =========================================================

func _complete_task() -> String:
	if _state == null:
		return EVENT_NONE

	var result: String = (
		_stage_engine.complete_current_stage(
			_state
		)
	)

	match result:

		EggStageEngine.RESULT_STAGE_CHANGED:
			return EVENT_STAGE_CHANGED

		EggStageEngine.RESULT_MUTATION:
			return EVENT_MUTATION

		EggStageEngine.RESULT_READY_TO_HATCH:
			return EVENT_READY_TO_HATCH

	return EVENT_NONE


func _can_process_task() -> bool:
	if not has_state():
		return false

	if _state.status != "incubating":
		return false

	if _state.current_task.is_empty():
		return false

	return true
