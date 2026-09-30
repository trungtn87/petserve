class_name InfantGameFacade
extends RefCounted


const ElementCrystallizationServiceScript = preload(
	"res://gameplay/crystallization/element_crystallization_service.gd"
)


const META_SCHEMA: int = 4
const DEV_INSTANT_EVOLUTION_TALENT: StringName = &"dev_instant_evolution"


var _meta: Dictionary = {}
var _generator: ItemGenerator = ItemGenerator.new()
var _inventory: InventoryService = InventoryService.new()
var _chests: ChestService = ChestService.new()
var _lifecycle: StageLifecycle = StageLifecycle.new()
var _entertainment: MiniGameRewardService = MiniGameRewardService.new()
var _crystallization = ElementCrystallizationServiceScript.new()
var _evolution_save: EvolutionSaveService = EvolutionSaveService.new()
var _gene_policy: StageGenePolicy
var _gene_catalog: GeneCatalog = GeneCatalog.new()
var _gene_definitions: Array[GeneDefinition] = []
var _gene_state: GeneDevelopmentState
var _evolution_plan_pending: bool = false
var _run_id: int = 0
var _stage_index: int = 1
var _element_id: StringName = &"neutral"


func setup(
	run_id: int,
	stage_index: int = 1,
	element_id: StringName = &"neutral"
) -> bool:
	_run_id = run_id
	_stage_index = maxi(
		1,
		stage_index
	)
	_element_id = element_id
	_meta = SaveManager.load_meta()
	_evolution_plan_pending = _load_pending_evolution_state()

	if _meta.is_empty():
		_meta = {
			"schema": META_SCHEMA,
			"inventory": [],
			"chest_queue": [],
		}
	else:
		_meta["schema"] = META_SCHEMA

	_sanitize_dev_test_talent()

	_gene_policy = StageGenePolicy.load_default()
	_gene_definitions = (
		_gene_catalog.load_default()
	)

	if (
		_gene_policy == null
		or _gene_definitions.is_empty()
	):
		return false

	var previous_stage := _saved_stage_index()

	_inventory.setup(
		_meta
	)
	_chests.setup(
		_meta,
		_generator
	)
	_chests.ensure_hatch_chest(
		run_id
	)
	_chests.ensure_daily_chest(
		_stage_index
	)
	_lifecycle.setup(
		_meta,
		run_id,
		_stage_index
	)

	if (
		previous_stage >= 1
		and _stage_index == previous_stage + 1
	):
		_chests.ensure_evolution_chest(
			run_id,
			previous_stage,
			_stage_index
		)
	_setup_gene_state(
		int(
			_lifecycle.snapshot().get(
				"stage_index",
				_stage_index
			)
		)
	)
	_crystallization.setup(
		_meta,
		_generator,
		_gene_definitions,
		_gene_policy,
		_run_id,
		_stage_index,
		_element_id
	)
	_apply_crystallization_update(
		_crystallization.process()
	)
	_entertainment.setup(
		_meta,
		_chests,
		run_id
	)

	return save()


func tick(
	delta: float
) -> void:
	var should_save := _lifecycle.tick(
		delta
	)
	var crystallization_changed := (
		_apply_crystallization_update(
			_crystallization.process()
		)
	)

	if should_save or crystallization_changed:
		save()


func save() -> bool:
	_sync_gene_meta()
	return SaveManager.save_meta(
		_meta
	)


