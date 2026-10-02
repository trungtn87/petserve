class_name InfantGameFacade
extends RefCounted


const ElementCrystallizationServiceScript = preload(
	"res://gameplay/crystallization/element_crystallization_service.gd"
)


const META_SCHEMA: int = 5
const CRYSTALLIZATION_NOTICE_SECONDS: int = 8


var _meta: Dictionary = {}
var _generator: ItemGenerator = ItemGenerator.new()
var _inventory: InventoryService = InventoryService.new()
var _chests: ChestService = ChestService.new()
var _lifecycle: StageLifecycle = StageLifecycle.new()
var _entertainment: MiniGameRewardService = MiniGameRewardService.new()
var _crystallization = ElementCrystallizationServiceScript.new()
var _evolution_save: EvolutionSaveService = EvolutionSaveService.new()
var _legacy: LegacyInheritanceService = LegacyInheritanceService.new()
var _skills: PetSkillService = PetSkillService.new()
var _gene_policy: StageGenePolicy
var _gene_catalog: GeneCatalog = GeneCatalog.new()
var _gene_definitions: Array[GeneDefinition] = []
var _gene_state: GeneDevelopmentState
var _evolution_plan_pending: bool = false
var _crystallization_notice: Dictionary = {}
var _run_id: int = 0
var _stage_index: int = 1
var _element_id: StringName = &"neutral"


