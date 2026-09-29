class_name GeneDevelopmentState
extends RefCounted


const SCHEMA_VERSION: int = 1


var _stage: int = 1
var _applications: Array[Dictionary] = []
var _influences: Dictionary = {}


func _init(
	stage: int = 1
) -> void:
	_stage = stage


func stage() -> int:
	return _stage


func application_count() -> int:
	return _applications.size()


func remaining_slots(
	policy: StageGenePolicy
) -> int:
	if policy == null:
		return 0

	return maxi(
		0,
		policy.max_gene_items(_stage)
		- application_count()
	)


func is_full(
	policy: StageGenePolicy
) -> bool:
	if policy == null:
		return true

	return not policy.can_accept_item(
		_stage,
		application_count()
	)


func influence(
	locus: StringName,
	direction: StringName
) -> float:
	var locus_key := String(
		_normalize_token(locus)
	)
	var direction_key := String(
		_normalize_token(direction)
	)

	var locus_value: Variant = _influences.get(
		locus_key,
		{}
	)

	if typeof(locus_value) != TYPE_DICTIONARY:
		return 0.0

	return float(
		(locus_value as Dictionary).get(
			direction_key,
			0.0
		)
	)


func locus_influences(
	locus: StringName
) -> Dictionary:
	var key := String(
		_normalize_token(locus)
	)
	var value: Variant = _influences.get(
		key,
		{}
	)

	if typeof(value) != TYPE_DICTIONARY:
		return {}

	return (
		value as Dictionary
	).duplicate(true)


func influences_snapshot() -> Dictionary:
	return _influences.duplicate(true)


func applications_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for application in _applications:
		result.append(
			application.duplicate(true)
		)

	return result


func try_apply(
	policy: StageGenePolicy,
	gene_item_id: StringName,
	locus: StringName,
	direction: StringName,
	influence_value: float
) -> Dictionary:
	if policy == null:
		return _failure(
			"Thiếu StageGenePolicy."
		)

	if not policy.is_stage_defined(_stage):
		return _failure(
			"Stage không tồn tại trong Gene Policy."
		)

	var normalized_item := _normalize_token(
		gene_item_id
	)
	var normalized_locus := _normalize_token(
		locus
	)
	var normalized_direction := _normalize_token(
		direction
	)

	if String(normalized_item).is_empty():
		return _failure(
			"Gene Item id không hợp lệ."
		)

	if (
		not PetGenomeSchema.is_visual_locus(
			normalized_locus
		)
		or not policy.allows_locus(
			_stage,
			normalized_locus
		)
	):
		return _failure(
			"Locus chưa được mở ở Stage hiện tại."
		)

	if (
		String(normalized_direction).is_empty()
		or normalized_direction
		== PetGenomeSchema.BASE_TRAIT
	):
		return _failure(
			"Gene direction không hợp lệ."
		)

	if influence_value <= 0.0:
		return _failure(
			"Gene influence phải lớn hơn 0."
		)

	if not policy.can_accept_item(
		_stage,
		application_count()
	):
		return _failure(
			"Đã đạt giới hạn Gene Item của Stage."
		)

	var application := {
		"gene_item_id": String(
			normalized_item
		),
		"locus": String(
			normalized_locus
		),
		"direction": String(
			normalized_direction
		),
		"influence": influence_value,
	}

	_applications.append(application)
	_add_influence(
		normalized_locus,
		normalized_direction,
		influence_value
	)

	return {
		"ok": true,
		"application": application.duplicate(true),
		"remaining_slots": remaining_slots(policy),
	}


func is_valid(
	policy: StageGenePolicy
) -> bool:
	if (
		policy == null
		or not policy.is_stage_defined(_stage)
		or application_count()
		> policy.max_gene_items(_stage)
	):
		return false

	var rebuilt := GeneDevelopmentState.new(
		_stage
	)

	for application in _applications:
		var result := rebuilt.try_apply(
			policy,
			StringName(str(
				application.get(
					"gene_item_id",
					""
				)
			)),
			StringName(str(
				application.get(
					"locus",
					""
				)
			)),
			StringName(str(
				application.get(
					"direction",
					""
				)
			)),
			float(
				application.get(
					"influence",
					0.0
				)
			)
		)

		if not bool(
			result.get(
				"ok",
				false
			)
		):
			return false

	return (
		rebuilt._influences
		== _influences
	)


func same_state(
	other: GeneDevelopmentState
) -> bool:
	if other == null:
		return false

	return (
		_stage == other._stage
		and _applications == other._applications
		and _influences == other._influences
	)


func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"stage": _stage,
		"applications": applications_snapshot(),
	}


static func from_dict(
	data: Dictionary,
	policy: StageGenePolicy
) -> GeneDevelopmentState:
	if policy == null:
		return null

	var applications_value: Variant = data.get(
		"applications",
		[]
	)

	if typeof(applications_value) != TYPE_ARRAY:
		return null

	var state := GeneDevelopmentState.new(
		int(
			data.get(
				"stage",
				0
			)
		)
	)

	for raw_value in applications_value as Array:
		if typeof(raw_value) != TYPE_DICTIONARY:
			return null

		var raw := raw_value as Dictionary
		var result := state.try_apply(
			policy,
			StringName(str(
				raw.get(
					"gene_item_id",
					""
				)
			)),
			StringName(str(
				raw.get(
					"locus",
					""
				)
			)),
			StringName(str(
				raw.get(
					"direction",
					""
				)
			)),
			float(
				raw.get(
					"influence",
					0.0
				)
			)
		)

		if not bool(
			result.get(
				"ok",
				false
			)
		):
			return null

	if not state.is_valid(policy):
		return null

	return state


func _add_influence(
	locus: StringName,
	direction: StringName,
	value: float
) -> void:
	var locus_key := String(locus)
	var direction_key := String(direction)
	var directions: Dictionary = {}

	var current_value: Variant = _influences.get(
		locus_key,
		{}
	)

	if typeof(current_value) == TYPE_DICTIONARY:
		directions = (
			current_value as Dictionary
		).duplicate(true)

	directions[direction_key] = (
		float(
			directions.get(
				direction_key,
				0.0
			)
		)
		+ value
	)

	_influences[locus_key] = directions


func _failure(
	message: String
) -> Dictionary:
	return {
		"ok": false,
		"error": message,
	}


static func _normalize_token(
	value: StringName
) -> StringName:
	return StringName(
		String(value)
			.strip_edges()
			.to_lower()
			.replace(" ", "_")
	)