func snapshot() -> Dictionary:
	var state := _lifecycle.snapshot()
	var has_instant_evolution := _has_talent(
		DEV_INSTANT_EVOLUTION_TALENT
	)

	state["talents"] = _talent_ids()
	state["instant_evolution_talent"] = has_instant_evolution
	state["can_evolve"] = (
		not bool(
			state.get(
				"final_form",
				false
			)
		)
		and (
			bool(
				state.get(
					"ready_to_evolve",
					false
				)
			)
			or has_instant_evolution
		)
	)

	state["pending_chests"] = (
		_chests.pending_count()
	)
	state["inventory_count"] = (
		_inventory.count()
	)
	state["chest_fragments"] = (
		_chests.fragment_count()
	)
	state["chest_fragments_required"] = (
		ChestService.FRAGMENTS_PER_RECYCLED_CHEST
	)
	state["evolution_plan_pending"] = (
		_evolution_plan_pending
	)
	state["crystallization"] = (
		_crystallization.snapshot()
	)

	if (
		_gene_policy != null
		and _gene_state != null
	):
		var current_stage := int(
			state.get(
				"stage_index",
				_stage_index
			)
		)
		state["gene_items_used"] = _gene_state.item_count()
		state["gene_items_used_lifetime"] = _gene_state.lifetime_gene_count()
		state["gene_item_limit"] = _gene_policy.max_gene_items(
			current_stage
		)
		state["gene_unlimited"] = _gene_policy.is_unlimited(
			current_stage
		)
		state["gene_slots_remaining"] = -1
		state["gene_influences"] = _gene_state.influences_snapshot()
		state["gene_tag_influences"] = _gene_state.tag_influences_snapshot()
		state["gene_scores"] = _gene_state.gene_scores_snapshot()
		state["gene_lifetime_tag_influences"] = (
			_gene_state.lifetime_tag_influences_snapshot()
		)
		state["gene_development"] = _gene_state.to_dict()
	else:
		state["gene_items_used"] = 0
		state["gene_items_used_lifetime"] = 0
		state["gene_item_limit"] = 0
		state["gene_unlimited"] = false
		state["gene_slots_remaining"] = 0
		state["gene_influences"] = {}
		state["gene_tag_influences"] = {}
		state["gene_scores"] = {}
		state["gene_lifetime_tag_influences"] = {}
		state["gene_development"] = {}

	var entertainment_state := (
		_entertainment.snapshot(
			_run_id
		)
	)

	for key in entertainment_state.keys():
		state[key] = (
			entertainment_state[key]
		)

	return state


func claim_caro_win_reward() -> Dictionary:
	var lifecycle_state := (
		_lifecycle.snapshot()
	)

	if (
		int(
			lifecycle_state.get(
				"stage_index",
				1
			)
		) != 1
		or bool(
			lifecycle_state.get(
				"ready_to_evolve",
				false
			)
		)
	):
		return {
			"ok": false,
			"rewarded": false,
			"message": "Thưởng Caro giới hạn ở giai đoạn Ấu thể.",
		}

	var before := _meta.duplicate(
		true
	)
	var result := (
		_entertainment.claim_caro_win(
			_run_id
		)
	)

	if bool(
		result.get(
			"rewarded",
			false
		)
	):
		if not save():
			_restore(
				before
			)
			return {
				"ok": false,
				"rewarded": false,
				"message": "Chưa lưu được phần thưởng. Hãy thử lại.",
			}

	return result


func claim_obstacle_run_reward(
	score: int,
	match_id: String
) -> Dictionary:
	var lifecycle_state := (
		_lifecycle.snapshot()
	)
	var stage_index := int(
		lifecycle_state.get(
			"stage_index",
			1
		)
	)

	if stage_index != 2:
		return {
			"ok": false,
			"rewarded": false,
			"message": "Rương Vượt chướng ngại chỉ nhận được trong Stage 2.",
		}

	var before := _meta.duplicate(
		true
	)
	var result := (
		_entertainment.claim_obstacle_run(
			_run_id,
			maxi(
				0,
				score
			),
			match_id
		)
	)

	if bool(
		result.get(
			"rewarded",
			false
		)
	):
		if not save():
			_restore(
				before
			)
			return {
				"ok": false,
				"rewarded": false,
				"message": "Chưa lưu được phần thưởng. Hãy thử lại.",
			}

	return result


func claim_snake_hunt_reward(
	score: int,
	match_id: String
) -> Dictionary:
	var lifecycle_state := (
		_lifecycle.snapshot()
	)
	var stage_index := int(
		lifecycle_state.get(
			"stage_index",
			1
		)
	)

	if stage_index != 2:
		return {
			"ok": false,
			"rewarded": false,
			"message": "Rương Snake Hunt chỉ nhận được trong Stage 2.",
		}

	var before := _meta.duplicate(
		true
	)
	var result := (
		_entertainment.claim_snake_hunt(
			_run_id,
			maxi(
				0,
				score
			),
			match_id
		)
	)

	if bool(
		result.get(
			"rewarded",
			false
		)
	):
		if not save():
			_restore(
				before
			)
			return {
				"ok": false,
				"rewarded": false,
				"message": "Chưa lưu được phần thưởng. Hãy thử lại.",
			}

	return result


