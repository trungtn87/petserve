class_name TaskEngine
extends RefCounted


const EVENT_NONE: String = "none"
const EVENT_PROGRESS: String = "progress"
const EVENT_INTERRUPTED: String = "interrupted"


func create_task(
	options: Array,
	rng: RandomNumberGenerator,
	stage: int
) -> Dictionary:
	if options.is_empty():
		return {}

	var index: int = rng.randi_range(
		0,
		options.size() - 1
	)

	var selected_value: Variant = options[
		index
	]

	if typeof(selected_value) != TYPE_DICTIONARY:
		push_error(
			"TaskEngine: Task definition không phải Dictionary."
		)

		return {}

	var task: Dictionary = (
		selected_value as Dictionary
	).duplicate(true)

	var minimum: int = int(
		task.get(
			"target_min",
			1
		)
	)

	var maximum: int = int(
		task.get(
			"target_max",
			minimum
		)
	)

	if maximum < minimum:
		maximum = minimum

	var target: float = float(
		rng.randi_range(
			minimum,
			maximum
		)
	)

	var task_id: String = str(
		task.get(
			"id",
			task.get(
				"task_id",
				"unknown_task"
			)
		)
	)

	var mechanic: String = str(
		task.get(
			"mechanic",
			task.get(
				"type",
				""
			)
		)
	)

	task.erase("id")
	task.erase("type")
	task.erase("target_min")
	task.erase("target_max")

	task["task_id"] = task_id
	task["mechanic"] = mechanic

	task["stage"] = stage
	task["target"] = target
	task["progress"] = 0.0
	task["completed"] = false

	return task


func normalize_task(
	source: Dictionary,
	fallback_stage: int
) -> Dictionary:
	if source.is_empty():
		return {}

	var task: Dictionary = source.duplicate(
		true
	)

	var mechanic: String = str(
		task.get(
			"mechanic",
			task.get(
				"type",
				""
			)
		)
	)

	task["mechanic"] = mechanic

	if task.has("type"):
		task.erase("type")

	if not task.has("task_id"):
		task["task_id"] = (
			"legacy_%d_%s"
			% [
				fallback_stage,
				mechanic
			]
		)

	if not task.has("stage"):
		task["stage"] = fallback_stage

	if not task.has("progress"):
		task["progress"] = 0.0

	if not task.has("target"):
		task["target"] = 1.0

	if not task.has("completed"):
		task["completed"] = false

	if not task.has("title"):
		task["title"] = "NHIỆM VỤ"

	if not task.has("instruction"):
		task["instruction"] = ""

	return task


func tap(
	task: Dictionary
) -> String:
	if task.is_empty():
		return EVENT_NONE

	if bool(
		task.get(
			"completed",
			false
		)
	):
		return EVENT_NONE

	var mechanic: String = str(
		task.get(
			"mechanic",
			""
		)
	)

	match mechanic:
		"tap":
			var progress: float = float(
				task.get(
					"progress",
					0.0
				)
			)

			progress += 1.0

			task["progress"] = progress

			return EVENT_PROGRESS

		"rest":
			task["progress"] = 0.0

			return EVENT_INTERRUPTED

	return EVENT_NONE


func advance_time(
	task: Dictionary,
	delta: float,
	is_pressed: bool
) -> String:
	if task.is_empty():
		return EVENT_NONE

	if bool(
		task.get(
			"completed",
			false
		)
	):
		return EVENT_NONE

	var mechanic: String = str(
		task.get(
			"mechanic",
			""
		)
	)

	var should_progress: bool = false

	match mechanic:
		"warm":
			should_progress = is_pressed

		"rest":
			should_progress = true

	if not should_progress:
		return EVENT_NONE

	var progress: float = float(
		task.get(
			"progress",
			0.0
		)
	)

	progress += maxf(
		delta,
		0.0
	)

	task["progress"] = progress

	return EVENT_PROGRESS


func is_complete(
	task: Dictionary
) -> bool:
	if task.is_empty():
		return false

	var progress: float = float(
		task.get(
			"progress",
			0.0
		)
	)

	var target: float = float(
		task.get(
			"target",
			0.0
		)
	)

	if target <= 0.0:
		return false

	return progress >= target


func mark_complete(
	task: Dictionary
) -> void:
	if task.is_empty():
		return

	task["completed"] = true
