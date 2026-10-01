class_name GeneDevelopmentState
extends RefCounted

const SCHEMA_VERSION: int = 2

var _stage_index: int = 1
var _gene_items: Array[Dictionary] = []
var _gene_scores: Dictionary = {}
var _lifetime_tag_influences: Dictionary = {}
var _used_gene_ids: Array[String] = []
var _used_item_uids: Array[String] = []

func _init(stage_index: int = 1) -> void:
	_stage_index = stage_index

func stage_index() -> int:
	return _stage_index

func item_count() -> int:
	return _gene_items.size()

func lifetime_gene_count() -> int:
	return _used_item_uids.size()

func is_empty() -> bool:
	return _gene_items.is_empty()

func has_lifetime_scores() -> bool:
	return not _gene_scores.is_empty()

func gene_items_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in _gene_items:
		result.append(item.duplicate(true))
	return result

func gene_scores_snapshot() -> Dictionary:
	return _gene_scores.duplicate(true)

func used_gene_ids_snapshot() -> Array[String]:
	return _used_gene_ids.duplicate()

func lifetime_tag_influences_snapshot() -> Dictionary:
	return _lifetime_tag_influences.duplicate(true)

func influences_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for item in _gene_items:
		var key := score_key(StringName(item.get("locus", "")), StringName(item.get("direction", "")))
		result[key] = float(result.get(key, 0.0)) + float(item.get("score", item.get("influence", 0.0)))
	return result

func influence_for(locus: StringName, direction: StringName) -> float:
	return float(influences_snapshot().get(score_key(locus, direction), 0.0))

func score_for(locus: StringName, direction: StringName) -> float:
	return float(_gene_scores.get(score_key(locus, direction), 0.0))

func tag_influences_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for item in _gene_items:
		var tags_value: Variant = item.get("influence_tags", {})
		if typeof(tags_value) != TYPE_DICTIONARY:
			continue
		for key_value in (tags_value as Dictionary).keys():
			var key := String(key_value)
			result[key] = float(result.get(key, 0.0)) + float((tags_value as Dictionary)[key_value])
	return result

func can_record(policy: StageGenePolicy, locus: StringName) -> bool:
	return policy != null and policy.can_accept_gene(_stage_index, locus)

func record_gene_item(
	policy: StageGenePolicy,
	item_uid: String,
	gene_id: StringName,
	locus: StringName,
	direction: StringName,
	influence: float,
	influence_tags: Dictionary = {},
	rarity: String = "",
	element_lock: StringName = &""
) -> Dictionary:
	var normalized_uid := item_uid.strip_edges()
	var normalized_gene := _normalize_name(gene_id)
	var normalized_locus := _normalize_name(locus)
	var normalized_direction := _normalize_name(direction)
	var normalized_tags := _normalize_influence_tags(influence_tags)
	var normalized_element := _normalize_name(element_lock)
	if policy == null:
		return _error("Thiếu StageGenePolicy.")
	if (
		normalized_uid.is_empty()
		or String(normalized_gene).is_empty()
		or String(normalized_locus).is_empty()
		or String(normalized_direction).is_empty()
		or normalized_direction == PetGenomeSchema.BASE_TRAIT
		or influence <= 0.0
		or not _valid_influence_tags(influence_tags)
	):
		return _error("Gene Item không hợp lệ.")
	if not PetGenomeSchema.is_visual_locus(normalized_locus):
		return _error("Locus không thuộc Genome V1.")
	if not policy.can_accept_gene(_stage_index, normalized_locus):
		return _error("Locus chưa dùng được ở Stage hiện tại.")
	if _used_item_uids.has(normalized_uid):
		return _error("Gene Item này đã được ghi nhận.")
	var item := {
		"item_uid": normalized_uid,
		"gene_id": String(normalized_gene),
		"locus": String(normalized_locus),
		"direction": String(normalized_direction),
		"score": influence,
		"influence": influence,
		"influence_tags": normalized_tags,
		"rarity": rarity.strip_edges().to_lower(),
		"element_lock": String(normalized_element),
		"stage_used": _stage_index,
	}
	_gene_items.append(item)
	_used_item_uids.append(normalized_uid)
	if not _used_gene_ids.has(String(normalized_gene)):
		_used_gene_ids.append(String(normalized_gene))
		_used_gene_ids.sort()
	var key := score_key(normalized_locus, normalized_direction)
	_gene_scores[key] = float(_gene_scores.get(key, 0.0)) + influence
	for tag_key in normalized_tags.keys():
		var name := String(tag_key)
		_lifetime_tag_influences[name] = float(_lifetime_tag_influences.get(name, 0.0)) + float(normalized_tags[tag_key])
	var total_score := float(_gene_scores.get(key, 0.0))
	return {
		"ok": true,
		"stage_index": _stage_index,
		"gene_items_used": item_count(),
		"lifetime_gene_items_used": lifetime_gene_count(),
		"score_added": influence,
		"total_score": total_score,
		"expression_tier": String(GeneExpressionScale.tier_for_score(total_score)),
		"next_threshold": GeneExpressionScale.next_threshold(total_score),
		"gene_scores": gene_scores_snapshot(),
		"influences": influences_snapshot(),
		"tag_influences": tag_influences_snapshot(),
		"lifetime_tag_influences": lifetime_tag_influences_snapshot(),
	}