func inventory(
	filter_type: StringName = &""
) -> Array[Dictionary]:
	return _inventory.list_items(
		filter_type
	)


func start_crystallization() -> Dictionary:
	var before := _meta.duplicate(true)
	var result := _crystallization.start()

	if not bool(
		result.get(
			"ok",
			false
		)
	):
		return result

	if not save():
		_restore(before)
		return {
			"ok": false,
			"message": "Chưa lưu được lượt kết tinh. Hãy thử lại.",
		}

	return result


func cancel_crystallization() -> Dictionary:
	var before := _meta.duplicate(true)
	var result := _crystallization.cancel()

	if not bool(
		result.get(
			"ok",
			false
		)
	):
		return result

	if not save():
		_restore(before)
		return {
			"ok": false,
			"message": "Chưa lưu được thay đổi. Lượt kết tinh vẫn được giữ.",
		}

	return result


func open_next_chest() -> Array[Dictionary]:
	var before := _meta.duplicate(
		true
	)
	var rewards := _chests.open_next()

	if rewards.is_empty():
		return []

	_inventory.add_items(
		rewards
	)

	if not save():
		_restore(
			before
		)
		return []

	return rewards


func can_use_item(
	item: Dictionary
) -> bool:
	var state := _lifecycle.snapshot()
	var stage_index := int(
		state.get(
			"stage_index",
			_stage_index
		)
	)
	var item_type := StringName(
		item.get(
			"item_type",
			""
		)
	)

	if (
		item_type == ItemGenerator.TYPE_GENE
		and _evolution_plan_pending
	):
		return false

	if bool(
		state.get(
			"ready_to_evolve",
			false
		)
	):
		return false

	if (
		item_type == ItemGenerator.TYPE_GENE
		and bool(
			state.get(
				"hibernating",
				false
			)
		)
	):
		return false

	if not _inventory.can_use_in_stage(
		item,
		stage_index,
		_gene_policy
	):
		return false

	if item_type == ItemGenerator.TYPE_GENE:
		var definition := _gene_definition_for_item(
			item
		)
		return (
			_gene_state != null
			and definition != null
			and definition.is_element_compatible(
				_element_id
			)
			and _gene_state.can_record(
				_gene_policy,
				definition.locus()
			)
		)

	return true


func gene_item_context(
	item: Dictionary
) -> Dictionary:
	if (
		_gene_policy == null
		or _gene_state == null
		or StringName(
			item.get(
				"item_type",
				""
			)
		) != ItemGenerator.TYPE_GENE
	):
		return {}

	var definition := _gene_definition_for_item(
		item
	)
	if definition == null:
		return {}

	var locus := definition.locus()
	var direction := definition.direction()
	var allowed_stages: Array[int] = []

	for stage_index in range(
		StageGenePolicy.FIRST_STAGE,
		StageGenePolicy.FINAL_STAGE + 1
	):
		if _gene_policy.can_accept_gene(
			stage_index,
			locus
		):
			allowed_stages.append(
				stage_index
			)

	var lifecycle_state := _lifecycle.snapshot()
	var current_stage := int(
		lifecycle_state.get(
			"stage_index",
			_stage_index
		)
	)
	var current_score := _gene_state.score_for(
		locus,
		direction
	)
	var item_score := float(
		item.get(
			"gene_score",
			item.get(
				"gene_influence",
				definition.primary_influence()
			)
		)
	)
	var projected_score := current_score + item_score
	var current_tier := GeneExpressionScale.tier_for_score(
		current_score
	)
	var projected_tier := GeneExpressionScale.tier_for_score(
		projected_score
	)
	var element_lock := definition.element_lock()
	var element_compatible := definition.is_element_compatible(
		_element_id
	)

	return {
		"locus": String(locus),
		"direction": String(direction),
		"allowed_stages": allowed_stages,
		"current_stage": current_stage,
		"item_score": item_score,
		"current_score": current_score,
		"projected_score": projected_score,
		"current_tier": String(current_tier),
		"projected_tier": String(projected_tier),
		"current_tier_label": GeneExpressionScale.tier_label_vi(
			current_tier
		),
		"projected_tier_label": GeneExpressionScale.tier_label_vi(
			projected_tier
		),
		"next_threshold": GeneExpressionScale.next_threshold(
			projected_score
		),
		"lifetime_gene_items_used": _gene_state.lifetime_gene_count(),
		"element_lock": String(element_lock),
		"element_compatible": element_compatible,
		"evolution_plan_pending": _evolution_plan_pending,
		"ready_to_evolve": bool(
			lifecycle_state.get(
				"ready_to_evolve",
				false
			)
		),
		"usable_now": can_use_item(
			item
		),
	}


