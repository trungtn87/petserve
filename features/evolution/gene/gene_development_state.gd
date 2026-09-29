class_name GeneDevelopmentState
extends RefCounted


const SCHEMA_VERSION: int = 1


var _stage: int = 1
var _applications: Array[Dictionary] = []


func _init(
	stage_index: int = 1,
	applications: Array = []
) -> void:
	_stage = stage_index

	for raw_application in applications:
		if typeof(raw_application) != TYPE_DICTIONARY:
			continue

		_applications.append(
			_normalize_application(
				raw_application as Dictionary
			)
		)


func stage() -> int:
	return _stage


func used_gene_items() -> int:
	return _applications.size()


func has_gene_input() -> bool:
	return not _applications.is_empty()


func remaining_slots(
	policy: StageGenePolicy
) -> int:
	if (
		policy == null
		or not policy.is_valid()
	):
		return 0

	return policy.remaining_slots(
		_stage,
		used_gene_items()
	)


func has_item(
	item_uid: String
) -> bool:
	var expected := item_uid.strip_edges()

	for application in _applications:
		if String(
			application.get(
				"item_uid",
				""
			)
		) == expected:
			return true

	return false


func record_gene_item(
	policy: StageGenePolicy,
	item_uid: String,
	gene_id: StringName,
	locus: StringName,
	direction: StringName,
	influence: float
) -> bool:
	var normalized_uid := (
		item_uid.strip_edges()
	)
	var normalized_gene := StringName(
		String(gene_id)
		.strip_edges()
		.to_lower()
	)
	var normalized_locus := StringName(
		String(locus)
		.strip_edges()
		.to_lower()
	)
	var normalized_direction := StringName(
		String(direction)
		.strip_edges()
		.to_lower()
	)

	if (
		policy == null
		or not policy.is_valid()
		or normalized_uid.is_empty()
		or String(normalized_gene).is_empty()
		or String(normalized_direction).is_empty()
		or influence <= 0.0
		or has_item(
			normalized_uid
		)
		or not PetGenomeSchema.is_visual_locus(
			normalized_locus
		)
		or not policy.can_accept_gene_item(
			_stage,
			used_gene_items(),
			normalized_locus
		)
	):
		return false

	_applications.append({
		"item_uid": normalized_uid,
		"gene_id": String(
			normalized_gene
		),
		"locus": String(
			normalized_locus
		),
		"direction": String(
			normalized_direction
		),
		"influence": influence,
	})

	return true


func influence_for(
	locus: StringName,
	direction: StringName
) -> float:
	var normalized_locus := String(
		locus
	).strip_edges().to_lower()
	var normalized_direction := String(
		direction
	).strip_edges().to_lower()
	var total := 0.0

	for application in _applications:
		if (
			String(
				application.get(
					"locus",
					""
				)
			) == normalized_locus
			and String(
				application.get(
					"direction",
					""
				)
			) == normalized_direction
		):
			total += float(
				application.get(
					"influence",
					0.0
				)
			)

	return total


func influence_snapshot() -> Dictionary:
	var result: Dictionary = {}

	for application in _applications:
		var locus := String(
			application.get(
				"locus",
				""
			)
		)
		var direction := String(
			application.get(
				"direction",
				""
			)
		)
		var key := (
			locus
			+ "."
			+ direction
		)

		result[key] = float(
			result.get(
				key,
				0.0
			)
		) + float(
			application.get(
				"influence",
				0.0
			)
		)

	return result


func applications_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for application in _applications:
		result.append(
			application.duplicate(true)
		)

	return result


func is_valid() -> bool:
	if _stage < 1 or _stage > 4:
		return false

	var seen_items: Dictionary = {}

	for application in _applications:
		var item_uid := String(
			application.get(
				"item_uid",
				""
			)
		).strip_edges()
		var gene_id := StringName(
			str(
				application.get(
					"gene_id",
					""
				)
			)
			.strip_edges()
			.to_lower()
		)
		var locus := StringName(
			str(
				application.get(
					"locus",
					""
				)
			)
			.strip_edges()
			.to_lower()
		)
		var direction := StringName(
			str(
				application.get(
					"direction",
					""
				)
			)
			.strip_edges()
			.to_lower()
		)
		var influence := float(
			application.get(
				"influence",
				0.0
			)
		)

		if (
			item_uid.is_empty()
			or String(gene_id).is_empty()
			or String(direction).is_empty()
			or influence <= 0.0
			or not PetGenomeSchema.is_visual_locus(
				locus
			)
			or seen_items.has(
				item_uid
			)
		):
			return false

		seen_items[item_uid] = true

	return true


func is_valid_for_policy(
	policy: StageGenePolicy
) -> bool:
	if (
		policy == null
		or not policy.is_valid()
		or not is_valid()
		or used_gene_items()
			> policy.max_gene_items(
				_stage
			)
	):
		return false

	for application in _applications:
		if not policy.allows_locus(
			_stage,
			StringName(
				str(
					application.get(
						"locus",
						""
					)
				)
			)
		):
			return false

	return true


func same_state(
	other: GeneDevelopmentState
) -> bool:
	if other == null:
		return false

	return (
		_stage == other._stage
		and _applications
			== other._applications
	)


func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"stage": _stage,
		"applications": applications_snapshot(),
	}


static func from_dict(
	data: Dictionary
) -> GeneDevelopmentState:
	if int(
		data.get(
			"schema",
			0
		)
	) != SCHEMA_VERSION:
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
		),
		applications_value as Array
	)

	if not state.is_valid():
		return null

	return state


func _normalize_application(
	source: Dictionary
) -> Dictionary:
	return {
		"item_uid": String(
			source.get(
				"item_uid",
				""
			)
		).strip_edges(),
		"gene_id": str(
			source.get(
				"gene_id",
				""
			)
		)
		.strip_edges()
		.to_lower(),
		"locus": str(
			source.get(
				"locus",
				""
			)
		)
		.strip_edges()
		.to_lower(),
		"direction": str(
			source.get(
				"direction",
				""
			)
		)
		.strip_edges()
		.to_lower(),
		"influence": float(
			source.get(
				"influence",
				0.0
			)
		),
	}
