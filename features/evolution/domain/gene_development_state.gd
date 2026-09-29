class_name GeneDevelopmentState
extends RefCounted


const SCHEMA_VERSION: int = 1


var _stage_index: int = 1
var _gene_items: Array[Dictionary] = []


func _init(
	stage_index: int = 1
) -> void:
	_stage_index = maxi(
		1,
		stage_index
	)


func stage_index() -> int:
	return _stage_index


func item_count() -> int:
	return _gene_items.size()


func is_empty() -> bool:
	return _gene_items.is_empty()


func gene_items_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for item in _gene_items:
		result.append(
			item.duplicate(true)
		)

	return result


func influences_snapshot() -> Dictionary:
	var result: Dictionary = {}

	for item in _gene_items:
		var key := _influence_key(
			StringName(
				item.get(
					"locus",
					""
				)
			),
			StringName(
				item.get(
					"direction",
					""
				)
			)
		)

		result[key] = float(
			result.get(
				key,
				0.0
			)
		) + float(
			item.get(
				"influence",
				0.0
			)
		)

	return result


func influence_for(
	locus: StringName,
	direction: StringName
) -> float:
	return float(
		influences_snapshot().get(
			_influence_key(
				locus,
				direction
			),
			0.0
		)
	)


func can_record(
	policy: StageGenePolicy,
	locus: StringName
) -> bool:
	if policy == null:
		return false

	if not policy.can_accept_gene(
		_stage_index,
		locus
	):
		return false

	return (
		item_count()
		< policy.max_gene_items(
			_stage_index
		)
	)


func record_gene_item(
	policy: StageGenePolicy,
	item_uid: String,
	gene_id: StringName,
	locus: StringName,
	direction: StringName,
	influence: float
) -> Dictionary:
	var normalized_uid := (
		item_uid.strip_edges()
	)
	var normalized_gene := _normalize_name(
		gene_id
	)
	var normalized_locus := _normalize_name(
		locus
	)
	var normalized_direction := _normalize_name(
		direction
	)

	if policy == null:
		return _error(
			"Thiếu StageGenePolicy."
		)

	if (
		normalized_uid.is_empty()
		or String(normalized_gene).is_empty()
		or String(normalized_locus).is_empty()
		or String(normalized_direction).is_empty()
		or influence <= 0.0
	):
		return _error(
			"Gene Item không hợp lệ."
		)

	if not PetGenomeSchema.is_visual_locus(
		normalized_locus
	):
		return _error(
			"Locus không thuộc Genome V1."
		)

	if not policy.can_accept_gene(
		_stage_index,
		normalized_locus
	):
		return _error(
			"Locus chưa mở ở Stage hiện tại."
		)

	if _has_item_uid(
		normalized_uid
	):
		return _error(
			"Gene Item này đã được ghi nhận."
		)

	if item_count() >= policy.max_gene_items(
		_stage_index
	):
		return _error(
			"Đã đạt giới hạn Gene Item của Stage."
		)

	_gene_items.append({
		"item_uid": normalized_uid,
		"gene_id": String(normalized_gene),
		"locus": String(normalized_locus),
		"direction": String(normalized_direction),
		"influence": influence,
	})

	return {
		"ok": true,
		"stage_index": _stage_index,
		"gene_items_used": item_count(),
		"max_gene_items": policy.max_gene_items(
			_stage_index
		),
		"influences": influences_snapshot(),
	}


func reset_for_stage(
	stage_index: int
) -> bool:
	if stage_index < 1:
		return false

	_stage_index = stage_index
	_gene_items.clear()
	return true


func is_valid(
	policy: StageGenePolicy = null
) -> bool:
	if _stage_index < 1:
		return false

	var seen_uids: Dictionary = {}

	for item in _gene_items:
		var uid := String(
			item.get(
				"item_uid",
				""
			)
		).strip_edges()
		var gene_id := _normalize_name(
			StringName(
				item.get(
					"gene_id",
					""
				)
			)
		)
		var locus := _normalize_name(
			StringName(
				item.get(
					"locus",
					""
				)
			)
		)
		var direction := _normalize_name(
			StringName(
				item.get(
					"direction",
					""
				)
			)
		)
		var influence := float(
			item.get(
				"influence",
				0.0
			)
		)

		if (
			uid.is_empty()
			or String(gene_id).is_empty()
			or String(direction).is_empty()
			or influence <= 0.0
			or not PetGenomeSchema.is_visual_locus(
				locus
			)
			or seen_uids.has(
				uid
			)
		):
			return false

		if (
			policy != null
			and not policy.can_accept_gene(
				_stage_index,
				locus
			)
		):
			return false

		seen_uids[uid] = true

	if (
		policy != null
		and item_count()
		> policy.max_gene_items(
			_stage_index
		)
	):
		return false

	return true


func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"stage_index": _stage_index,
		"gene_items": gene_items_snapshot(),
	}


static func from_dict(
	data: Dictionary,
	policy: StageGenePolicy = null
) -> GeneDevelopmentState:
	var stage_index := int(
		data.get(
			"stage_index",
			0
		)
	)
	var items_value: Variant = data.get(
		"gene_items",
		[]
	)

	if (
		stage_index < 1
		or typeof(items_value) != TYPE_ARRAY
	):
		return null

	var state := GeneDevelopmentState.new(
		stage_index
	)

	for raw_value in items_value as Array:
		if typeof(raw_value) != TYPE_DICTIONARY:
			return null

		var raw := raw_value as Dictionary
		state._gene_items.append({
			"item_uid": String(
				raw.get(
					"item_uid",
					""
				)
			).strip_edges(),
			"gene_id": String(
				state._normalize_name(
					StringName(
						raw.get(
							"gene_id",
							""
						)
					)
				)
			),
			"locus": String(
				state._normalize_name(
					StringName(
						raw.get(
							"locus",
							""
						)
					)
				)
			),
			"direction": String(
				state._normalize_name(
					StringName(
						raw.get(
							"direction",
							""
						)
					)
				)
			),
			"influence": float(
				raw.get(
					"influence",
					0.0
				)
			),
		})

	if not state.is_valid(
		policy
	):
		return null

	return state


func _has_item_uid(
	item_uid: String
) -> bool:
	for item in _gene_items:
		if String(
			item.get(
				"item_uid",
				""
			)
		) == item_uid:
			return true

	return false


func _normalize_name(
	value: StringName
) -> StringName:
	return StringName(
		String(value)
		.strip_edges()
		.to_lower()
	)


func _influence_key(
	locus: StringName,
	direction: StringName
) -> String:
	return (
		String(
			_normalize_name(
				locus
			)
		)
		+ "."
		+ String(
			_normalize_name(
				direction
			)
		)
	)


func _error(
	message: String
) -> Dictionary:
	return {
		"ok": false,
		"message": message,
	}