func use_item(
	uid: String
) -> Dictionary:
	var item := _inventory.get_item(
		uid
	)

	if item.is_empty():
		return {
			"ok": false,
			"message": "Không tìm thấy vật phẩm.",
		}

	var item_type := StringName(
		item.get(
			"item_type",
			""
		)
	)

	if (
		item_type == ItemGenerator.TYPE_GENE
		and _evolution_plan_pending
	):
		return {
			"ok": false,
			"message": "Đang chờ hoàn tất tiến hóa. Gene Item được giữ trong Hòm Item.",
		}

	var stage_index := int(
		_lifecycle.snapshot().get(
			"stage_index",
			_stage_index
		)
	)

	if not _inventory.can_use_in_stage(
		item,
		stage_index,
		_gene_policy
	):
		return {
			"ok": false,
			"message": "Vật phẩm này chưa dùng được ở giai đoạn hiện tại.",
		}

	var before := _meta.duplicate(
		true
	)

	if item_type == ItemGenerator.TYPE_GENE:
		return _use_gene_item(
			item,
			before
		)

	var result := _lifecycle.apply_item(
		item
	)

	if not bool(
		result.get(
			"ok",
			false
		)
	):
		return result

	if not _inventory.remove_item(
		uid
	):
		_restore(
			before
		)
		return {
			"ok": false,
			"message": "Đã áp dụng hiệu ứng nhưng không thể cập nhật kho đồ.",
		}

	_meta["growth_items_used"] = int(
		_meta.get(
			"growth_items_used",
			0
		)
	) + 1

	if stage_index == 1:
		_meta["infant_items_used"] = int(
			_meta.get(
				"infant_items_used",
				0
			)
		) + 1

	if not save():
		_restore(
			before
		)
		return {
			"ok": false,
			"message": "Chưa lưu được. Vật phẩm vẫn còn trong kho.",
		}

	return result


func salvage_item(
	uid: String
) -> Dictionary:
	var item := _inventory.get_item(
		uid
	)

	if item.is_empty():
		return {
			"ok": false,
			"message": "Không tìm thấy vật phẩm để phân giải.",
		}

	var before := _meta.duplicate(
		true
	)

	if not _inventory.remove_item(
		uid
	):
		return {
			"ok": false,
			"message": "Không thể lấy vật phẩm khỏi Hòm Item.",
		}

	var stage_index := int(
		_lifecycle.snapshot().get(
			"stage_index",
			_stage_index
		)
	)
	var crafted := _chests.add_salvage_fragments(
		1,
		_run_id,
		stage_index
	)

	if not save():
		_restore(
			before
		)
		return {
			"ok": false,
			"message": "Chưa lưu được. Vật phẩm vẫn còn trong Hòm Item.",
		}

	var fragments := _chests.fragment_count()
	var message := (
		"Đã phân giải thành 1 mảnh rương • %d/%d"
		% [
			fragments,
			ChestService.FRAGMENTS_PER_RECYCLED_CHEST,
		]
	)

	if crafted > 0:
		message = (
			"Đủ 10 mảnh • đã ghép %d Rương Tái Chế"
			% crafted
		)

	return {
		"ok": true,
		"fragments": fragments,
		"crafted_chests": crafted,
		"message": message,
	}


func describe_item(
	item: Dictionary
) -> String:
	return _generator.describe(
		item
	)


func rarity_label(
	rarity: String
) -> String:
	return _generator.rarity_label(
		rarity
	)


func quality_label(
	quality: String
) -> String:
	return _generator.quality_label(
		quality
	)


func property_label(
	value: StringName
) -> String:
	return _generator.property_label(
		value
	)


func defect_label(
	value: StringName
) -> String:
	return _generator.defect_label(
		value
	)


func complete_infant() -> bool:
	return advance_to_stage(
		2
	)