func reset_for_stage(stage_index: int) -> bool:
	if stage_index < StageGenePolicy.FIRST_STAGE or stage_index > StageGenePolicy.FINAL_STAGE:
		return false
	_stage_index = stage_index
	_gene_items.clear()
	return true

func is_valid(policy: StageGenePolicy = null) -> bool:
	if _stage_index < StageGenePolicy.FIRST_STAGE or _stage_index > StageGenePolicy.FINAL_STAGE:
		return false
	if policy != null and not policy.has_stage(_stage_index):
		return false
	var seen_current: Dictionary = {}
	for item in _gene_items:
		var uid := String(item.get("item_uid", "")).strip_edges()
		var locus := _normalize_name(StringName(item.get("locus", "")))
		var direction := _normalize_name(StringName(item.get("direction", "")))
		var score := float(item.get("score", item.get("influence", 0.0)))
		if (
			uid.is_empty()
			or String(direction).is_empty()
			or score <= 0.0
			or not PetGenomeSchema.is_visual_locus(locus)
			or seen_current.has(uid)
		):
			return false
		if policy != null and not policy.can_accept_gene(_stage_index, locus):
			return false
		seen_current[uid] = true
	for key in _gene_scores.keys():
		if String(key).is_empty() or float(_gene_scores[key]) <= 0.0:
			return false
	return true

func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"stage_index": _stage_index,
		"gene_items": gene_items_snapshot(),
		"gene_scores": gene_scores_snapshot(),
		"lifetime_tag_influences": lifetime_tag_influences_snapshot(),
		"used_gene_ids": used_gene_ids_snapshot(),
		"used_item_uids": _used_item_uids.duplicate(),
	}

