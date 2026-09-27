class_name EggState
extends RefCounted


const GAME_VERSION: String = "1.1"


var game_version: String = GAME_VERSION

var run_seed: int = 0
var egg_seed: int = 0
var egg_type: String = ""

var stage: int = 1

var status: String = "incubating"

var mutation_checked: bool = false
var mutation: bool = false
var mutation_roll: int = -1

var current_task: Dictionary = {}
var completed_tasks: Dictionary = {}


func reset() -> void:
	game_version = GAME_VERSION

	run_seed = 0
	egg_seed = 0
	egg_type = ""

	stage = 1
	status = "incubating"

	mutation_checked = false
	mutation = false
	mutation_roll = -1

	current_task = {}
	completed_tasks = {}


func has_active_run() -> bool:
	return (
		run_seed > 0
		and egg_seed > 0
		and not egg_type.is_empty()
	)


func is_ready_to_hatch() -> bool:
	return status == "ready_to_hatch"


func to_save_dict() -> Dictionary:
	return {
		"game_version": game_version,

		"run_seed": run_seed,

		"stage": (
			"egg_stage_%d"
			% stage
		),

		"egg_stage": stage,

		"status": status,

		"mutation_checked": mutation_checked,
		"mutation": mutation,
		"mutation_roll": mutation_roll,

		"current_task": (
			current_task.duplicate(true)
		),

		"completed_tasks": (
			completed_tasks.duplicate(true)
		),

		"egg": {
			"egg_seed": egg_seed,
			"egg_type": egg_type
		}
	}


static func from_save_dict(
	data: Dictionary
) -> EggState:
	var state: EggState = EggState.new()

	state.game_version = str(
		data.get(
			"game_version",
			GAME_VERSION
		)
	)

	state.run_seed = int(
		data.get(
			"run_seed",
			0
		)
	)

	state.stage = int(
		data.get(
			"egg_stage",
			1
		)
	)

	state.stage = clampi(
		state.stage,
		1,
		4
	)

	state.status = str(
		data.get(
			"status",
			"incubating"
		)
	)

	state.mutation_checked = bool(
		data.get(
			"mutation_checked",
			false
		)
	)

	state.mutation = bool(
		data.get(
			"mutation",
			false
		)
	)

	state.mutation_roll = int(
		data.get(
			"mutation_roll",
			-1
		)
	)

	var task_value: Variant = data.get(
		"current_task",
		{}
	)

	if typeof(task_value) == TYPE_DICTIONARY:
		state.current_task = (
			task_value as Dictionary
		).duplicate(true)

	var completed_value: Variant = data.get(
		"completed_tasks",
		{}
	)

	if typeof(completed_value) == TYPE_DICTIONARY:
		state.completed_tasks = (
			completed_value as Dictionary
		).duplicate(true)

	# Tương thích save cũ.
	var stage_one_value: Variant = data.get(
		"stage_1_task",
		null
	)

	if typeof(stage_one_value) == TYPE_DICTIONARY:
		state.completed_tasks["1"] = (
			stage_one_value as Dictionary
		).duplicate(true)

	var stage_two_value: Variant = data.get(
		"stage_2_task",
		null
	)

	if typeof(stage_two_value) == TYPE_DICTIONARY:
		state.completed_tasks["2"] = (
			stage_two_value as Dictionary
		).duplicate(true)

	var egg_value: Variant = data.get(
		"egg",
		{}
	)

	if typeof(egg_value) == TYPE_DICTIONARY:
		var egg_data: Dictionary = (
			egg_value as Dictionary
		)

		state.egg_seed = int(
			egg_data.get(
				"egg_seed",
				0
			)
		)

		state.egg_type = str(
			egg_data.get(
				"egg_type",
				""
			)
		)

	return state