func advance_to_stage(
	stage_index: int
) -> bool:
	var previous_stage := int(
		_lifecycle.snapshot().get(
			"stage_index",
			_stage_index
		)
	)

	_stage_index = stage_index
	_lifecycle.advance_to_stage(
		stage_index
	)

	if stage_index == previous_stage + 1:
		_chests.ensure_evolution_chest(
			_run_id,
			previous_stage,
			stage_index
		)

	if _gene_state == null:
		_gene_state = GeneDevelopmentState.new(
			stage_index
		)
	else:
		_gene_state.reset_for_stage(
			stage_index
		)

	_crystallization.update_context(
		stage_index,
		_element_id
	)
	_sync_gene_meta()
	return save()


func _use_gene_item(
	item: Dictionary,
	before: Dictionary
) -> Dictionary:
	if (
		_gene_policy == null
		or _gene_state == null
	):
		return {
			"ok": false,
			"message": "Hệ Gene chưa sẵn sàng.",
		}

	var definition := _gene_definition_for_item(
		item
	)

	if definition == null:
		return {
			"ok": false,
			"message": "Gene Item không có định nghĩa hợp lệ.",
		}

	if not definition.is_element_compatible(
		_element_id
	):
		return {
			"ok": false,
			"message": (
				"Gene hiệu ứng thuộc hệ %s. Item được giữ lại để dùng hoặc kế thừa cho pet phù hợp."
				% PetElementCatalog.prompt_name(
					definition.element_lock()
				)
			),
		}

	var influence_tags := definition.influence_tags()
	var item_tags_value: Variant = item.get(
		"influence_tags",
		{}
	)

	if typeof(item_tags_value) == TYPE_DICTIONARY:
		influence_tags = (
			item_tags_value as Dictionary
		).duplicate(true)

	var gene_score := float(
		item.get(
			"gene_score",
			item.get(
				"gene_influence",
				definition.primary_influence()
			)
		)
	)
	var result := _gene_state.record_gene_item(
		_gene_policy,
		String(
			item.get(
				"uid",
				""
			)
		),
		definition.id(),
		definition.locus(),
		definition.direction(),
		gene_score,
		influence_tags,
		String(
			item.get(
				"rarity",
				""
			)
		),
		definition.element_lock()
	)

	if not bool(
		result.get(
			"ok",
			false
		)
	):
		return result

	var growth_result := (
		_lifecycle.apply_growth_bonus_percent(
			float(
				item.get(
					"growth_bonus_percent",
					ItemGenerator.GENE_GROWTH_BONUS_PERCENT
				)
			)
		)
	)

	if not bool(
		growth_result.get(
			"ok",
			false
		)
	):
		_restore(
			before
		)
		return growth_result

	if not _inventory.remove_item(
		String(
			item.get(
				"uid",
				""
			)
		)
	):
		_restore(
			before
		)
		return {
			"ok": false,
			"message": "Không thể cập nhật Hòm Item.",
		}

	_meta["gene_items_used_total"] = int(
		_meta.get(
			"gene_items_used_total",
			0
		)
	) + 1
	_sync_gene_meta()

	if not save():
		_restore(
			before
		)
		return {
			"ok": false,
			"message": "Chưa lưu được. Gene Item vẫn còn trong Hòm Item.",
		}

	result["growth_bonus_percent"] = float(
		growth_result.get(
			"growth_bonus_percent",
			0.0
		)
	)
	result["growth_delta_seconds"] = int(
		growth_result.get(
			"growth_delta_seconds",
			0
		)
	)
	result["ready_to_evolve"] = bool(
		growth_result.get(
			"ready_to_evolve",
			false
		)
	)
	result["message"] = (
		"Đã sử dụng %s • Điểm Gene +%d → %d • %s • Growth +%d%%"
		% [
			String(
				item.get(
					"display_name",
					"Gene Item"
				)
			),
			int(
				round(
					float(
						result.get(
							"score_added",
							gene_score
						)
					)
				)
			),
			int(
				round(
					float(
						result.get(
							"total_score",
							gene_score
						)
					)
				)
			),
			GeneExpressionScale.tier_label_vi(
				StringName(
					result.get(
						"expression_tier",
						"none"
					)
				)
			),
			int(
				round(
					float(
						result.get(
							"growth_bonus_percent",
							0.0
						)
					)
				)
			),
		]
	)
	return result