static func from_dict(data: Dictionary, policy: StageGenePolicy = null) -> GeneDevelopmentState:
	var stage_index := int(data.get("stage_index", 0))
	var items_value: Variant = data.get("gene_items", [])
	if stage_index < StageGenePolicy.FIRST_STAGE or stage_index > StageGenePolicy.FINAL_STAGE or typeof(items_value) != TYPE_ARRAY:
		return null
	var state := GeneDevelopmentState.new(stage_index)
	for raw_value in items_value as Array:
		if typeof(raw_value) != TYPE_DICTIONARY:
			return null
		var raw := raw_value as Dictionary
		var uid := String(raw.get("item_uid", "")).strip_edges()
		var gene_id := String(state._normalize_name(StringName(raw.get("gene_id", ""))))
		var locus := String(state._normalize_name(StringName(raw.get("locus", ""))))
		var direction := String(state._normalize_name(StringName(raw.get("direction", ""))))
		var score := float(raw.get("score", raw.get("influence", 0.0)))
		var tags_value: Variant = raw.get("influence_tags", {})
		var tags := state._normalize_influence_tags(tags_value as Dictionary) if typeof(tags_value) == TYPE_DICTIONARY else {}
		state._gene_items.append({
			"item_uid": uid,
			"gene_id": gene_id,
			"locus": locus,
			"direction": direction,
			"score": score,
			"influence": score,
			"influence_tags": tags,
			"rarity": String(raw.get("rarity", "")),
			"element_lock": String(state._normalize_name(StringName(raw.get("element_lock", "")))),
			"stage_used": int(raw.get("stage_used", stage_index)),
		})
	var scores_value: Variant = data.get("gene_scores", {})
	if typeof(scores_value) == TYPE_DICTIONARY and not (scores_value as Dictionary).is_empty():
		for key in (scores_value as Dictionary).keys():
			state._gene_scores[String(key)] = float((scores_value as Dictionary)[key])
	else:
		for item in state._gene_items:
			var key := score_key(StringName(item.get("locus", "")), StringName(item.get("direction", "")))
			state._gene_scores[key] = float(state._gene_scores.get(key, 0.0)) + float(item.get("score", 0.0))
	var tags_lifetime: Variant = data.get("lifetime_tag_influences", {})
	if typeof(tags_lifetime) == TYPE_DICTIONARY:
		state._lifetime_tag_influences = state._normalize_influence_tags(tags_lifetime as Dictionary)
	if state._lifetime_tag_influences.is_empty():
		for item in state._gene_items:
			var tags: Dictionary = item.get("influence_tags", {})
			for key in tags.keys():
				state._lifetime_tag_influences[String(key)] = float(state._lifetime_tag_influences.get(String(key), 0.0)) + float(tags[key])
	var ids_value: Variant = data.get("used_gene_ids", [])
	if typeof(ids_value) == TYPE_ARRAY:
		for value in ids_value as Array:
			var gene_id := String(state._normalize_name(StringName(str(value))))
			if not gene_id.is_empty() and not state._used_gene_ids.has(gene_id):
				state._used_gene_ids.append(gene_id)
	if state._used_gene_ids.is_empty():
		for item in state._gene_items:
			var gene_id := String(item.get("gene_id", ""))
			if not gene_id.is_empty() and not state._used_gene_ids.has(gene_id):
				state._used_gene_ids.append(gene_id)
	state._used_gene_ids.sort()
	var uids_value: Variant = data.get("used_item_uids", [])
	if typeof(uids_value) == TYPE_ARRAY:
		for value in uids_value as Array:
			var uid := String(value).strip_edges()
			if not uid.is_empty() and not state._used_item_uids.has(uid):
				state._used_item_uids.append(uid)
	if state._used_item_uids.is_empty():
		for item in state._gene_items:
			var uid := String(item.get("item_uid", ""))
			if not uid.is_empty() and not state._used_item_uids.has(uid):
				state._used_item_uids.append(uid)
	return state if state.is_valid(policy) else null

static func score_key(locus: StringName, direction: StringName) -> String:
	return String(_normalize_name(locus)) + "." + String(_normalize_name(direction))

func _normalize_influence_tags(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_value in source.keys():
		var key := String(key_value).strip_edges().to_lower().replace(" ", "_")
		if not key.is_empty():
			result[key] = float(source[key_value])
	return result

func _valid_influence_tags(source: Dictionary) -> bool:
	for key_value in source.keys():
		var key := String(key_value).strip_edges()
		if key.is_empty() or float(source[key_value]) <= 0.0:
			return false
	return true

static func _normalize_name(value: StringName) -> StringName:
	return StringName(String(value).strip_edges().to_lower().replace(" ", "_"))

func _error(message: String) -> Dictionary:
	return {"ok": false, "message": message}