func setup(
	run_id: int,
	stage_index: int = 1,
	element_id: StringName = &"neutral",
	egg_stage: int = 1
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

	var legacy_claim := _legacy.apply_pending_to_meta(
		_meta,
		run_id
	)

	_clear_legacy_dev_test_talent()

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
	if _stage_index < StageLifecycle.FINAL_STAGE:
		_chests.ensure_daily_chest(
			_stage_index
		)
	_skills.setup(
		_meta,
		run_id,
		egg_stage
	)
	_skills.ensure_for_stage(
		_stage_index
	)
	_lifecycle.setup(
		_meta,
		run_id,
		_stage_index,
		_skills
	)

	if (
		previous_stage >= 1
		and _stage_index == previous_stage + 1
		and _stage_index < StageLifecycle.FINAL_STAGE
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

	var saved := save()

	if (
		saved
		and bool(
			legacy_claim.get(
				"applied",
				false
			)
		)
	):
		_legacy.mark_claimed(
			String(
				legacy_claim.get(
					"inheritance_id",
					""
				)
			),
			run_id
		)

	return saved


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
	state["can_evolve"] = (
		not bool(
			state.get(
				"final_form",
				false
			)
		)
		and bool(
			state.get(
				"ready_to_evolve",
				false
			)
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
	state["crystallization_notice"] = (
		_active_crystallization_notice()
	)
	state["legacy_inheritance_id"] = String(
		_meta.get(
			"legacy_inheritance_id",
			""
		)
	)
	var legacy_items_value: Variant = _meta.get(
		"legacy_inherited_items",
		[]
	)
	state["legacy_inherited_items"] = (
		(legacy_items_value as Array).duplicate(
			true
		)
		if typeof(legacy_items_value) == TYPE_ARRAY
		else []
	)
	var legacy_item_value: Variant = _meta.get(
		"legacy_inherited_item",
		{}
	)
	state["legacy_inherited_item"] = (
		(legacy_item_value as Dictionary).duplicate(
			true
		)
		if typeof(legacy_item_value) == TYPE_DICTIONARY
		else {}
	)

	var skill_state := _skills.snapshot()
	state["skills"] = skill_state.get(
		"skills",
		[]
	)
	state["skill_slots_unlocked"] = int(
		skill_state.get(
			"unlocked_slots",
			0
		)
	)
	state["skill_slots_max"] = int(
		skill_state.get(
			"max_slots",
			PetSkillCatalog.MAX_SLOTS
		)
	)
	state["skill_egg_stage4_bonus"] = bool(
		skill_state.get(
			"egg_stage4_bonus",
			false
		)
	)
	state["skill_food_preference"] = String(
		skill_state.get(
			"food_preference",
			""
		)
	)
	state["skill_night_window_start_hour"] = int(
		skill_state.get(
			"night_window_start_hour",
			0
		)
	)
	state["legacy_inherited_skill_id"] = String(
		_meta.get(
			"legacy_inherited_skill_id",
			""
		)
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
	var stage_index := int(
		lifecycle_state.get(
			"stage_index",
			1
		)
	)
	var chest_reward_enabled := (
		stage_index == 1
		and not bool(
			lifecycle_state.get(
				"ready_to_evolve",
				false
			)
		)
	)
	var before := _meta.duplicate(
		true
	)
	var result := (
		_entertainment.claim_caro_win(
			_run_id,
			stage_index,
			chest_reward_enabled
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
			match_id,
			stage_index
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
			match_id,
			stage_index
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


func start_crystallization(
	slot_index: int = -1
) -> Dictionary:
	var before := _meta.duplicate(true)
	var result := _crystallization.start(
		-1,
		slot_index
	)

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


func cancel_crystallization(
	slot_index: int = -1
) -> Dictionary:
	var before := _meta.duplicate(true)
	var result := _crystallization.cancel(
		-1,
		slot_index
	)

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
	var raw_rewards := _chests.open_next()

	if raw_rewards.is_empty():
		return []

	var rewards := _resolve_duplicate_gene_rewards(
		raw_rewards
	)

	_inventory.add_items(
		rewards
	)

	if not save():
		_restore(
			before
		)
		return []

	return rewards


func _resolve_duplicate_gene_rewards(
	rewards: Array[Dictionary]
) -> Array[Dictionary]:
	var seen_lookup: Dictionary = {}
	var seen_ids: Array[String] = []
	var seen_value: Variant = _meta.get(
		"gene_seen_ids",
		[]
	)

	if typeof(seen_value) == TYPE_ARRAY:
		for raw_id in seen_value as Array:
			var gene_id := String(
				raw_id
			)

			if gene_id.is_empty():
				continue

			if not seen_lookup.has(
				gene_id
			):
				seen_lookup[gene_id] = true
				seen_ids.append(
					gene_id
				)

	if _gene_state != null:
		for gene_id in _gene_state.used_gene_ids_snapshot():
			if (
				not gene_id.is_empty()
				and not seen_lookup.has(
					gene_id
				)
			):
				seen_lookup[gene_id] = true
				seen_ids.append(
					gene_id
				)

	for stored in _inventory.list_items():
		if StringName(
			stored.get(
				"item_type",
				""
			)
		) != ItemGenerator.TYPE_GENE:
			continue

		var stored_gene_id := String(
			stored.get(
				"gene_id",
				stored.get(
					"definition_id",
					""
				)
			)
		)

		if (
			not stored_gene_id.is_empty()
			and not seen_lookup.has(
				stored_gene_id
			)
		):
			seen_lookup[stored_gene_id] = true
			seen_ids.append(
				stored_gene_id
			)

	var resolved: Array[Dictionary] = []

	for reward in rewards:
		if StringName(
			reward.get(
				"item_type",
				""
			)
		) != ItemGenerator.TYPE_GENE:
			resolved.append(
				reward
			)
			continue

		var gene_id := String(
			reward.get(
				"gene_id",
				reward.get(
					"definition_id",
					""
				)
			)
		)

		if (
			gene_id.is_empty()
			or not seen_lookup.has(
				gene_id
			)
		):
			if not gene_id.is_empty():
				seen_lookup[gene_id] = true
				seen_ids.append(
					gene_id
				)
			resolved.append(
				reward
			)
			continue

		var fragment_seed := absi(
			hash(
				"duplicate:%s"
				% String(
					reward.get(
						"uid",
						gene_id
					)
				)
			)
		)

		if fragment_seed == 0:
			fragment_seed = 1

		var fragment := _generator.generate_gene_fragment(
			reward,
			fragment_seed,
			_generator.duplicate_gene_fragment_amount(
				String(
					reward.get(
						"rarity",
						"common"
					)
				)
			)
		)

		if fragment.is_empty():
			resolved.append(
				reward
			)
			continue

		fragment["converted_from_duplicate"] = true

		if reward.has(
			"chest_tier"
		):
			fragment["chest_tier"] = reward["chest_tier"]

		if reward.has(
			"chest_roll"
		):
			fragment["chest_roll"] = reward["chest_roll"]

		resolved.append(
			fragment
		)

	_meta["gene_seen_ids"] = seen_ids
	return resolved


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
		and float(
			state.get(
				"food_ratio",
				0.0
			)
		) <= 0.0
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
		_restore(
			before
		)
		return result

	var preserve_item := (
		item_type == ItemGenerator.TYPE_FOOD
		and _skills.should_preserve_food_item(
			uid
		)
	)

	if (
		not preserve_item
		and not _inventory.remove_item(
			uid
		)
	):
		_restore(
			before
		)
		return {
			"ok": false,
			"message": "Đã áp dụng hiệu ứng nhưng không thể cập nhật kho đồ.",
		}

	if preserve_item:
		result["item_preserved"] = true
		result["message"] = (
			String(
				result.get(
					"message",
					"Đã sử dụng vật phẩm."
				)
			)
			+ " • Chuyển Hóa Hoàn Hảo: Food không bị tiêu hao"
		)

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
	_skills.ensure_for_stage(
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
	gene_score *= _skills.item_influence_multiplier()

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
		var first_reward := rewards[0]
		var now := int(
			Time.get_unix_time_from_system()
		)
		_crystallization_notice = {
			"uid": String(
				first_reward.get(
					"uid",
					""
				)
			),
			"message": (
				"Kết tinh thành công • "
				+ String(
					first_reward.get(
						"display_name",
						"Vật phẩm"
					)
				)
			),
			"created_at_unix": now,
			"expires_at_unix": (
				now
				+ CRYSTALLIZATION_NOTICE_SECONDS
			),
		}
		changed = true

	return changed


func _active_crystallization_notice() -> Dictionary:
	if _crystallization_notice.is_empty():
		return {}

	var now := int(
		Time.get_unix_time_from_system()
	)
	var expires_at := int(
		_crystallization_notice.get(
			"expires_at_unix",
			0
		)
	)

	if expires_at <= now:
		_crystallization_notice = {}
		return {}

	return _crystallization_notice.duplicate(
		true
	)


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


func _clear_legacy_dev_test_talent() -> void:
	# Migration only: old debug builds injected an instant-evolution
	# pseudo talent. Remove it permanently so progression uses the
	# real lifecycle rules and player choices.
	var value: Variant = _meta.get(
		"talents",
		[]
	)

	if typeof(value) == TYPE_ARRAY:
		var talents := (
			value as Array
		).duplicate(true)
		talents.erase(
			"dev_instant_evolution"
		)

		if talents.is_empty():
			_meta.erase(
				"talents"
			)
		else:
			_meta["talents"] = talents

	_meta.erase(
		"dev_instant_evolution_enabled"
	)


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
	_skills.reload()
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


func energy_2048_snapshot() -> Dictionary:
	var data: Dictionary = _meta.get("energy_2048", {})
	if int(data.get("run_id", -1)) != _run_id:
		return {}
	var result := data.duplicate(true)
	result["best_score"] = int(_meta.get("energy_2048_best", 0))
	return result


func open_energy_2048() -> Dictionary:
	var session := Energy2048Session.new()
	var current := energy_2048_snapshot()
	if not current.is_empty() and session.restore(current):
		return {"ok": true, "state": current}
	session.start()
	return _commit_energy_2048(session)


func restart_energy_2048() -> Dictionary:
	var current := energy_2048_snapshot()
	if not current.is_empty() and not bool(current.get("settled", false)):
		return {"ok": false, "message": "Hãy kết thúc và nhận thưởng ván hiện tại trước."}
	var session := Energy2048Session.new()
	session.start()
	return _commit_energy_2048(session)


func move_energy_2048(direction: Vector2i) -> Dictionary:
	var session := Energy2048Session.new()
	if not session.restore(energy_2048_snapshot()):
		return {"ok": false, "message": "Không có ván đang chơi."}
	var motion := session.move(direction)
	if not bool(motion.get("changed", false)):
		return {"ok": true, "state": energy_2048_snapshot(), "changed": false}
	var result := _commit_energy_2048(session)
	if bool(result.get("ok", false)):
		result["motion"] = motion
		result["changed"] = true
	return result


func finish_energy_2048() -> Dictionary:
	var session := Energy2048Session.new()
	if not session.restore(energy_2048_snapshot()):
		return {"ok": false, "message": "Không có ván đang chơi."}
	session.finish()
	var before := _meta.duplicate(true)
	var stored := session.snapshot()
	stored["run_id"] = _run_id
	_meta["energy_2048"] = stored
	var stage := int(_lifecycle.snapshot().get("stage_index", _stage_index))
	var result := _entertainment.claim_energy_2048(_run_id, stage, session.match_id)
	if not bool(result.get("ok", false)):
		_restore(before)
		return result
	if not save():
		_restore(before)
		return {"ok": false, "message": "Chưa lưu được phần thưởng. Hãy thử lại."}
	result["state"] = energy_2048_snapshot()
	return result


func _commit_energy_2048(session: Energy2048Session) -> Dictionary:
	var before := _meta.duplicate(true)
	var stored := session.snapshot()
	stored["run_id"] = _run_id
	_meta["energy_2048"] = stored
	_meta["energy_2048_best"] = maxi(int(_meta.get("energy_2048_best", 0)), session.score)
	if not save():
		_restore(before)
		return {"ok": false, "message": "Chưa lưu được ván 2048. Hãy thử lại."}
	return {"ok": true, "state": energy_2048_snapshot()}


# Tetris runs in memory: leaving the activity forfeits the unfinished match.
# Only this facade owns the score used for settlement; UI never submits a score.
var _tetris_session: TetrisSession

func tetris_records() -> Dictionary:
	if not _meta.has("tetris_records"):
		_meta["tetris_records"] = TetrisRecords.load_archive()
	return (_meta["tetris_records"] as Dictionary).duplicate(true)

func tetris_snapshot() -> Dictionary:
	if _tetris_session == null:
		return {}
	var state := _tetris_session.snapshot()
	state["best_score"] = TetrisRecords.top_score(tetris_records())
	return state

func start_tetris() -> Dictionary:
	if _tetris_session != null and not _tetris_session.settled:
		return {"ok": false, "message": "Hãy hoàn thành hoặc rời ván hiện tại trước."}
	_tetris_session = TetrisSession.new()
	_tetris_session.start()
	return {"ok": true, "state": tetris_snapshot()}

func abandon_tetris() -> void:
	_tetris_session = null

func tick_tetris(delta: float) -> Dictionary:
	if _tetris_session == null:
		return {}
	var changed := _tetris_session.tick(delta)
	return {"ok": true, "changed": changed, "state": tetris_snapshot()} if changed else {"ok": true, "changed": false}

func action_tetris(action: String) -> Dictionary:
	if _tetris_session == null or _tetris_session.status != "playing":
		return {"ok": false}
	match action:
		"left": _tetris_session.move_horizontal(-1)
		"right": _tetris_session.move_horizontal(1)
		"rotate": _tetris_session.rotate_piece()
		"down": _tetris_session.soft_drop()
		"drop": _tetris_session.hard_drop()
		_: return {"ok": false}
	return {"ok": true, "state": tetris_snapshot()}

func settle_tetris() -> Dictionary:
	if _tetris_session == null or _tetris_session.status != "lost" or _tetris_session.settled:
		return {"ok": false, "message": "Ván chưa kết thúc hoặc đã nhận thưởng."}
	tetris_records()
	var before := _meta.duplicate(true)
	var records: Dictionary = _meta["tetris_records"]
	var now := int(Time.get_unix_time_from_system())
	var day := Time.get_date_string_from_system()
	var result := TetrisRecords.record(records, _tetris_session, day, now)
	var stage := int(_lifecycle.snapshot().get("stage_index", _stage_index))
	var amount := _tetris_session.fragments()
	var crafted := _chests.add_salvage_fragments(amount, _run_id, stage)
	if int(result.bonus_chests) > 0:
		_chests.add_salvage_fragments(ChestService.FRAGMENTS_PER_RECYCLED_CHEST, _run_id, stage)
	if not save():
		_restore(before)
		return {"ok": false, "message": "Chưa lưu được thưởng. Bấm Nhận thưởng để thử lại."}
	_tetris_session.settled = true
	result["ok"] = true
	result["fragments"] = amount
	result["crafted"] = crafted
	result["state"] = tetris_snapshot()
	result["message"] = "Nhận %d mảnh rương" % amount
	if crafted > 0:
		result.message += " • Đã ghép %d rương" % crafted
	if bool(result.broken_record):
		result.message += " • Kỷ lục mới!"
	if int(result.bonus_chests) > 0:
		result.message += " • Thưởng top 1: +1 rương"
	elif bool(result.broken_record):
		result.message += " • Hôm nay đã nhận rương top 1"
	return result


func tank_records(duo: bool) -> Dictionary:
	var key := "tank_records_duo" if duo else "tank_records_solo"
	if not _meta.has(key):
		var archive := AtomicJson.read("user://" + key + ".json")
		_meta[key] = archive if archive is Dictionary else {}
	return (_meta[key] as Dictionary).duplicate(true)

func settle_tank(state: Dictionary, slot: int) -> Dictionary:
	if state.get("status") != "lost" or str(state.get("match_id", "")).is_empty():
		return {"ok": false, "message": "Ván chưa kết thúc."}
	var players: Array = state.get("players", [])
	if slot < 0 or slot >= players.size():
		return {"ok": false, "message": "Người chơi không hợp lệ."}
	var ids: Array = _meta.get("tank_claimed_ids", [])
	if ids.has(state.match_id):
		return {"ok": false, "message": "Ván đã nhận thưởng."}
	var before := _meta.duplicate(true)
	var duo := bool(state.get("duo", false))
	var key := "tank_records_duo" if duo else "tank_records_solo"
	var records := tank_records(duo)
	var score := maxi(0, int(state.get("team_score", 0)))
	var broken := score > maxi(5000, int(records.get("best_score", 5000)))
	var day := Time.get_date_string_from_system()
	var bonus := broken and day > str(records.get("last_bonus_day", ""))
	var entries: Array = records.get("entries", [])
	entries.append({"score":score,"wave":int(state.get("wave",1)),"at_unix":int(Time.get_unix_time_from_system())})
	entries.sort_custom(func(a: Dictionary,b: Dictionary): return int(a.score)>int(b.score))
	if entries.size() > 10:
		entries.resize(10)
	records["entries"] = entries
	records["best_score"] = maxi(score,maxi(5000,int(records.get("best_score",5000))))
	if bonus:
		records["last_bonus_day"] = day
	_meta[key] = records
	ids.append(state.match_id)
	_meta["tank_claimed_ids"] = ids
	var stage := int(_lifecycle.snapshot().get("stage_index", _stage_index))
	var fragments := maxi(0,int(players[slot].score)) / 1000
	var crafted := _chests.add_salvage_fragments(fragments + (10 if bonus else 0),_run_id,stage)
	if not save():
		_restore(before)
		return {"ok":false,"message":"Chưa lưu được thưởng. Bấm Nhận thưởng để thử lại."}
	return {"ok":true,"fragments":fragments,"bonus_chests":1 if bonus else 0,"crafted":crafted,
		"message":"Nhận %d mảnh%s%s" % [fragments," • Kỷ lục mới!" if broken else ""," • +1 rương top 1" if bonus else ""]}


func sudoku_snapshot() -> Dictionary:
	var data: Dictionary = _meta.get("sudoku", {})
	return data.duplicate(true) if int(data.get("run_id", -1)) == _run_id else {}

func open_sudoku(level: int = 0, restart: bool = false) -> Dictionary:
	var session := SudokuSession.new()
	if not restart and session.restore(sudoku_snapshot()):
		return {"ok": true, "state": session.snapshot()}
	if restart and session.restore(sudoku_snapshot()) and session.complete() and not session.settled:
		return {"ok": false, "message": "Nhận thưởng ván đã hoàn thành trước."}
	session.start(level)
	return _commit_sudoku(session)

func enter_sudoku(index: int, value: int, note: bool = false) -> Dictionary:
	var session := SudokuSession.new()
	if not session.restore(sudoku_snapshot()):
		return {"ok": false, "message": "Không có ván Sudoku."}
	session.enter(index, value, note)
	return _commit_sudoku(session)

func undo_sudoku() -> Dictionary:
	var session := SudokuSession.new()
	if not session.restore(sudoku_snapshot()):
		return {"ok": false}
	session.undo()
	return _commit_sudoku(session)

func settle_sudoku() -> Dictionary:
	var session := SudokuSession.new()
	if not session.restore(sudoku_snapshot()) or not session.complete() or session.settled:
		return {"ok": false, "message": "Ván chưa hoàn thành hoặc đã nhận thưởng."}
	var before := _meta.duplicate(true)
	session.settled = true
	var stored := session.snapshot()
	stored["run_id"] = _run_id
	_meta["sudoku"] = stored
	var amount: int = SudokuRules.REWARDS[session.level]
	var stage := int(_lifecycle.snapshot().get("stage_index", _stage_index))
	_chests.add_salvage_fragments(amount * ChestService.FRAGMENTS_PER_RECYCLED_CHEST, _run_id, stage)
	if not save():
		_restore(before)
		return {"ok": false, "message": "Chưa lưu được thưởng. Bấm Nhận thưởng để thử lại."}
	return {"ok": true, "state": sudoku_snapshot(), "chests": amount, "message": "Đã nhận %d rương." % amount}

func _commit_sudoku(session: SudokuSession) -> Dictionary:
	var before := _meta.duplicate(true)
	var stored := session.snapshot()
	stored["run_id"] = _run_id
	_meta["sudoku"] = stored
	if not save():
		_restore(before)
		return {"ok": false, "message": "Chưa lưu được ván. Hãy thử lại."}
	return {"ok": true, "state": sudoku_snapshot()}


var _breakout_session: BreakoutSession

func breakout_progress() -> Dictionary:
	var cleared: Array[int] = []
	var stored: Variant = _meta.get("breakout_cleared", [])
	if stored is Array:
		for value in stored:
			var level := int(value)
			if level >= 1 and level <= BreakoutMaps.COUNT and not cleared.has(level):
				cleared.append(level)
	return {"unlocked": clampi(int(_meta.get("breakout_unlocked", 1)), 1, BreakoutMaps.COUNT), "cleared": cleared}

func breakout_snapshot() -> Dictionary:
	return _breakout_session.snapshot() if _breakout_session != null else {}

func open_breakout() -> Dictionary:
	if _breakout_session != null:
		return {"ok": true, "state": breakout_snapshot(), "progress": breakout_progress()}
	var saved: Dictionary = _meta.get("breakout", {})
	var session := BreakoutSession.new()
	if int(saved.get("run_id", -1)) == _run_id and session.restore(saved):
		_breakout_session = session
		return {"ok": true, "state": breakout_snapshot(), "progress": breakout_progress()}
	return start_breakout(int(breakout_progress().unlocked))

func start_breakout(level: int) -> Dictionary:
	if level < 1 or level > int(breakout_progress().unlocked):
		return {"ok": false, "message": "Vượt màn trước để mở màn này."}
	if _breakout_session != null and _breakout_session.status == "won" and not _breakout_session.settled:
		return {"ok": false, "message": "Nhận thưởng màn đã hoàn thành trước."}
	var previous := _breakout_session
	_breakout_session = BreakoutSession.new()
	_breakout_session.start(level)
	var result := checkpoint_breakout()
	if not bool(result.get("ok", false)):
		_breakout_session = previous
	return result

func tick_breakout(delta: float, x: float, launch: bool = false) -> Dictionary:
	if _breakout_session == null:
		return {"ok": false}
	_breakout_session.set_paddle(x)
	if launch:
		_breakout_session.launch()
	_breakout_session.tick(delta)
	return {"ok": true, "state": breakout_snapshot()}

func checkpoint_breakout() -> Dictionary:
	if _breakout_session == null:
		return {"ok": false}
	var before := _meta.duplicate(true)
	var stored := breakout_snapshot()
	stored["run_id"] = _run_id
	_meta["breakout"] = stored
	if not save():
		_restore(before)
		return {"ok": false, "message": "Chưa lưu được màn chơi. Hãy thử lại."}
	return {"ok": true, "state": breakout_snapshot(), "progress": breakout_progress()}

func settle_breakout() -> Dictionary:
	if _breakout_session == null or _breakout_session.status != "won" or _breakout_session.remaining() != 0 or _breakout_session.settled:
		return {"ok": false, "message": "Màn chưa hoàn thành hoặc đã nhận thưởng."}
	var before := _meta.duplicate(true)
	var cleared: Array = breakout_progress().cleared.duplicate()
	var level := _breakout_session.level
	var first := not cleared.has(level)
	if first:
		cleared.append(level)
	_meta["breakout_cleared"] = cleared
	_meta["breakout_unlocked"] = mini(BreakoutMaps.COUNT, maxi(int(breakout_progress().unlocked), level + 1))
	if first:
		var stage := int(_lifecycle.snapshot().get("stage_index", _stage_index))
		_chests.add_salvage_fragments(1, _run_id, stage)
	_breakout_session.settled = true
	var stored := breakout_snapshot()
	stored["run_id"] = _run_id
	_meta["breakout"] = stored
	if not save():
		_restore(before)
		_breakout_session.settled = false
		return {"ok": false, "message": "Chưa lưu được kết quả. Bấm Nhận thưởng để thử lại."}
	return {"ok": true, "state": breakout_snapshot(), "progress": breakout_progress(), "fragments": 1 if first else 0,
		"message": "Vượt màn! +1 mảnh rương." if first else "Đã vượt lại màn này • Thưởng lần đầu đã nhận."}