func _apply_crystallization_update(
	update: Dictionary
) -> bool:
	var changed := bool(
		update.get(
			"changed",
			false
		)
	)
	var rewards_value: Variant = update.get(
		"rewards",
		[]
	)

	if typeof(rewards_value) != TYPE_ARRAY:
		return changed

	var rewards: Array[Dictionary] = []

	for raw_value in rewards_value as Array:
		if typeof(raw_value) != TYPE_DICTIONARY:
			continue
		rewards.append(
			(raw_value as Dictionary).duplicate(true)
		)

	if not rewards.is_empty():
		_inventory.add_items(rewards)
		changed = true

	return changed


func _gene_definition_for_item(
	item: Dictionary
) -> GeneDefinition:
	if StringName(
		item.get(
			"item_type",
			""
		)
	) != ItemGenerator.TYPE_GENE:
		return null

	return _gene_catalog.find_by_id(
		_gene_definitions,
		StringName(
			item.get(
				"definition_id",
				item.get(
					"gene_id",
					""
				)
			)
		)
	)


func _setup_gene_state(
	stage_index: int
) -> void:
	var value: Variant = _meta.get(
		"gene_development",
		{}
	)
	var restored: GeneDevelopmentState = null

	if typeof(value) == TYPE_DICTIONARY:
		restored = (
			GeneDevelopmentState.from_dict(
				value as Dictionary,
				_gene_policy
			)
		)

	if restored == null:
		restored = GeneDevelopmentState.new(
			stage_index
		)
	elif restored.stage_index() != stage_index:
		restored.reset_for_stage(
			stage_index
		)

	_gene_state = restored
	_sync_gene_meta()


func _sync_gene_meta() -> void:
	if _gene_state == null:
		return

	_meta["gene_development"] = _gene_state.to_dict()
	_meta["gene_scores"] = _gene_state.gene_scores_snapshot()
	_meta["gene_items_used"] = _gene_state.item_count()
	_meta["gene_items_used_lifetime"] = _gene_state.lifetime_gene_count()


func set_dev_instant_evolution_enabled(
	enabled: bool
) -> bool:
	if not OS.is_debug_build():
		return false

	_meta["dev_instant_evolution_enabled"] = enabled
	_sanitize_dev_test_talent()
	return save()


func _sanitize_dev_test_talent() -> void:
	var talents := _talent_ids()
	var talent_id := String(
		DEV_INSTANT_EVOLUTION_TALENT
	)
	var enabled := OS.is_debug_build()
	_meta["dev_instant_evolution_enabled"] = enabled

	if enabled:
		if not talents.has(
			talent_id
		):
			talents.append(
				talent_id
			)
	else:
		talents.erase(
			talent_id
		)
		_meta["dev_instant_evolution_enabled"] = false

	_meta["talents"] = talents


func _talent_ids() -> Array:
	var value: Variant = _meta.get(
		"talents",
		[]
	)

	if typeof(value) != TYPE_ARRAY:
		return []

	return (
		value as Array
	).duplicate(true)


func _has_talent(
	talent_id: StringName
) -> bool:
	var expected := String(
		talent_id
	)

	for value in _talent_ids():
		if str(value) == expected:
			return true

	return false


func _saved_stage_index() -> int:
	for key in [
		"life_state",
		"infant_state",
	]:
		var value: Variant = _meta.get(
			key,
			{}
		)

		if typeof(value) != TYPE_DICTIONARY:
			continue

		var state := value as Dictionary

		if state.is_empty():
			continue

		return int(
			state.get(
				"stage_index",
				1
			)
		)

	return 0


func _load_pending_evolution_state() -> bool:
	var data := _evolution_save.load_data()
	var value: Variant = data.get(
		"pending_evolution",
		{}
	)

	return (
		typeof(value) == TYPE_DICTIONARY
		and not (value as Dictionary).is_empty()
	)


func _restore(
	before: Dictionary
) -> void:
	_meta.clear()
	_meta.merge(
		before,
		true
	)
	_inventory.setup(
		_meta
	)
	_lifecycle.restore_state()

	if _gene_policy != null:
		_setup_gene_state(
			int(
				_lifecycle.snapshot().get(
					"stage_index",
					_stage_index
				)
			)
		)
